-- Store additional non-secret ZIMRA activation details per organization.
ALTER TABLE public.organization_fiscal_config
  ADD COLUMN IF NOT EXISTS device_address TEXT,
  ADD COLUMN IF NOT EXISTS device_model_name TEXT,
  ADD COLUMN IF NOT EXISTS device_model_version TEXT;

-- Preserve any legacy free-form model value as the model name for existing orgs.
UPDATE public.organization_fiscal_config
SET device_model_name = device_model
WHERE device_model_name IS NULL
  AND device_model IS NOT NULL;
