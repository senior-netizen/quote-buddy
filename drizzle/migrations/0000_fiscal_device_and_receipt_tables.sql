-- 1. documents: device attribution for the ZIMRA hash chain
ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS fiscal_device_id text;

-- 2. organization_fiscal_config: extra columns used by onboarding/config flows
ALTER TABLE public.organization_fiscal_config
  ADD COLUMN IF NOT EXISTS device_address text,
  ADD COLUMN IF NOT EXISTS device_model_name text,
  ADD COLUMN IF NOT EXISTS device_model_version text,
  ADD COLUMN IF NOT EXISTS activation_key_encrypted text,
  ADD COLUMN IF NOT EXISTS activation_key_id text,
  ADD COLUMN IF NOT EXISTS activation_key_secret_ref text,
  ADD COLUMN IF NOT EXISTS certificate_secret_ref text,
  ADD COLUMN IF NOT EXISTS private_key_secret_ref text;

-- 3. devices
CREATE TABLE IF NOT EXISTS public.devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  environment text NOT NULL DEFAULT 'test',
  fdms_device_id text NOT NULL,
  device_serial_no text,
  device_model_name text,
  device_model_version text,
  activation_key text,
  activation_key_encrypted text,
  activation_key_secret_ref text,
  activation_key_hash text,
  taxpayer_tin text,
  vat_number text,
  registration_response jsonb,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.devices TO authenticated;
GRANT ALL ON public.devices TO service_role;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Org admins read devices" ON public.devices FOR SELECT TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'));

-- 4. device_keys
CREATE TABLE IF NOT EXISTS public.device_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id uuid,
  key_algorithm text,
  key_size integer,
  public_key_pem text,
  encrypted_private_key_ref text,
  encrypted_payload text,
  key_id text,
  thumbprint text,
  active boolean NOT NULL DEFAULT true,
  csr_pem text,
  csr_fingerprint text,
  valid_from timestamptz,
  valid_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.device_keys TO service_role;
ALTER TABLE public.device_keys ENABLE ROW LEVEL SECURITY;

-- 5. device_certificates
CREATE TABLE IF NOT EXISTS public.device_certificates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id uuid,
  fdms_device_id text,
  environment text,
  certificate_pem text,
  encrypted_payload text,
  key_id text,
  thumbprint text,
  certificate_serial_number text,
  certificate_thumbprint text,
  active boolean NOT NULL DEFAULT true,
  valid_from timestamptz,
  valid_to timestamptz,
  valid_until timestamptz,
  csr_pem text,
  issued_by text,
  fdms_response jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.device_certificates TO service_role;
ALTER TABLE public.device_certificates ENABLE ROW LEVEL SECURITY;

-- 6. device_configuration
CREATE TABLE IF NOT EXISTS public.device_configuration (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id uuid,
  fdms_device_id text,
  environment text,
  source text NOT NULL DEFAULT 'fdms',
  configuration jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.device_configuration TO authenticated;
GRANT ALL ON public.device_configuration TO service_role;
ALTER TABLE public.device_configuration ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Org admins read device configuration" ON public.device_configuration FOR SELECT TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'));

-- 7. certificate_history
CREATE TABLE IF NOT EXISTS public.certificate_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id uuid,
  certificate_id uuid,
  event_type text NOT NULL,
  event_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.certificate_history TO authenticated;
GRANT ALL ON public.certificate_history TO service_role;
ALTER TABLE public.certificate_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Org admins read certificate history" ON public.certificate_history FOR SELECT TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'));

-- 8. receipt_status: immutable status event log
CREATE TABLE IF NOT EXISTS public.receipt_status (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  status text NOT NULL,
  message text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS receipt_status_document_idx ON public.receipt_status (document_id, created_at DESC);
GRANT SELECT ON public.receipt_status TO authenticated;
GRANT ALL ON public.receipt_status TO service_role;
ALTER TABLE public.receipt_status ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Org members read receipt status" ON public.receipt_status FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id));

-- 9. current_receipt_status view (latest event per document)
CREATE OR REPLACE VIEW public.current_receipt_status
WITH (security_invoker = on) AS
SELECT DISTINCT ON (rs.document_id)
  rs.document_id,
  rs.org_id,
  rs.status,
  rs.message,
  rs.metadata,
  rs.created_at
FROM public.receipt_status rs
ORDER BY rs.document_id, rs.created_at DESC, rs.id DESC;
GRANT SELECT ON public.current_receipt_status TO authenticated;
GRANT SELECT ON public.current_receipt_status TO service_role;

-- 10. receipt_history: allocated fiscal counters per document
CREATE TABLE IF NOT EXISTS public.receipt_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  receipt_type text NOT NULL DEFAULT 'FiscalInvoice',
  fiscal_day_no integer NOT NULL,
  receipt_global_no bigint NOT NULL,
  receipt_counter integer NOT NULL,
  receipt_type_counter integer,
  invoice_no text NOT NULL,
  status text NOT NULL DEFAULT 'allocated',
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (document_id)
);
GRANT SELECT ON public.receipt_history TO authenticated;
GRANT ALL ON public.receipt_history TO service_role;
ALTER TABLE public.receipt_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Org members read receipt history" ON public.receipt_history FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id));

-- 11. atomic counter allocation
CREATE OR REPLACE FUNCTION public.allocate_fiscal_receipt_counters(
  _org_id uuid,
  _document_id uuid,
  _receipt_type text DEFAULT 'FiscalInvoice',
  _requires_receipt_type_counter boolean DEFAULT true
)
RETURNS TABLE (
  fiscal_day_no integer,
  receipt_global_no bigint,
  receipt_counter integer,
  receipt_type_counter integer,
  invoice_no text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_day public.fiscal_days%ROWTYPE;
  v_existing public.receipt_history%ROWTYPE;
  v_global bigint;
  v_counter integer;
  v_type_counter integer;
  v_invoice text;
BEGIN
  SELECT * INTO v_existing FROM public.receipt_history WHERE document_id = _document_id;
  IF FOUND THEN
    RETURN QUERY SELECT v_existing.fiscal_day_no, v_existing.receipt_global_no,
                        v_existing.receipt_counter, v_existing.receipt_type_counter,
                        v_existing.invoice_no;
    RETURN;
  END IF;

  SELECT * INTO v_day
  FROM public.fiscal_days
  WHERE org_id = _org_id AND status = 'open'
  ORDER BY opened_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No open fiscal day for organization %', _org_id;
  END IF;

  UPDATE public.organization_fiscal_config
     SET last_receipt_global_no = COALESCE(last_receipt_global_no, 0) + 1,
         last_receipt_counter = COALESCE(last_receipt_counter, 0) + 1,
         updated_at = now()
   WHERE org_id = _org_id
   RETURNING last_receipt_global_no, last_receipt_counter
    INTO v_global, v_counter;

  IF v_global IS NULL THEN
    RAISE EXCEPTION 'No fiscal configuration for organization %', _org_id;
  END IF;

  IF _requires_receipt_type_counter THEN
    SELECT COALESCE(MAX(receipt_type_counter), 0) + 1 INTO v_type_counter
    FROM public.receipt_history
    WHERE org_id = _org_id AND receipt_type = _receipt_type AND fiscal_day_no = v_day.fiscal_day_no;
  ELSE
    v_type_counter := NULL;
  END IF;

  v_invoice := to_char(v_day.fiscal_day_no, 'FM0000') || '-' || to_char(v_counter, 'FM0000000');

  INSERT INTO public.receipt_history (
    org_id, document_id, receipt_type, fiscal_day_no, receipt_global_no,
    receipt_counter, receipt_type_counter, invoice_no, status
  ) VALUES (
    _org_id, _document_id, _receipt_type, v_day.fiscal_day_no, v_global,
    v_counter, v_type_counter, v_invoice, 'allocated'
  );

  RETURN QUERY SELECT v_day.fiscal_day_no, v_global, v_counter, v_type_counter, v_invoice;
END;
$$;

REVOKE ALL ON FUNCTION public.allocate_fiscal_receipt_counters(uuid, uuid, text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.allocate_fiscal_receipt_counters(uuid, uuid, text, boolean) TO service_role;