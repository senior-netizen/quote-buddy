-- Tighten bucket constraints
UPDATE storage.buckets
SET file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/png','image/jpeg','image/svg+xml','image/webp']
WHERE id = 'org-logos';

-- Drop all existing org-logos policies (duplicates exist) and recreate a single clean set
DROP POLICY IF EXISTS "Admins can delete org logos" ON storage.objects;
DROP POLICY IF EXISTS "Admins can update org logos" ON storage.objects;
DROP POLICY IF EXISTS "Admins can upload org logos" ON storage.objects;
DROP POLICY IF EXISTS "Org admins can delete logos" ON storage.objects;
DROP POLICY IF EXISTS "Org admins can update logos" ON storage.objects;
DROP POLICY IF EXISTS "Org admins can upload logos" ON storage.objects;
DROP POLICY IF EXISTS "Org logos are public" ON storage.objects;
DROP POLICY IF EXISTS "Public can view org logos" ON storage.objects;

-- Helper expression: first path segment must be a valid UUID matching an org
-- where the caller is admin or owner.
CREATE POLICY "org_logos_public_read"
ON storage.objects FOR SELECT
USING (bucket_id = 'org-logos');

CREATE POLICY "org_logos_admin_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'org-logos'
  AND auth.uid() IS NOT NULL
  AND (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin'::public.app_role)
);

CREATE POLICY "org_logos_admin_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'org-logos'
  AND (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin'::public.app_role)
)
WITH CHECK (
  bucket_id = 'org-logos'
  AND (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin'::public.app_role)
);

CREATE POLICY "org_logos_admin_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'org-logos'
  AND (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND public.has_org_role(auth.uid(), ((storage.foldername(name))[1])::uuid, 'admin'::public.app_role)
);