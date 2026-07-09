-- Full fiscal audit schema
-- The tables below are designed to preserve history. Operational state transitions are
-- represented by appended rows in status/history/log tables and exposed with views.

CREATE OR REPLACE FUNCTION public.prevent_fiscal_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Fiscal audit rows are append-only; append a new history/status row instead';
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_fiscal_audit_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Fiscal audit rows cannot be deleted';
END;
$$;

CREATE OR REPLACE FUNCTION public.install_append_only_guard(_table regclass)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  table_name_text text := replace(_table::text, '.', '_');
BEGIN
  EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', 'prevent_update_' || table_name_text, _table);
  EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', 'prevent_delete_' || table_name_text, _table);
  EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION public.prevent_fiscal_audit_mutation()', 'prevent_update_' || table_name_text, _table);
  EXECUTE format('CREATE TRIGGER %I BEFORE DELETE ON %s FOR EACH ROW EXECUTE FUNCTION public.prevent_fiscal_audit_delete()', 'prevent_delete_' || table_name_text, _table);
END;
$$;

-- -----------------------------------------------------------------------------
-- Device identity and cryptographic material
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  external_device_id TEXT NOT NULL,
  serial_number TEXT,
  model TEXT,
  manufacturer TEXT,
  environment TEXT NOT NULL DEFAULT 'test' CHECK (environment IN ('test','prod')),
  activation_key_hash TEXT,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  registered_by UUID,
  source TEXT NOT NULL DEFAULT 'app',
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, external_device_id, environment)
);

CREATE TABLE IF NOT EXISTS public.device_certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  certificate_pem TEXT NOT NULL,
  certificate_fingerprint TEXT NOT NULL,
  subject TEXT,
  issuer TEXT,
  serial_number TEXT,
  valid_from TIMESTAMPTZ,
  valid_to TIMESTAMPTZ,
  installed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  installed_by UUID,
  supersedes_certificate_id UUID REFERENCES public.device_certificates(id) ON DELETE RESTRICT,
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (device_id, certificate_fingerprint)
);

CREATE TABLE IF NOT EXISTS public.device_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  key_label TEXT NOT NULL,
  key_type TEXT NOT NULL DEFAULT 'private' CHECK (key_type IN ('private','public','symmetric','csr')),
  algorithm TEXT,
  key_fingerprint TEXT NOT NULL,
  encrypted_key TEXT,
  public_key_pem TEXT,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  generated_by UUID,
  supersedes_key_id UUID REFERENCES public.device_keys(id) ON DELETE RESTRICT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (device_id, key_fingerprint)
);

CREATE TABLE IF NOT EXISTS public.certificate_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_certificate_id UUID NOT NULL REFERENCES public.device_certificates(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('issued','installed','activated','rotated','revoked','expired','validation_failed','archived')),
  event_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id UUID,
  reason TEXT,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Fiscal days and counters
-- -----------------------------------------------------------------------------

ALTER TABLE public.fiscal_days
  ADD COLUMN IF NOT EXISTS device_id UUID REFERENCES public.devices(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS opened_by UUID,
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'app';

CREATE TABLE IF NOT EXISTS public.fiscal_day_counters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_day_id UUID NOT NULL REFERENCES public.fiscal_days(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE RESTRICT,
  counter_name TEXT NOT NULL,
  counter_value NUMERIC(20,4) NOT NULL,
  currency TEXT,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source TEXT NOT NULL DEFAULT 'device',
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fdms_operations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE RESTRICT,
  fiscal_day_id UUID REFERENCES public.fiscal_days(id) ON DELETE SET NULL,
  document_id UUID REFERENCES public.documents(id) ON DELETE SET NULL,
  operation_type TEXT NOT NULL,
  request_id TEXT,
  idempotency_key TEXT,
  request_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  response_payload JSONB,
  http_status INTEGER,
  fdms_status TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS public.fdms_errors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id UUID REFERENCES public.fdms_operations(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE RESTRICT,
  error_code TEXT,
  error_message TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'error' CHECK (severity IN ('info','warning','error','critical')),
  retryable BOOLEAN NOT NULL DEFAULT false,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  context JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Receipt audit records
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.receipt_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  fiscal_day_id UUID REFERENCES public.fiscal_days(id) ON DELETE SET NULL,
  device_id UUID REFERENCES public.devices(id) ON DELETE RESTRICT,
  receipt_global_no BIGINT,
  receipt_counter INTEGER,
  signature_algorithm TEXT NOT NULL,
  signature_value TEXT NOT NULL,
  signed_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  signed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.receipt_hashes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  previous_hash TEXT,
  receipt_hash TEXT NOT NULL,
  hash_algorithm TEXT NOT NULL DEFAULT 'SHA-256',
  canonical_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  hashed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, receipt_hash)
);

CREATE TABLE IF NOT EXISTS public.receipt_server_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  operation_id UUID REFERENCES public.fdms_operations(id) ON DELETE SET NULL,
  server_signature TEXT NOT NULL,
  verification_code TEXT,
  receipt_qr_url TEXT,
  response_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.receipt_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('draft','queued','signing','signed','submitted','accepted','rejected','failed','cancelled','corrected')),
  status_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id UUID,
  operation_id UUID REFERENCES public.fdms_operations(id) ON DELETE SET NULL,
  reason TEXT,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.receipt_validation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  validation_type TEXT NOT NULL,
  is_valid BOOLEAN NOT NULL,
  validated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  validator TEXT,
  errors JSONB NOT NULL DEFAULT '[]'::jsonb,
  warnings JSONB NOT NULL DEFAULT '[]'::jsonb,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.receipt_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id UUID,
  operation_id UUID REFERENCES public.fdms_operations(id) ON DELETE SET NULL,
  snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Sync, configuration, tax, queue, and audit trails
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.sync_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE RESTRICT,
  job_type TEXT NOT NULL,
  idempotency_key TEXT,
  requested_by UUID,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  parameters JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS public.sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sync_job_id UUID NOT NULL REFERENCES public.sync_jobs(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  level TEXT NOT NULL DEFAULT 'info' CHECK (level IN ('debug','info','warning','error')),
  message TEXT NOT NULL,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  context JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.device_configuration (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  config_key TEXT NOT NULL,
  config_value JSONB NOT NULL,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  recorded_by UUID,
  source TEXT NOT NULL DEFAULT 'app',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tax_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  tax_code TEXT NOT NULL,
  name TEXT NOT NULL,
  rate NUMERIC(8,4) NOT NULL,
  effective_from DATE NOT NULL,
  recorded_by UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, tax_code, effective_from)
);

CREATE TABLE IF NOT EXISTS public.offline_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE RESTRICT,
  document_id UUID REFERENCES public.documents(id) ON DELETE SET NULL,
  queue_key TEXT NOT NULL,
  payload JSONB NOT NULL,
  enqueued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, queue_key)
);

CREATE TABLE IF NOT EXISTS public.audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  actor_id UUID,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  event_type TEXT NOT NULL,
  event_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip_address INET,
  user_agent TEXT,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS devices_org_idx ON public.devices(org_id, environment, external_device_id);
CREATE INDEX IF NOT EXISTS device_certificates_device_idx ON public.device_certificates(device_id, installed_at DESC);
CREATE INDEX IF NOT EXISTS device_keys_device_idx ON public.device_keys(device_id, generated_at DESC);
CREATE INDEX IF NOT EXISTS fiscal_day_counters_day_idx ON public.fiscal_day_counters(fiscal_day_id, captured_at DESC);
CREATE INDEX IF NOT EXISTS fdms_operations_org_idx ON public.fdms_operations(org_id, started_at DESC);
CREATE INDEX IF NOT EXISTS fdms_errors_org_idx ON public.fdms_errors(org_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS receipt_signatures_document_idx ON public.receipt_signatures(document_id, signed_at DESC);
CREATE INDEX IF NOT EXISTS receipt_hashes_document_idx ON public.receipt_hashes(document_id, hashed_at DESC);
CREATE INDEX IF NOT EXISTS receipt_server_signatures_document_idx ON public.receipt_server_signatures(document_id, received_at DESC);
CREATE INDEX IF NOT EXISTS receipt_status_document_idx ON public.receipt_status(document_id, status_at DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS receipt_validation_document_idx ON public.receipt_validation(document_id, validated_at DESC);
CREATE INDEX IF NOT EXISTS receipt_history_document_idx ON public.receipt_history(document_id, event_at DESC);
CREATE INDEX IF NOT EXISTS certificate_history_org_idx ON public.certificate_history(org_id, event_at DESC);
CREATE INDEX IF NOT EXISTS sync_jobs_org_idx ON public.sync_jobs(org_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS sync_logs_job_idx ON public.sync_logs(sync_job_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS device_configuration_current_idx ON public.device_configuration(device_id, config_key, effective_from DESC);
CREATE INDEX IF NOT EXISTS tax_rates_current_idx ON public.tax_rates(org_id, tax_code, effective_from DESC);
CREATE INDEX IF NOT EXISTS offline_queue_org_idx ON public.offline_queue(org_id, available_at, enqueued_at);
CREATE INDEX IF NOT EXISTS audit_events_org_idx ON public.audit_events(org_id, event_at DESC);

-- RLS and grants
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'devices','device_certificates','device_keys','fiscal_day_counters','receipt_signatures','receipt_hashes',
    'receipt_server_signatures','receipt_status','receipt_validation','fdms_operations','fdms_errors','sync_jobs',
    'sync_logs','device_configuration','tax_rates','receipt_history','certificate_history','offline_queue','audit_events'
  ] LOOP
    EXECUTE format('GRANT SELECT, INSERT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- Policies use organization membership. Certificate/key tables derive org through devices/certificates.
CREATE POLICY "Members can view devices" ON public.devices FOR SELECT TO authenticated USING (public.is_org_member(auth.uid(), org_id));
CREATE POLICY "Admins can insert devices" ON public.devices FOR INSERT TO authenticated WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Members can view device certificates" ON public.device_certificates FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.devices d WHERE d.id = device_id AND public.is_org_member(auth.uid(), d.org_id)));
CREATE POLICY "Admins can insert device certificates" ON public.device_certificates FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.devices d WHERE d.id = device_id AND public.has_org_role(auth.uid(), d.org_id, 'admin')));

CREATE POLICY "Members can view device keys" ON public.device_keys FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.devices d WHERE d.id = device_id AND public.is_org_member(auth.uid(), d.org_id)));
CREATE POLICY "Admins can insert device keys" ON public.device_keys FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.devices d WHERE d.id = device_id AND public.has_org_role(auth.uid(), d.org_id, 'admin')));

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'fiscal_day_counters','receipt_signatures','receipt_hashes','receipt_server_signatures','receipt_status',
    'receipt_validation','fdms_operations','fdms_errors','sync_jobs','sync_logs','device_configuration','tax_rates',
    'receipt_history','certificate_history','offline_queue','audit_events'
  ] LOOP
    EXECUTE format('CREATE POLICY "Members can view %1$s" ON public.%1$I FOR SELECT TO authenticated USING (org_id IS NULL OR public.is_org_member(auth.uid(), org_id))', t);
    EXECUTE format('CREATE POLICY "Admins can insert %1$s" ON public.%1$I FOR INSERT TO authenticated WITH CHECK (org_id IS NULL OR public.has_org_role(auth.uid(), org_id, ''admin''))', t);
  END LOOP;
END $$;

-- Current-state views. These provide queryable state without in-place fact updates.
CREATE OR REPLACE VIEW public.current_receipt_status WITH (security_invoker = true) AS
SELECT DISTINCT ON (rs.document_id)
  rs.*
FROM public.receipt_status rs
ORDER BY rs.document_id, rs.status_at DESC, rs.created_at DESC;

CREATE OR REPLACE VIEW public.current_device_configuration WITH (security_invoker = true) AS
SELECT DISTINCT ON (dc.device_id, dc.config_key)
  dc.*
FROM public.device_configuration dc
ORDER BY dc.device_id, dc.config_key, dc.effective_from DESC, dc.created_at DESC;

CREATE OR REPLACE VIEW public.current_tax_rates WITH (security_invoker = true) AS
SELECT DISTINCT ON (tr.org_id, tr.tax_code)
  tr.*
FROM public.tax_rates tr
WHERE tr.effective_from <= CURRENT_DATE
ORDER BY tr.org_id, tr.tax_code, tr.effective_from DESC, tr.created_at DESC;

CREATE OR REPLACE VIEW public.current_device_certificates WITH (security_invoker = true) AS
SELECT DISTINCT ON (dc.device_id)
  dc.*
FROM public.device_certificates dc
WHERE dc.valid_to IS NULL OR dc.valid_to > now()
ORDER BY dc.device_id, dc.installed_at DESC, dc.created_at DESC;

GRANT SELECT ON public.current_receipt_status TO authenticated;
GRANT SELECT ON public.current_device_configuration TO authenticated;
GRANT SELECT ON public.current_tax_rates TO authenticated;
GRANT SELECT ON public.current_device_certificates TO authenticated;
GRANT ALL ON public.current_receipt_status TO service_role;
GRANT ALL ON public.current_device_configuration TO service_role;
GRANT ALL ON public.current_tax_rates TO service_role;
GRANT ALL ON public.current_device_certificates TO service_role;

-- Append-only guards. Keep mutations out of the audit ledger; append status/history rows instead.
SELECT public.install_append_only_guard('public.fiscal_days'::regclass);
SELECT public.install_append_only_guard('public.devices'::regclass);
SELECT public.install_append_only_guard('public.device_certificates'::regclass);
SELECT public.install_append_only_guard('public.device_keys'::regclass);
SELECT public.install_append_only_guard('public.fiscal_day_counters'::regclass);
SELECT public.install_append_only_guard('public.receipt_signatures'::regclass);
SELECT public.install_append_only_guard('public.receipt_hashes'::regclass);
SELECT public.install_append_only_guard('public.receipt_server_signatures'::regclass);
SELECT public.install_append_only_guard('public.receipt_status'::regclass);
SELECT public.install_append_only_guard('public.receipt_validation'::regclass);
SELECT public.install_append_only_guard('public.fdms_operations'::regclass);
SELECT public.install_append_only_guard('public.fdms_errors'::regclass);
SELECT public.install_append_only_guard('public.sync_jobs'::regclass);
SELECT public.install_append_only_guard('public.sync_logs'::regclass);
SELECT public.install_append_only_guard('public.device_configuration'::regclass);
SELECT public.install_append_only_guard('public.tax_rates'::regclass);
SELECT public.install_append_only_guard('public.receipt_history'::regclass);
SELECT public.install_append_only_guard('public.certificate_history'::regclass);
SELECT public.install_append_only_guard('public.offline_queue'::regclass);
SELECT public.install_append_only_guard('public.audit_events'::regclass);
