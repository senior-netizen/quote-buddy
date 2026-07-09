-- Immutable FDMS device lifecycle records.  These tables append new rows for
-- certificates, keys, CSR material, configuration snapshots, and renewal events
-- so previous device credentials remain auditable and are never overwritten.

CREATE TABLE public.devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  environment TEXT NOT NULL CHECK (environment IN ('test','prod')),
  fdms_device_id TEXT NOT NULL,
  device_serial_no TEXT NOT NULL,
  device_model_name TEXT,
  device_model_version TEXT,
  activation_key TEXT NOT NULL,
  taxpayer_tin TEXT NOT NULL,
  vat_number TEXT,
  registration_response JSONB,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (environment, fdms_device_id),
  UNIQUE (org_id, environment, device_serial_no)
);

CREATE TABLE public.device_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  key_algorithm TEXT NOT NULL,
  key_size INTEGER NOT NULL,
  public_key_pem TEXT NOT NULL,
  encrypted_private_key_ref TEXT NOT NULL,
  csr_pem TEXT NOT NULL,
  csr_fingerprint TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (csr_fingerprint)
);

CREATE TABLE public.device_certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  fdms_device_id TEXT NOT NULL,
  environment TEXT NOT NULL CHECK (environment IN ('test','prod')),
  certificate_pem TEXT NOT NULL,
  certificate_serial_number TEXT,
  certificate_thumbprint TEXT NOT NULL,
  valid_from TIMESTAMPTZ,
  valid_to TIMESTAMPTZ,
  csr_pem TEXT,
  issued_by TEXT,
  fdms_response JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (certificate_thumbprint)
);

CREATE TABLE public.certificate_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  certificate_id UUID REFERENCES public.device_certificates(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('issued','renewal_due','renewal_requested','renewed','revoked','expired')),
  event_payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.device_configuration (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  fdms_device_id TEXT NOT NULL,
  environment TEXT NOT NULL CHECK (environment IN ('test','prod')),
  source TEXT NOT NULL CHECK (source IN ('fdms','manual')),
  configuration JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_devices_org_id ON public.devices(org_id);
CREATE INDEX idx_device_keys_device_id ON public.device_keys(device_id);
CREATE INDEX idx_device_certificates_device_id ON public.device_certificates(device_id);
CREATE INDEX idx_device_certificates_expiry ON public.device_certificates(valid_to);
CREATE INDEX idx_certificate_history_device_id ON public.certificate_history(device_id);
CREATE INDEX idx_device_configuration_device_id_created_at ON public.device_configuration(device_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.prevent_fdms_immutable_update_delete()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'FDMS lifecycle table % is immutable; append a new row instead', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER devices_immutable_update BEFORE UPDATE ON public.devices FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER devices_immutable_delete BEFORE DELETE ON public.devices FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER device_keys_immutable_update BEFORE UPDATE ON public.device_keys FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER device_keys_immutable_delete BEFORE DELETE ON public.device_keys FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER device_certificates_immutable_update BEFORE UPDATE ON public.device_certificates FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER device_certificates_immutable_delete BEFORE DELETE ON public.device_certificates FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER certificate_history_immutable_update BEFORE UPDATE ON public.certificate_history FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER certificate_history_immutable_delete BEFORE DELETE ON public.certificate_history FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER device_configuration_immutable_update BEFORE UPDATE ON public.device_configuration FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();
CREATE TRIGGER device_configuration_immutable_delete BEFORE DELETE ON public.device_configuration FOR EACH ROW EXECUTE FUNCTION public.prevent_fdms_immutable_update_delete();

GRANT SELECT, INSERT ON public.devices, public.device_certificates, public.device_keys, public.certificate_history, public.device_configuration TO authenticated;
GRANT ALL ON public.devices, public.device_certificates, public.device_keys, public.certificate_history, public.device_configuration TO service_role;

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificate_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_configuration ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view devices" ON public.devices FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can insert devices" ON public.devices FOR INSERT TO authenticated WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));
CREATE POLICY "Members can view device certificates" ON public.device_certificates FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can insert device certificates" ON public.device_certificates FOR INSERT TO authenticated WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));
CREATE POLICY "Members can view device keys" ON public.device_keys FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can insert device keys" ON public.device_keys FOR INSERT TO authenticated WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));
CREATE POLICY "Members can view certificate history" ON public.certificate_history FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can insert certificate history" ON public.certificate_history FOR INSERT TO authenticated WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));
CREATE POLICY "Members can view device configuration" ON public.device_configuration FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can insert device configuration" ON public.device_configuration FOR INSERT TO authenticated WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));
