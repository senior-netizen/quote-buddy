
CREATE TABLE public.api_keys (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  prefix TEXT NOT NULL,
  key_hash TEXT NOT NULL UNIQUE,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX api_keys_org_id_idx ON public.api_keys(org_id);
CREATE INDEX api_keys_key_hash_idx ON public.api_keys(key_hash);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.api_keys TO authenticated;
GRANT ALL ON public.api_keys TO service_role;

ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Org admins can view api keys"
  ON public.api_keys FOR SELECT
  TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Org admins can insert api keys"
  ON public.api_keys FOR INSERT
  TO authenticated
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Org admins can update api keys"
  ON public.api_keys FOR UPDATE
  TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'))
  WITH CHECK (public.has_org_role(auth.uid(), org_id, 'admin'));

CREATE POLICY "Org admins can delete api keys"
  ON public.api_keys FOR DELETE
  TO authenticated
  USING (public.has_org_role(auth.uid(), org_id, 'admin'));
