# Friends v2 — Supabase design sketch (no code yet)

Replaces the CloudKit sharing approach (see FRIENDS-DESIGN.md). CloudKit works
technically but is iCloud-account-only, restricts secure invites to
Messages/Mail, and is painful to operate. Supabase gives us control over
identity, discovery, and a proper mutual-friend model.

## Principles kept from v1

- **Solo use stays account-free and local.** The app works fully with no
  sign-in; you only authenticate when you tap into Friends.
- **Summary only.** Shared data is per-period, per-activity totals — never
  individual workouts, dates, times, or routes.
- **Mutual, opt-in, revocable.** Nobody sees your data without an accepted,
  two-way friendship you can cut at any time.

## Identity

- **Anchor: Sign in with Apple** (Supabase Apple OIDC). Stable private user id,
  no password, survives reinstall, standard on iOS. Owns the account.
- **Handle ("tag"): unique @handle** on top of the Apple identity — the
  human-friendly, searchable key friends use to find you. Uniqueness enforced
  by a DB constraint; ownership guaranteed by the Apple identity behind it.
- Rationale: a self-chosen tag alone is fragile (lost on reinstall, no
  ownership proof, impersonation). Apple identity + handle fixes all three.

## Onboarding flow

1. Tap **Friends** (first time) → "Sign in with Apple to connect."
2. Choose a **unique @handle** (live availability check) + display name + emoji.
3. **Opt in to sharing** (toggle). Off = invisible, unsearchable, shares nothing.
4. **Find a friend** by exact @handle (or share your handle / QR) → send request.
5. Friend **Accepts** pending request → mutual visibility. Decline → nothing.
6. Either party **Revokes** → both lose access immediately.
7. **Respect 🤜 / Whoops 🙈** via a reactions table.

## Data model (Postgres / Supabase)

- `profiles`: id (uuid = auth uid, PK), handle (citext unique), display_name,
  emoji, sharing_enabled (bool), created_at.
- `summaries`: user_id (uuid PK/FK), payload (jsonb — period buckets of
  per-activity totals; no dates/times), updated_at.
- `friendships`: id, requester_id, addressee_id, status
  ('pending' | 'accepted'), created_at, responded_at; unique(requester,
  addressee); check(requester <> addressee).
- `reactions`: id, from_id, to_id, kind ('respect' | 'whoops'), period_type,
  created_at.

## Row-Level Security (the security core — enforced by Postgres, not the app)

- **profiles**: own row read/write. Handle lookup via a `SECURITY DEFINER`
  function returning a single exact match (avoids enumerating the table).
- **summaries**: read own; read another's only if an `accepted` friendship
  exists between the two users. Write own only.
- **friendships**: the two parties can read; requester can insert; addressee
  can update status; either can delete (revoke).
- **reactions**: from_id can insert if an accepted friendship exists; to_id and
  from_id can read.

## What's stored (summary only)

jsonb payload = array of period buckets (today/week/month/year/all), each a list
of per-activity aggregates {typeRaw, distanceMeters, durationSeconds,
kilocalories, workoutCount} plus optional avgHeartRate. **No workout dates,
times, routes, or individual sessions.** Same shape as v1 `FriendFeed`, so the
existing Friends/compare/reaction UI is reused unchanged — only the service
layer swaps from CloudKit to Supabase.

## Client changes

- New dependency: `supabase-swift` (first third-party dep — a conscious
  departure from the dependency-free stance; free tier covers this app).
- Replace the CloudKit `FriendsService` with a Supabase-backed one:
  publish summary (upsert) on app open; fetch friends' summaries via
  friendships join; send/accept/revoke requests; write/read reactions.
- Optional: Supabase Realtime for instant request/summary updates (else poll
  on foreground).
- Reuse: RootView tabs, FriendsTabView, FriendComparisonCard, FriendDetailView,
  reactions, FriendFeed/PeriodBucket/ActivityAggregate models.

## Privacy / App Store

- App Privacy label: Health & Fitness (summary) + handle, **linked to
  identity, not used for tracking**, purpose App Functionality.
- Privacy policy: new section describing Supabase storage, exactly what's
  shared, retention, and deletion.
- **In-app account + data deletion** (Apple requirement once accounts exist) —
  one button; cascades delete of profile/summary/friendships/reactions.
- Host in the **EU region** (owner is UK) for GDPR simplicity.

## Open decisions

1. Identity: Sign in with Apple (recommended) vs anonymous + handle only.
2. Discovery: exact-handle search only (recommended) vs any browsing.
3. Approve the first third-party dependency (supabase-swift).
4. Keep CloudKit code as a fallback, or remove it cleanly (recommended: remove).
5. Realtime now, or poll-on-open first (recommended: poll first, add realtime
   later).

## Phasing

1. Supabase project + schema + RLS + Apple auth wired; sign-in & handle claim.
2. Opt-in + publish summary + handle search + request/accept/revoke.
3. Friends list + comparison + reactions repointed at Supabase.
4. Account deletion, privacy policy/label updates, EU region.
5. Optional: realtime, QR handle sharing, leaderboards, Plus paywall.
