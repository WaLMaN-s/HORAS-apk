-- 0009_place_coordinates.sql: Koordinat Tempat Umum (Lapangan & Gereja)
-- Catatan Privasi (SEK-R2, AC-07): Koordinat HANYA untuk tempat umum (courts, churches),
-- TIDAK PERNAH untuk pengguna (profiles).

-- 1. Kolom koordinat pada public.churches beserta batas rentang yang sah
ALTER TABLE public.churches
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

ALTER TABLE public.churches
  DROP CONSTRAINT IF EXISTS chk_churches_latitude_range,
  ADD CONSTRAINT chk_churches_latitude_range
    CHECK (latitude IS NULL OR (latitude >= -90.0 AND latitude <= 90.0)),
  DROP CONSTRAINT IF EXISTS chk_churches_longitude_range,
  ADD CONSTRAINT chk_churches_longitude_range
    CHECK (longitude IS NULL OR (longitude >= -180.0 AND longitude <= 180.0));

-- 2. Batas rentang koordinat pada public.courts
ALTER TABLE public.courts
  DROP CONSTRAINT IF EXISTS chk_courts_latitude_range,
  ADD CONSTRAINT chk_courts_latitude_range
    CHECK (latitude IS NULL OR (latitude >= -90.0 AND latitude <= 90.0)),
  DROP CONSTRAINT IF EXISTS chk_courts_longitude_range,
  ADD CONSTRAINT chk_courts_longitude_range
    CHECK (longitude IS NULL OR (longitude >= -180.0 AND longitude <= 180.0));

CREATE INDEX IF NOT EXISTS idx_courts_city_coords
  ON public.courts (city)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_churches_city_coords
  ON public.churches (city)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- 3. Isi koordinat pada 10 lapangan benih bila belum terisi
UPDATE public.courts SET latitude = 3.5952, longitude = 98.6722 WHERE id = '10000000-0000-4000-8000-000000000001' AND latitude IS NULL;
UPDATE public.courts SET latitude = 3.5714, longitude = 98.6415 WHERE id = '10000000-0000-4000-8000-000000000002' AND latitude IS NULL;
UPDATE public.courts SET latitude = -6.2361, longitude = 106.8524 WHERE id = '10000000-0000-4000-8000-000000000003' AND latitude IS NULL;
UPDATE public.courts SET latitude = -6.1942, longitude = 106.8925 WHERE id = '10000000-0000-4000-8000-000000000004' AND latitude IS NULL;
UPDATE public.courts SET latitude = -6.8915, longitude = 107.6105 WHERE id = '10000000-0000-4000-8000-000000000005' AND latitude IS NULL;
UPDATE public.courts SET latitude = -6.9298, longitude = 107.6258 WHERE id = '10000000-0000-4000-8000-000000000006' AND latitude IS NULL;
UPDATE public.courts SET latitude = 1.1301, longitude = 104.0529 WHERE id = '10000000-0000-4000-8000-000000000007' AND latitude IS NULL;
UPDATE public.courts SET latitude = 1.0543, longitude = 103.9612 WHERE id = '10000000-0000-4000-8000-000000000008' AND latitude IS NULL;
UPDATE public.courts SET latitude = 2.9591, longitude = 99.0687 WHERE id = '10000000-0000-4000-8000-000000000009' AND latitude IS NULL;
UPDATE public.courts SET latitude = 2.9612, longitude = 99.0654 WHERE id = '10000000-0000-4000-8000-000000000010' AND latitude IS NULL;

-- 4. Benih awal 5 Gereja Batak beserta koordinat tempat umum
INSERT INTO public.churches (
  id, name, denomination, address, city, service_schedules, contact_phone, contact_email, is_verified, member_count, latitude, longitude
) VALUES
  (
    '30000000-0000-4000-8000-000000000001',
    'HKBP Sudirman Medan',
    'hkbp',
    'Jl. Jenderal Sudirman No. 10',
    'Medan',
    '[{"dayOfWeek":"Minggu","time":"06.00 WIB","language":"Batak Toba"},{"dayOfWeek":"Minggu","time":"09.00 WIB","language":"Bahasa Indonesia"},{"dayOfWeek":"Minggu","time":"17.00 WIB","language":"Batak Toba"}]'::jsonb,
    '+628126000001',
    'sekretariat@hkbpsudirmanmedan.org',
    true,
    42,
    3.5811,
    98.6756
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    'GKPI Menteng Jakarta',
    'gkpi',
    'Jl. Menteng Raya No. 24',
    'Jakarta Pusat',
    '[{"dayOfWeek":"Minggu","time":"08.30 WIB","language":"Bahasa Indonesia"},{"dayOfWeek":"Minggu","time":"10.30 WIB","language":"Batak Toba"}]'::jsonb,
    '+628126000002',
    'info@gkpimenteng.org',
    true,
    18,
    -6.1865,
    106.8341
  ),
  (
    '30000000-0000-4000-8000-000000000003',
    'HKI Pematangsiantar Kota',
    'hki',
    'Jl. Gereja No. 14',
    'Pematangsiantar',
    '[{"dayOfWeek":"Minggu","time":"09.00 WIB","language":"Batak Toba"}]'::jsonb,
    '+628126000003',
    'kantor@hkisiantar.org',
    false,
    7,
    2.9547,
    99.0623
  ),
  (
    '30000000-0000-4000-8000-000000000004',
    'GKPS Cikini',
    'gkps',
    'Jl. Cikini Raya No. 35',
    'Jakarta Pusat',
    '[{"dayOfWeek":"Minggu","time":"09.00 WIB","language":"Simalungun"}]'::jsonb,
    '+628126000004',
    '',
    true,
    2,
    -6.1912,
    106.8389
  ),
  (
    '30000000-0000-4000-8000-000000000005',
    'GBKP Rawamangun',
    'gbkp',
    'Jl. Balai Pustaka Timur No. 8',
    'Jakarta Timur',
    '[{"dayOfWeek":"Minggu","time":"08.00 WIB","language":"Karo"},{"dayOfWeek":"Minggu","time":"10.00 WIB","language":"Bahasa Indonesia"}]'::jsonb,
    '+628126000005',
    '',
    false,
    3,
    -6.1968,
    106.8891
  )
ON CONFLICT (id) DO UPDATE
  SET latitude = COALESCE(public.churches.latitude, EXCLUDED.latitude),
      longitude = COALESCE(public.churches.longitude, EXCLUDED.longitude);
