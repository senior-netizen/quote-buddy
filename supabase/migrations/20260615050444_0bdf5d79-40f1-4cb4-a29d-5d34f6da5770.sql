ALTER TABLE public.organization_profiles ADD COLUMN praz TEXT;

COMMENT ON COLUMN public.organization_profiles.praz IS 'Public Registration of Zimbabwe (PRAZ) number';
