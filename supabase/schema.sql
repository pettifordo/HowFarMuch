-- How Far/Much — Friends v2 schema (run in Supabase SQL editor).
-- Security lives in Row-Level Security: a user can read another user's summary
-- only if an accepted friendship exists between them.
-- Safe to re-run: uses create-or-replace / if-not-exists / drop-if-exists.

create extension if not exists citext;

-- updated_at helper
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

-- ---------------------------------------------------------------------------
-- Tables (must exist before the functions/policies that reference them)
-- ---------------------------------------------------------------------------

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle citext unique not null,
  display_name text not null default '',
  emoji text not null default '🏃',
  sharing_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint handle_format check (handle ~ '^[a-z0-9_]{3,20}$')
);
create or replace trigger profiles_updated before update on profiles
  for each row execute function set_updated_at();

create table if not exists summaries (
  user_id uuid primary key references profiles(id) on delete cascade,
  payload jsonb not null,          -- period buckets of per-activity totals only
  updated_at timestamptz not null default now()
);
create or replace trigger summaries_updated before update on summaries
  for each row execute function set_updated_at();

create table if not exists friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  addressee_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create table if not exists reactions (
  id uuid primary key default gen_random_uuid(),
  from_id uuid not null references profiles(id) on delete cascade,
  to_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('respect','whoops')),
  period_type text not null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Functions that reference the tables
-- ---------------------------------------------------------------------------

-- Are two users accepted friends (either direction)?
create or replace function are_friends(a uuid, b uuid) returns boolean as $$
  select exists (
    select 1 from friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$ language sql stable security definer;

-- Handle discovery: exact, opted-in match only (no table enumeration).
create or replace function find_profile_by_handle(p_handle citext)
returns table (id uuid, handle citext, display_name text, emoji text) as $$
  select id, handle, display_name, emoji
  from profiles
  where handle = p_handle and sharing_enabled = true
  limit 1;
$$ language sql stable security definer;

create or replace function is_handle_available(p_handle citext)
returns boolean as $$
  select not exists (select 1 from profiles where handle = p_handle);
$$ language sql stable security definer;

-- ---------------------------------------------------------------------------
-- Row-Level Security
-- ---------------------------------------------------------------------------

alter table profiles    enable row level security;
alter table summaries   enable row level security;
alter table friendships enable row level security;
alter table reactions   enable row level security;

-- profiles: own row full access; friends can read each other's profile.
drop policy if exists profiles_self on profiles;
create policy profiles_self on profiles
  for all using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists profiles_friends_read on profiles;
create policy profiles_friends_read on profiles
  for select using (are_friends(auth.uid(), id));

-- summaries: read own or an accepted friend's; write own only.
drop policy if exists summaries_read on summaries;
create policy summaries_read on summaries
  for select using (user_id = auth.uid() or are_friends(auth.uid(), user_id));
drop policy if exists summaries_write on summaries;
create policy summaries_write on summaries
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- friendships: the two parties can see; requester creates pending; addressee
-- responds; either can delete (revoke/cancel).
drop policy if exists friendships_read on friendships;
create policy friendships_read on friendships
  for select using (auth.uid() in (requester_id, addressee_id));
drop policy if exists friendships_insert on friendships;
create policy friendships_insert on friendships
  for insert with check (auth.uid() = requester_id and status = 'pending');
drop policy if exists friendships_update on friendships;
create policy friendships_update on friendships
  for update using (auth.uid() = addressee_id);
drop policy if exists friendships_delete on friendships;
create policy friendships_delete on friendships
  for delete using (auth.uid() in (requester_id, addressee_id));

-- reactions: send if friends; read if you're either party; delete your own.
drop policy if exists reactions_insert on reactions;
create policy reactions_insert on reactions
  for insert with check (auth.uid() = from_id and are_friends(from_id, to_id));
drop policy if exists reactions_read on reactions;
create policy reactions_read on reactions
  for select using (auth.uid() in (from_id, to_id));
drop policy if exists reactions_delete on reactions;
create policy reactions_delete on reactions
  for delete using (auth.uid() = from_id);

-- Account + data deletion: deleting the auth user cascades to profiles and on
-- to summaries/friendships/reactions.
