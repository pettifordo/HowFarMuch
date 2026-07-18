# Friends — design sketch (no code yet)

Follow other people's workout totals. Invite-only mutual sharing modelled on
Apple Activity ring sharing. Planned as the first paid ("Plus") feature.

## Principles

- **Aggregates only, never workouts.** Individual workout start times reveal
  routines and location patterns. Share per-period, per-activity totals.
- **Publish numbers, not strings.** Viewer's own unit (km/mi) and
  compact-value settings format the display. (Opposite of the widget
  snapshot, which is deliberately pre-formatted.)
- **The user chooses what leaves the device.** Sharing is opt-in per metric,
  per activity type, and per period floor.
- **No servers of ours.** CloudKit shared zones live in each user's own
  iCloud private database; the developer cannot read them. Privacy label and
  "we run no servers" stance survive.
- **Solo features stay free forever.** Only social (and future AI) features
  are paid.

## Architecture

- **Transport: CloudKit + CKShare.** Each user has a shared record zone in
  their private DB containing their published summaries; a CKShare grants
  read access to invited friends. No accounts — iCloud identity.
  - Rejected: true P2P (async following needs an always-on intermediary;
    phones can't accept incoming connections), custom backend
    (accounts/GDPR/privacy-label cost; revisit only if leaderboards or
    Android ever matter), shared iCloud Drive folders (no push, fragile).
- **Published records** (upserted on app open + daily BGAppRefresh):
  - `SharedProfile`: display name, avatar emoji, last-published date.
  - `PeriodSummary` keyed by (periodType, periodStart): JSON of per-activity
    aggregates {distanceMeters, durationSeconds, kilocalories, workoutCount,
    avgHeartRate?} plus overall totals.
  - Buckets: today, current week/month/year, all-time, plus trailing history
    (12 weeks, 12 months) for trend arrows.
- **Freshness:** CloudKit subscriptions push updates to followers; UI shows
  "last updated Nd ago" staleness badges.
- **Revocation:** remove CKShare participant. Leaving a share removes the feed.
- **Guards:** never publish demo data; clear error states for no-iCloud and
  iCloud-storage-full.

## Sharing controls (Settings → Sharing)

- Metric toggles: distance / time / calories / count (default on),
  **heart rate (default off)**.
- Activity-type toggles (reuse exclusion UI pattern).
- Period floor: "Share Today" off ⇒ weekly and coarser only (avoids
  "they're out right now" signals).
- One configuration for all friends in v1; per-friend tiers are a possible
  v2 (requires parallel shares — deferred).

## UI

- **Friends** section on dashboard: person cards showing their hero value
  for the currently selected period + staleness badge.
- Friend detail: read-only mirror of own dashboard (hero, activity cards,
  trend arrows) built from their aggregates.
- Invite flow: Friends → Invite → UICloudSharingController → Messages link →
  accept → nudge to share back.
- v1.1 idea: "You vs them" side-by-side weekly comparison.

## Monetisation — "How Far/Much Plus"

- StoreKit 2 subscription, ~£9.99/year, **Family Sharing enabled** (one
  household purchase covers spouse — the primary use case).
- Intro free trial so invites aren't dead ends.
- Gate: both sharing and viewing require Plus. Enforced locally
  (CloudKit doesn't care). Everything currently shipped stays free.
- Future Plus additions: AI insights/coach summary.

## Policy updates required at launch

- Privacy policy: new optional-sharing section (via user's iCloud, only to
  invited people, revocable; we still see nothing).
- Verify App Privacy label can remain "Data Not Collected" given developer
  has no access to users' private/shared DB zones (believed yes — confirm
  against current Apple guidance before submission).

## Phasing

1. **Spike** CKShare: invite → accept → read between two devices/simulators
   (riskiest unknown; throwaway code).
2. Publish/read pipeline + Friends UI.
3. Paywall (StoreKit 2).
4. Comparisons.
