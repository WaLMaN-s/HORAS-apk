-- =============================================================================
-- 0005_rpc_partuturan_and_business_rules.sql
-- Fungsi RPC bisnis inti: helper error terstandar (AppFailure), engine
-- generation_delta & Partuturan, summary profil anti-leak (AC-07), batasan
-- kuota PRD 7.2, antrean daftar tunggu FIFO (AC-08), keandalan Main (AC-09),
-- PSN-R1 1-pesan-awal & PSN-R9 20/hari, moderasi/strikes/audit_log.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Standar Error & Guard Akun Aktif
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.raise_horas_error(
  p_code text,
  p_retry_at timestamptz,
  p_field text,
  p_message text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_retry text := COALESCE(
    to_char(p_retry_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    ''
  );
  v_sqlstate text := CASE p_code
    WHEN 'PERMISSION_DENIED' THEN '42501'
    ELSE 'P0001'
  END;
BEGIN
  RAISE EXCEPTION 'HORAS_ERR|%|%|%|%', p_code, v_retry, COALESCE(p_field, ''), p_message
    USING ERRCODE = v_sqlstate,
          DETAIL = jsonb_build_object(
            'code', p_code,
            'retry_at', NULLIF(v_retry, ''),
            'field', NULLIF(p_field, '')
          )::text;
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_active_account(p_user_id uuid)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof public.profiles;
BEGIN
  IF p_user_id IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Sesi login diperlukan.');
  END IF;

  SELECT * INTO v_prof FROM public.profiles WHERE id = p_user_id;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'profile', 'Profil tidak ditemukan.');
  END IF;

  IF v_prof.account_status = 'permanently_banned' THEN
    PERFORM public.raise_horas_error('SUSPENDED', NULL, 'false', 'Akun diblokir permanen karena pelanggaran berat.');
  END IF;

  IF v_prof.account_status = 'suspended' AND (v_prof.suspended_until IS NULL OR v_prof.suspended_until > now()) THEN
    PERFORM public.raise_horas_error('SUSPENDED', v_prof.suspended_until, 'true', 'Akun sedang ditangguhkan sementara. Kamu dapat mengajukan banding dalam 14 hari.');
  END IF;

  RETURN v_prof;
END;
$$;

-- Helper jam tenang 22.00-06.00 WIB (Asia/Jakarta)
CREATE OR REPLACE FUNCTION public.adjust_for_quiet_hours(p_ts timestamptz)
RETURNS timestamptz
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_local timestamp := p_ts AT TIME ZONE 'Asia/Jakarta';
  v_hour int := EXTRACT(HOUR FROM v_local)::int;
BEGIN
  IF v_hour >= 22 THEN
    RETURN ((date_trunc('day', v_local) + interval '1 day 6 hours') AT TIME ZONE 'Asia/Jakarta');
  ELSIF v_hour < 6 THEN
    RETURN ((date_trunc('day', v_local) + interval '6 hours') AT TIME ZONE 'Asia/Jakarta');
  END IF;
  RETURN p_ts;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. Engine Partuturan & Anti-Leak Summary (PRD 7.1, TAR-R5/R6, AC-07)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_age_group(p_birth_year integer)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN p_birth_year IS NULL THEN NULL
    ELSE CASE
      WHEN (EXTRACT(YEAR FROM now())::int - p_birth_year) < 25 THEN '17-24'
      WHEN (EXTRACT(YEAR FROM now())::int - p_birth_year) < 35 THEN '25-34'
      WHEN (EXTRACT(YEAR FROM now())::int - p_birth_year) < 45 THEN '35-44'
      WHEN (EXTRACT(YEAR FROM now())::int - p_birth_year) < 55 THEN '45-54'
      ELSE '55+'
    END
  END;
$$;

-- SECURITY DEFINER: mengembalikan HANYA selisih generasi integer (atau NULL) tanpa membocorkan birth_year!
CREATE OR REPLACE FUNCTION public.generation_delta(viewer_id uuid, target_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_variable
DECLARE
  v_viewer public.profiles;
  v_target public.profiles;
  v_claim_delta integer;
BEGIN
  IF viewer_id IS NULL OR target_id IS NULL OR viewer_id = target_id THEN
    RETURN 0;
  END IF;

  -- Prioritaskan klaim silsilah terkonfirmasi (jika ada)
  SELECT CASE
    WHEN pc.proposer_id = viewer_id THEN pc.generation_delta
    ELSE -pc.generation_delta
  END
  INTO v_claim_delta
  FROM public.partuturan_claims pc
  WHERE pc.status = 'confirmed'
    AND pc.generation_delta IS NOT NULL
    AND (
      (pc.proposer_id = viewer_id AND pc.target_id = target_id)
      OR (pc.proposer_id = target_id AND pc.target_id = viewer_id)
    )
  ORDER BY pc.confirmed_at DESC NULLS LAST
  LIMIT 1;

  IF v_claim_delta IS NOT NULL THEN
    RETURN v_claim_delta;
  END IF;

  SELECT * INTO v_viewer FROM public.profiles WHERE id = viewer_id;
  SELECT * INTO v_target FROM public.profiles WHERE id = target_id;
  IF v_viewer.id IS NULL OR v_target.id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Gunakan sundut bila tersedia pada keduanya & semarga
  IF v_viewer.sundut IS NOT NULL AND v_target.sundut IS NOT NULL
     AND lower(btrim(v_viewer.marga)) = lower(btrim(v_target.marga))
     AND btrim(v_viewer.marga) <> '' THEN
    RETURN v_viewer.sundut - v_target.sundut;
  END IF;

  -- Estimasi internal server-side dari birth_year (~25 tahun per generasi) tanpa membuka birth_year
  IF v_viewer.birth_year IS NOT NULL AND v_target.birth_year IS NOT NULL THEN
    RETURN GREATEST(-2, LEAST(2, ROUND((v_viewer.birth_year - v_target.birth_year)::numeric / 25.0)::int));
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.evaluate_partuturan(p_viewer_id uuid, p_target_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer public.profiles;
  v_target public.profiles;
  v_claim public.partuturan_claims;
  v_ruleset public.partuturan_rulesets;
  v_delta integer;
  v_rule jsonb;
  v_rel text;
  v_istilah text;
  v_conf text;
  v_expl text;
  v_q text;
BEGIN
  IF p_viewer_id IS NULL OR p_target_id IS NULL OR p_viewer_id = p_target_id THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_viewer FROM public.profiles WHERE id = p_viewer_id;
  SELECT * INTO v_target FROM public.profiles WHERE id = p_target_id;
  IF v_viewer.id IS NULL OR v_target.id IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. Klaim terkonfirmasi kedua pihak -> keyakinan Tinggi (TAR-R5)
  SELECT * INTO v_claim
  FROM public.partuturan_claims
  WHERE status = 'confirmed'
    AND (
      (proposer_id = p_viewer_id AND target_id = p_target_id)
      OR (proposer_id = p_target_id AND target_id = p_viewer_id)
    )
  ORDER BY confirmed_at DESC NULLS LAST
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'istilah', v_claim.claimed_istilah,
      'displayLabel', v_claim.claimed_istilah,
      'confidence', 'tinggi',
      'isFactual', true,
      'subEthnic', v_viewer.sub_ethnic,
      'explanation', 'Jalur partuturan telah dikonfirmasi bersama oleh kedua pihak.',
      'followUpQuestion', NULL,
      'rulesetVersion', 'confirmed-claim'
    );
  END IF;

  -- 2. Evaluasi data-driven dari tabel partuturan_rulesets (TAR-R6)
  SELECT * INTO v_ruleset
  FROM public.partuturan_rulesets
  WHERE sub_ethnic = v_viewer.sub_ethnic AND is_active = true
  ORDER BY validated DESC, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'istilah', 'Dongan Sahuta / Kenalan',
      'displayLabel', 'Kemungkinan: Kenalan (' || initcap(v_viewer.sub_ethnic::text) || ')',
      'confidence', 'rendah',
      'isFactual', false,
      'subEthnic', v_viewer.sub_ethnic,
      'explanation', 'Aturan partuturan rinci untuk sub-suku ini belum divalidasi peninjau adat; gunakan sapaan netral dan konfirmasi langsung.',
      'followUpQuestion', 'Bagaimana jalur kekerabatan atau panggilan adat yang biasa dipakai di keluarga kalian?',
      'rulesetVersion', NULL
    );
  END IF;

  v_delta := public.generation_delta(p_viewer_id, p_target_id);

  FOR v_rule IN
    SELECT value FROM jsonb_array_elements(COALESCE(v_ruleset.rules_json->'rules', '[]'::jsonb))
  LOOP
    v_rel := v_rule->>'targetMargaRelation';
    IF v_rel = 'sameAsViewerMarga' AND (
      btrim(v_viewer.marga) = '' OR lower(btrim(v_viewer.marga)) <> lower(btrim(v_target.marga))
    ) THEN
      CONTINUE;
    ELSIF v_rel = 'sameAsViewerMotherMarga' AND (
      COALESCE(btrim(v_viewer.mother_marga), '') = '' OR lower(btrim(v_viewer.mother_marga)) <> lower(btrim(v_target.marga))
    ) THEN
      CONTINUE;
    ELSIF v_rel = 'sameAsTargetMotherMarga' AND (
      COALESCE(btrim(v_target.mother_marga), '') = '' OR lower(btrim(v_target.mother_marga)) <> lower(btrim(v_viewer.marga))
    ) THEN
      CONTINUE;
    END IF;

    IF COALESCE(v_rule->>'viewerGender', 'any') <> 'any'
       AND (v_rule->>'viewerGender') <> v_viewer.gender::text THEN
      CONTINUE;
    END IF;
    IF COALESCE(v_rule->>'targetGender', 'any') <> 'any'
       AND (v_rule->>'targetGender') <> v_target.gender::text THEN
      CONTINUE;
    END IF;

    IF COALESCE((v_rule->>'requireGenerationKnown')::boolean, false) THEN
      IF v_delta IS NULL OR v_delta <> (v_rule->>'generationDelta')::int THEN
        CONTINUE;
      END IF;
    END IF;

    v_istilah := v_rule->>'istilah';
    v_conf := COALESCE(v_rule->>'confidence', 'sedang');
    IF v_conf = 'tinggi' AND NOT v_ruleset.validated THEN
      v_conf := 'sedang';
    END IF;

    v_expl := COALESCE(v_rule->>'explanationTemplate', '');
    v_expl := replace(v_expl, '{targetMarga}', COALESCE(v_target.marga, ''));
    v_expl := replace(v_expl, '{viewerMarga}', COALESCE(v_viewer.marga, ''));
    v_expl := replace(v_expl, '{viewerMotherMarga}', COALESCE(v_viewer.mother_marga, ''));
    v_q := v_rule->>'followUpQuestion';

    RETURN jsonb_build_object(
      'istilah', v_istilah,
      'displayLabel', CASE WHEN v_conf = 'tinggi' THEN v_istilah ELSE 'Kemungkinan: ' || v_istilah END,
      'confidence', v_conf,
      'isFactual', (v_conf = 'tinggi'),
      'subEthnic', v_viewer.sub_ethnic,
      'explanation', v_expl,
      'followUpQuestion', v_q,
      'rulesetVersion', v_ruleset.version
    );
  END LOOP;

  RETURN jsonb_build_object(
    'istilah', 'Dongan',
    'displayLabel', 'Perlu konfirmasi silsilah',
    'confidence', 'rendah',
    'isFactual', false,
    'subEthnic', v_viewer.sub_ethnic,
    'explanation', COALESCE(
      v_ruleset.rules_json->>'defaultLowExplanation',
      'Data silsilah atau marga ibu belum lengkap untuk menarik jalur partuturan secara pasti.'
    ),
    'followUpQuestion', COALESCE(
      v_ruleset.rules_json->>'defaultLowQuestion',
      'Apa marga ibu dan kira-kira berada di generasi (sundut) ke berapa dibanding dirimu?'
    ),
    'rulesetVersion', v_ruleset.version
  );
END;
$$;

-- Helper membentuk DTO PersonSummary aman privasi (AC-07: ZERO phone/birth_year/coords/km)
CREATE OR REPLACE FUNCTION public._build_person_summary(p_viewer_id uuid, p_target public.profiles)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer public.profiles;
  v_ups public.user_privacy_settings;
  v_connected boolean := public.are_connected(p_viewer_id, p_target.id);
  v_following boolean := public.is_following(p_viewer_id, p_target.id);
  v_shared_comm_cnt int := 0;
  v_can_see_private boolean := false;
  v_show_subdistrict boolean := false;
  v_show_mother boolean := false;
  v_show_church boolean := false;
  v_prox text := 'DiKotamu';
  v_can_msg boolean := false;
BEGIN
  IF p_viewer_id IS NOT NULL THEN
    SELECT * INTO v_viewer FROM public.profiles WHERE id = p_viewer_id;
    SELECT count(*)::int INTO v_shared_comm_cnt
    FROM public.community_memberships m1
    JOIN public.community_memberships m2 ON m1.community_id = m2.community_id
    WHERE m1.user_id = p_viewer_id AND m2.user_id = p_target.id;
  END IF;

  SELECT * INTO v_ups FROM public.user_privacy_settings WHERE user_id = p_target.id;

  v_can_see_private := (p_viewer_id = p_target.id)
    OR (COALESCE(v_ups.account_type, 'public_account') = 'public_account')
    OR v_connected
    OR v_following;

  v_show_subdistrict := (p_viewer_id = p_target.id)
    OR (v_ups.subdistrict = 'everyone')
    OR (v_ups.subdistrict = 'connected_only' AND v_connected);

  v_show_mother := (p_viewer_id = p_target.id)
    OR (v_ups.mother_marga = 'everyone')
    OR (v_ups.mother_marga = 'connected_only' AND v_connected);

  v_show_church := (p_viewer_id = p_target.id)
    OR (v_ups.home_church = 'everyone')
    OR (v_ups.home_church = 'connected_only' AND v_connected);

  IF v_show_subdistrict
     AND v_viewer.id IS NOT NULL
     AND lower(btrim(v_viewer.city)) = lower(btrim(p_target.city))
     AND lower(btrim(v_viewer.subdistrict)) = lower(btrim(p_target.subdistrict))
     AND btrim(p_target.subdistrict) <> '' THEN
    v_prox := 'DiKecamatanmu';
  END IF;

  v_can_msg := v_connected OR (COALESCE(v_ups.allow_messages_from_shared_context, true) AND v_shared_comm_cnt > 0);

  RETURN jsonb_build_object(
    'id', p_target.id,
    'displayName', p_target.display_name,
    'gender', p_target.gender,
    'marga', p_target.marga,
    'subEthnic', p_target.sub_ethnic,
    'city', p_target.city,
    'proximity', v_prox,
    'avatarSeed', p_target.avatar_seed,
    'avatarPath', p_target.avatar_path,
    'sharedCommunitiesCount', v_shared_comm_cnt,
    'isSameMarga', (v_viewer.id IS NOT NULL AND lower(btrim(v_viewer.marga)) = lower(btrim(p_target.marga)) AND btrim(p_target.marga) <> ''),
    'partuturan', CASE WHEN p_viewer_id IS NOT NULL AND p_viewer_id <> p_target.id THEN public.evaluate_partuturan(p_viewer_id, p_target.id) ELSE NULL END,
    'visibleMotherMarga', CASE WHEN v_show_mother THEN p_target.mother_marga ELSE NULL END,
    'visibleSubdistrict', CASE WHEN v_show_subdistrict THEN p_target.subdistrict ELSE NULL END,
    'visibleAgeGroup', CASE WHEN (p_viewer_id = p_target.id OR COALESCE(v_ups.show_age_group, false)) THEN public.compute_age_group(p_target.birth_year) ELSE NULL END,
    'visibleHomeChurch', CASE WHEN v_show_church THEN p_target.home_church ELSE NULL END,
    'bio', CASE WHEN v_can_see_private THEN p_target.bio ELSE '' END,
    'hobbies', CASE WHEN v_can_see_private THEN to_jsonb(p_target.hobbies) ELSE '[]'::jsonb END,
    'campusOrOffice', CASE WHEN v_can_see_private THEN p_target.campus_or_office ELSE NULL END,
    'websiteUrl', CASE WHEN v_can_see_private THEN p_target.website_url ELSE NULL END,
    'isPrivateAccount', (COALESCE(v_ups.account_type, 'public_account') = 'private_account'),
    'isFollowing', v_following,
    'isConnected', v_connected,
    'canMessage', v_can_msg
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_person_summary(p_target_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid := auth.uid();
  v_target public.profiles;
BEGIN
  IF v_viewer_id IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Autentikasi diperlukan.');
  END IF;
  IF public.is_blocked_between(v_viewer_id, p_target_id) THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'targetId', 'Profil tidak tersedia.');
  END IF;

  SELECT * INTO v_target FROM public.profiles
  WHERE id = p_target_id AND onboarding_completed = true AND account_status IN ('active', 'restricted');

  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'targetId', 'Profil tidak ditemukan.');
  END IF;

  RETURN public._build_person_summary(v_viewer_id, v_target);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_nearby_people(
  p_city text DEFAULT NULL,
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid := auth.uid();
  v_city text;
  v_row public.profiles;
BEGIN
  IF v_viewer_id IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Autentikasi diperlukan.');
  END IF;

  SELECT COALESCE(NULLIF(btrim(p_city), ''), city) INTO v_city FROM public.profiles WHERE id = v_viewer_id;

  FOR v_row IN
    SELECT p.*
    FROM public.profiles p
    JOIN public.user_privacy_settings ups ON ups.user_id = p.id
    WHERE p.id <> v_viewer_id
      AND p.onboarding_completed = true
      AND p.account_status IN ('active', 'restricted')
      AND ups.discoverable_in_nearby_and_search = true
      AND lower(btrim(p.city)) = lower(btrim(v_city))
      AND NOT public.is_blocked_between(v_viewer_id, p.id)
    ORDER BY p.updated_at DESC
    LIMIT LEAST(GREATEST(p_limit, 1), 100)
    OFFSET GREATEST(p_offset, 0)
  LOOP
    RETURN NEXT public._build_person_summary(v_viewer_id, v_row);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.search_people(
  p_query text DEFAULT '',
  p_city text DEFAULT NULL,
  p_marga text DEFAULT NULL,
  p_limit integer DEFAULT 30
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid := auth.uid();
  v_q text := btrim(COALESCE(p_query, ''));
  v_row public.profiles;
BEGIN
  IF v_viewer_id IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Autentikasi diperlukan.');
  END IF;

  FOR v_row IN
    SELECT p.*
    FROM public.profiles p
    JOIN public.user_privacy_settings ups ON ups.user_id = p.id
    WHERE p.id <> v_viewer_id
      AND p.onboarding_completed = true
      AND p.account_status IN ('active', 'restricted')
      AND ups.discoverable_in_nearby_and_search = true
      AND NOT public.is_blocked_between(v_viewer_id, p.id)
      AND (v_q = '' OR p.display_name ILIKE '%' || v_q || '%' OR p.marga ILIKE '%' || v_q || '%')
      AND (p_city IS NULL OR btrim(p_city) = '' OR lower(btrim(p.city)) = lower(btrim(p_city)))
      AND (p_marga IS NULL OR btrim(p_marga) = '' OR lower(btrim(p.marga)) = lower(btrim(p_marga)))
    ORDER BY p.display_name ASC
    LIMIT LEAST(GREATEST(p_limit, 1), 100)
  LOOP
    RETURN NEXT public._build_person_summary(v_viewer_id, v_row);
  END LOOP;
END;
$$;

-- Komunitas terlihat pada profil target (AC-13: closed selalu tersembunyi!)
CREATE OR REPLACE FUNCTION public.get_user_visible_communities(p_target_id uuid)
RETURNS SETOF public.communities
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid := auth.uid();
  v_vis public.field_visibility;
  v_allowed boolean := false;
BEGIN
  IF v_viewer_id IS NULL THEN RETURN; END IF;
  IF public.is_blocked_between(v_viewer_id, p_target_id) THEN RETURN; END IF;

  IF v_viewer_id = p_target_id THEN
    v_allowed := true;
  ELSE
    SELECT joined_communities INTO v_vis FROM public.user_privacy_settings WHERE user_id = p_target_id;
    v_allowed := (v_vis = 'everyone') OR (v_vis = 'connected_only' AND public.are_connected(v_viewer_id, p_target_id));
  END IF;

  IF NOT v_allowed THEN RETURN; END IF;

  RETURN QUERY
  SELECT c.*
  FROM public.communities c
  JOIN public.community_memberships cm ON cm.community_id = c.id
  WHERE cm.user_id = p_target_id
    AND (c.access_type <> 'closed' OR c.owner_id = v_viewer_id OR public.is_community_member(c.id, v_viewer_id));
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Onboarding, Akun Lifecycle, Blokir, Ekspor Data, Pemulihan Akun
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_onboarding(
  p_display_name text,
  p_gender public.user_gender,
  p_birth_year integer,
  p_marga text,
  p_sub_ethnic public.sub_ethnic,
  p_mother_marga text DEFAULT NULL,
  p_city text DEFAULT 'Medan',
  p_subdistrict text DEFAULT 'Medan Baru',
  p_hobbies text[] DEFAULT '{}'::text[],
  p_campus_or_office text DEFAULT NULL,
  p_is_custom_marga boolean DEFAULT false,
  p_legal_consent jsonb DEFAULT NULL
)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_name text := btrim(COALESCE(p_display_name, ''));
  v_age int := EXTRACT(YEAR FROM now())::int - p_birth_year;
  v_prof public.profiles;
BEGIN
  IF v_uid IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Login diperlukan.');
  END IF;
  IF char_length(v_name) < 2 OR char_length(v_name) > 40 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'displayName', 'Nama tampil harus 2 sampai 40 karakter.');
  END IF;
  IF v_age < 17 OR v_age > 110 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'birthYear', 'Pengguna HORAS harus berusia minimal 17 tahun.');
  END IF;
  IF btrim(COALESCE(p_marga, '')) = '' THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'marga', 'Marga wajib diisi.');
  END IF;
  IF p_legal_consent IS NULL OR NOT (p_legal_consent ? 'version') THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'legalConsent', 'Persetujuan ketentuan & konfirmasi usia 17+ wajib dicatat.');
  END IF;

  PERFORM set_config('horas.bypass_profile_guard', 'on', true);
  UPDATE public.profiles SET
    display_name = v_name,
    gender = p_gender,
    birth_year = p_birth_year,
    marga = btrim(p_marga),
    is_custom_marga = p_is_custom_marga,
    sub_ethnic = p_sub_ethnic,
    mother_marga = NULLIF(btrim(COALESCE(p_mother_marga, '')), ''),
    city = btrim(p_city),
    subdistrict = btrim(p_subdistrict),
    hobbies = COALESCE(p_hobbies, '{}'::text[]),
    campus_or_office = NULLIF(btrim(COALESCE(p_campus_or_office, '')), ''),
    onboarding_completed = true,
    legal_consent = p_legal_consent,
    onboarding_draft = NULL
  WHERE id = v_uid
  RETURNING * INTO v_prof;

  RETURN v_prof;
END;
$$;

CREATE OR REPLACE FUNCTION public.block_user(p_target_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF p_target_id IS NULL OR p_target_id = v_uid THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'targetId', 'Target blokir tidak valid.');
  END IF;

  INSERT INTO public.blocks (blocker_id, blocked_id)
  VALUES (v_uid, p_target_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  -- Bersihkan relasi ikuti & kenalan agar blokir dua arah tuntas (AC-11)
  DELETE FROM public.follows
  WHERE (follower_id = v_uid AND followee_id = p_target_id)
     OR (follower_id = p_target_id AND followee_id = v_uid);

  DELETE FROM public.connections
  WHERE user_a = LEAST(v_uid, p_target_id) AND user_b = GREATEST(v_uid, p_target_id);

  UPDATE public.connection_requests
  SET status = 'cancelled', responded_at = now()
  WHERE status = 'pending'
    AND ((requester_id = v_uid AND recipient_id = p_target_id)
      OR (requester_id = p_target_id AND recipient_id = v_uid));
END;
$$;

CREATE OR REPLACE FUNCTION public.unblock_user(p_target_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  PERFORM public.assert_active_account(v_uid);
  DELETE FROM public.blocks WHERE blocker_id = v_uid AND blocked_id = p_target_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.request_data_export()
RETURNS public.data_export_jobs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_last timestamptz;
  v_job public.data_export_jobs;
BEGIN
  PERFORM public.assert_active_account(v_uid);

  SELECT max(requested_at) INTO v_last FROM public.data_export_jobs WHERE user_id = v_uid;
  IF v_last IS NOT NULL AND (v_last + interval '7 days') > now() THEN
    PERFORM public.raise_horas_error(
      'RATE_LIMITED',
      v_last + interval '7 days',
      'dataExport',
      'Unduh arsip data pribadi maksimal sekali setiap 7 hari.'
    );
  END IF;

  INSERT INTO public.data_export_jobs (user_id, status)
  VALUES (v_uid, 'queued')
  RETURNING * INTO v_job;

  RETURN v_job;
END;
$$;

CREATE OR REPLACE FUNCTION public.request_account_deletion(p_reason text DEFAULT '')
RETURNS public.account_deletions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_del public.account_deletions;
BEGIN
  PERFORM public.assert_active_account(v_uid);

  INSERT INTO public.account_deletions (
    user_id, reason, requested_at, scheduled_permanent_deletion_at,
    is_cancelled, cancelled_at, is_permanently_deleted, permanently_deleted_at
  )
  VALUES (v_uid, COALESCE(p_reason, ''), now(), now() + interval '30 days', false, NULL, false, NULL)
  ON CONFLICT (user_id) DO UPDATE SET
    reason = EXCLUDED.reason,
    requested_at = now(),
    scheduled_permanent_deletion_at = now() + interval '30 days',
    is_cancelled = false,
    cancelled_at = NULL
  RETURNING * INTO v_del;

  PERFORM set_config('horas.bypass_profile_guard', 'on', true);
  UPDATE public.profiles SET deleted_at = now() WHERE id = v_uid;
  RETURN v_del;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_account_deletion()
RETURNS public.account_deletions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_del public.account_deletions;
BEGIN
  IF v_uid IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Autentikasi diperlukan.');
  END IF;

  UPDATE public.account_deletions
  SET is_cancelled = true, cancelled_at = now()
  WHERE user_id = v_uid
    AND NOT is_permanently_deleted
    AND scheduled_permanent_deletion_at > now()
  RETURNING * INTO v_del;

  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'accountDeletion', 'Tidak ada permintaan penghapusan aktif yang dapat dibatalkan.');
  END IF;

  PERFORM set_config('horas.bypass_profile_guard', 'on', true);
  UPDATE public.profiles SET deleted_at = NULL WHERE id = v_uid;
  RETURN v_del;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_account_recovery(
  p_old_phone_e164 text,
  p_new_phone_e164 text,
  p_approximate_registration_period text,
  p_marga text,
  p_known_friends_text text
)
RETURNS public.account_recovery_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req public.account_recovery_requests;
BEGIN
  IF p_old_phone_e164 !~ '^\+[1-9]\d{7,14}$' OR p_new_phone_e164 !~ '^\+[1-9]\d{7,14}$' THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'phone', 'Format nomor HP harus menggunakan kode negara E.164.');
  END IF;

  INSERT INTO public.account_recovery_requests (
    old_phone_e164, new_phone_e164, approximate_registration_period, marga, known_friends_text
  ) VALUES (
    btrim(p_old_phone_e164), btrim(p_new_phone_e164),
    btrim(p_approximate_registration_period), btrim(p_marga), btrim(p_known_friends_text)
  )
  RETURNING * INTO v_req;

  RETURN v_req;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Sosial: Follow (200/hari) & Kenalan (10/hari, 200 char, 30d cooldown)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.follow_user(p_target_id uuid)
RETURNS public.follows
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_cnt int;
  v_oldest timestamptz;
  v_row public.follows;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF p_target_id IS NULL OR p_target_id = v_uid THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'targetId', 'Target tidak valid.');
  END IF;
  IF public.is_blocked_between(v_uid, p_target_id) THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'targetId', 'Pengguna tidak tersedia.');
  END IF;

  SELECT * INTO v_row FROM public.follows WHERE follower_id = v_uid AND followee_id = p_target_id;
  IF FOUND THEN RETURN v_row; END IF;

  SELECT count(*)::int, min(created_at)
    INTO v_cnt, v_oldest
  FROM public.follows
  WHERE follower_id = v_uid AND created_at > (now() - interval '24 hours');

  IF v_cnt >= 200 THEN
    PERFORM public.raise_horas_error(
      'RATE_LIMITED', v_oldest + interval '24 hours', 'follow',
      'Maksimal 200 ikuti baru per hari.'
    );
  END IF;

  INSERT INTO public.follows (follower_id, followee_id)
  VALUES (v_uid, p_target_id)
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_connection_request(
  p_recipient_id uuid,
  p_intro_message text DEFAULT ''
)
RETURNS public.connection_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_intro text := btrim(COALESCE(p_intro_message, ''));
  v_allow public.connection_allowance;
  v_last_reject timestamptz;
  v_cnt int;
  v_oldest timestamptz;
  v_req public.connection_requests;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF p_recipient_id IS NULL OR p_recipient_id = v_uid THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'recipientId', 'Penerima tidak valid.');
  END IF;
  IF public.is_blocked_between(v_uid, p_recipient_id) THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'recipientId', 'Pengguna tidak tersedia.');
  END IF;
  IF char_length(v_intro) > 200 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'introMessage', 'Pesan pengantar Kenalan maksimal 200 karakter.');
  END IF;
  IF public.are_connected(v_uid, p_recipient_id) THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'recipientId', 'Kalian sudah saling terhubung sebagai Kenalan.');
  END IF;

  SELECT who_can_send_connection_request INTO v_allow
  FROM public.user_privacy_settings WHERE user_id = p_recipient_id;

  IF v_allow = 'no_one' THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'connectionRequest', 'Pengguna ini menutup permintaan Kenalan.');
  ELSIF v_allow = 'same_community' AND NOT public.share_community(v_uid, p_recipient_id) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'connectionRequest', 'Pengguna ini hanya menerima Kenalan dari satu komunitas.');
  END IF;

  -- Cooldown 30 hari setelah ditolak atau kedaluwarsa (AC-05)
  SELECT max(COALESCE(responded_at, expires_at)) INTO v_last_reject
  FROM public.connection_requests
  WHERE ((requester_id = v_uid AND recipient_id = p_recipient_id)
      OR (requester_id = p_recipient_id AND recipient_id = v_uid))
    AND status IN ('rejected', 'expired');

  IF v_last_reject IS NOT NULL AND (v_last_reject + interval '30 days') > now() THEN
    PERFORM public.raise_horas_error(
      'RATE_LIMITED', v_last_reject + interval '30 days', 'recipientId',
      'Permintaan Kenalan ke pengguna ini baru dapat dikirim kembali setelah 30 hari.'
    );
  END IF;

  -- Batas 10 permintaan Kenalan baru / hari (PRD 7.2)
  SELECT count(*)::int, min(created_at)
    INTO v_cnt, v_oldest
  FROM public.connection_requests
  WHERE requester_id = v_uid AND created_at > (now() - interval '24 hours');

  IF v_cnt >= 10 THEN
    PERFORM public.raise_horas_error(
      'RATE_LIMITED', v_oldest + interval '24 hours', 'connectionRequest',
      'Maksimal 10 permintaan Kenalan baru per hari.'
    );
  END IF;

  INSERT INTO public.connection_requests (requester_id, recipient_id, intro_message)
  VALUES (v_uid, p_recipient_id, v_intro)
  RETURNING * INTO v_req;

  RETURN v_req;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_connection_request(
  p_request_id uuid,
  p_accept boolean
)
RETURNS public.connection_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_req public.connection_requests;
BEGIN
  PERFORM public.assert_active_account(v_uid);

  SELECT * INTO v_req FROM public.connection_requests
  WHERE id = p_request_id AND recipient_id = v_uid AND status = 'pending';
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'requestId', 'Permintaan Kenalan tidak ditemukan atau sudah diproses.');
  END IF;

  UPDATE public.connection_requests
  SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
      responded_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_req;

  IF p_accept THEN
    INSERT INTO public.connections (user_a, user_b)
    VALUES (LEAST(v_req.requester_id, v_req.recipient_id), GREATEST(v_req.requester_id, v_req.recipient_id))
    ON CONFLICT (user_a, user_b) DO NOTHING;

    INSERT INTO public.notifications (user_id, type, title, body, action_route)
    VALUES (
      v_req.requester_id, 'sosial', 'Permintaan Kenalan Diterima',
      'Permintaan Kenalanmu telah diterima.', '/profile/' || v_req.recipient_id::text
    );
  END IF;

  RETURN v_req;
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. Beranda: Postingan (20/24j, 2000 char, 10 foto, hold BER-R10/R11) & Komentar (60/j)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_post(
  p_text text DEFAULT '',
  p_visibility public.post_visibility DEFAULT 'publik',
  p_community_id uuid DEFAULT NULL,
  p_media jsonb DEFAULT '[]'::jsonb
)
RETURNS public.posts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_prof public.profiles;
  v_clean text := btrim(COALESCE(p_text, ''));
  v_media_cnt int := jsonb_array_length(COALESCE(p_media, '[]'::jsonb));
  v_cnt int;
  v_oldest timestamptz;
  v_is_new boolean;
  v_has_link boolean;
  v_link_cnt int;
  v_has_bad_words boolean;
  v_has_spam boolean;
  v_status public.post_moderation_status := 'published';
  v_post public.posts;
  v_item jsonb;
  v_idx int := 0;
BEGIN
  v_prof := public.assert_active_account(v_uid);

  IF v_clean = '' AND v_media_cnt = 0 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'text', 'Postingan harus berisi minimal teks atau satu foto.');
  END IF;
  IF char_length(v_clean) > 2000 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'text', 'Teks postingan maksimal 2.000 karakter.');
  END IF;
  IF v_media_cnt > 10 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'media', 'Maksimal 10 foto dalam satu postingan.');
  END IF;

  IF p_community_id IS NOT NULL AND NOT public.is_community_member(p_community_id, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya anggota yang dapat memposting di komunitas ini.');
  END IF;

  SELECT count(*)::int, min(created_at)
    INTO v_cnt, v_oldest
  FROM public.posts
  WHERE author_id = v_uid AND created_at > (now() - interval '24 hours');

  IF v_cnt >= 20 THEN
    PERFORM public.raise_horas_error(
      'RATE_LIMITED', v_oldest + interval '24 hours', 'post',
      'Maksimal 20 postingan per 24 jam.'
    );
  END IF;

  -- BER-R10 & BER-R11
  v_is_new := v_prof.created_at > (now() - interval '7 days');
  v_has_link := v_clean ~* '(https?://|www\.)\S+';
  SELECT count(*)::int INTO v_link_cnt FROM regexp_matches(v_clean, '(https?://|www\.)\S+', 'gi');
  v_has_bad_words := lower(v_clean) ~ '\m(slot\s*gacor|judi\s*online|pinjol\s*ilegal|taruhan\s*bola|promo\s*togel|kasar_sara)\M';
  v_has_spam := (v_link_cnt >= 3) OR (v_clean ~ '(.)\1{9,}');

  IF (v_has_link AND v_is_new) OR v_has_bad_words OR v_has_spam THEN
    v_status := 'under_review';
  END IF;

  INSERT INTO public.posts (author_id, community_id, text, visibility, moderation_status)
  VALUES (v_uid, p_community_id, v_clean, p_visibility, v_status)
  RETURNING * INTO v_post;

  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(p_media, '[]'::jsonb))
  LOOP
    INSERT INTO public.post_media (
      post_id, owner_id, storage_path, mime_type, width, height, size_bytes, exif_stripped, sort_order
    ) VALUES (
      v_post.id,
      v_uid,
      v_item->>'storagePath',
      COALESCE(v_item->>'mimeType', 'image/jpeg'),
      NULLIF(v_item->>'width', '')::int,
      NULLIF(v_item->>'height', '')::int,
      (v_item->>'sizeBytes')::int,
      COALESCE((v_item->>'exifStripped')::boolean, true),
      v_idx
    );
    v_idx := v_idx + 1;
  END LOOP;

  RETURN v_post;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_comment(
  p_post_id uuid,
  p_text text,
  p_parent_comment_id uuid DEFAULT NULL
)
RETURNS public.comments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_clean text := btrim(COALESCE(p_text, ''));
  v_post public.posts;
  v_cnt int;
  v_oldest timestamptz;
  v_comment public.comments;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF char_length(v_clean) < 1 OR char_length(v_clean) > 1000 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'text', 'Komentar harus 1 sampai 1.000 karakter.');
  END IF;

  SELECT * INTO v_post FROM public.posts WHERE id = p_post_id;
  IF NOT FOUND OR v_post.moderation_status = 'removed' OR public.is_blocked_between(v_uid, v_post.author_id) THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'postId', 'Postingan tidak tersedia.');
  END IF;

  SELECT count(*)::int, min(created_at)
    INTO v_cnt, v_oldest
  FROM public.comments
  WHERE author_id = v_uid AND created_at > (now() - interval '1 hour');

  IF v_cnt >= 60 THEN
    PERFORM public.raise_horas_error(
      'RATE_LIMITED', v_oldest + interval '1 hour', 'comment',
      'Maksimal 60 komentar per jam.'
    );
  END IF;

  INSERT INTO public.comments (post_id, author_id, parent_comment_id, text)
  VALUES (p_post_id, v_uid, p_parent_comment_id, v_clean)
  RETURNING * INTO v_comment;

  RETURN v_comment;
END;
$$;

-- ---------------------------------------------------------------------------
-- 6. Komunitas (min 7 hari akun, maks 5 komunitas, maks 10 pengurus, maks 3 pin, 14h expiry)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_community(
  p_name text,
  p_type public.community_type,
  p_access_type public.community_access_type,
  p_city text,
  p_marga_name text DEFAULT NULL,
  p_description text DEFAULT '',
  p_rules_text text DEFAULT ''
)
RETURNS public.communities
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_prof public.profiles;
  v_owned_cnt int;
  v_conv_id uuid;
  v_comm public.communities;
BEGIN
  v_prof := public.assert_active_account(v_uid);

  IF v_prof.created_at > (now() - interval '7 days') THEN
    PERFORM public.raise_horas_error(
      'PERMISSION_DENIED', v_prof.created_at + interval '7 days', 'community',
      'Akun baru minimal berusia 7 hari sebelum dapat membuat komunitas.'
    );
  END IF;

  SELECT count(*)::int INTO v_owned_cnt FROM public.communities WHERE owner_id = v_uid;
  IF v_owned_cnt >= 5 THEN
    PERFORM public.raise_horas_error('RATE_LIMITED', NULL, 'community', 'Maksimal 5 komunitas yang dibuat per akun.');
  END IF;

  INSERT INTO public.conversations (type, title)
  VALUES ('community', btrim(p_name))
  RETURNING id INTO v_conv_id;

  INSERT INTO public.communities (
    name, type, access_type, city, marga_name, description, rules_text,
    avatar_seed, owner_id, conversation_id, member_count
  ) VALUES (
    btrim(p_name), p_type, p_access_type, btrim(p_city),
    NULLIF(btrim(COALESCE(p_marga_name, '')), ''),
    btrim(COALESCE(p_description, '')),
    btrim(COALESCE(p_rules_text, '')),
    'com-' || substring(v_conv_id::text FROM 1 FOR 8),
    v_uid, v_conv_id, 1
  ) RETURNING * INTO v_comm;

  UPDATE public.conversations SET community_id = v_comm.id WHERE id = v_conv_id;

  INSERT INTO public.community_memberships (community_id, user_id, role)
  VALUES (v_comm.id, v_uid, 'owner');

  INSERT INTO public.conversation_participants (conversation_id, user_id)
  VALUES (v_conv_id, v_uid);

  RETURN v_comm;
END;
$$;

CREATE OR REPLACE FUNCTION public.join_community(
  p_community_id uuid,
  p_note text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_comm public.communities;
  v_req public.community_join_requests;
BEGIN
  PERFORM public.assert_active_account(v_uid);

  SELECT * INTO v_comm FROM public.communities WHERE id = p_community_id;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'communityId', 'Komunitas tidak ditemukan.');
  END IF;

  IF public.is_community_member(p_community_id, v_uid) THEN
    RETURN jsonb_build_object('status', 'member');
  END IF;

  IF v_comm.access_type = 'closed' THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Komunitas tertutup hanya dapat diikuti melalui undangan pengurus.');
  END IF;

  IF v_comm.access_type = 'open' THEN
    INSERT INTO public.community_memberships (community_id, user_id, role)
    VALUES (p_community_id, v_uid, 'member') ON CONFLICT DO NOTHING;
    IF v_comm.conversation_id IS NOT NULL THEN
      INSERT INTO public.conversation_participants (conversation_id, user_id)
      VALUES (v_comm.conversation_id, v_uid) ON CONFLICT DO NOTHING;
    END IF;
    RETURN jsonb_build_object('status', 'joined');
  END IF;

  INSERT INTO public.community_join_requests (community_id, user_id, note, expires_at)
  VALUES (p_community_id, v_uid, COALESCE(p_note, ''), now() + interval '14 days')
  RETURNING * INTO v_req;

  RETURN jsonb_build_object('status', 'pending', 'requestId', v_req.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_community_announcement(
  p_community_id uuid,
  p_title text,
  p_content text,
  p_is_pinned boolean DEFAULT false
)
RETURNS public.community_announcements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_pin_cnt int;
  v_ann public.community_announcements;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF NOT public.is_community_manager(p_community_id, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya pengurus komunitas yang dapat membuat pengumuman.');
  END IF;

  IF p_is_pinned THEN
    SELECT count(*)::int INTO v_pin_cnt
    FROM public.community_announcements
    WHERE community_id = p_community_id AND is_pinned = true;
    IF v_pin_cnt >= 3 THEN
      PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'isPinned', 'Maksimal 3 pengumuman tersemat di satu komunitas.');
    END IF;
  END IF;

  INSERT INTO public.community_announcements (community_id, author_id, title, content, is_pinned)
  VALUES (p_community_id, v_uid, btrim(p_title), btrim(p_content), p_is_pinned)
  RETURNING * INTO v_ann;

  UPDATE public.communities SET last_manager_active_at = now(), is_inactive_flagged = false WHERE id = p_community_id;
  RETURN v_ann;
END;
$$;

CREATE OR REPLACE FUNCTION public.promote_community_manager(p_community_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_mgr_cnt int;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF NOT public.is_community_manager(p_community_id, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya pemilik atau pengurus yang dapat menunjuk pengurus.');
  END IF;

  SELECT count(*)::int INTO v_mgr_cnt
  FROM public.community_memberships
  WHERE community_id = p_community_id AND role IN ('owner', 'manager');

  IF v_mgr_cnt >= 10 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'manager', 'Maksimal 10 pengurus per komunitas.');
  END IF;

  UPDATE public.community_memberships
  SET role = 'manager'
  WHERE community_id = p_community_id AND user_id = p_user_id AND role = 'member';
END;
$$;

-- ---------------------------------------------------------------------------
-- 7. Main Olahraga: Create, Join + FIFO Waitlist (AC-08), Leave + Keandalan (AC-09)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_session(
  p_title text,
  p_sport public.sport_type,
  p_skill_level public.skill_level,
  p_start_time timestamptz,
  p_end_time timestamptz,
  p_max_slots integer,
  p_fee_per_person_rupiah integer DEFAULT 0,
  p_notes text DEFAULT '',
  p_visibility public.session_visibility DEFAULT 'terbuka',
  p_join_mode public.session_join_mode DEFAULT 'langsung_masuk',
  p_court_id uuid DEFAULT NULL,
  p_community_id uuid DEFAULT NULL
)
RETURNS public.play_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_prof public.profiles;
  v_active_cnt int;
  v_conv_id uuid;
  v_session public.play_sessions;
  v_combined text := lower(COALESCE(p_title, '') || ' ' || COALESCE(p_notes, ''));
BEGIN
  v_prof := public.assert_active_account(v_uid);

  IF v_prof.restricted_until IS NOT NULL AND v_prof.restricted_until > now() THEN
    PERFORM public.raise_horas_error('RATE_LIMITED', v_prof.restricted_until, 'session', 'Akun dibatasi sementara 7 hari karena catatan keandalan.');
  END IF;

  SELECT count(*)::int INTO v_active_cnt
  FROM public.play_sessions
  WHERE host_id = v_uid AND status IN ('terjadwal', 'berlangsung');
  IF v_active_cnt >= 5 THEN
    PERFORM public.raise_horas_error('RATE_LIMITED', NULL, 'hostId', 'Maksimal 5 sesi aktif yang dikelola secara bersamaan.');
  END IF;

  IF p_start_time < (now() + interval '1 hour') OR p_start_time > (now() + interval '60 days') THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'startTime', 'Jadwal sesi harus antara 1 jam hingga 60 hari ke depan.');
  END IF;
  IF p_end_time <= p_start_time THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'endTime', 'Waktu selesai sesi harus setelah waktu mulai.');
  END IF;
  IF p_max_slots < 2 OR p_max_slots > 50 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'maxSlots', 'Jumlah slot peserta harus antara 2 sampai 50 orang.');
  END IF;
  IF p_fee_per_person_rupiah < 0 OR p_fee_per_person_rupiah > 1000000 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'feePerPersonRupiah', 'Biaya per orang harus antara Rp0 sampai Rp1.000.000.');
  END IF;
  IF char_length(btrim(COALESCE(p_notes, ''))) > 300 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'notes', 'Catatan sesi maksimal 300 karakter.');
  END IF;

  -- MAN-R7: Larangan mutlak taruhan / judi
  IF v_combined ~ '\m(taruhan|judi|betting|voor|pur-puran|uang\s+taruhan)\M' THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'notes', 'Taruhan uang atau judi dalam bentuk apa pun dilarang keras di HORAS.');
  END IF;

  INSERT INTO public.conversations (type, title)
  VALUES ('session', btrim(p_title))
  RETURNING id INTO v_conv_id;

  INSERT INTO public.play_sessions (
    host_id, community_id, court_id, conversation_id, title, sport, skill_level,
    start_time, end_time, max_slots, fee_per_person_rupiah, notes, visibility, join_mode
  ) VALUES (
    v_uid, p_community_id, p_court_id, v_conv_id, btrim(p_title), p_sport, p_skill_level,
    p_start_time, p_end_time, p_max_slots, p_fee_per_person_rupiah, btrim(COALESCE(p_notes, '')),
    p_visibility, p_join_mode
  ) RETURNING * INTO v_session;

  UPDATE public.conversations SET session_id = v_session.id WHERE id = v_conv_id;

  INSERT INTO public.session_participants (session_id, user_id, status)
  VALUES (v_session.id, v_uid, 'joined');

  INSERT INTO public.conversation_participants (conversation_id, user_id)
  VALUES (v_conv_id, v_uid);

  RETURN v_session;
END;
$$;

CREATE OR REPLACE FUNCTION public.join_session(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_prof public.profiles;
  v_sess public.play_sessions;
  v_joined_cnt int;
  v_status public.participant_status;
BEGIN
  v_prof := public.assert_active_account(v_uid);

  -- AC-09: Pembatasan gabung sesi 7 hari setelah 3 catatan keandalan dalam 30 hari
  IF v_prof.restricted_until IS NOT NULL AND v_prof.restricted_until > now() THEN
    PERFORM public.raise_horas_error(
      'RATE_LIMITED', v_prof.restricted_until, 'session',
      'Akunmu dibatasi bergabung ke sesi baru selama 7 hari karena 3 catatan keandalan dalam 30 hari.'
    );
  END IF;

  SELECT * INTO v_sess FROM public.play_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND OR v_sess.status <> 'terjadwal' THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'sessionId', 'Sesi tidak ditemukan atau sudah tidak menerima peserta.');
  END IF;
  IF public.is_blocked_between(v_uid, v_sess.host_id) THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'sessionId', 'Sesi tidak tersedia.');
  END IF;

  SELECT count(*)::int INTO v_joined_cnt
  FROM public.session_participants
  WHERE session_id = p_session_id AND status = 'joined';

  IF v_sess.join_mode = 'persetujuan_host' THEN
    v_status := 'pending_approval';
  ELSIF v_joined_cnt < v_sess.max_slots THEN
    v_status := 'joined';
  ELSE
    v_status := 'waitlisted';
  END IF;

  INSERT INTO public.session_participants (session_id, user_id, status, joined_at)
  VALUES (p_session_id, v_uid, v_status, now())
  ON CONFLICT (session_id, user_id) DO UPDATE SET
    status = EXCLUDED.status,
    joined_at = now(),
    left_at = NULL;

  IF v_status = 'waitlisted' THEN
    INSERT INTO public.session_waitlist (session_id, user_id, queued_at)
    VALUES (p_session_id, v_uid, now())
    ON CONFLICT (session_id, user_id) DO NOTHING;
  ELSIF v_status = 'joined' THEN
    IF v_sess.conversation_id IS NOT NULL THEN
      INSERT INTO public.conversation_participants (conversation_id, user_id)
      VALUES (v_sess.conversation_id, v_uid) ON CONFLICT DO NOTHING;
    END IF;
    IF v_sess.fee_per_person_rupiah > 0 THEN
      INSERT INTO public.session_payment_shares (session_id, user_id, amount_rupiah)
      VALUES (p_session_id, v_uid, v_sess.fee_per_person_rupiah)
      ON CONFLICT (session_id, user_id) DO NOTHING;
    END IF;
  END IF;

  RETURN jsonb_build_object('sessionId', p_session_id, 'status', v_status);
END;
$$;

CREATE OR REPLACE FUNCTION public._apply_reliability_mark(
  p_user_id uuid,
  p_session_id uuid,
  p_reason public.reliability_reason,
  p_recorded_by uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cnt int;
BEGIN
  INSERT INTO public.reliability_marks (user_id, session_id, reason, recorded_by)
  VALUES (p_user_id, p_session_id, p_reason, p_recorded_by);

  SELECT count(*)::int INTO v_cnt
  FROM public.reliability_marks
  WHERE user_id = p_user_id AND created_at > (now() - interval '30 days');

  IF v_cnt >= 3 THEN
    UPDATE public.profiles
    SET restricted_until = GREATEST(COALESCE(restricted_until, now()), now() + interval '7 days')
    WHERE id = p_user_id;

    INSERT INTO public.notifications (user_id, type, title, body, action_route)
    VALUES (
      p_user_id, 'main_olahraga', 'Pembatasan Gabung Sesi 7 Hari',
      'Karena terdapat 3 catatan keandalan dalam 30 hari terakhir, kamu tidak dapat bergabung ke sesi baru selama 7 hari.',
      '/play'
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_session(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sess public.play_sessions;
  v_part public.session_participants;
  v_next public.session_waitlist;
  v_late_leave boolean := false;
BEGIN
  PERFORM public.assert_active_account(v_uid);

  SELECT * INTO v_sess FROM public.play_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'sessionId', 'Sesi tidak ditemukan.');
  END IF;
  IF v_sess.host_id = v_uid THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'sessionId', 'Host tidak dapat keluar sebagai peserta biasa.');
  END IF;

  SELECT * INTO v_part FROM public.session_participants
  WHERE session_id = p_session_id AND user_id = v_uid;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'sessionId', 'Kamu tidak terdaftar di sesi ini.');
  END IF;

  -- Hapus dari waitlist bila masih antre
  IF v_part.status = 'waitlisted' THEN
    DELETE FROM public.session_waitlist WHERE session_id = p_session_id AND user_id = v_uid;
  END IF;

  -- Cek MAN-R3, MAN-R4, MAN-R5 late leave < 3 jam
  IF v_part.status = 'joined' AND v_sess.start_time > now() AND (v_sess.start_time - now()) < interval '3 hours' THEN
    IF NOT (
      (v_sess.schedule_updated_at IS NOT NULL AND now() >= v_sess.schedule_updated_at)
      OR (v_part.promoted_from_waitlist_at IS NOT NULL AND (now() - v_part.promoted_from_waitlist_at) <= interval '1 hour')
    ) THEN
      v_late_leave := true;
    END IF;
  END IF;

  UPDATE public.session_participants
  SET status = 'left_before_start', left_at = now()
  WHERE id = v_part.id;

  IF v_sess.conversation_id IS NOT NULL THEN
    DELETE FROM public.conversation_participants
    WHERE conversation_id = v_sess.conversation_id AND user_id = v_uid;
  END IF;

  IF v_late_leave THEN
    PERFORM public._apply_reliability_mark(v_uid, p_session_id, 'late_leave', v_uid);
  END IF;

  -- AC-08: Promosi otomatis FIFO dari waitlist saat slot joined kosong
  IF v_part.status = 'joined' AND v_sess.status = 'terjadwal' THEN
    SELECT * INTO v_next
    FROM public.session_waitlist
    WHERE session_id = p_session_id
    ORDER BY queued_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF FOUND THEN
      DELETE FROM public.session_waitlist WHERE id = v_next.id;
      UPDATE public.session_participants
      SET status = 'joined', promoted_from_waitlist_at = now(), joined_at = now()
      WHERE session_id = p_session_id AND user_id = v_next.user_id;

      IF v_sess.conversation_id IS NOT NULL THEN
        INSERT INTO public.conversation_participants (conversation_id, user_id)
        VALUES (v_sess.conversation_id, v_next.user_id) ON CONFLICT DO NOTHING;
      END IF;

      INSERT INTO public.notifications (user_id, type, title, body, action_route, deliver_after)
      VALUES (
        v_next.user_id, 'main_olahraga', 'Naik dari Daftar Tunggu',
        'Slot tersedia untuk sesi "' || v_sess.title || '"! Kamu bebas keluar dalam 1 jam jika berhalangan.',
        '/play/' || v_sess.id::text,
        public.adjust_for_quiet_hours(now())
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'sessionId', p_session_id,
    'lateLeaveRecorded', v_late_leave,
    'promotedUserId', v_next.user_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_session_no_show(p_session_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sess public.play_sessions;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_sess FROM public.play_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_sess.host_id <> v_uid THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'sessionId', 'Hanya host sesi yang dapat mencatat ketidakhadiran.');
  END IF;

  UPDATE public.session_participants
  SET status = 'no_show'
  WHERE session_id = p_session_id AND user_id = p_user_id AND status = 'joined';
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'userId', 'Peserta tidak ditemukan pada sesi ini.');
  END IF;

  PERFORM public._apply_reliability_mark(p_user_id, p_session_id, 'no_show', v_uid);
END;
$$;

-- ---------------------------------------------------------------------------
-- 8. Chat & Permintaan Pesan (PSN-R1, PSN-R9 20/hari, MAN-R9 24h read-only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_first_message(
  p_recipient_id uuid,
  p_text text DEFAULT '',
  p_attachment_path text DEFAULT NULL,
  p_attachment_bytes integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_clean text := btrim(COALESCE(p_text, ''));
  v_connected boolean := public.are_connected(v_uid, p_recipient_id);
  v_ups public.user_privacy_settings;
  v_existing_conv_id uuid;
  v_conv_id uuid;
  v_cnt int;
  v_oldest timestamptz;
  v_msg public.messages;
  v_req public.message_requests;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF p_recipient_id IS NULL OR p_recipient_id = v_uid THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'recipientId', 'Penerima tidak valid.');
  END IF;
  IF public.is_blocked_between(v_uid, p_recipient_id) THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'recipientId', 'Pengguna tidak tersedia.');
  END IF;
  IF v_clean = '' AND p_attachment_path IS NULL THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'text', 'Pesan tidak boleh kosong.');
  END IF;
  IF char_length(v_clean) > 2000 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'text', 'Pesan maksimal 2.000 karakter.');
  END IF;
  IF p_attachment_bytes IS NOT NULL AND p_attachment_bytes > 5242880 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'attachment', 'Lampiran pesan maksimal 5 MB.');
  END IF;

  -- Cek apakah sudah pernah ada percakapan direct antara keduanya
  SELECT cp1.conversation_id INTO v_existing_conv_id
  FROM public.conversation_participants cp1
  JOIN public.conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
  JOIN public.conversations c ON c.id = cp1.conversation_id
  WHERE c.type = 'direct' AND cp1.user_id = v_uid AND cp2.user_id = p_recipient_id
  LIMIT 1;

  IF v_existing_conv_id IS NOT NULL THEN
    -- Delegasikan ke send_message (yang juga menegakkan PSN-R1 jika masih pending!)
    v_msg := public.send_message(v_existing_conv_id, v_clean, p_attachment_path, p_attachment_bytes, NULL);
    RETURN jsonb_build_object('conversationId', v_existing_conv_id, 'message', to_jsonb(v_msg), 'isRequest', NOT v_connected);
  END IF;

  IF NOT v_connected THEN
    SELECT * INTO v_ups FROM public.user_privacy_settings WHERE user_id = p_recipient_id;
    IF NOT COALESCE(v_ups.allow_messages_from_shared_context, true) THEN
      PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'recipientId', 'Pengguna ini menonaktifkan pesan dari non-Kenalan.');
    END IF;

    -- Kuota PSN-R9: maks 20 pesan pertama ke orang baru per 24 jam
    SELECT count(*)::int, min(created_at)
      INTO v_cnt, v_oldest
    FROM public.message_requests
    WHERE sender_id = v_uid AND created_at > (now() - interval '24 hours');

    IF v_cnt >= 20 THEN
      PERFORM public.raise_horas_error(
        'RATE_LIMITED', v_oldest + interval '24 hours', 'messageRequest',
        'Maksimal 20 pesan pertama ke orang baru per hari.'
      );
    END IF;
  END IF;

  INSERT INTO public.conversations (type, last_message_preview, last_message_at)
  VALUES ('direct', left(COALESCE(NULLIF(v_clean, ''), '[Foto]'), 120), now())
  RETURNING id INTO v_conv_id;

  INSERT INTO public.conversation_participants (conversation_id, user_id, unread_count)
  VALUES (v_conv_id, v_uid, 0), (v_conv_id, p_recipient_id, 1);

  INSERT INTO public.messages (conversation_id, sender_id, sender_fallback_label, text, attachment_path, attachment_bytes)
  VALUES (v_conv_id, v_uid, 'Pengguna HORAS', v_clean, p_attachment_path, p_attachment_bytes)
  RETURNING * INTO v_msg;

  IF NOT v_connected THEN
    INSERT INTO public.message_requests (conversation_id, sender_id, recipient_id, first_message_id, status)
    VALUES (v_conv_id, v_uid, p_recipient_id, v_msg.id, 'pending')
    RETURNING * INTO v_req;
  END IF;

  RETURN jsonb_build_object('conversationId', v_conv_id, 'message', to_jsonb(v_msg), 'requestId', v_req.id, 'isRequest', NOT v_connected);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_message(
  p_conversation_id uuid,
  p_text text DEFAULT '',
  p_attachment_path text DEFAULT NULL,
  p_attachment_bytes integer DEFAULT NULL,
  p_reply_to uuid DEFAULT NULL
)
RETURNS public.messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_clean text := btrim(COALESCE(p_text, ''));
  v_conv public.conversations;
  v_peer_id uuid;
  v_req public.message_requests;
  v_msg_cnt int;
  v_msg public.messages;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF NOT public.is_conversation_participant(p_conversation_id, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'conversationId', 'Kamu bukan peserta percakapan ini.');
  END IF;

  SELECT * INTO v_conv FROM public.conversations WHERE id = p_conversation_id;
  IF v_conv.is_read_only THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'conversationId', 'Grup chat sesi telah berstatus hanya-baca setelah 24 jam sesi selesai.');
  END IF;

  IF v_clean = '' AND p_attachment_path IS NULL THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'text', 'Pesan tidak boleh kosong.');
  END IF;
  IF char_length(v_clean) > 2000 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'text', 'Pesan maksimal 2.000 karakter.');
  END IF;
  IF p_attachment_bytes IS NOT NULL AND p_attachment_bytes > 5242880 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'attachment', 'Lampiran pesan maksimal 5 MB.');
  END IF;

  IF v_conv.type = 'direct' THEN
    SELECT user_id INTO v_peer_id
    FROM public.conversation_participants
    WHERE conversation_id = p_conversation_id AND user_id <> v_uid
    LIMIT 1;

    IF v_peer_id IS NOT NULL AND public.is_blocked_between(v_uid, v_peer_id) THEN
      PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'conversationId', 'Percakapan tidak tersedia.');
    END IF;

    -- PSN-R1: non-Kenalan hanya boleh kirim 1 pesan permintaan sampai diterima/dibalas penerima
    IF v_peer_id IS NOT NULL AND NOT public.are_connected(v_uid, v_peer_id) THEN
      SELECT * INTO v_req FROM public.message_requests WHERE conversation_id = p_conversation_id;
      IF FOUND THEN
        IF v_req.status = 'declined' AND v_req.sender_id = v_uid THEN
          PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'messageRequest', 'Permintaan pesan telah ditolak penerima.');
        ELSIF v_req.status = 'pending' AND v_req.sender_id = v_uid THEN
          SELECT count(*)::int INTO v_msg_cnt
          FROM public.messages WHERE conversation_id = p_conversation_id AND sender_id = v_uid;
          IF v_msg_cnt >= 1 THEN
            PERFORM public.raise_horas_error(
              'PERMISSION_DENIED', NULL, 'messageRequest',
              'Maksimal 1 pesan pembuka sebelum permintaan pesan diterima oleh penerima (PSN-R1).'
            );
          END IF;
        ELSIF v_req.status = 'pending' AND v_req.recipient_id = v_uid THEN
          -- Penerima membalas -> otomatis terima permintaan
          UPDATE public.message_requests SET status = 'accepted', responded_at = now() WHERE id = v_req.id;
        END IF;
      END IF;
    END IF;
  END IF;

  INSERT INTO public.messages (
    conversation_id, sender_id, sender_fallback_label, text, attachment_path, attachment_bytes, reply_to_message_id
  ) VALUES (
    p_conversation_id, v_uid, 'Pengguna HORAS', v_clean, p_attachment_path, p_attachment_bytes, p_reply_to
  ) RETURNING * INTO v_msg;

  UPDATE public.conversations
  SET last_message_preview = left(COALESCE(NULLIF(v_clean, ''), '[Foto]'), 120),
      last_message_at = now()
  WHERE id = p_conversation_id;

  UPDATE public.conversation_participants
  SET unread_count = unread_count + 1
  WHERE conversation_id = p_conversation_id AND user_id <> v_uid;

  RETURN v_msg;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_message_request(p_request_id uuid, p_accept boolean)
RETURNS public.message_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_req public.message_requests;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  UPDATE public.message_requests
  SET status = CASE WHEN p_accept THEN 'accepted'::public.message_request_status ELSE 'declined'::public.message_request_status END,
      responded_at = now()
  WHERE id = p_request_id AND recipient_id = v_uid AND status = 'pending'
  RETURNING * INTO v_req;

  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'requestId', 'Permintaan pesan tidak ditemukan.');
  END IF;
  RETURN v_req;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_message_for_everyone(p_message_id uuid)
RETURNS public.messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_msg public.messages;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_msg FROM public.messages WHERE id = p_message_id AND sender_id = v_uid;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'messageId', 'Pesan tidak ditemukan.');
  END IF;
  IF (now() - v_msg.created_at) > interval '1 hour' THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'messageId', 'Hapus untuk semua hanya dapat dilakukan dalam 1 jam setelah pesan dikirim.');
  END IF;

  UPDATE public.messages
  SET deleted_for_everyone = true, deleted_for_everyone_at = now(), text = '', attachment_path = NULL
  WHERE id = p_message_id
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

-- ---------------------------------------------------------------------------
-- 9. Tarombo Claims, Laporan (20/hari, 1 aktif), Banding (14h), Verifikasi, Admin Audit
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.propose_partuturan_claim(
  p_target_id uuid,
  p_claimed_istilah text,
  p_generation_delta integer,
  p_lineage_note text DEFAULT ''
)
RETURNS public.partuturan_claims
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_claim public.partuturan_claims;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF p_target_id IS NULL OR p_target_id = v_uid THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'targetId', 'Target klaim tidak valid.');
  END IF;
  IF public.is_blocked_between(v_uid, p_target_id) THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'targetId', 'Pengguna tidak tersedia.');
  END IF;

  INSERT INTO public.partuturan_claims (
    proposer_id, target_id, claimed_istilah, generation_delta, lineage_note
  ) VALUES (
    v_uid, p_target_id, btrim(p_claimed_istilah), p_generation_delta, btrim(COALESCE(p_lineage_note, ''))
  ) RETURNING * INTO v_claim;

  RETURN v_claim;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_partuturan_claim(p_claim_id uuid, p_confirm boolean)
RETURNS public.partuturan_claims
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_claim public.partuturan_claims;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  UPDATE public.partuturan_claims
  SET status = CASE WHEN p_confirm THEN 'confirmed'::public.partuturan_claim_status ELSE 'rejected'::public.partuturan_claim_status END,
      confirmed_at = CASE WHEN p_confirm THEN now() ELSE NULL END,
      rejected_at = CASE WHEN NOT p_confirm THEN now() ELSE NULL END
  WHERE id = p_claim_id AND target_id = v_uid AND status = 'pending'
  RETURNING * INTO v_claim;

  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'claimId', 'Klaim partuturan tidak ditemukan.');
  END IF;
  RETURN v_claim;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_report(
  p_target_type public.report_target_type,
  p_target_id text,
  p_category public.report_category,
  p_note text DEFAULT ''
)
RETURNS public.reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_clean_note text := btrim(COALESCE(p_note, ''));
  v_cnt int;
  v_oldest timestamptz;
  v_rep public.reports;
  v_snap jsonb := '{}'::jsonb;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF char_length(v_clean_note) > 500 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'note', 'Catatan laporan maksimal 500 karakter.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.reports
    WHERE reporter_id = v_uid AND target_type = p_target_type AND target_id = p_target_id
      AND status IN ('queued', 'in_review')
  ) THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'targetId', 'Kamu sudah memiliki laporan aktif untuk target ini yang sedang ditinjau.');
  END IF;

  SELECT count(*)::int, min(created_at)
    INTO v_cnt, v_oldest
  FROM public.reports
  WHERE reporter_id = v_uid AND created_at > (now() - interval '24 hours');

  IF v_cnt >= 20 THEN
    PERFORM public.raise_horas_error(
      'RATE_LIMITED', v_oldest + interval '24 hours', 'report',
      'Maksimal 20 laporan per hari.'
    );
  END IF;

  INSERT INTO public.reports (reporter_id, target_type, target_id, category, note)
  VALUES (v_uid, p_target_type, p_target_id, p_category, v_clean_note)
  RETURNING * INTO v_rep;

  -- PRD 10: Simpan salinan postingan/pesan/komentar terlapor selama 30 hari untuk audit moderasi
  IF p_target_type = 'post' AND p_target_id ~* '^[0-9a-f-]{36}$' THEN
    SELECT COALESCE(to_jsonb(p), '{}'::jsonb) INTO v_snap FROM public.posts p WHERE p.id = p_target_id::uuid;
  ELSIF p_target_type = 'message' AND p_target_id ~* '^[0-9a-f-]{36}$' THEN
    SELECT COALESCE(to_jsonb(m), '{}'::jsonb) INTO v_snap FROM public.messages m WHERE m.id = p_target_id::uuid;
  ELSIF p_target_type = 'comment' AND p_target_id ~* '^[0-9a-f-]{36}$' THEN
    SELECT COALESCE(to_jsonb(c), '{}'::jsonb) INTO v_snap FROM public.comments c WHERE c.id = p_target_id::uuid;
  END IF;

  IF v_snap <> '{}'::jsonb THEN
    INSERT INTO public.retained_moderated_content (report_id, target_type, target_id, snapshot_json)
    VALUES (v_rep.id, p_target_type, p_target_id, v_snap);
  END IF;

  RETURN v_rep;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_appeal(p_strike_id uuid, p_reason text)
RETURNS public.appeals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_strike public.strikes;
  v_app public.appeals;
BEGIN
  IF v_uid IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Login diperlukan.');
  END IF;

  SELECT * INTO v_strike FROM public.strikes WHERE id = p_strike_id AND user_id = v_uid;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'strikeId', 'Data pelanggaran tidak ditemukan.');
  END IF;

  IF now() > (v_strike.created_at + interval '14 days') THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'sanctionCreatedAt', 'Pengajuan banding hanya dapat dikirim dalam 14 hari sejak sanksi diterapkan.');
  END IF;

  INSERT INTO public.appeals (user_id, strike_id, reason)
  VALUES (v_uid, p_strike_id, btrim(p_reason))
  RETURNING * INTO v_app;

  RETURN v_app;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_verification_request(
  p_community_id uuid,
  p_organization_name text,
  p_document_path text,
  p_notes text DEFAULT ''
)
RETURNS public.verification_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ver public.verification_requests;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF NOT public.is_community_manager(p_community_id, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya pengurus komunitas yang dapat mengajukan verifikasi punguan.');
  END IF;

  INSERT INTO public.verification_requests (community_id, requester_id, organization_name, document_path, notes)
  VALUES (p_community_id, v_uid, btrim(p_organization_name), p_document_path, btrim(COALESCE(p_notes, '')))
  RETURNING * INTO v_ver;

  RETURN v_ver;
END;
$$;

-- Staff/Admin RPC dengan pencatatan audit_log otomatis
CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id uuid,
  p_dismiss boolean DEFAULT false,
  p_issue_strike_user_id uuid DEFAULT NULL,
  p_strike_reason text DEFAULT NULL,
  p_remove_target boolean DEFAULT false,
  p_resolution_note text DEFAULT ''
)
RETURNS public.reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_rep public.reports;
  v_strike_cnt int;
BEGIN
  IF NOT public.is_staff_role(v_uid, ARRAY['moderator', 'admin']::public.app_role[]) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'role', 'Akses moderator atau admin diperlukan.');
  END IF;

  UPDATE public.reports
  SET status = CASE WHEN p_dismiss THEN 'dismissed'::public.report_status ELSE 'resolved'::public.report_status END,
      assigned_moderator_id = v_uid,
      resolution_note = COALESCE(p_resolution_note, ''),
      resolved_at = now()
  WHERE id = p_report_id
  RETURNING * INTO v_rep;

  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'reportId', 'Laporan tidak ditemukan.');
  END IF;

  IF NOT p_dismiss AND p_remove_target THEN
    IF v_rep.target_type = 'post' AND v_rep.target_id ~* '^[0-9a-f-]{36}$' THEN
      UPDATE public.posts SET moderation_status = 'removed' WHERE id = v_rep.target_id::uuid;
    ELSIF v_rep.target_type = 'comment' AND v_rep.target_id ~* '^[0-9a-f-]{36}$' THEN
      UPDATE public.comments SET is_removed = true WHERE id = v_rep.target_id::uuid;
    END IF;
  END IF;

  IF NOT p_dismiss AND p_issue_strike_user_id IS NOT NULL THEN
    INSERT INTO public.strikes (user_id, reason, report_id, issued_by)
    VALUES (p_issue_strike_user_id, COALESCE(NULLIF(p_strike_reason, ''), v_rep.category::text), v_rep.id, v_uid);

    SELECT count(*)::int INTO v_strike_cnt
    FROM public.strikes
    WHERE user_id = p_issue_strike_user_id AND created_at > (now() - interval '90 days');

    IF v_strike_cnt >= 3 THEN
      PERFORM set_config('horas.bypass_profile_guard', 'on', true);
      UPDATE public.profiles
      SET account_status = 'suspended', suspended_until = now() + interval '30 days'
      WHERE id = p_issue_strike_user_id AND account_status <> 'permanently_banned';
    END IF;
  END IF;

  INSERT INTO public.audit_log (actor_id, actor_role, action, target_type, target_id, metadata)
  VALUES (
    v_uid, 'moderator', CASE WHEN p_dismiss THEN 'dismiss_report' ELSE 'resolve_report' END,
    v_rep.target_type::text, v_rep.target_id,
    jsonb_build_object('reportId', v_rep.id, 'strikeUserId', p_issue_strike_user_id, 'removed', p_remove_target)
  );

  RETURN v_rep;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_verification(
  p_request_id uuid,
  p_approve boolean,
  p_note text DEFAULT ''
)
RETURNS public.verification_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_req public.verification_requests;
BEGIN
  IF NOT public.is_staff_role(v_uid, ARRAY['support', 'admin']::public.app_role[]) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'role', 'Akses support atau admin diperlukan.');
  END IF;

  UPDATE public.verification_requests
  SET status = CASE WHEN p_approve THEN 'approved'::public.verification_status ELSE 'rejected'::public.verification_status END,
      reviewed_by = v_uid,
      reviewed_at = now(),
      review_note = COALESCE(p_note, '')
  WHERE id = p_request_id
  RETURNING * INTO v_req;

  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'requestId', 'Pengajuan verifikasi tidak ditemukan.');
  END IF;

  IF p_approve THEN
    UPDATE public.communities SET is_verified = true WHERE id = v_req.community_id;
  END IF;

  INSERT INTO public.audit_log (actor_id, actor_role, action, target_type, target_id, metadata)
  VALUES (v_uid, 'support', 'review_verification', 'community', v_req.community_id::text, jsonb_build_object('approved', p_approve));

  RETURN v_req;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_community_join_request(
  p_request_id uuid,
  p_approve boolean
)
RETURNS public.community_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_req public.community_join_requests;
  v_conv_id uuid;
BEGIN
  PERFORM public.assert_active_account(v_uid);

  SELECT * INTO v_req FROM public.community_join_requests
  WHERE id = p_request_id AND status = 'pending';
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'requestId', 'Permintaan gabung komunitas tidak ditemukan.');
  END IF;

  IF NOT public.is_community_manager(v_req.community_id, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya pengurus komunitas yang dapat memproses permintaan ini.');
  END IF;

  UPDATE public.community_join_requests
  SET status = CASE WHEN p_approve THEN 'approved'::public.join_request_status ELSE 'rejected'::public.join_request_status END,
      reviewed_by = v_uid,
      responded_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_req;

  IF p_approve THEN
    INSERT INTO public.community_memberships (community_id, user_id, role)
    VALUES (v_req.community_id, v_req.user_id, 'member') ON CONFLICT DO NOTHING;

    SELECT conversation_id INTO v_conv_id FROM public.communities WHERE id = v_req.community_id;
    IF v_conv_id IS NOT NULL THEN
      INSERT INTO public.conversation_participants (conversation_id, user_id)
      VALUES (v_conv_id, v_req.user_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  UPDATE public.communities SET last_manager_active_at = now(), is_inactive_flagged = false WHERE id = v_req.community_id;
  RETURN v_req;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_partuturan_ruleset(
  p_ruleset_id uuid,
  p_validated boolean
)
RETURNS public.partuturan_rulesets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_rs public.partuturan_rulesets;
BEGIN
  IF NOT public.is_staff_role(v_uid, ARRAY['adat_reviewer', 'admin']::public.app_role[]) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'role', 'Akses peninjau adat atau admin diperlukan.');
  END IF;

  UPDATE public.partuturan_rulesets
  SET validated = p_validated,
      reviewed_by = v_uid,
      reviewed_at = now()
  WHERE id = p_ruleset_id
  RETURNING * INTO v_rs;

  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'rulesetId', 'Ruleset partuturan tidak ditemukan.');
  END IF;

  INSERT INTO public.audit_log (actor_id, actor_role, action, target_type, target_id, metadata)
  VALUES (v_uid, 'adat_reviewer', 'review_partuturan_ruleset', 'partuturan_ruleset', v_rs.id::text, jsonb_build_object('validated', p_validated));

  RETURN v_rs;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_resolve_appeal(
  p_appeal_id uuid,
  p_accept boolean,
  p_note text DEFAULT ''
)
RETURNS public.appeals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_app public.appeals;
BEGIN
  IF NOT public.is_staff_role(v_uid, ARRAY['moderator', 'support', 'admin']::public.app_role[]) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'role', 'Akses moderator, support, atau admin diperlukan.');
  END IF;

  UPDATE public.appeals
  SET status = CASE WHEN p_accept THEN 'accepted'::public.appeal_status ELSE 'rejected'::public.appeal_status END,
      reviewer_note = COALESCE(p_note, ''),
      reviewed_by = v_uid,
      reviewed_at = now()
  WHERE id = p_appeal_id
  RETURNING * INTO v_app;

  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'appealId', 'Banding tidak ditemukan.');
  END IF;

  IF p_accept THEN
    PERFORM set_config('horas.bypass_profile_guard', 'on', true);
    DELETE FROM public.strikes WHERE id = v_app.strike_id;
    UPDATE public.profiles
    SET account_status = 'active', suspended_until = NULL
    WHERE id = v_app.user_id AND account_status = 'suspended';
  END IF;

  INSERT INTO public.audit_log (actor_id, actor_role, action, target_type, target_id, metadata)
  VALUES (v_uid, 'moderator', 'resolve_appeal', 'appeal', v_app.id::text, jsonb_build_object('accepted', p_accept));

  RETURN v_app;
END;
$$;
