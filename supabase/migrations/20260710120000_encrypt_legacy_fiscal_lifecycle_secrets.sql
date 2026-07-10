-- Harden legacy FDMS lifecycle tables so credential material is only stored in
-- encrypted server-managed payload columns. Existing plaintext values cannot be
-- encrypted in SQL because FISCAL_SECRET_ENCRYPTION_KEY is application-only, so
-- this migration removes plaintext after encrypted replacements exist and makes
-- plaintext columns nullable for new encrypted-only writes.

ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS activation_key_encrypted TEXT,
  ADD COLUMN IF NOT EXISTS activation_key_secret_ref TEXT,
  ADD COLUMN IF NOT EXISTS activation_key_hash TEXT;

ALTER TABLE public.devices
  ALTER COLUMN activation_key DROP NOT NULL;

UPDATE public.devices
SET activation_key = NULL
WHERE activation_key_encrypted IS NOT NULL
  AND activation_key IS NOT NULL;

ALTER TABLE public.device_certificates
  ADD COLUMN IF NOT EXISTS encrypted_payload TEXT,
  ADD COLUMN IF NOT EXISTS key_id TEXT,
  ADD COLUMN IF NOT EXISTS thumbprint TEXT,
  ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.device_certificates
  ALTER COLUMN certificate_pem DROP NOT NULL;

UPDATE public.device_certificates
SET certificate_pem = NULL
WHERE encrypted_payload IS NOT NULL
  AND certificate_pem IS NOT NULL;

ALTER TABLE public.device_keys
  ADD COLUMN IF NOT EXISTS encrypted_payload TEXT,
  ADD COLUMN IF NOT EXISTS key_id TEXT,
  ADD COLUMN IF NOT EXISTS thumbprint TEXT,
  ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ;

UPDATE public.device_keys
SET encrypted_private_key_ref = 'encrypted_payload:' || id::text
WHERE encrypted_payload IS NOT NULL
  AND encrypted_private_key_ref IS NULL;

CREATE INDEX IF NOT EXISTS idx_devices_activation_key_hash ON public.devices(activation_key_hash);
CREATE INDEX IF NOT EXISTS idx_device_certificates_org_active_created ON public.device_certificates(org_id, active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_keys_org_active_created ON public.device_keys(org_id, active, created_at DESC);
