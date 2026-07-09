-- Replace plaintext fiscal secrets with encrypted server-managed references.
ALTER TABLE public.organization_fiscal_config
  ADD COLUMN IF NOT EXISTS activation_key_encrypted TEXT,
  ADD COLUMN IF NOT EXISTS activation_key_id TEXT,
  ADD COLUMN IF NOT EXISTS activation_key_secret_ref TEXT,
  ADD COLUMN IF NOT EXISTS certificate_secret_ref TEXT,
  ADD COLUMN IF NOT EXISTS private_key_secret_ref TEXT;

UPDATE public.organization_fiscal_config
SET activation_key = NULL,
    certificate_pem = NULL,
    private_key_pem = NULL;

ALTER TABLE public.organization_fiscal_config
  DROP COLUMN IF EXISTS activation_key,
  DROP COLUMN IF EXISTS certificate_pem,
  DROP COLUMN IF EXISTS private_key_pem;

CREATE TABLE IF NOT EXISTS public.device_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  encrypted_payload TEXT NOT NULL,
  key_id TEXT NOT NULL,
  thumbprint TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT false,
  valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE IF NOT EXISTS public.device_certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  encrypted_payload TEXT NOT NULL,
  key_id TEXT NOT NULL,
  thumbprint TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT false,
  valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE IF NOT EXISTS public.certificate_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  certificate_id UUID REFERENCES public.device_certificates(id) ON DELETE SET NULL,
  key_id TEXT NOT NULL,
  thumbprint TEXT NOT NULL,
  active BOOLEAN NOT NULL,
  valid_from TIMESTAMPTZ NOT NULL,
  valid_until TIMESTAMPTZ,
  encrypted_payload TEXT NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  recorded_by UUID DEFAULT auth.uid()
);

CREATE UNIQUE INDEX IF NOT EXISTS device_keys_one_active_per_org
  ON public.device_keys (org_id) WHERE active;
CREATE UNIQUE INDEX IF NOT EXISTS device_certificates_one_active_per_org
  ON public.device_certificates (org_id) WHERE active;
CREATE INDEX IF NOT EXISTS device_keys_org_validity_idx ON public.device_keys (org_id, valid_from, valid_until);
CREATE INDEX IF NOT EXISTS device_certificates_org_validity_idx ON public.device_certificates (org_id, valid_from, valid_until);
CREATE INDEX IF NOT EXISTS certificate_history_org_recorded_idx ON public.certificate_history (org_id, recorded_at DESC);

CREATE TRIGGER touch_device_keys_updated_at
  BEFORE UPDATE ON public.device_keys
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER touch_device_certificates_updated_at
  BEFORE UPDATE ON public.device_certificates
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE OR REPLACE FUNCTION public.record_certificate_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.certificate_history (
    org_id, certificate_id, key_id, thumbprint, active, valid_from, valid_until, encrypted_payload
  ) VALUES (
    NEW.org_id, NEW.id, NEW.key_id, NEW.thumbprint, NEW.active, NEW.valid_from, NEW.valid_until, NEW.encrypted_payload
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER record_device_certificate_history_insert
  AFTER INSERT ON public.device_certificates
  FOR EACH ROW EXECUTE FUNCTION public.record_certificate_history();

CREATE TRIGGER record_device_certificate_history_update
  AFTER UPDATE ON public.device_certificates
  FOR EACH ROW EXECUTE FUNCTION public.record_certificate_history();

CREATE OR REPLACE FUNCTION public.prevent_certificate_history_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'certificate_history rows are immutable';
END;
$$;

CREATE TRIGGER certificate_history_no_update
  BEFORE UPDATE ON public.certificate_history
  FOR EACH ROW EXECUTE FUNCTION public.prevent_certificate_history_mutation();

CREATE TRIGGER certificate_history_no_delete
  BEFORE DELETE ON public.certificate_history
  FOR EACH ROW EXECUTE FUNCTION public.prevent_certificate_history_mutation();

GRANT ALL ON public.device_keys TO service_role;
GRANT ALL ON public.device_certificates TO service_role;
GRANT ALL ON public.certificate_history TO service_role;

ALTER TABLE public.device_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificate_history ENABLE ROW LEVEL SECURITY;

-- No authenticated policies are created for fiscal secret tables; access is service-role only.
