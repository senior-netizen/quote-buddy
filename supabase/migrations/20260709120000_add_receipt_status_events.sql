-- Immutable fiscal receipt status event log and current-status read model.
CREATE TABLE public.receipt_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES public.documents(id),
  org_id UUID NOT NULL REFERENCES public.organizations(id),
  status TEXT NOT NULL CHECK (status IN ('Draft','Ready','Signed','Submitted','Accepted','Rejected','Retrying','Cancelled')),
  message TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX receipt_status_document_created_idx
  ON public.receipt_status (document_id, created_at DESC, id DESC);

CREATE INDEX receipt_status_org_status_created_idx
  ON public.receipt_status (org_id, status, created_at DESC);

GRANT SELECT, INSERT ON public.receipt_status TO authenticated;
GRANT ALL ON public.receipt_status TO service_role;

ALTER TABLE public.receipt_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view receipt status events"
  ON public.receipt_status FOR SELECT TO authenticated
  USING (public.is_org_member(auth.uid(), org_id));

CREATE POLICY "Admins can append receipt status events"
  ON public.receipt_status FOR INSERT TO authenticated
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE OR REPLACE FUNCTION public.prevent_receipt_status_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'receipt_status events are immutable';
END;
$$;

CREATE TRIGGER receipt_status_no_update
  BEFORE UPDATE ON public.receipt_status
  FOR EACH ROW EXECUTE FUNCTION public.prevent_receipt_status_mutation();

CREATE TRIGGER receipt_status_no_delete
  BEFORE DELETE ON public.receipt_status
  FOR EACH ROW EXECUTE FUNCTION public.prevent_receipt_status_mutation();

INSERT INTO public.receipt_status (document_id, org_id, status, message, metadata, created_at)
SELECT
  d.id,
  d.org_id,
  CASE d.fiscal_status
    WHEN 'pending' THEN 'Submitted'
    WHEN 'submitted' THEN 'Accepted'
    WHEN 'failed' THEN 'Rejected'
    WHEN 'skipped' THEN 'Cancelled'
    ELSE 'Draft'
  END,
  'Backfilled from documents.fiscal_status',
  jsonb_build_object('legacy_fiscal_status', d.fiscal_status),
  COALESCE(d.fiscal_submitted_at, d.created_at, now())
FROM public.documents d
WHERE NOT EXISTS (
  SELECT 1 FROM public.receipt_status rs WHERE rs.document_id = d.id
);

CREATE VIEW public.current_receipt_status
WITH (security_invoker = true) AS
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
GRANT ALL ON public.current_receipt_status TO service_role;
