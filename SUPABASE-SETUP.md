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

## 3. Configure Sign in with Apple

In the **Apple Developer** portal (developer.apple.com):
1. **Certificates, Identifiers & Profiles → Identifiers**: your app id
   `com.owenpettiford.HowFarMuch` should have **Sign in with Apple** capability
   enabled (add it if not).
2. Create a **Services ID** (e.g. `com.owenpettiford.HowFarMuch.signin`),
   enable Sign in with Apple, and set the return URL to your Supabase callback:
   `https://<your-project-ref>.supabase.co/auth/v1/callback`.
3. **Keys**: create a new **Sign in with Apple** key; download the `.p8`; note
   the **Key ID** and your **Team ID**.

In **Supabase** → **Authentication → Providers → Apple**:
1. Enable Apple.
2. Fill in: Services ID (client id), Team ID, Key ID, and the `.p8` key contents.
3. Save.

(Native Sign in with Apple on-device also works via the app's own bundle id;
we'll use `ASAuthorizationController` in-app and pass the identity token to
Supabase — the Services ID above covers the web callback Supabase needs.)

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
