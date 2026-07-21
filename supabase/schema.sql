-- How Far/Much — Friends v2 schema (run in Supabase SQL editor).
-- Security lives in Row-Level Security: a user can read another user's summary
-- only if an accepted friendship exists between them.

create extension if not exists citext;

-- updated_at helper
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

-- Are two users accepted friends (either direction)?
create or replace function are_friends(a uuid, b uuid) returns boolean as $$
  select exists (
    select 1 from friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$ language sql stable security definer;

-- ---------------------------------------------------------------------------
-- Tables
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
create trigger profiles_updated before update on profiles
  for each row execute function set_updated_at();

create table if not exists summaries (
  user_id uuid primary key references profiles(id) on delete cascade,
  payload jsonb not null,          -- period buckets of per-activity totals only
  updated_at timestamptz not null default now()
);
create trigger summaries_updated before update on summaries
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
-- Row-Level Security
-- ---------------------------------------------------------------------------

alter table profiles   enable row level security;
alter table summaries  enable row level security;
alter table friendships enable row level security;
alter table reactions  enable row level security;

-- profiles: own row full access; friends can read each other's profile.
create policy profiles_self on profiles
  for all using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_friends_read on profiles
  for select using (are_friends(auth.uid(), id));

-- summaries: read own or an accepted friend's; write own only.
create policy summaries_read on summaries
  for select using (user_id = auth.uid() or are_friends(auth.uid(), user_id));
create policy summaries_write on summaries
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- friendships: the two parties can see; requester creates pending; addressee
-- responds; either can delete (revoke/cancel).
create policy friendships_read on friendships
  for select using (auth.uid() in (requester_id, addressee_id));
create policy friendships_insert on friendships
  for insert with check (auth.uid() = requester_id and status = 'pending');
create policy friendships_update on friendships
  for update using (auth.uid() = addressee_id);
create policy friendships_delete on friendships
  for delete using (auth.uid() in (requester_id, addressee_id));

-- reactions: send if friends; read if you're either party; delete your own.
create policy reactions_insert on reactions
  for insert with check (auth.uid() = from_id and are_friends(from_id, to_id));
create policy reactions_read on reactions
  for select using (auth.uid() in (from_id, to_id));
create policy reactions_delete on reactions
  for delete using (auth.uid() = from_id);

-- ---------------------------------------------------------------------------
-- Handle discovery (SECURITY DEFINER so it can look past RLS for an exact,
-- opted-in match only — no table enumeration).
-- ---------------------------------------------------------------------------

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

-- Account + data deletion: delete the auth user; everything cascades.
-- Call from an Edge Function or the client via auth admin. Profiles/summaries/
-- friendships/reactions all cascade from profiles.id -> auth.users.id.
