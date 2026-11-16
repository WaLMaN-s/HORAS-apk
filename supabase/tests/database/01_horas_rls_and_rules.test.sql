-- =============================================================================
-- 01_horas_rls_and_rules.test.sql
-- Uji pgTAP untuk privasi, RLS, Partuturan, batas kuota PRD 7.2, dan lifecycle.
-- Dijalankan dengan: supabase test db
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgtap;

BEGIN;
SELECT plan(15);

-- 1. Pastikan RLS aktif di semua tabel inti public
SELECT ok(
  (
    SELECT bool_and(c.relrowsecurity)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname IN (
        'profiles', 'user_privacy_settings', 'follows', 'connection_requests',
        'connections', 'blocks', 'posts', 'comments', 'communities',
        'play_sessions', 'messages', 'message_requests', 'notifications',
        'reports', 'strikes', 'audit_log', 'otp_security_state'
      )
  ),
  'Semua tabel utama memiliki RLS aktif'
);

-- 2. generation_delta(viewer, target) hanya mengembalikan integer delta
SELECT is(
  public.generation_delta(
    '00000000-0000-4000-8000-000000000001'::uuid,
    '00000000-0000-4000-8000-000000000003'::uuid
  ),
  1,
  'generation_delta u-01 (sundut 16) ke u-03 (sundut 15) bernilai 1'
);

-- 3. AC-07 & TAR-R5: Simulasi sebagai u-01 (authenticated)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);

-- u-01 hanya bisa melihat profilnya sendiri dari tabel mentah profiles
SELECT is(
  (SELECT count(*)::int FROM public.profiles),
  1,
  'SELECT langsung ke tabel profiles oleh authenticated hanya melihat baris milik sendiri'
);

-- get_person_summary mengembalikan DTO aman tanpa phone_e164 / birth_year / km
SELECT ok(
  NOT (public.get_person_summary('00000000-0000-4000-8000-000000000003'::uuid) ? 'phoneE164')
  AND NOT (public.get_person_summary('00000000-0000-4000-8000-000000000003'::uuid) ? 'phone_e164')
  AND NOT (public.get_person_summary('00000000-0000-4000-8000-000000000003'::uuid) ? 'birthYear')
  AND NOT (public.get_person_summary('00000000-0000-4000-8000-000000000003'::uuid) ? 'birth_year')
  AND NOT (public.get_person_summary('00000000-0000-4000-8000-000000000003'::uuid) ? 'distanceKm'),
  'AC-07: get_person_summary tidak pernah memuat nomor HP, tahun lahir, atau jarak km'
);

-- Partuturan Sedang selalu berlabel Kemungkinan (TAR-R5)
SELECT is(
  public.evaluate_partuturan(
    '00000000-0000-4000-8000-000000000001'::uuid,
    '00000000-0000-4000-8000-000000000003'::uuid
  )->>'displayLabel',
  'Kemungkinan: Tulang',
  'TAR-R5: Partuturan u-01 ke u-03 (marga ibu Sitorus +1) berlabel Kemungkinan: Tulang'
);

-- 4. AC-13: Komunitas closed com-10 tidak terlihat non-anggota (u-01)
SELECT is(
  (SELECT count(*)::int FROM public.communities WHERE id = '20000000-0000-4000-8000-000000000010'::uuid),
  0,
  'AC-13: Komunitas closed tersembunyi bagi non-anggota'
);

-- 5. PSN-R1: Non-kenalan dengan komunitas bersama dibatasi 1 pesan pembuka sampai diterima/dibalas
SELECT lives_ok(
  $$SELECT public.send_first_message('00000000-0000-4000-8000-000000000004'::uuid, 'Horas Agus!');$$,
  'Pesan permintaan pertama ke non-Kenalan (komunitas bersama) berhasil'
);

SELECT throws_like(
  $$SELECT public.send_first_message('00000000-0000-4000-8000-000000000004'::uuid, 'Pesan kedua sebelum diterima');$$,
  '%PSN-R1%',
  'PSN-R1: Pesan kedua sebelum permintaan diterima ditolak server'
);

-- 6. AC-11: Blokir dua arah menyembunyikan target dari pencarian & profil
SELECT lives_ok(
  $$SELECT public.block_user('00000000-0000-4000-8000-000000000004'::uuid);$$,
  'u-01 memblokir u-04'
);

SELECT throws_like(
  $$SELECT public.get_person_summary('00000000-0000-4000-8000-000000000004'::uuid);$$,
  '%CONTENT_UNAVAILABLE%',
  'AC-11: Profil target yang diblokir tidak lagi dapat dibuka'
);

-- Uji sisi sebaliknya (u-04 tidak melihat u-01 saat mencari)
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000004', true);
SELECT is(
  (SELECT count(*)::int FROM public.search_people('Rudi') WHERE (search_people->>'id') = '00000000-0000-4000-8000-000000000001'),
  0,
  'AC-11: Blokir bersifat dua arah (u-04 tidak menemukan u-01 di search_people)'
);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);

-- 7. MAN-R7: Anti taruhan / judi saat buat sesi Main
SELECT throws_like(
  $$SELECT public.create_session(
    'Badminton Taruhan Uang', 'badminton', 'menengah',
    now() + interval '2 days', now() + interval '2 days 2 hours',
    6, 25000, 'Main voor uang taruhan'
  );$$,
  '%Taruhan uang atau judi%',
  'MAN-R7: Sesi dengan kata kunci taruhan/judi ditolak'
);

-- 8. AC-05: Tolak Kenalan memicu cooldown 30 hari
SELECT lives_ok(
  $$SELECT public.send_connection_request('00000000-0000-4000-8000-000000000008'::uuid, 'Kenalan ya Brema');$$,
  'Kirim permintaan Kenalan ke u-08 berhasil'
);

SET LOCAL ROLE postgres;
UPDATE public.connection_requests
SET status = 'rejected', responded_at = now()
WHERE requester_id = '00000000-0000-4000-8000-000000000001'::uuid
  AND recipient_id = '00000000-0000-4000-8000-000000000008'::uuid;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
SELECT throws_like(
  $$SELECT public.send_connection_request('00000000-0000-4000-8000-000000000008'::uuid, 'Coba ulang cepat');$$,
  '%RATE_LIMITED%',
  'AC-05: Kirim ulang Kenalan setelah ditolak dalam 30 hari terkena RATE_LIMITED'
);

-- 9. Staff/Admin audit_log & non-admin blocked
SELECT throws_like(
  $$SELECT public.admin_review_partuturan_ruleset('30000000-0000-4000-8000-000000000001'::uuid, true);$$,
  '%PERMISSION_DENIED%',
  'Pengguna biasa tidak bisa memvalidasi ruleset Partuturan'
);

SELECT * FROM finish();
ROLLBACK;
