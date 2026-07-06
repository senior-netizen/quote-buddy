
-- Fiscal device config per organization
CREATE TABLE public.organization_fiscal_config (
  org_id UUID PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT false,
  environment TEXT NOT NULL DEFAULT 'test' CHECK (environment IN ('test','prod')),
  device_id TEXT,
  device_serial TEXT,
  device_model TEXT,
  activation_key TEXT,
  tax_payer_name TEXT,
  tax_payer_tin TEXT,
  vat_number TEXT,
  trade_name TEXT,
  certificate_pem TEXT,
  private_key_pem TEXT,
  device_operating_mode TEXT NOT NULL DEFAULT 'Online',
  last_fiscal_day_no INTEGER,
  last_receipt_global_no BIGINT NOT NULL DEFAULT 0,
  last_receipt_counter INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.organization_fiscal_config TO authenticated;
GRANT ALL ON public.organization_fiscal_config TO service_role;

ALTER TABLE public.organization_fiscal_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view fiscal config"
  ON public.organization_fiscal_config FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id));

CREATE POLICY "Admins can insert fiscal config"
  ON public.organization_fiscal_config FOR INSERT TO authenticated
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Admins can update fiscal config"
  ON public.organization_fiscal_config FOR UPDATE TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'))
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Owners can delete fiscal config"
  ON public.organization_fiscal_config FOR DELETE TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'owner'));

CREATE TRIGGER touch_fiscal_config_updated_at
  BEFORE UPDATE ON public.organization_fiscal_config
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


-- Fiscal days
CREATE TABLE public.fiscal_days (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  fiscal_day_no INTEGER NOT NULL,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','error')),
  opening_response JSONB,
  closing_response JSONB,
  totals JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, fiscal_day_no)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.fiscal_days TO authenticated;
GRANT ALL ON public.fiscal_days TO service_role;

ALTER TABLE public.fiscal_days ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view fiscal days"
  ON public.fiscal_days FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id));

CREATE POLICY "Admins can insert fiscal days"
  ON public.fiscal_days FOR INSERT TO authenticated
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Admins can update fiscal days"
  ON public.fiscal_days FOR UPDATE TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'))
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));


-- Fiscal fields on documents
ALTER TABLE public.documents
  ADD COLUMN fiscal_status TEXT NOT NULL DEFAULT 'none' CHECK (fiscal_status IN ('none','pending','submitted','failed','skipped')),
  ADD COLUMN fiscal_day_no INTEGER,
  ADD COLUMN receipt_global_no BIGINT,
  ADD COLUMN receipt_counter INTEGER,
  ADD COLUMN receipt_hash TEXT,
  ADD COLUMN verification_code TEXT,
  ADD COLUMN receipt_qr_url TEXT,
  ADD COLUMN fiscal_submitted_at TIMESTAMPTZ,
  ADD COLUMN fiscal_error TEXT,
  ADD COLUMN fiscal_response JSONB;
