-- Optional cleanup: orphan business_media rows whose storage objects are gone.
-- Review first. Safe subset: only non-http supabase paths for demo-unrelated uploads
-- that are known missing from diagnosis (NoSuchKey).
--
-- Paste into Supabase SQL Editor ONLY if you want to remove broken gallery rows
-- that spam 400 errors. Demo picsum rows (storage_path like http%) are kept.

-- Preview what would be deleted:
-- select id, storage_path, media_type
-- from public.business_media
-- where storage_path not like 'http%'
--   and storage_provider = 'supabase';

-- Delete broken non-demo storage references (keeps external/http demo assets):
delete from public.business_media
where storage_path not like 'http%'
  and coalesce(storage_provider, 'supabase') = 'supabase'
  and id in (
    '215d8bc4-d9df-4338-bf71-662f87d2040b',
    'f3bf4420-dad4-4a7c-a2f2-7e179c3e0a4b',
    '8dd86ac4-e76d-46f7-90ff-3fa3b5693e60',
    'fa90b33a-85e2-4027-9dd2-afffe2b35a13',
    '164f6ca8-e2fc-4b88-9f56-c85bc0564cde',
    '508f0b6c-d797-4dc6-8a43-d3a738d5ef1c',
    '52b451ef-046a-4975-a1b3-28f2d900b79d',
    '16d68c1d-1641-4ca6-8f91-a9a29a1c40e4',
    '663b79b8-6faa-4c8b-ab23-be3454dab102',
    '7a1a57d0-5b87-42d8-a57b-6897ef9de83e'
  );
