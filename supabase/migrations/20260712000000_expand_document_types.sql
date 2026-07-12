ALTER TABLE public.documents
  DROP CONSTRAINT IF EXISTS documents_doc_type_check;

ALTER TABLE public.documents
  ADD CONSTRAINT documents_doc_type_check
  CHECK (doc_type IN ('quote', 'invoice', 'credit_note', 'debit_note', 'receipt'));
