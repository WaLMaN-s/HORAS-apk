-- =============================================================================
-- 0004_rls_and_storage.sql
-- Helper otorisasi, pengaktifan RLS di SEMUA tabel public, kebijakan privasi
-- ketat (AC-07, AC-11, AC-13, PSN-R1), penguncian kolom sensitif profil,
-- serta Storage buckets & policies (avatars, posts, chat-media, support).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Helper Role & Relasi (SECURITY DEFINER agar bebas rekursi RLS)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_role(p_user_id uuid, p_role public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = p_user_id AND role = p_role
  );
$$;

CREATE OR REPLACE FUNCTION public.is_staff_role(p_user_id uuid, p_roles public.app_role[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = p_user_id AND role = ANY(p_roles)
  );
$$;

CREATE OR REPLACE FUNCTION public.is_blocked_between(a uuid, b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN a IS NULL OR b IS NULL THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.blocks
      WHERE (blocker_id = a AND blocked_id = b)
         OR (blocker_id = b AND blocked_id = a)
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.are_connected(a uuid, b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN a IS NULL OR b IS NULL OR a = b THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.connections
      WHERE user_a = LEAST(a, b) AND user_b = GREATEST(a, b)
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.is_following(p_follower uuid, p_followee uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_follower IS NULL OR p_followee IS NULL THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.follows
      WHERE follower_id = p_follower AND followee_id = p_followee
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.share_community(a uuid, b uuid)
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
      FROM public.community_memberships m1
      JOIN public.community_memberships m2 ON m1.community_id = m2.community_id
      WHERE m1.user_id = a AND m2.user_id = b
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.is_community_member(p_comm_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_comm_id IS NULL OR p_user_id IS NULL THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.community_memberships
      WHERE community_id = p_comm_id AND user_id = p_user_id
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.is_community_manager(p_comm_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_comm_id IS NULL OR p_user_id IS NULL THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.community_memberships
      WHERE community_id = p_comm_id
        AND user_id = p_user_id
        AND role IN ('owner', 'manager')
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.is_conversation_participant(p_conv_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_conv_id IS NULL OR p_user_id IS NULL THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_id = p_conv_id AND user_id = p_user_id
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.can_view_user_posts(p_viewer_id uuid, p_author_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status public.account_status;
  v_acc_type public.account_visibility_type;
BEGIN
  IF p_author_id IS NULL THEN RETURN false; END IF;
  IF p_viewer_id = p_author_id THEN RETURN true; END IF;
  IF p_viewer_id IS NULL THEN RETURN false; END IF;
  IF public.is_blocked_between(p_viewer_id, p_author_id) THEN RETURN false; END IF;

  SELECT p.account_status, ups.account_type
    INTO v_status, v_acc_type
  FROM public.profiles p
  LEFT JOIN public.user_privacy_settings ups ON ups.user_id = p.id
  WHERE p.id = p_author_id;

  IF v_status IS NULL OR v_status IN ('suspended', 'permanently_banned') THEN
    RETURN false;
  END IF;

  IF COALESCE(v_acc_type, 'public_account') = 'private_account' THEN
    RETURN public.are_connected(p_viewer_id, p_author_id)
        OR public.is_following(p_viewer_id, p_author_id);
  END IF;

  RETURN true;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. Penguncian kolom sensitif & aturan ubah nama 30 hari pada profiles
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_profile_locked_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text := COALESCE(NULLIF(current_setting('role', true), 'none'), session_user);
  v_bypass text := COALESCE(current_setting('horas.bypass_profile_guard', true), '');
  v_uid uuid := auth.uid();
  v_is_privileged boolean := false;
BEGIN
  IF v_bypass = 'on' OR v_role IN ('postgres', 'service_role', 'supabase_admin', 'cli_login_postgres') THEN
    v_is_privileged := true;
  ELSIF v_uid IS NOT NULL AND public.is_staff_role(v_uid, ARRAY['admin', 'support']::public.app_role[]) THEN
    v_is_privileged := true;
  END IF;

  IF NOT v_is_privileged THEN
    -- Kolom sistem yang tidak boleh diubah langsung oleh pengguna biasa
    IF NEW.account_status IS DISTINCT FROM OLD.account_status
       OR NEW.suspended_until IS DISTINCT FROM OLD.suspended_until
       OR NEW.restricted_until IS DISTINCT FROM OLD.restricted_until
       OR NEW.phone_e164 IS DISTINCT FROM OLD.phone_e164
       OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at THEN
      RAISE EXCEPTION 'HORAS_ERR|PERMISSION_DENIED||profile|Perubahan kolom sistem memerlukan proses resmi atau dukungan.' USING ERRCODE = '42501';
    END IF;

    -- Marga, sub-suku, jenis kelamin terkunci setelah onboarding selesai (faq-01)
    IF OLD.onboarding_completed THEN
      IF NEW.marga IS DISTINCT FROM OLD.marga
         OR NEW.sub_ethnic IS DISTINCT FROM OLD.sub_ethnic
         OR NEW.gender IS DISTINCT FROM OLD.gender THEN
        RAISE EXCEPTION 'HORAS_ERR|PERMISSION_DENIED||marga|Marga, sub-suku, dan jenis kelamin terkunci. Ajukan perubahan lewat Hubungi Dukungan.' USING ERRCODE = '42501';
      END IF;

      -- Cooldown ubah nama tampil 30 hari
      IF NEW.display_name IS DISTINCT FROM OLD.display_name THEN
        IF OLD.display_name_changed_at IS NOT NULL
           AND (OLD.display_name_changed_at + interval '30 days') > now() THEN
          RAISE EXCEPTION 'HORAS_ERR|RATE_LIMITED|%|displayName|Nama tampil hanya dapat diubah sekali setiap 30 hari.',
            to_char((OLD.display_name_changed_at + interval '30 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
            USING ERRCODE = 'P0001';
        END IF;
        NEW.display_name_changed_at := now();
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profile_locked_fields ON public.profiles;
CREATE TRIGGER trg_guard_profile_locked_fields
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_locked_fields();

-- ---------------------------------------------------------------------------
-- 3. Aktifkan RLS di SEMUA tabel schema public
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marga ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wilayah ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partuturan_rulesets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_privacy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_security_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_request_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connection_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partuturan_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partuturan_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.play_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_waitlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_payment_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reliability_marks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retained_moderated_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strikes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_recovery_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_export_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_deletions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.help_articles ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 4. Kebijakan RLS per tabel (DROP IF EXISTS agar idempoten)
-- ---------------------------------------------------------------------------

-- Referensi publik (read-only bagi pengguna)
DROP POLICY IF EXISTS marga_read_all ON public.marga;
CREATE POLICY marga_read_all ON public.marga FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS wilayah_read_all ON public.wilayah;
CREATE POLICY wilayah_read_all ON public.wilayah FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS help_articles_read_all ON public.help_articles;
CREATE POLICY help_articles_read_all ON public.help_articles FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS partuturan_rulesets_read ON public.partuturan_rulesets;
CREATE POLICY partuturan_rulesets_read ON public.partuturan_rulesets
  FOR SELECT TO authenticated, anon USING (is_active = true);

DROP POLICY IF EXISTS partuturan_rulesets_reviewer_manage ON public.partuturan_rulesets;
CREATE POLICY partuturan_rulesets_reviewer_manage ON public.partuturan_rulesets
  FOR ALL TO authenticated
  USING (public.is_staff_role(auth.uid(), ARRAY['adat_reviewer', 'admin']::public.app_role[]))
  WITH CHECK (public.is_staff_role(auth.uid(), ARRAY['adat_reviewer', 'admin']::public.app_role[]));

DROP POLICY IF EXISTS courts_read ON public.courts;
CREATE POLICY courts_read ON public.courts
  FOR SELECT TO authenticated
  USING (
    moderation_status = 'approved'
    OR suggested_by = auth.uid()
    OR public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin']::public.app_role[])
  );

DROP POLICY IF EXISTS courts_suggest_insert ON public.courts;
CREATE POLICY courts_suggest_insert ON public.courts
  FOR INSERT TO authenticated
  WITH CHECK (suggested_by = auth.uid() AND moderation_status = 'pending_review');

-- User Roles & Audit Log
DROP POLICY IF EXISTS user_roles_self_or_admin ON public.user_roles;
CREATE POLICY user_roles_self_or_admin ON public.user_roles
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS audit_log_staff_read ON public.audit_log;
CREATE POLICY audit_log_staff_read ON public.audit_log
  FOR SELECT TO authenticated
  USING (public.is_staff_role(auth.uid(), ARRAY['moderator', 'adat_reviewer', 'support', 'admin']::public.app_role[]));

-- Profiles: HANYA pemilik atau admin/support (ZERO raw peer SELECT!)
DROP POLICY IF EXISTS profiles_select_self_or_staff ON public.profiles;
CREATE POLICY profiles_select_self_or_staff ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR public.is_staff_role(auth.uid(), ARRAY['support', 'admin', 'moderator']::public.app_role[])
  );

DROP POLICY IF EXISTS profiles_update_self ON public.profiles;
CREATE POLICY profiles_update_self ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Privacy settings, devices, login_history
DROP POLICY IF EXISTS privacy_self_all ON public.user_privacy_settings;
CREATE POLICY privacy_self_all ON public.user_privacy_settings
  FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS devices_self_select ON public.user_devices;
CREATE POLICY devices_self_select ON public.user_devices
  FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS devices_self_delete ON public.user_devices;
CREATE POLICY devices_self_delete ON public.user_devices
  FOR DELETE TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS login_history_self_select ON public.login_history;
CREATE POLICY login_history_self_select ON public.login_history
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Follows, Connections, Connection Requests, Blocks
DROP POLICY IF EXISTS follows_read ON public.follows;
CREATE POLICY follows_read ON public.follows
  FOR SELECT TO authenticated
  USING (
    (follower_id = auth.uid() OR followee_id = auth.uid())
    AND NOT public.is_blocked_between(follower_id, followee_id)
  );

DROP POLICY IF EXISTS follows_self_delete ON public.follows;
CREATE POLICY follows_self_delete ON public.follows
  FOR DELETE TO authenticated USING (follower_id = auth.uid());

DROP POLICY IF EXISTS conn_req_read ON public.connection_requests;
CREATE POLICY conn_req_read ON public.connection_requests
  FOR SELECT TO authenticated
  USING (
    (requester_id = auth.uid() OR recipient_id = auth.uid())
    AND NOT public.is_blocked_between(requester_id, recipient_id)
  );

DROP POLICY IF EXISTS connections_read ON public.connections;
CREATE POLICY connections_read ON public.connections
  FOR SELECT TO authenticated
  USING (
    (user_a = auth.uid() OR user_b = auth.uid())
    AND NOT public.is_blocked_between(user_a, user_b)
  );

DROP POLICY IF EXISTS blocks_self_select ON public.blocks;
CREATE POLICY blocks_self_select ON public.blocks
  FOR SELECT TO authenticated USING (blocker_id = auth.uid());

-- Tarombo & Partuturan claims/feedback
DROP POLICY IF EXISTS family_members_self_all ON public.family_members;
CREATE POLICY family_members_self_all ON public.family_members
  FOR ALL TO authenticated USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS partuturan_claims_participant_read ON public.partuturan_claims;
CREATE POLICY partuturan_claims_participant_read ON public.partuturan_claims
  FOR SELECT TO authenticated
  USING (
    (proposer_id = auth.uid() OR target_id = auth.uid())
    AND NOT public.is_blocked_between(proposer_id, target_id)
  );

DROP POLICY IF EXISTS partuturan_feedback_self_or_reviewer ON public.partuturan_feedback;
CREATE POLICY partuturan_feedback_self_or_reviewer ON public.partuturan_feedback
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_staff_role(auth.uid(), ARRAY['adat_reviewer', 'admin']::public.app_role[])
  );

DROP POLICY IF EXISTS partuturan_feedback_insert ON public.partuturan_feedback;
CREATE POLICY partuturan_feedback_insert ON public.partuturan_feedback
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Komunitas (AC-13: closed tersembunyi bagi non-anggota)
DROP POLICY IF EXISTS communities_read ON public.communities;
CREATE POLICY communities_read ON public.communities
  FOR SELECT TO authenticated
  USING (
    access_type <> 'closed'
    OR owner_id = auth.uid()
    OR public.is_community_member(id, auth.uid())
    OR public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin']::public.app_role[])
  );

DROP POLICY IF EXISTS comm_memberships_read ON public.community_memberships;
CREATE POLICY comm_memberships_read ON public.community_memberships
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_community_member(community_id, auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.communities c
      WHERE c.id = community_id AND c.access_type <> 'closed'
    )
  );

DROP POLICY IF EXISTS comm_join_req_read ON public.community_join_requests;
CREATE POLICY comm_join_req_read ON public.community_join_requests
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_community_manager(community_id, auth.uid()));

DROP POLICY IF EXISTS comm_announcements_read ON public.community_announcements;
CREATE POLICY comm_announcements_read ON public.community_announcements
  FOR SELECT TO authenticated
  USING (
    public.is_community_member(community_id, auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.communities c
      WHERE c.id = community_id AND c.access_type = 'open'
    )
  );

-- Posts, Media, Comments, Likes, Saved Posts
DROP POLICY IF EXISTS posts_read ON public.posts;
CREATE POLICY posts_read ON public.posts
  FOR SELECT TO authenticated
  USING (
    author_id = auth.uid()
    OR (
      moderation_status = 'published'
      AND NOT public.is_blocked_between(auth.uid(), author_id)
      AND public.can_view_user_posts(auth.uid(), author_id)
      AND (
        visibility = 'publik'
        OR (visibility = 'komunitas' AND community_id IS NOT NULL AND public.is_community_member(community_id, auth.uid()))
        OR (visibility = 'kenalan' AND public.are_connected(auth.uid(), author_id))
      )
    )
    OR public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin']::public.app_role[])
  );

DROP POLICY IF EXISTS posts_delete_self ON public.posts;
CREATE POLICY posts_delete_self ON public.posts
  FOR DELETE TO authenticated USING (author_id = auth.uid());

DROP POLICY IF EXISTS post_media_read ON public.post_media;
CREATE POLICY post_media_read ON public.post_media
  FOR SELECT TO authenticated
  USING (
    owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id)
  );

DROP POLICY IF EXISTS comments_read ON public.comments;
CREATE POLICY comments_read ON public.comments
  FOR SELECT TO authenticated
  USING (
    NOT is_removed
    AND NOT public.is_blocked_between(auth.uid(), author_id)
    AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id)
  );

DROP POLICY IF EXISTS comments_delete_self ON public.comments;
CREATE POLICY comments_delete_self ON public.comments
  FOR DELETE TO authenticated USING (author_id = auth.uid());

DROP POLICY IF EXISTS likes_read ON public.likes;
CREATE POLICY likes_read ON public.likes
  FOR SELECT TO authenticated
  USING (
    NOT public.is_blocked_between(auth.uid(), user_id)
    AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id)
  );

DROP POLICY IF EXISTS likes_self_manage ON public.likes;
CREATE POLICY likes_self_manage ON public.likes
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id));

DROP POLICY IF EXISTS saved_posts_self_all ON public.saved_posts;
CREATE POLICY saved_posts_self_all ON public.saved_posts
  FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Main Olahraga
DROP POLICY IF EXISTS play_sessions_read ON public.play_sessions;
CREATE POLICY play_sessions_read ON public.play_sessions
  FOR SELECT TO authenticated
  USING (
    host_id = auth.uid()
    OR (
      NOT public.is_blocked_between(auth.uid(), host_id)
      AND (
        visibility = 'terbuka'
        OR (visibility = 'komunitas' AND community_id IS NOT NULL AND public.is_community_member(community_id, auth.uid()))
        OR (visibility = 'kenalan' AND public.are_connected(auth.uid(), host_id))
        OR EXISTS (SELECT 1 FROM public.session_participants sp WHERE sp.session_id = id AND sp.user_id = auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS session_participants_read ON public.session_participants;
CREATE POLICY session_participants_read ON public.session_participants
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.play_sessions ps WHERE ps.id = session_id)
  );

DROP POLICY IF EXISTS session_waitlist_read ON public.session_waitlist;
CREATE POLICY session_waitlist_read ON public.session_waitlist
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.play_sessions ps WHERE ps.id = session_id AND ps.host_id = auth.uid())
  );

DROP POLICY IF EXISTS session_payment_shares_read ON public.session_payment_shares;
CREATE POLICY session_payment_shares_read ON public.session_payment_shares
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.play_sessions ps WHERE ps.id = session_id AND ps.host_id = auth.uid())
  );

DROP POLICY IF EXISTS reliability_marks_self_or_staff ON public.reliability_marks;
CREATE POLICY reliability_marks_self_or_staff ON public.reliability_marks
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin', 'support']::public.app_role[])
  );

-- Percakapan & Pesan (Realtime)
DROP POLICY IF EXISTS conversations_read ON public.conversations;
CREATE POLICY conversations_read ON public.conversations
  FOR SELECT TO authenticated
  USING (public.is_conversation_participant(id, auth.uid()));

DROP POLICY IF EXISTS conv_participants_read ON public.conversation_participants;
CREATE POLICY conv_participants_read ON public.conversation_participants
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_conversation_participant(conversation_id, auth.uid())
  );

DROP POLICY IF EXISTS conv_participants_update_self ON public.conversation_participants;
CREATE POLICY conv_participants_update_self ON public.conversation_participants
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS messages_read ON public.messages;
CREATE POLICY messages_read ON public.messages
  FOR SELECT TO authenticated
  USING (
    public.is_conversation_participant(conversation_id, auth.uid())
    AND (sender_id IS NULL OR NOT public.is_blocked_between(auth.uid(), sender_id))
  );

DROP POLICY IF EXISTS message_requests_read ON public.message_requests;
CREATE POLICY message_requests_read ON public.message_requests
  FOR SELECT TO authenticated
  USING (sender_id = auth.uid() OR recipient_id = auth.uid());

-- Notifikasi
DROP POLICY IF EXISTS notifications_self_select ON public.notifications;
CREATE POLICY notifications_self_select ON public.notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_self_update ON public.notifications;
CREATE POLICY notifications_self_update ON public.notifications
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS notif_prefs_self_all ON public.notification_preferences;
CREATE POLICY notif_prefs_self_all ON public.notification_preferences
  FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Laporan, Moderasi, Strikes, Banding, Verifikasi, Support, Ekspor, Hapus Akun
DROP POLICY IF EXISTS reports_read ON public.reports;
CREATE POLICY reports_read ON public.reports
  FOR SELECT TO authenticated
  USING (
    reporter_id = auth.uid()
    OR public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin']::public.app_role[])
  );

DROP POLICY IF EXISTS retained_mod_content_staff ON public.retained_moderated_content;
CREATE POLICY retained_mod_content_staff ON public.retained_moderated_content
  FOR ALL TO authenticated
  USING (public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin']::public.app_role[]))
  WITH CHECK (public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin']::public.app_role[]));

DROP POLICY IF EXISTS strikes_read ON public.strikes;
CREATE POLICY strikes_read ON public.strikes
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin', 'support']::public.app_role[])
  );

DROP POLICY IF EXISTS appeals_read ON public.appeals;
CREATE POLICY appeals_read ON public.appeals
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_staff_role(auth.uid(), ARRAY['moderator', 'admin', 'support']::public.app_role[])
  );

DROP POLICY IF EXISTS verif_requests_read ON public.verification_requests;
CREATE POLICY verif_requests_read ON public.verification_requests
  FOR SELECT TO authenticated
  USING (
    requester_id = auth.uid()
    OR public.is_community_manager(community_id, auth.uid())
    OR public.is_staff_role(auth.uid(), ARRAY['support', 'admin']::public.app_role[])
  );

DROP POLICY IF EXISTS support_tickets_read ON public.support_tickets;
CREATE POLICY support_tickets_read ON public.support_tickets
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_staff_role(auth.uid(), ARRAY['support', 'admin']::public.app_role[])
  );

DROP POLICY IF EXISTS support_tickets_insert ON public.support_tickets;
CREATE POLICY support_tickets_insert ON public.support_tickets
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS account_recovery_staff_read ON public.account_recovery_requests;
CREATE POLICY account_recovery_staff_read ON public.account_recovery_requests
  FOR ALL TO authenticated
  USING (public.is_staff_role(auth.uid(), ARRAY['support', 'admin']::public.app_role[]))
  WITH CHECK (public.is_staff_role(auth.uid(), ARRAY['support', 'admin']::public.app_role[]));

DROP POLICY IF EXISTS data_export_jobs_self_read ON public.data_export_jobs;
CREATE POLICY data_export_jobs_self_read ON public.data_export_jobs
  FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS account_deletions_self_read ON public.account_deletions;
CREATE POLICY account_deletions_self_read ON public.account_deletions
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 5. Storage Buckets & RLS Policies (BER-R4 / AC-10: upload lewat process-image)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('posts', 'posts', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('chat-media', 'chat-media', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('support', 'support', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Hanya Edge Function `process-image` (service_role) yang menulis ke avatars/posts/chat-media
-- agar SEMUA gambar dijamin melalui re-encoding & pembuangan metadata EXIF/GPS.
DROP POLICY IF EXISTS storage_avatars_public_read ON storage.objects;
CREATE POLICY storage_avatars_public_read ON storage.objects
  FOR SELECT TO authenticated, anon
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS storage_posts_auth_read ON storage.objects;
CREATE POLICY storage_posts_auth_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'posts'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR (
        (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        AND NOT public.is_blocked_between(
          auth.uid(),
          ((storage.foldername(name))[1])::uuid
        )
      )
    )
  );

DROP POLICY IF EXISTS storage_chat_media_participant_read ON storage.objects;
CREATE POLICY storage_chat_media_participant_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'chat-media'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR (
        (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        AND public.is_conversation_participant(
          ((storage.foldername(name))[2])::uuid,
          auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS storage_support_owner_or_staff ON storage.objects;
CREATE POLICY storage_support_owner_or_staff ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'support'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_staff_role(auth.uid(), ARRAY['support', 'admin', 'moderator']::public.app_role[])
    )
  );

DROP POLICY IF EXISTS storage_support_owner_insert ON storage.objects;
CREATE POLICY storage_support_owner_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'support'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
