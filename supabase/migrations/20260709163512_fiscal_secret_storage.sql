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

-- Earlier fiscal migrations created device_keys/device_certificates as append-only
-- device lifecycle tables. The application runtime now treats them as org-scoped
-- encrypted secret slots, so explicitly reshape any existing tables instead of
-- relying on CREATE TABLE IF NOT EXISTS no-ops. These rows must be updateable so
-- onboardFiscalDeviceSecrets can deactivate old active secrets before inserting
-- replacements.
DROP TRIGGER IF EXISTS device_keys_immutable_update ON public.device_keys;
DROP TRIGGER IF EXISTS device_keys_immutable_delete ON public.device_keys;
DROP TRIGGER IF EXISTS device_certificates_immutable_update ON public.device_certificates;
DROP TRIGGER IF EXISTS device_certificates_immutable_delete ON public.device_certificates;
DROP TRIGGER IF EXISTS prevent_update_device_keys ON public.device_keys;
DROP TRIGGER IF EXISTS prevent_delete_device_keys ON public.device_keys;
DROP TRIGGER IF EXISTS prevent_update_device_certificates ON public.device_certificates;
DROP TRIGGER IF EXISTS prevent_delete_device_certificates ON public.device_certificates;

CREATE TABLE IF NOT EXISTS public.device_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

ALTER TABLE public.device_keys
  ADD COLUMN IF NOT EXISTS org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS encrypted_payload TEXT,
  ADD COLUMN IF NOT EXISTS key_id TEXT,
  ADD COLUMN IF NOT EXISTS thumbprint TEXT,
  ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.device_keys dk
SET org_id = d.org_id
FROM public.devices d
WHERE dk.org_id IS NULL
  AND dk.device_id = d.id;

UPDATE public.device_keys
SET encrypted_payload = COALESCE(encrypted_payload, encrypted_private_key_ref),
    key_id = COALESCE(key_id, key_algorithm, 'legacy'),
    thumbprint = COALESCE(thumbprint, csr_fingerprint, md5(COALESCE(public_key_pem, encrypted_private_key_ref, id::text))),
    valid_from = COALESCE(created_at, valid_from, now())
WHERE encrypted_payload IS NULL
   OR key_id IS NULL
   OR thumbprint IS NULL;

ALTER TABLE public.device_keys
  ALTER COLUMN org_id SET NOT NULL,
  ALTER COLUMN encrypted_payload SET NOT NULL,
  ALTER COLUMN key_id SET NOT NULL,
  ALTER COLUMN thumbprint SET NOT NULL,
  ALTER COLUMN device_id DROP NOT NULL,
  ALTER COLUMN key_algorithm DROP NOT NULL,
  ALTER COLUMN key_size DROP NOT NULL,
  ALTER COLUMN public_key_pem DROP NOT NULL,
  ALTER COLUMN encrypted_private_key_ref DROP NOT NULL,
  ALTER COLUMN csr_pem DROP NOT NULL,
  ALTER COLUMN csr_fingerprint DROP NOT NULL;

ALTER TABLE public.device_keys
  DROP CONSTRAINT IF EXISTS device_keys_valid_window_chk,
  ADD CONSTRAINT device_keys_valid_window_chk CHECK (valid_until IS NULL OR valid_until > valid_from);

CREATE TABLE IF NOT EXISTS public.device_certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

ALTER TABLE public.device_certificates
  ADD COLUMN IF NOT EXISTS org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS encrypted_payload TEXT,
  ADD COLUMN IF NOT EXISTS key_id TEXT,
  ADD COLUMN IF NOT EXISTS thumbprint TEXT,
  ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.device_certificates dc
SET org_id = d.org_id
FROM public.devices d
WHERE dc.org_id IS NULL
  AND dc.device_id = d.id;

UPDATE public.device_certificates
SET encrypted_payload = COALESCE(encrypted_payload, certificate_pem),
    key_id = COALESCE(key_id, certificate_serial_number, 'legacy'),
    thumbprint = COALESCE(thumbprint, certificate_thumbprint, md5(COALESCE(certificate_pem, id::text))),
    valid_from = COALESCE(valid_from, created_at, now()),
    valid_until = COALESCE(valid_until, valid_to)
WHERE encrypted_payload IS NULL
   OR key_id IS NULL
   OR thumbprint IS NULL;

ALTER TABLE public.device_certificates
  ALTER COLUMN org_id SET NOT NULL,
  ALTER COLUMN encrypted_payload SET NOT NULL,
  ALTER COLUMN key_id SET NOT NULL,
  ALTER COLUMN thumbprint SET NOT NULL,
  ALTER COLUMN device_id DROP NOT NULL,
  ALTER COLUMN fdms_device_id DROP NOT NULL,
  ALTER COLUMN environment DROP NOT NULL,
  ALTER COLUMN certificate_pem DROP NOT NULL,
  ALTER COLUMN certificate_thumbprint DROP NOT NULL;

ALTER TABLE public.device_certificates
  DROP CONSTRAINT IF EXISTS device_certificates_valid_window_chk,
  ADD CONSTRAINT device_certificates_valid_window_chk CHECK (valid_until IS NULL OR valid_until > valid_from);

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
