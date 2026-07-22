# Supabase setup for Friends v2 (one-time, ~20 min)

Do these steps, then send me the **Project URL** and **anon public key** (both are
safe to embed in the app — security is enforced by Row-Level Security, not by
hiding the anon key). I'll then add the SDK and build the client.

## 1. Create the project

1. Go to https://supabase.com → sign in → **New project**.
2. Name: `howfarmuch`. Choose a strong DB password (save it).
3. **Region: EU (e.g. London / Frankfurt)** — you're UK, keeps GDPR simple.
4. Wait for it to provision (~2 min).

## 2. Create the schema

1. Left sidebar → **SQL Editor** → **New query**.
2. Paste the entire contents of `supabase/schema.sql` and **Run**.
3. Confirm no errors. Under **Table Editor** you should see `profiles`,
   `summaries`, `friendships`, `reactions`.

## 3. Configure Sign in with Apple (native — the simple path)

Because the app uses **native** Sign in with Apple (`ASAuthorizationController`
in-app, token handed straight to Supabase's `signInWithIdToken`), you do NOT
need a Services ID, key, or web callback. Just:

In **Supabase** → **Authentication → Providers → Apple**:
1. Toggle **Apple** on.
2. In **Authorized Client IDs**, add the app's bundle id:
   `com.owenpettiford.HowFarMuch`
3. Leave Services ID / Secret Key blank (those are only for web OAuth). Save.

The app target's **Sign in with Apple** capability I'll add in `project.yml`.
Your App ID in the Apple Developer portal needs Sign in with Apple enabled —
automatic signing usually handles this on first build; if it complains, tick it
under Identifiers → your app id → Sign in with Apple.

## 4. Get the client credentials

Supabase → **Project Settings → API**:
- **Project URL** — e.g. `https://abcxyz.supabase.co`
- **anon public** key — a long JWT starting `eyJ...`

Send me both. (Do **not** send the `service_role` key — that one is secret and
never goes in the app.)

## 5. What I do next

- Add `supabase-swift` via SPM to `project.yml`.
- Add Sign in with Apple capability to the app target.
- Build: auth manager (Apple sign-in → Supabase session), handle claim +
  availability check, opt-in toggle, summary publish, handle search, friend
  request/accept/revoke, reactions — repointing the existing Friends UI.
- Remove the CloudKit Friends code.
- Update the privacy policy + App Store privacy label, and add in-app
  "Delete my account & data".
