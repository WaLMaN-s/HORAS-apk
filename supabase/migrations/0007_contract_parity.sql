-- =============================================================================
-- 0007_contract_parity.sql
-- Penyelarasan kontrak 23 repository Flutter <-> Postgres (AC-06, AC-16,
-- PSN-R4/R5/R6, BER-R5, MAN-R5/R7, TAR-R2/R8/R10, FCM tokens, batch summaries).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Penambahan kolom paritas domain
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS tarombo_consent_at timestamptz,
  ADD COLUMN IF NOT EXISTS tarombo_parent_names_vis public.field_visibility NOT NULL DEFAULT 'only_me',
  ADD COLUMN IF NOT EXISTS fcm_tokens text[] NOT NULL DEFAULT '{}'::text[];

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS comments_disabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_edited boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS city_tag text,
  ADD COLUMN IF NOT EXISTS community_ids uuid[] NOT NULL DEFAULT '{}'::uuid[];

ALTER TABLE public.post_media
  ADD COLUMN IF NOT EXISTS aspect_ratio double precision NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.play_sessions
  ADD COLUMN IF NOT EXISTS city text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS manual_location_summary text,
  ADD COLUMN IF NOT EXISTS manual_location_full_detail text;

ALTER TABLE public.session_payment_shares
  ADD COLUMN IF NOT EXISTS is_confirmed_by_host boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS confirmed_at timestamptz;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS hidden_for_user_ids uuid[] NOT NULL DEFAULT '{}'::uuid[],
  ADD COLUMN IF NOT EXISTS has_scam_warning boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_pinned_announcement boolean NOT NULL DEFAULT false;

ALTER TABLE public.family_members
  ADD COLUMN IF NOT EXISTS gender public.user_gender NOT NULL DEFAULT 'male';

ALTER TABLE public.partuturan_feedback
  ALTER COLUMN target_id DROP NOT NULL;

ALTER TABLE public.partuturan_feedback
  ADD COLUMN IF NOT EXISTS viewer_marga text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS target_marga text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS shown_term text,
  ADD COLUMN IF NOT EXISTS rule_version text NOT NULL DEFAULT '0.1.0-draft';

ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS contact_email text,
  ADD COLUMN IF NOT EXISTS attachment_path text;

-- ---------------------------------------------------------------------------
-- 2. Helper konteks bersama (komunitas ATAU sesi Main aktif) & batch summary
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.share_session(a uuid, b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN a IS NULL OR b IS NULL THEN false
    ELSE EXISTS (
      SELECT 1
      FROM public.session_participants p1
      JOIN public.session_participants p2 ON p1.session_id = p2.session_id
      WHERE p1.user_id = a
        AND p2.user_id = b
        AND p1.status = 'joined'
        AND p2.status = 'joined'
    )
  END;
$$;

-- Perbarui _build_person_summary agar canMessage juga mencakup sesi bersama (AC-06)
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
  v_shared_session boolean := false;
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
    v_shared_session := public.share_session(p_viewer_id, p_target.id);
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

  v_can_msg := v_connected
    OR (COALESCE(v_ups.allow_messages_from_shared_context, true)
        AND (v_shared_comm_cnt > 0 OR v_shared_session));

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

CREATE OR REPLACE FUNCTION public.get_batch_person_summaries(p_ids uuid[])
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid := auth.uid();
  v_row public.profiles;
BEGIN
  IF v_viewer_id IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Autentikasi diperlukan.');
  END IF;

  FOR v_row IN
    SELECT * FROM public.profiles
    WHERE id = ANY(COALESCE(p_ids, '{}'::uuid[]))
      AND (id = v_viewer_id OR NOT public.is_blocked_between(v_viewer_id, id))
  LOOP
    RETURN NEXT public._build_person_summary(v_viewer_id, v_row);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Postingan: create_post dgn community_ids/city_tag, edit & kunci komentar
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_post(text, public.post_visibility, uuid, jsonb);
CREATE OR REPLACE FUNCTION public.create_post(
  p_text text DEFAULT '',
  p_visibility public.post_visibility DEFAULT 'publik',
  p_community_id uuid DEFAULT NULL,
  p_media jsonb DEFAULT '[]'::jsonb,
  p_community_ids uuid[] DEFAULT '{}'::uuid[],
  p_city_tag text DEFAULT NULL
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
  v_primary_comm uuid := COALESCE(p_community_id, p_community_ids[1]);
  v_all_comms uuid[] := CASE
    WHEN array_length(p_community_ids, 1) > 0 THEN p_community_ids
    WHEN p_community_id IS NOT NULL THEN ARRAY[p_community_id]
    ELSE '{}'::uuid[]
  END;
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

  IF v_primary_comm IS NOT NULL AND NOT public.is_community_member(v_primary_comm, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya anggota yang dapat memposting di komunitas ini.');
  END IF;

  SELECT count(*)::int, min(created_at)
    INTO v_cnt, v_oldest
  FROM public.posts
  WHERE author_id = v_uid AND created_at > (now() - interval '24 hours');

  IF v_cnt >= 20 THEN
    PERFORM public.raise_horas_error('RATE_LIMITED', v_oldest + interval '24 hours', 'post', 'Maksimal 20 postingan per 24 jam.');
  END IF;

  v_is_new := v_prof.created_at > (now() - interval '7 days');
  v_has_link := v_clean ~* '(https?://|www\.)\S+';
  SELECT count(*)::int INTO v_link_cnt FROM regexp_matches(v_clean, '(https?://|www\.)\S+', 'gi');
  v_has_bad_words := lower(v_clean) ~ '\m(slot\s*gacor|judi\s*online|pinjol\s*ilegal|taruhan\s*bola|promo\s*togel|kasar_sara)\M';
  v_has_spam := (v_link_cnt >= 3) OR (v_clean ~ '(.)\1{9,}');

  IF (v_has_link AND v_is_new) OR v_has_bad_words OR v_has_spam THEN
    v_status := 'under_review';
  END IF;

  INSERT INTO public.posts (author_id, community_id, community_ids, city_tag, text, visibility, moderation_status)
  VALUES (v_uid, v_primary_comm, v_all_comms, NULLIF(btrim(COALESCE(p_city_tag, '')), ''), v_clean, p_visibility, v_status)
  RETURNING * INTO v_post;

  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(p_media, '[]'::jsonb))
  LOOP
    INSERT INTO public.post_media (
      post_id, owner_id, storage_path, mime_type, width, height, size_bytes, exif_stripped, sort_order, aspect_ratio, metadata
    ) VALUES (
      v_post.id,
      v_uid,
      v_item->>'storagePath',
      COALESCE(v_item->>'mimeType', 'image/jpeg'),
      NULLIF(v_item->>'width', '')::int,
      NULLIF(v_item->>'height', '')::int,
      COALESCE((v_item->>'sizeBytes')::int, 1024),
      COALESCE((v_item->>'exifStripped')::boolean, true),
      v_idx,
      COALESCE((v_item->>'aspectRatio')::double precision, 1.0),
      COALESCE(v_item->'metadata', '{}'::jsonb)
    );
    v_idx := v_idx + 1;
  END LOOP;

  RETURN v_post;
END;
$$;

CREATE OR REPLACE FUNCTION public.edit_post_text(p_post_id uuid, p_new_text text)
RETURNS public.posts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_clean text := btrim(COALESCE(p_new_text, ''));
  v_post public.posts;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF char_length(v_clean) > 2000 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'text', 'Teks postingan maksimal 2.000 karakter.');
  END IF;
  UPDATE public.posts
  SET text = v_clean, is_edited = true, updated_at = now()
  WHERE id = p_post_id AND author_id = v_uid
  RETURNING * INTO v_post;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'postId', 'Postingan tidak ditemukan.');
  END IF;
  RETURN v_post;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_post_comments_disabled(p_post_id uuid, p_disabled boolean)
RETURNS public.posts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_post public.posts;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  UPDATE public.posts
  SET comments_disabled = p_disabled, updated_at = now()
  WHERE id = p_post_id AND author_id = v_uid
  RETURNING * INTO v_post;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'postId', 'Postingan tidak ditemukan.');
  END IF;
  RETURN v_post;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Komunitas: leave_community (SEK-R8), remove, set_role, toggle_pin, transfer
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.leave_community(p_community_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_comm public.communities;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_comm FROM public.communities WHERE id = p_community_id;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'communityId', 'Komunitas tidak ditemukan.');
  END IF;
  IF v_comm.owner_id = v_uid THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'owner', 'Pemilik komunitas harus menyerahkan kepemilikan sebelum keluar.');
  END IF;

  DELETE FROM public.community_memberships WHERE community_id = p_community_id AND user_id = v_uid;
  IF v_comm.conversation_id IS NOT NULL THEN
    DELETE FROM public.conversation_participants WHERE conversation_id = v_comm.conversation_id AND user_id = v_uid;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_community_member(p_community_id uuid, p_target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_comm public.communities;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF NOT public.is_community_manager(p_community_id, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya pengurus yang dapat mengeluarkan anggota.');
  END IF;
  SELECT * INTO v_comm FROM public.communities WHERE id = p_community_id;
  IF v_comm.owner_id = p_target_user_id THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'targetUserId', 'Pemilik komunitas tidak dapat dikeluarkan.');
  END IF;

  DELETE FROM public.community_memberships WHERE community_id = p_community_id AND user_id = p_target_user_id;
  IF v_comm.conversation_id IS NOT NULL THEN
    DELETE FROM public.conversation_participants WHERE conversation_id = v_comm.conversation_id AND user_id = p_target_user_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_community_member_role(
  p_community_id uuid,
  p_target_user_id uuid,
  p_role public.community_role
)
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
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya pengurus yang dapat mengubah peran anggota.');
  END IF;
  IF p_role = 'manager' THEN
    SELECT count(*)::int INTO v_mgr_cnt
    FROM public.community_memberships
    WHERE community_id = p_community_id AND role IN ('owner', 'manager') AND user_id <> p_target_user_id;
    IF v_mgr_cnt >= 10 THEN
      PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'role', 'Maksimal 10 pengurus per komunitas.');
    END IF;
  END IF;
  UPDATE public.community_memberships
  SET role = p_role
  WHERE community_id = p_community_id AND user_id = p_target_user_id AND role <> 'owner';
END;
$$;

CREATE OR REPLACE FUNCTION public.transfer_community_ownership(p_community_id uuid, p_new_owner_id uuid)
RETURNS public.communities
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_comm public.communities;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_comm FROM public.communities WHERE id = p_community_id;
  IF NOT FOUND OR v_comm.owner_id <> v_uid THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya pemilik saat ini yang dapat menyerahkan kepemilikan.');
  END IF;
  IF NOT public.is_community_member(p_community_id, p_new_owner_id) THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'newOwnerId', 'Calon pemilik harus anggota komunitas.');
  END IF;

  UPDATE public.community_memberships SET role = 'manager' WHERE community_id = p_community_id AND user_id = v_uid;
  UPDATE public.community_memberships SET role = 'owner' WHERE community_id = p_community_id AND user_id = p_new_owner_id;
  UPDATE public.communities SET owner_id = p_new_owner_id, last_manager_active_at = now()
  WHERE id = p_community_id RETURNING * INTO v_comm;
  RETURN v_comm;
END;
$$;

CREATE OR REPLACE FUNCTION public.toggle_pin_announcement(p_community_id uuid, p_announcement_id uuid)
RETURNS public.community_announcements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ann public.community_announcements;
  v_pin_cnt int;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF NOT public.is_community_manager(p_community_id, v_uid) THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'communityId', 'Hanya pengurus yang dapat menyematkan pengumuman.');
  END IF;

  SELECT * INTO v_ann FROM public.community_announcements WHERE id = p_announcement_id AND community_id = p_community_id;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'announcementId', 'Pengumuman tidak ditemukan.');
  END IF;

  IF NOT v_ann.is_pinned THEN
    SELECT count(*)::int INTO v_pin_cnt FROM public.community_announcements WHERE community_id = p_community_id AND is_pinned = true;
    IF v_pin_cnt >= 3 THEN
      PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'isPinned', 'Maksimal 3 pengumuman tersemat di satu komunitas.');
    END IF;
  END IF;

  UPDATE public.community_announcements SET is_pinned = NOT is_pinned WHERE id = p_announcement_id RETURNING * INTO v_ann;
  RETURN v_ann;
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. Sesi Main: schedule, cancel, approval, patungan, attendance
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_session(text, public.sport_type, public.skill_level, timestamptz, timestamptz, integer, integer, text, public.session_visibility, public.session_join_mode, uuid, uuid);
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
  p_community_id uuid DEFAULT NULL,
  p_city text DEFAULT '',
  p_manual_location_summary text DEFAULT NULL,
  p_manual_location_full_detail text DEFAULT NULL
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
  FROM public.play_sessions WHERE host_id = v_uid AND status IN ('terjadwal', 'berlangsung');
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
  IF v_combined ~ '\m(taruhan|judi|betting|voor|pur-puran|uang\s+taruhan)\M' THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'notes', 'Taruhan uang atau judi dalam bentuk apa pun dilarang keras di HORAS.');
  END IF;

  INSERT INTO public.conversations (type, title) VALUES ('session', btrim(p_title)) RETURNING id INTO v_conv_id;

  INSERT INTO public.play_sessions (
    host_id, community_id, court_id, conversation_id, title, sport, skill_level,
    start_time, end_time, max_slots, fee_per_person_rupiah, notes, visibility, join_mode,
    city, manual_location_summary, manual_location_full_detail
  ) VALUES (
    v_uid, p_community_id, p_court_id, v_conv_id, btrim(p_title), p_sport, p_skill_level,
    p_start_time, p_end_time, p_max_slots, p_fee_per_person_rupiah, btrim(COALESCE(p_notes, '')),
    p_visibility, p_join_mode, COALESCE(NULLIF(btrim(p_city), ''), v_prof.city),
    p_manual_location_summary, p_manual_location_full_detail
  ) RETURNING * INTO v_session;

  UPDATE public.conversations SET session_id = v_session.id WHERE id = v_conv_id;
  INSERT INTO public.session_participants (session_id, user_id, status) VALUES (v_session.id, v_uid, 'joined');
  INSERT INTO public.conversation_participants (conversation_id, user_id) VALUES (v_conv_id, v_uid);

  IF p_fee_per_person_rupiah > 0 THEN
    INSERT INTO public.session_payment_shares (session_id, user_id, amount_rupiah)
    VALUES (v_session.id, v_uid, p_fee_per_person_rupiah) ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_session;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_session_schedule(
  p_session_id uuid,
  p_start_time timestamptz DEFAULT NULL,
  p_end_time timestamptz DEFAULT NULL,
  p_court_id uuid DEFAULT NULL,
  p_manual_location_summary text DEFAULT NULL,
  p_manual_location_full_detail text DEFAULT NULL
)
RETURNS public.play_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sess public.play_sessions;
  v_p record;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_sess FROM public.play_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_sess.host_id <> v_uid THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'sessionId', 'Hanya host yang dapat mengubah jadwal sesi.');
  END IF;

  UPDATE public.play_sessions SET
    start_time = COALESCE(p_start_time, start_time),
    end_time = COALESCE(p_end_time, end_time),
    court_id = COALESCE(p_court_id, court_id),
    manual_location_summary = COALESCE(p_manual_location_summary, manual_location_summary),
    manual_location_full_detail = COALESCE(p_manual_location_full_detail, manual_location_full_detail),
    schedule_updated_at = now()
  WHERE id = p_session_id
  RETURNING * INTO v_sess;

  FOR v_p IN
    SELECT user_id FROM public.session_participants
    WHERE session_id = p_session_id AND user_id <> v_uid AND status = 'joined'
  LOOP
    INSERT INTO public.notifications (user_id, type, title, body, action_route)
    VALUES (v_p.user_id, 'main_olahraga', 'Jadwal Sesi Diubah', 'Host mengubah jadwal atau lokasi sesi "' || v_sess.title || '".', '/play/' || v_sess.id::text);
  END LOOP;

  RETURN v_sess;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_session(p_session_id uuid)
RETURNS public.play_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sess public.play_sessions;
  v_p record;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  UPDATE public.play_sessions
  SET status = 'dibatalkan'
  WHERE id = p_session_id AND host_id = v_uid
  RETURNING * INTO v_sess;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'sessionId', 'Hanya host yang dapat membatalkan sesi.');
  END IF;

  FOR v_p IN
    SELECT user_id FROM public.session_participants WHERE session_id = p_session_id AND user_id <> v_uid
  LOOP
    INSERT INTO public.notifications (user_id, type, title, body, action_route)
    VALUES (v_p.user_id, 'main_olahraga', 'Sesi Dibatalkan', 'Sesi "' || v_sess.title || '" dibatalkan oleh host.', '/play/' || v_sess.id::text);
  END LOOP;

  RETURN v_sess;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_session_join(
  p_session_id uuid,
  p_participant_id uuid,
  p_approve boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sess public.play_sessions;
  v_part public.session_participants;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_sess FROM public.play_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_sess.host_id <> v_uid THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'sessionId', 'Hanya host yang dapat menyetujui peserta.');
  END IF;

  UPDATE public.session_participants
  SET status = CASE WHEN p_approve THEN 'joined'::public.participant_status ELSE 'rejected'::public.participant_status END,
      joined_at = now()
  WHERE id = p_participant_id AND session_id = p_session_id
  RETURNING * INTO v_part;

  IF FOUND AND p_approve AND v_sess.conversation_id IS NOT NULL THEN
    INSERT INTO public.conversation_participants (conversation_id, user_id)
    VALUES (v_sess.conversation_id, v_part.user_id) ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_session_participant(p_session_id uuid, p_participant_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sess public.play_sessions;
  v_part public.session_participants;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_sess FROM public.play_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_sess.host_id <> v_uid THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'sessionId', 'Hanya host yang dapat mengeluarkan peserta.');
  END IF;

  DELETE FROM public.session_participants
  WHERE id = p_participant_id AND session_id = p_session_id AND user_id <> v_uid
  RETURNING * INTO v_part;

  IF FOUND AND v_sess.conversation_id IS NOT NULL THEN
    DELETE FROM public.conversation_participants WHERE conversation_id = v_sess.conversation_id AND user_id = v_part.user_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_session_attendance(
  p_session_id uuid,
  p_participant_id uuid,
  p_attended boolean
)
RETURNS public.session_participants
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sess public.play_sessions;
  v_part public.session_participants;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_sess FROM public.play_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_sess.host_id <> v_uid THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'sessionId', 'Hanya host yang dapat menandai kehadiran.');
  END IF;

  UPDATE public.session_participants
  SET status = CASE WHEN p_attended THEN 'joined'::public.participant_status ELSE 'no_show'::public.participant_status END
  WHERE id = p_participant_id AND session_id = p_session_id
  RETURNING * INTO v_part;

  IF FOUND AND NOT p_attended THEN
    PERFORM public._apply_reliability_mark(v_part.user_id, p_session_id, 'no_show', v_uid);
  END IF;
  RETURN v_part;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_session_patungan(
  p_session_id uuid,
  p_amount_rupiah integer,
  p_is_total boolean
)
RETURNS SETOF public.session_payment_shares
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sess public.play_sessions;
  v_cnt int;
  v_per int;
  v_raw int;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_sess FROM public.play_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_sess.host_id <> v_uid THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'sessionId', 'Hanya host yang dapat mengatur patungan.');
  END IF;

  SELECT count(*)::int INTO v_cnt FROM public.session_participants WHERE session_id = p_session_id AND status = 'joined';
  v_cnt := GREATEST(v_cnt, 1);

  IF p_is_total THEN
    v_raw := (p_amount_rupiah + v_cnt - 1) / v_cnt;
    v_per := ((v_raw + 499) / 500) * 500;
  ELSE
    v_per := p_amount_rupiah;
  END IF;

  IF v_per < 0 OR v_per > 1000000 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'feePerPersonRupiah', 'Biaya per orang harus antara Rp0 sampai Rp1.000.000.');
  END IF;

  UPDATE public.play_sessions SET fee_per_person_rupiah = v_per WHERE id = p_session_id;

  INSERT INTO public.session_payment_shares (session_id, user_id, amount_rupiah)
  SELECT p_session_id, sp.user_id, v_per
  FROM public.session_participants sp
  WHERE sp.session_id = p_session_id AND sp.status = 'joined'
  ON CONFLICT (session_id, user_id) DO UPDATE SET amount_rupiah = EXCLUDED.amount_rupiah;

  RETURN QUERY SELECT * FROM public.session_payment_shares WHERE session_id = p_session_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_payment_paid(p_share_id uuid)
RETURNS public.session_payment_shares
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_share public.session_payment_shares;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  UPDATE public.session_payment_shares
  SET is_paid = true, marked_paid_at = now(), marked_by = v_uid
  WHERE id = p_share_id AND user_id = v_uid
  RETURNING * INTO v_share;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'paymentShareId', 'Tagihan patungan tidak ditemukan.');
  END IF;
  RETURN v_share;
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_payment_received(p_share_id uuid)
RETURNS public.session_payment_shares
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_share public.session_payment_shares;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  UPDATE public.session_payment_shares sps
  SET is_confirmed_by_host = true, confirmed_at = now()
  FROM public.play_sessions ps
  WHERE sps.id = p_share_id AND ps.id = sps.session_id AND ps.host_id = v_uid
  RETURNING sps.* INTO v_share;
  IF NOT FOUND THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'paymentShareId', 'Hanya host yang dapat mengonfirmasi pembayaran.');
  END IF;
  RETURN v_share;
END;
$$;

-- ---------------------------------------------------------------------------
-- 6. Chat AC-06 & AC-16 + Delete for me, Mute, Pinned, Leave Group
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
  v_shared_context boolean := public.share_community(v_uid, p_recipient_id) OR public.share_session(v_uid, p_recipient_id);
  v_ups public.user_privacy_settings;
  v_existing_conv_id uuid;
  v_conv_id uuid;
  v_cnt int;
  v_oldest timestamptz;
  v_scam boolean := false;
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

  SELECT cp1.conversation_id INTO v_existing_conv_id
  FROM public.conversation_participants cp1
  JOIN public.conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
  JOIN public.conversations c ON c.id = cp1.conversation_id
  WHERE c.type = 'direct' AND cp1.user_id = v_uid AND cp2.user_id = p_recipient_id
  LIMIT 1;

  IF v_existing_conv_id IS NOT NULL THEN
    v_msg := public.send_message(v_existing_conv_id, v_clean, p_attachment_path, p_attachment_bytes, NULL);
    RETURN jsonb_build_object('conversationId', v_existing_conv_id, 'message', to_jsonb(v_msg), 'isRequest', NOT v_connected);
  END IF;

  IF NOT v_connected THEN
    IF NOT v_shared_context THEN
      PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'recipientId', 'Chat hanya terbuka bagi Kenalan atau pengguna dengan komunitas/sesi bersama (PSN-R1).');
    END IF;
    SELECT * INTO v_ups FROM public.user_privacy_settings WHERE user_id = p_recipient_id;
    IF NOT COALESCE(v_ups.allow_messages_from_shared_context, true) THEN
      PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'recipientId', 'Pengguna ini menonaktifkan pesan dari non-Kenalan.');
    END IF;

    SELECT count(*)::int, min(created_at)
      INTO v_cnt, v_oldest
    FROM public.message_requests
    WHERE sender_id = v_uid AND created_at > (now() - interval '24 hours');

    IF v_cnt >= 20 THEN
      PERFORM public.raise_horas_error('RATE_LIMITED', v_oldest + interval '24 hours', 'messageRequest', 'Maksimal 20 pesan pertama ke orang baru per hari.');
    END IF;

    -- AC-16: Deteksi indikasi transfer/tautan pada pesan pertama non-Kenalan
    v_scam := (v_clean ~* '(https?://|www\.)\S+')
      OR (lower(v_clean) ~ '\m(transfer|rekening|dana|gopay|ovo|pinjam|pinjaman|bayar|uang)\M');
  END IF;

  INSERT INTO public.conversations (type, last_message_preview, last_message_at)
  VALUES ('direct', left(COALESCE(NULLIF(v_clean, ''), '[Foto]'), 120), now())
  RETURNING id INTO v_conv_id;

  INSERT INTO public.conversation_participants (conversation_id, user_id, unread_count)
  VALUES (v_conv_id, v_uid, 0), (v_conv_id, p_recipient_id, 1);

  INSERT INTO public.messages (conversation_id, sender_id, sender_fallback_label, text, attachment_path, attachment_bytes, has_scam_warning)
  VALUES (v_conv_id, v_uid, 'Pengguna HORAS', v_clean, p_attachment_path, p_attachment_bytes, v_scam)
  RETURNING * INTO v_msg;

  IF NOT v_connected THEN
    INSERT INTO public.message_requests (conversation_id, sender_id, recipient_id, first_message_id, status)
    VALUES (v_conv_id, v_uid, p_recipient_id, v_msg.id, 'pending')
    RETURNING * INTO v_req;
  END IF;

  RETURN jsonb_build_object('conversationId', v_conv_id, 'message', to_jsonb(v_msg), 'requestId', v_req.id, 'isRequest', NOT v_connected);
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_message_for_me(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  PERFORM public.assert_active_account(v_uid);
  UPDATE public.messages
  SET hidden_for_user_ids = array_append(hidden_for_user_ids, v_uid)
  WHERE id = p_message_id
    AND public.is_conversation_participant(conversation_id, v_uid)
    AND NOT (v_uid = ANY(hidden_for_user_ids));
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_group_conversation(p_conversation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  PERFORM public.assert_active_account(v_uid);
  DELETE FROM public.conversation_participants cp
  USING public.conversations c
  WHERE cp.conversation_id = p_conversation_id
    AND c.id = cp.conversation_id
    AND c.type <> 'direct'
    AND cp.user_id = v_uid;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_group_member(p_conversation_id uuid, p_target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_conv public.conversations;
  v_is_admin boolean := false;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_conv FROM public.conversations WHERE id = p_conversation_id;
  IF v_conv.community_id IS NOT NULL THEN
    v_is_admin := public.is_community_manager(v_conv.community_id, v_uid);
  ELSIF v_conv.session_id IS NOT NULL THEN
    v_is_admin := EXISTS (SELECT 1 FROM public.play_sessions WHERE id = v_conv.session_id AND host_id = v_uid);
  END IF;
  IF NOT v_is_admin THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'conversationId', 'Hanya pengurus atau host yang dapat mengeluarkan anggota grup.');
  END IF;
  DELETE FROM public.conversation_participants WHERE conversation_id = p_conversation_id AND user_id = p_target_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_pinned_announcement_message(p_conversation_id uuid, p_text text)
RETURNS public.messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_conv public.conversations;
  v_is_admin boolean := false;
  v_msg public.messages;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  SELECT * INTO v_conv FROM public.conversations WHERE id = p_conversation_id;
  IF v_conv.community_id IS NOT NULL THEN
    v_is_admin := public.is_community_manager(v_conv.community_id, v_uid);
  ELSIF v_conv.session_id IS NOT NULL THEN
    v_is_admin := EXISTS (SELECT 1 FROM public.play_sessions WHERE id = v_conv.session_id AND host_id = v_uid);
  END IF;
  IF NOT v_is_admin THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'conversationId', 'Hanya admin grup yang dapat mengirim pengumuman tersemat.');
  END IF;

  INSERT INTO public.messages (conversation_id, sender_id, sender_fallback_label, text, is_pinned_announcement)
  VALUES (p_conversation_id, v_uid, 'Pengurus HORAS', btrim(p_text), true)
  RETURNING * INTO v_msg;
  RETURN v_msg;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7. Marga Custom, Tarombo Consent/Delete All, Push Notification, FCM Token
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_custom_marga(p_name text, p_sub_ethnic public.sub_ethnic)
RETURNS public.marga
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_clean text := btrim(COALESCE(p_name, ''));
  v_row public.marga;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF char_length(v_clean) < 2 OR char_length(v_clean) > 40 THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'margaName', 'Nama marga tidak valid.');
  END IF;

  INSERT INTO public.marga (id, name, sub_ethnic, is_verified)
  VALUES ('marga-custom-' || lower(regexp_replace(v_clean, '[^a-zA-Z0-9]+', '-', 'g')), v_clean, p_sub_ethnic, false)
  ON CONFLICT (name) DO UPDATE SET name = public.marga.name
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_all_my_tarombo()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  PERFORM public.assert_active_account(v_uid);
  DELETE FROM public.family_members WHERE owner_id = v_uid;
  PERFORM set_config('horas.bypass_profile_guard', 'on', true);
  UPDATE public.profiles SET mother_marga = NULL, tarombo_consent_at = NULL WHERE id = v_uid;
END;
$$;

CREATE OR REPLACE FUNCTION public.register_fcm_token(p_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_tok text := btrim(COALESCE(p_token, ''));
BEGIN
  IF v_uid IS NULL OR v_tok = '' THEN RETURN; END IF;
  UPDATE public.profiles
  SET fcm_tokens = (
    SELECT array_agg(DISTINCT t)
    FROM unnest(array_append(fcm_tokens, v_tok)) AS t
  )
  WHERE id = v_uid;
END;
$$;

CREATE OR REPLACE FUNCTION public.push_notification(
  p_recipient_id uuid,
  p_type public.notification_type,
  p_title text,
  p_body text,
  p_action_route text
)
RETURNS public.notifications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_notif public.notifications;
  v_deliver timestamptz := now();
BEGIN
  IF v_uid IS NULL THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'auth', 'Autentikasi diperlukan.');
  END IF;
  IF p_type <> 'sistem_keamanan' THEN
    v_deliver := public.adjust_for_quiet_hours(now());
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, action_route, deliver_after)
  VALUES (p_recipient_id, p_type, btrim(p_title), btrim(p_body), p_action_route, v_deliver)
  RETURNING * INTO v_notif;

  RETURN v_notif;
END;
$$;

-- ---------------------------------------------------------------------------
-- 8. Selaraskan kunci JSON evaluate_partuturan dengan PartuturanResult.fromJson
-- ---------------------------------------------------------------------------
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
  v_semarga boolean;
BEGIN
  IF p_viewer_id IS NULL OR p_target_id IS NULL OR p_viewer_id = p_target_id THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_viewer FROM public.profiles WHERE id = p_viewer_id;
  SELECT * INTO v_target FROM public.profiles WHERE id = p_target_id;
  IF v_viewer.id IS NULL OR v_target.id IS NULL THEN
    RETURN NULL;
  END IF;

  v_semarga := btrim(v_viewer.marga) <> '' AND lower(btrim(v_viewer.marga)) = lower(btrim(v_target.marga));

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
      'penjelasanJalur', 'Hubungan kekerabatan telah dikonfirmasi oleh kedua pihak dalam Tarombo.',
      'pertanyaanPelengkap', NULL,
      'versiAturan', 'confirmed-claim',
      'modeNetral', false,
      'isDraftRule', false,
      'isSemarga', v_semarga
    );
  END IF;

  SELECT * INTO v_ruleset
  FROM public.partuturan_rulesets
  WHERE sub_ethnic = v_viewer.sub_ethnic AND is_active = true
  ORDER BY validated DESC, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'istilah', NULL,
      'displayLabel', 'Kenalan (' || initcap(v_viewer.sub_ethnic::text) || ')',
      'confidence', 'rendah',
      'penjelasanJalur', '',
      'pertanyaanPelengkap', NULL,
      'versiAturan', 'neutral',
      'modeNetral', true,
      'isDraftRule', false,
      'isSemarga', v_semarga
    );
  END IF;

  v_delta := public.generation_delta(p_viewer_id, p_target_id);

  FOR v_rule IN
    SELECT value FROM jsonb_array_elements(COALESCE(v_ruleset.rules_json->'rules', '[]'::jsonb))
  LOOP
    v_rel := v_rule->>'targetMargaRelation';
    IF v_rel = 'sameAsViewerMarga' AND NOT v_semarga THEN
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

    IF COALESCE(v_rule->>'viewerGender', 'any') <> 'any' AND (v_rule->>'viewerGender') <> v_viewer.gender::text THEN
      CONTINUE;
    END IF;
    IF COALESCE(v_rule->>'targetGender', 'any') <> 'any' AND (v_rule->>'targetGender') <> v_target.gender::text THEN
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
      'penjelasanJalur', v_expl,
      'pertanyaanPelengkap', v_q,
      'versiAturan', v_ruleset.version,
      'modeNetral', false,
      'isDraftRule', NOT v_ruleset.validated,
      'isSemarga', v_semarga
    );
  END LOOP;

  RETURN jsonb_build_object(
    'istilah', NULL,
    'displayLabel', 'Belum bisa dipastikan',
    'confidence', 'rendah',
    'penjelasanJalur', COALESCE(v_ruleset.rules_json->>'defaultLowExplanation', ''),
    'pertanyaanPelengkap', COALESCE(v_ruleset.rules_json->>'defaultLowQuestion', ''),
    'versiAturan', v_ruleset.version,
    'modeNetral', false,
    'isDraftRule', NOT v_ruleset.validated,
    'isSemarga', v_semarga
  );
END;
$$;
