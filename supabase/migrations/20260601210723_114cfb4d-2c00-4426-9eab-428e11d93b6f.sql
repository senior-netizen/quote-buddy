
-- Allow anyone to read org logos (bucket is already public, but make policy explicit)
CREATE POLICY "Public can view org logos"
ON storage.objects FOR SELECT
USING (bucket_id = 'org-logos');

-- Admins/owners of an org can insert into that org's folder
CREATE POLICY "Org admins can upload logos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'org-logos'
  AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin'::public.app_role)
);

CREATE POLICY "Org admins can update logos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'org-logos'
  AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin'::public.app_role)
);

CREATE POLICY "Org admins can delete logos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'org-logos'
  AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin'::public.app_role)
);
