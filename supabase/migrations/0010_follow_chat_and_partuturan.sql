-- =============================================================================
-- 0010_follow_chat_and_partuturan.sql
-- 1. Mengizinkan chat langsung bila sudah Mengikuti (gaya Instagram)
-- 2. Memperbarui aturan Partuturan Toba v0.2.0-draft (9 Prioritas Panggilan:
--    Parra, Anggi, Haha, Pariban, Periksa generasi & silsilah, Bapa Uda,
--    Bapa Tua, Namboru, Tulang, Nantulang, Marpariban, Lae, Ito).
-- =============================================================================

-- 1. _build_person_summary: canMessage juga true bila sudah mengikuti (v_following)
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
    OR v_following
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

-- 2. RPC open_or_create_direct_conversation untuk membuka ruang chat langsung
--    bila sudah Terhubung atau sudah Mengikuti (gaya Instagram)
CREATE OR REPLACE FUNCTION public.open_or_create_direct_conversation(p_target_user_id uuid)
RETURNS public.conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_connected boolean;
  v_following boolean;
  v_conv public.conversations;
  v_existing_id uuid;
BEGIN
  PERFORM public.assert_active_account(v_uid);
  IF p_target_user_id IS NULL OR p_target_user_id = v_uid THEN
    PERFORM public.raise_horas_error('VALIDATION_ERROR', NULL, 'targetUserId', 'Pengguna tujuan tidak valid.');
  END IF;
  IF public.is_blocked_between(v_uid, p_target_user_id) THEN
    PERFORM public.raise_horas_error('CONTENT_UNAVAILABLE', NULL, 'targetUserId', 'Percakapan ditutup karena salah satu pengguna diblokir.');
  END IF;

  SELECT cp1.conversation_id INTO v_existing_id
  FROM public.conversation_participants cp1
  JOIN public.conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
  JOIN public.conversations c ON c.id = cp1.conversation_id
  WHERE c.type = 'direct' AND cp1.user_id = v_uid AND cp2.user_id = p_target_user_id
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    SELECT * INTO v_conv FROM public.conversations WHERE id = v_existing_id;
    RETURN v_conv;
  END IF;

  v_connected := public.are_connected(v_uid, p_target_user_id);
  v_following := public.is_following(v_uid, p_target_user_id);
  IF NOT v_connected AND NOT v_following THEN
    PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'targetUserId', 'Ikuti atau hubungkan pengguna terlebih dahulu untuk memulai percakapan.');
  END IF;

  INSERT INTO public.conversations (type, last_message_preview, last_message_at)
  VALUES ('direct', '', now())
  RETURNING * INTO v_conv;

  INSERT INTO public.conversation_participants (conversation_id, user_id, unread_count)
  VALUES (v_conv.id, v_uid, 0), (v_conv.id, p_target_user_id, 0);

  RETURN v_conv;
END;
$$;

-- 3. send_first_message: juga mengizinkan bila sudah mengikuti (v_following)
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
  v_following boolean := public.is_following(v_uid, p_recipient_id);
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
    RETURN jsonb_build_object('conversationId', v_existing_conv_id, 'message', to_jsonb(v_msg), 'isRequest', NOT (v_connected OR v_following));
  END IF;

  IF NOT v_connected AND NOT v_following THEN
    IF NOT v_shared_context THEN
      PERFORM public.raise_horas_error('PERMISSION_DENIED', NULL, 'recipientId', 'Chat hanya terbuka bagi pengguna yang diikuti, Kenalan, atau komunitas/sesi bersama (PSN-R1).');
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

  IF NOT v_connected AND NOT v_following THEN
    INSERT INTO public.message_requests (conversation_id, sender_id, recipient_id, first_message_id, status)
    VALUES (v_conv_id, v_uid, p_recipient_id, v_msg.id, 'pending')
    RETURNING * INTO v_req;
  END IF;

  RETURN jsonb_build_object('conversationId', v_conv_id, 'message', to_jsonb(v_msg), 'requestId', v_req.id, 'isRequest', NOT (v_connected OR v_following));
END;
$$;

-- 4. evaluate_partuturan mendukung selisih umur & marga ibu sama (sameMotherMarga)
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
  v_age_diff integer;
  v_rule jsonb;
  v_rel text;
  v_istilah text;
  v_conf text;
  v_expl text;
  v_q text;
  v_semarga boolean;
  v_same_mother boolean;
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
  v_same_mother := COALESCE(btrim(v_viewer.mother_marga), '') <> ''
    AND COALESCE(btrim(v_target.mother_marga), '') <> ''
    AND lower(btrim(v_viewer.mother_marga)) = lower(btrim(v_target.mother_marga));

  IF v_viewer.birth_year IS NOT NULL AND v_target.birth_year IS NOT NULL THEN
    v_age_diff := v_viewer.birth_year - v_target.birth_year;
  END IF;

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
    IF v_rel = 'specificKinshipBranch' THEN
      CONTINUE;
    ELSIF v_rel = 'sameAsViewerMarga' AND NOT v_semarga THEN
      CONTINUE;
    ELSIF v_rel = 'sameAsViewerMotherMarga' AND (
      v_semarga OR COALESCE(btrim(v_viewer.mother_marga), '') = '' OR lower(btrim(v_viewer.mother_marga)) <> lower(btrim(v_target.marga))
    ) THEN
      CONTINUE;
    ELSIF v_rel = 'sameMotherMarga' AND NOT v_same_mother THEN
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
      IF v_delta IS NULL THEN
        CONTINUE;
      END IF;
    END IF;
    IF v_rule->>'generationDelta' IS NOT NULL THEN
      IF v_delta IS NULL OR v_delta <> (v_rule->>'generationDelta')::int THEN
        CONTINUE;
      END IF;
    END IF;
    IF COALESCE((v_rule->>'requireAgeDifferenceKnown')::boolean, false) AND v_age_diff IS NULL THEN
      CONTINUE;
    END IF;
    IF v_age_diff IS NOT NULL THEN
      IF v_rule->>'minAgeDiffYears' IS NOT NULL AND v_age_diff < (v_rule->>'minAgeDiffYears')::int THEN
        CONTINUE;
      END IF;
      IF v_rule->>'maxAgeDiffYears' IS NOT NULL AND v_age_diff > (v_rule->>'maxAgeDiffYears')::int THEN
        CONTINUE;
      END IF;
      IF v_rule->>'maxAbsAgeDiffYears' IS NOT NULL AND abs(v_age_diff) > (v_rule->>'maxAbsAgeDiffYears')::int THEN
        CONTINUE;
      END IF;
      IF v_rule->>'minAbsAgeDiffYears' IS NOT NULL AND abs(v_age_diff) < (v_rule->>'minAbsAgeDiffYears')::int THEN
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
