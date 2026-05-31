-- ============================================================
-- Multi-tenant workspaces migration
-- ============================================================

-- 1. ENUM for roles
CREATE TYPE public.app_role AS ENUM ('owner', 'admin', 'member');

-- ============================================================
-- 2. NEW TABLES
-- ============================================================

-- organizations
CREATE TABLE public.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organizations TO authenticated;
GRANT ALL ON public.organizations TO service_role;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- organization_profiles (brand information, 1:1 with org)
CREATE TABLE public.organization_profiles (
  org_id UUID PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  short_name TEXT,
  logo_url TEXT,
  emails TEXT[] NOT NULL DEFAULT '{}',
  website TEXT,
  registration TEXT,
  tin TEXT,
  duns TEXT,
  currency TEXT NOT NULL DEFAULT 'USD',
  default_tax_rate NUMERIC NOT NULL DEFAULT 15,
  address TEXT,
  phone TEXT,
  payment_instructions TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organization_profiles TO authenticated;
GRANT ALL ON public.organization_profiles TO service_role;
ALTER TABLE public.organization_profiles ENABLE ROW LEVEL SECURITY;

-- organization_members
CREATE TABLE public.organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  role public.app_role NOT NULL DEFAULT 'member',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, user_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organization_members TO authenticated;
GRANT ALL ON public.organization_members TO service_role;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;

-- organization_invitations
CREATE TABLE public.organization_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role public.app_role NOT NULL DEFAULT 'member',
  token TEXT NOT NULL UNIQUE,
  invited_by UUID,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organization_invitations TO authenticated;
GRANT ALL ON public.organization_invitations TO service_role;
ALTER TABLE public.organization_invitations ENABLE ROW LEVEL SECURITY;

-- profiles (per-user: tracks active org)
CREATE TABLE public.profiles (
  user_id UUID PRIMARY KEY,
  display_name TEXT,
  active_org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. HELPER FUNCTIONS (SECURITY DEFINER to avoid RLS recursion)
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_org_member(_user_id UUID, _org_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE user_id = _user_id AND org_id = _org_id
  )
$$;

CREATE OR REPLACE FUNCTION public.has_org_role(_user_id UUID, _org_id UUID, _min_role public.app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE user_id = _user_id
      AND org_id = _org_id
      AND CASE _min_role
        WHEN 'member' THEN role IN ('member', 'admin', 'owner')
        WHEN 'admin' THEN role IN ('admin', 'owner')
        WHEN 'owner' THEN role = 'owner'
      END
  )
$$;

-- ============================================================
-- 4. RLS POLICIES ON NEW TABLES
-- ============================================================

-- organizations
CREATE POLICY "Members can view their orgs" ON public.organizations
  FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), id));
CREATE POLICY "Authenticated can create orgs" ON public.organizations
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Admins can update org" ON public.organizations
  FOR UPDATE TO authenticated USING (public.has_org_role(auth.uid(), id, 'admin'));
CREATE POLICY "Owners can delete org" ON public.organizations
  FOR DELETE TO authenticated USING (public.has_org_role(auth.uid(), id, 'owner'));

-- organization_profiles
CREATE POLICY "Members can view org profile" ON public.organization_profiles
  FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can update org profile" ON public.organization_profiles
  FOR UPDATE TO authenticated USING (public.has_org_role(auth.uid(), org_id, 'admin'));
-- INSERT only via trigger (SECURITY DEFINER bypasses RLS as postgres role)

-- organization_members
CREATE POLICY "Members can view their org members" ON public.organization_members
  FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can add members" ON public.organization_members
  FOR INSERT TO authenticated WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));
CREATE POLICY "Admins can update members" ON public.organization_members
  FOR UPDATE TO authenticated USING (public.has_org_role(auth.uid(), org_id, 'admin'));
CREATE POLICY "Admins or self can remove member" ON public.organization_members
  FOR DELETE TO authenticated USING (
    public.has_org_role(auth.uid(), org_id, 'admin') OR auth.uid() = user_id
  );

-- organization_invitations (managed via server fns)
CREATE POLICY "Admins can view invitations" ON public.organization_invitations
  FOR SELECT TO authenticated USING (public.has_org_role(auth.uid(), org_id, 'admin'));
CREATE POLICY "Admins can create invitations" ON public.organization_invitations
  FOR INSERT TO authenticated WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));
CREATE POLICY "Admins can delete invitations" ON public.organization_invitations
  FOR DELETE TO authenticated USING (public.has_org_role(auth.uid(), org_id, 'admin'));

-- profiles
CREATE POLICY "Users view own profile" ON public.profiles
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users insert own profile" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- ============================================================
-- 5. TRIGGERS
-- ============================================================

-- When a new organization is created, auto-create its profile and owner membership.
CREATE OR REPLACE FUNCTION public.handle_new_organization()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner UUID;
BEGIN
  v_owner := COALESCE(NEW.created_by, auth.uid());

  INSERT INTO public.organization_profiles (org_id, name)
  VALUES (NEW.id, NEW.name)
  ON CONFLICT (org_id) DO NOTHING;

  IF v_owner IS NOT NULL THEN
    INSERT INTO public.organization_members (org_id, user_id, role)
    VALUES (NEW.id, v_owner, 'owner')
    ON CONFLICT (org_id, user_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_organization_created
  AFTER INSERT ON public.organizations
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_organization();

-- When a user becomes a member, set their active org if they don't already have one.
CREATE OR REPLACE FUNCTION public.handle_first_membership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, active_org_id)
  VALUES (NEW.user_id, NEW.org_id)
  ON CONFLICT (user_id) DO UPDATE
    SET active_org_id = COALESCE(public.profiles.active_org_id, EXCLUDED.active_org_id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_member_added
  AFTER INSERT ON public.organization_members
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_first_membership();

-- touch_updated_at triggers on new tables
CREATE TRIGGER touch_organizations_updated_at
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER touch_organization_profiles_updated_at
  BEFORE UPDATE ON public.organization_profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER touch_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ============================================================
-- 6. ADD org_id TO EXISTING TABLES (nullable for now)
-- ============================================================

ALTER TABLE public.clients ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.documents ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- ============================================================
-- 7. SEED Squirrellabs org + backfill existing data
-- ============================================================

DO $$
DECLARE
  v_org_id UUID := gen_random_uuid();
  v_owner UUID;
BEGIN
  -- Pick a user_id from existing data to become first owner
  SELECT user_id INTO v_owner FROM public.clients LIMIT 1;
  IF v_owner IS NULL THEN
    SELECT user_id INTO v_owner FROM public.documents LIMIT 1;
  END IF;

  IF v_owner IS NOT NULL THEN
    -- Create the Squirrellabs org (trigger creates owner + blank profile)
    INSERT INTO public.organizations (id, name, created_by)
    VALUES (v_org_id, 'Squirrellabs Technologies Pvt Ltd', v_owner);

    -- Enrich the profile with the existing hardcoded brand data
    UPDATE public.organization_profiles SET
      short_name = 'Squirrellabs',
      emails = ARRAY['sales@rodent.co.zw', 'ndabaprinco@gmail.com'],
      website = 'www.rodent-lab.com',
      registration = '72190A01122025',
      tin = '2002367529',
      duns = '631177914',
      currency = 'USD',
      default_tax_rate = 15
    WHERE org_id = v_org_id;

    -- Add any other distinct users from existing data as owners
    INSERT INTO public.organization_members (org_id, user_id, role)
    SELECT DISTINCT v_org_id, user_id, 'owner'::public.app_role
    FROM (
      SELECT user_id FROM public.clients
      UNION
      SELECT user_id FROM public.documents
    ) all_users
    WHERE user_id <> v_owner AND user_id IS NOT NULL
    ON CONFLICT (org_id, user_id) DO NOTHING;

    -- Backfill org_id on existing rows
    UPDATE public.clients SET org_id = v_org_id WHERE org_id IS NULL;
    UPDATE public.documents SET org_id = v_org_id WHERE org_id IS NULL;
  END IF;
END $$;

-- ============================================================
-- 8. ENFORCE NOT NULL + unique doc_number per org
-- ============================================================

-- Only enforce NOT NULL if backfill succeeded (i.e. no nulls remain).
-- If tables are empty, this also works.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.clients WHERE org_id IS NULL) THEN
    ALTER TABLE public.clients ALTER COLUMN org_id SET NOT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.documents WHERE org_id IS NULL) THEN
    ALTER TABLE public.documents ALTER COLUMN org_id SET NOT NULL;
  END IF;
END $$;

CREATE INDEX idx_clients_org_id ON public.clients(org_id);
CREATE INDEX idx_documents_org_id ON public.documents(org_id);
CREATE INDEX idx_org_members_user_id ON public.organization_members(user_id);
CREATE INDEX idx_org_members_org_id ON public.organization_members(org_id);

ALTER TABLE public.documents
  ADD CONSTRAINT documents_org_doc_number_unique UNIQUE (org_id, doc_number);

-- ============================================================
-- 9. REPLACE RLS ON clients / documents
-- ============================================================

DROP POLICY IF EXISTS "Users manage own clients" ON public.clients;
DROP POLICY IF EXISTS "Users manage own documents" ON public.documents;

CREATE POLICY "Members can view org clients" ON public.clients
  FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Members can insert org clients" ON public.clients
  FOR INSERT TO authenticated WITH CHECK (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Members can update org clients" ON public.clients
  FOR UPDATE TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can delete org clients" ON public.clients
  FOR DELETE TO authenticated USING (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Members can view org documents" ON public.documents
  FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Members can insert org documents" ON public.documents
  FOR INSERT TO authenticated WITH CHECK (
    public.is_org_member(auth.uid(), org_id) AND auth.uid() = user_id
  );
CREATE POLICY "Members can update org documents" ON public.documents
  FOR UPDATE TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can delete org documents" ON public.documents
  FOR DELETE TO authenticated USING (public.has_org_role(auth.uid(), org_id, 'admin'));

-- ============================================================
-- 10. STORAGE BUCKET for org logos
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('org-logos', 'org-logos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Org logos are public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'org-logos');

CREATE POLICY "Admins can upload org logos"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'org-logos'
    AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin')
  );

CREATE POLICY "Admins can update org logos"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'org-logos'
    AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin')
  );

CREATE POLICY "Admins can delete org logos"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'org-logos'
    AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin')
  );