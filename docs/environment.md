# Required environment variables

Use this checklist when copying values from Supabase and configuring the app runtime.

## Supabase values

Find these in your Supabase dashboard under **Project Settings > API**.

| Variable | Where to get it | Required for | Notes |
| --- | --- | --- | --- |
| `VITE_SUPABASE_URL` | Project URL | Browser/client Supabase client | Same value as `SUPABASE_URL`. |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Publishable key, or anon public key if your project still labels it that way | Browser/client Supabase client | Safe to expose to the browser. |
| `SUPABASE_URL` | Project URL | Server routes/functions | Same value as `VITE_SUPABASE_URL`. |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key, or anon public key if your project still labels it that way | Server-side user-authenticated Supabase requests | Safe to expose, but still configure it in server environment variables. |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role / secret key | Server admin Supabase client and verification signing | Keep secret. Never expose this with a `VITE_` prefix. |

## App and email values

These do not come from Supabase, but the app expects them for invitation emails.

| Variable | Required for | Notes |
| --- | --- | --- |
| `APP_ORIGIN` | Building invitation links | Example: `https://yourdomain.co.zw`. |
| `PUBLIC_APP_ORIGIN` | Fallback for `APP_ORIGIN` | Optional if `APP_ORIGIN` is set. |
| `RESEND_API_KEY` | Sending invitation emails | Get this from Resend. |
| `RESEND_FROM_EMAIL` | Sending invitation emails | Example: `My Platform <noreply@yourdomain.co.zw>`. |

## Optional helpers

| Variable | Notes |
| --- | --- |
| `SUPABASE_PROJECT_ID` | Optional project-ref helper for local tooling; the app does not read it at runtime. |
| `VITE_SUPABASE_PROJECT_ID` | Optional project-ref helper; the app does not read it at runtime. |
