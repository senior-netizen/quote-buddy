# Multi-tenant workspaces

Turn the app from single-brand (Squirrellabs hardcoded) into a true multi-tenant system where any company can sign up, brand their own documents, and invite teammates.

## What you'll get

- **Anyone can sign up** and is auto-placed into their own organization (workspace).
- **Per-organization branding** — name, logo, emails, website, registration/TIN/DUNS, currency, default tax rate, address, phone. All of this drives the PDF + verification page.
- **Teams** — owners can invite teammates by email with roles: `owner`, `admin`, `member`.
- **Active organization switcher** in the header (for users who belong to multiple orgs).
- **All existing data scoped to an org** — clients, documents, doc numbering, verification — instead of to a single user.
- **Logo upload** via storage (no more hardcoded `logoData.ts`).

## Data model changes

New tables:

- `organizations` — `id`, `name`, `slug`, `created_by`, timestamps
- `organization_profiles` — 1:1 with org. Holds brand fields (name, short, logo_url, emails[], website, registration, tin, duns, currency, default_tax_rate, address, phone)
- `organization_members` — `org_id`, `user_id`, `role` (enum: owner/admin/member), `created_at`. Unique on (org_id, user_id).
- `organization_invitations` — `org_id`, `email`, `role`, `token`, `expires_at`, `accepted_at`
- `profiles` — `user_id`, `display_name`, `active_org_id` (which workspace the user is currently viewing)

New enum: `app_role` (owner, admin, member).

Schema changes to existing tables:

- `clients.org_id` (NOT NULL, FK to organizations) — replaces `user_id` as the scoping column
- `documents.org_id` (NOT NULL, FK) — same
- Keep `user_id` on documents to record the author, but RLS scopes by `org_id` membership
- `documents.doc_number` uniqueness becomes per-org, not per-user

Security:

- New `public.is_org_member(_user_id, _org_id)` and `public.has_org_role(_user_id, _org_id, _role)` SECURITY DEFINER functions to avoid RLS recursion.
- RLS on every table: members can read; admins/owners can write; only owners can delete the org or change billing-style settings; only owners can manage members.
- Storage bucket `org-logos` (public read) with write policy gated on org admin/owner.

## Backend (server functions)

- `getActiveOrg` — returns the current user's active org + profile + role
- `getMyOrganizations` — list orgs the user belongs to (for the switcher)
- `setActiveOrg` — switch the active org
- `createOrganization` — create new org, auto-add caller as owner, create blank profile
- `updateOrganizationProfile` — admin/owner only
- `uploadOrgLogo` — signed upload to `org-logos` bucket
- `inviteMember` / `acceptInvitation` / `removeMember` / `changeMemberRole`
- Refactor `docNumber.ts` + `verify.functions.ts` to scope by `org_id` instead of `user_id`

## PDF refactor

- `pdfDef.ts` `buildDef()` takes a `brand` argument (the org profile) instead of importing the constant
- `pdf.ts` loads the active org's profile + logo (fetched to data URL) and passes them in
- Delete `src/lib/brand.ts` and `src/lib/logoData.ts` (replaced by DB data)
- Verification page reads the issuing org's profile so the QR/verify page shows the right brand

## UI changes

- **Signup flow**: after email confirmation, prompt for company name → creates first org
- **`/settings/organization`** (admin/owner) — edit brand fields, upload logo
- **`/settings/team`** (admin/owner) — invite by email, list members, change roles, remove
- **`/invite/$token`** — accept invitation page
- **Header**: org switcher dropdown (only shown if user is in 2+ orgs) + current org name/logo
- **Login/signup**: keep email/password + Google (already there)

## Data migration

For your existing Squirrellabs data:

- Migration creates one organization called "Squirrellabs Technologies Pvt Ltd" seeded with the current `BRAND` values
- All existing clients/documents are assigned to that org
- Your existing user becomes its owner
- After migration runs, `brand.ts` and `logoData.ts` are removed and the app reads everything from the DB

## Out of scope (ask if you want any)

- Billing/subscriptions per org (Stripe)
- Custom domains per org (white-label hosting)
- Email-based invitation delivery (will store invites + show link; sending real emails needs Resend/SMTP setup — say the word and I'll add it)
- Audit log of who changed what

## Build order

1. Migration: create new tables, enum, helper functions, RLS, seed Squirrellabs org, backfill org_id on clients/documents, storage bucket
2. Server functions for org/profile/membership
3. Refactor `pdfDef.ts` + verification to take brand from DB
4. UI: org settings, team settings, invitation accept, switcher, signup-creates-org
5. Remove `brand.ts` / `logoData.ts`

This is one large coherent change — I'll do it in that order in subsequent turns. Approve and I'll start with the migration.