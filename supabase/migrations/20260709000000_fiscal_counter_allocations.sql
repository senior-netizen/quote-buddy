-- Atomic fiscal receipt counter allocation and durable allocation history.

CREATE TABLE public.fiscal_day_counters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  fiscal_day_no INTEGER NOT NULL,
  counter_type TEXT NOT NULL,
  counter_value BIGINT NOT NULL,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  receipt_type TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (org_id, device_id, fiscal_day_no, counter_type, counter_value),
  UNIQUE (org_id, document_id, counter_type)
);

GRANT SELECT, INSERT ON public.fiscal_day_counters TO authenticated;
GRANT ALL ON public.fiscal_day_counters TO service_role;

ALTER TABLE public.fiscal_day_counters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view fiscal day counters"
  ON public.fiscal_day_counters FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id));

CREATE POLICY "Admins can insert fiscal day counters"
  ON public.fiscal_day_counters FOR INSERT TO authenticated
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE TABLE public.receipt_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  fiscal_day_no INTEGER NOT NULL,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  invoice_no TEXT NOT NULL,
  receipt_type TEXT NOT NULL,
  receipt_global_no BIGINT NOT NULL,
  receipt_counter INTEGER NOT NULL,
  receipt_type_counter INTEGER,
  status TEXT NOT NULL DEFAULT 'allocated' CHECK (status IN ('allocated','submitted','failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  submitted_at TIMESTAMPTZ,
  UNIQUE (org_id, document_id),
  UNIQUE (org_id, device_id, fiscal_day_no, invoice_no),
  UNIQUE (org_id, device_id, fiscal_day_no, receipt_type, receipt_type_counter),
  UNIQUE (org_id, device_id, fiscal_day_no, receipt_type, receipt_counter)
);

CREATE UNIQUE INDEX receipt_history_global_no_key
  ON public.receipt_history (org_id, device_id, fiscal_day_no, receipt_global_no);

GRANT SELECT, INSERT, UPDATE ON public.receipt_history TO authenticated;
GRANT ALL ON public.receipt_history TO service_role;

ALTER TABLE public.receipt_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view receipt history"
  ON public.receipt_history FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id));

CREATE POLICY "Admins can insert receipt history"
  ON public.receipt_history FOR INSERT TO authenticated
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Admins can update receipt history"
  ON public.receipt_history FOR UPDATE TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'))
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE OR REPLACE FUNCTION public.allocate_fiscal_receipt_counters(
  _org_id UUID,
  _document_id UUID,
  _receipt_type TEXT DEFAULT 'FiscalInvoice',
  _requires_receipt_type_counter BOOLEAN DEFAULT true
)
RETURNS TABLE (
  fiscal_day_no INTEGER,
  receipt_global_no BIGINT,
  receipt_counter INTEGER,
  receipt_type_counter INTEGER,
  invoice_no TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cfg RECORD;
  day_row RECORD;
  doc_row RECORD;
  next_global BIGINT;
  next_day_counter INTEGER;
  next_type_counter INTEGER;
BEGIN
  SELECT * INTO cfg
  FROM public.organization_fiscal_config
  WHERE org_id = _org_id
  FOR UPDATE;

  IF NOT FOUND OR NOT cfg.enabled OR cfg.device_id IS NULL THEN
    RAISE EXCEPTION 'Fiscal config is not enabled or device ID is missing';
  END IF;

  SELECT * INTO day_row
  FROM public.fiscal_days fd
  WHERE fd.org_id = _org_id AND fd.status = 'open'
  ORDER BY fd.fiscal_day_no DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Open a fiscal day before fiscalising receipts';
  END IF;

  SELECT * INTO doc_row
  FROM public.documents
  WHERE id = _document_id AND org_id = _org_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document not found';
  END IF;

  IF doc_row.doc_type <> 'invoice' THEN
    RAISE EXCEPTION 'Only invoices can be fiscalised';
  END IF;

  IF doc_row.fiscal_status = 'submitted' THEN
    RAISE EXCEPTION 'Already submitted to ZIMRA';
  END IF;

  SELECT rh.fiscal_day_no, rh.receipt_global_no, rh.receipt_counter, rh.receipt_type_counter, rh.invoice_no
  INTO fiscal_day_no, receipt_global_no, receipt_counter, receipt_type_counter, invoice_no
  FROM public.receipt_history rh
  WHERE rh.org_id = _org_id AND rh.document_id = _document_id;

  IF FOUND THEN
    RETURN NEXT;
    RETURN;
  END IF;

  next_global := COALESCE(cfg.last_receipt_global_no, 0) + 1;

  SELECT COALESCE(MAX(fdc.counter_value), 0)::INTEGER + 1 INTO next_day_counter
  FROM public.fiscal_day_counters fdc
  WHERE fdc.org_id = _org_id
    AND fdc.device_id = cfg.device_id
    AND fdc.fiscal_day_no = day_row.fiscal_day_no
    AND fdc.counter_type = 'receipt_counter';

  IF _requires_receipt_type_counter THEN
    SELECT COALESCE(MAX(fdc.counter_value), 0)::INTEGER + 1 INTO next_type_counter
    FROM public.fiscal_day_counters fdc
    WHERE fdc.org_id = _org_id
      AND fdc.device_id = cfg.device_id
      AND fdc.fiscal_day_no = day_row.fiscal_day_no
      AND fdc.counter_type = _receipt_type;
  ELSE
    next_type_counter := NULL;
  END IF;

  INSERT INTO public.fiscal_day_counters (org_id, device_id, fiscal_day_no, counter_type, counter_value, document_id, receipt_type)
  VALUES
    (_org_id, cfg.device_id, day_row.fiscal_day_no, 'receipt_global_no', next_global, _document_id, _receipt_type),
    (_org_id, cfg.device_id, day_row.fiscal_day_no, 'receipt_counter', next_day_counter, _document_id, _receipt_type);

  IF next_type_counter IS NOT NULL THEN
    INSERT INTO public.fiscal_day_counters (org_id, device_id, fiscal_day_no, counter_type, counter_value, document_id, receipt_type)
    VALUES (_org_id, cfg.device_id, day_row.fiscal_day_no, _receipt_type, next_type_counter, _document_id, _receipt_type);
  END IF;

  INSERT INTO public.receipt_history (
    org_id, device_id, fiscal_day_no, document_id, invoice_no, receipt_type,
    receipt_global_no, receipt_counter, receipt_type_counter
  ) VALUES (
    _org_id, cfg.device_id, day_row.fiscal_day_no, _document_id, doc_row.doc_number, _receipt_type,
    next_global, next_day_counter, next_type_counter
  );

  UPDATE public.documents
  SET fiscal_status = 'pending',
      fiscal_day_no = day_row.fiscal_day_no,
      receipt_global_no = next_global,
      receipt_counter = next_day_counter
  WHERE id = _document_id;

  UPDATE public.organization_fiscal_config
  SET last_receipt_global_no = next_global,
      last_receipt_counter = next_day_counter
  WHERE org_id = _org_id;

  fiscal_day_no := day_row.fiscal_day_no;
  receipt_global_no := next_global;
  receipt_counter := next_day_counter;
  receipt_type_counter := next_type_counter;
  invoice_no := doc_row.doc_number;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.allocate_fiscal_receipt_counters(UUID, UUID, TEXT, BOOLEAN) TO authenticated, service_role;
