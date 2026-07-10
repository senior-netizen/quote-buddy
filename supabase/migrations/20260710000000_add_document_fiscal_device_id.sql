-- Persist the FDMS/ZIMRA device identifier used to fiscalize each document so
-- receipt hash chains can be selected per device and fiscal day.
ALTER TABLE public.documents
  ADD COLUMN IF NOT EXISTS fiscal_device_id TEXT;

-- Existing fiscalized documents predate this column. Backfill them with the
-- organization's configured FDMS device id so future chain lookups do not skip
-- historical accepted receipts for installations that have not changed devices.
UPDATE public.documents AS d
SET fiscal_device_id = cfg.device_id
FROM public.organization_fiscal_config AS cfg
WHERE d.org_id = cfg.org_id
  AND d.receipt_hash IS NOT NULL
  AND d.fiscal_device_id IS NULL
  AND cfg.device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS documents_fiscal_hash_chain_idx
  ON public.documents (org_id, fiscal_device_id, fiscal_day_no, receipt_global_no DESC)
  WHERE receipt_hash IS NOT NULL;
