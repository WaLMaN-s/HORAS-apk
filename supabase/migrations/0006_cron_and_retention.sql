-- =============================================================================
-- 0006_cron_and_retention.sql
-- Fungsi pemeliharaan terjadwal (pg_cron): lifecycle sesi olahraga (+2j selesai,
-- +24j chat read-only), kedaluwarsa kenalan/join (30h/14h), purge permanen akun
-- hari ke-30 (AC-12) dengan jejak "Pengguna terhapus" di chat lama, retensi PRD 10,
-- serta penandaan komunitas dengan pengurus tidak aktif >= 90 hari.
-- =============================================================================

-- Izinkan account_deletions mempertahankan log anonim setelah user/profile dihapus permanen
ALTER TABLE public.account_deletions
  ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE public.account_deletions
  DROP CONSTRAINT IF EXISTS account_deletions_user_id_fkey;

ALTER TABLE public.account_deletions
  ADD CONSTRAINT account_deletions_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- 1. Lifecycle Sesi Olahraga (MAN-R9)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.run_session_lifecycle_jobs()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_completed int := 0;
  v_readonly int := 0;
BEGIN
  -- Auto-complete 2 jam setelah end_time
  WITH updated AS (
    UPDATE public.play_sessions
    SET status = 'selesai',
        completed_at = COALESCE(completed_at, now())
    WHERE status IN ('terjadwal', 'berlangsung')
      AND end_time <= (now() - interval '2 hours')
    RETURNING id
  )
  SELECT count(*)::int INTO v_completed FROM updated;

  -- Chat grup sesi menjadi hanya-baca 24 jam setelah selesai
  WITH ro_sessions AS (
    UPDATE public.play_sessions
    SET chat_read_only_at = COALESCE(chat_read_only_at, now())
    WHERE status = 'selesai'
      AND completed_at IS NOT NULL
      AND completed_at <= (now() - interval '24 hours')
      AND chat_read_only_at IS NULL
    RETURNING conversation_id
  ),
  ro_convs AS (
    UPDATE public.conversations c
    SET is_read_only = true
    FROM ro_sessions r
    WHERE c.id = r.conversation_id
      AND NOT c.is_read_only
    RETURNING c.id
  )
  SELECT count(*)::int INTO v_readonly FROM ro_convs;

  RETURN jsonb_build_object(
    'sessionsCompleted', v_completed,
    'chatsMadeReadOnly', v_readonly
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. Kedaluwarsa Permintaan, Ekspor Data (48h SLA / 7d link), & Komunitas Pasif 90h
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.run_expiry_jobs()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conn_exp int := 0;
  v_join_exp int := 0;
  v_export_exp int := 0;
  v_comm_flagged int := 0;
BEGIN
  WITH c1 AS (
    UPDATE public.connection_requests
    SET status = 'expired', responded_at = COALESCE(responded_at, expires_at)
    WHERE status = 'pending' AND expires_at <= now()
    RETURNING id
  )
  SELECT count(*)::int INTO v_conn_exp FROM c1;

  WITH j1 AS (
    UPDATE public.community_join_requests
    SET status = 'expired', responded_at = COALESCE(responded_at, expires_at)
    WHERE status = 'pending' AND expires_at <= now()
    RETURNING id
  )
  SELECT count(*)::int INTO v_join_exp FROM j1;

  WITH e1 AS (
    UPDATE public.data_export_jobs
    SET status = 'expired'
    WHERE status = 'ready' AND expires_at IS NOT NULL AND expires_at <= now()
    RETURNING id
  )
  SELECT count(*)::int INTO v_export_exp FROM e1;

  WITH m1 AS (
    UPDATE public.communities
    SET is_inactive_flagged = true
    WHERE last_manager_active_at <= (now() - interval '90 days')
      AND NOT is_inactive_flagged
    RETURNING id
  )
  SELECT count(*)::int INTO v_comm_flagged FROM m1;

  RETURN jsonb_build_object(
    'expiredConnections', v_conn_exp,
    'expiredJoinRequests', v_join_exp,
    'expiredExports', v_export_exp,
    'inactiveCommunitiesFlagged', v_comm_flagged
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Penghapusan Akun Permanen Hari ke-30 (AC-12) dengan Jejak Chat Aman
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.run_account_purge_jobs()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rec record;
  v_purged int := 0;
BEGIN
  FOR v_rec IN
    SELECT id, user_id
    FROM public.account_deletions
    WHERE NOT is_cancelled
      AND NOT is_permanently_deleted
      AND user_id IS NOT NULL
      AND scheduled_permanent_deletion_at <= now()
  LOOP
    -- Pertahankan pesan lama dalam percakapan sebagai "Pengguna terhapus" (AC-12)
    UPDATE public.messages
    SET sender_id = NULL,
        sender_fallback_label = 'Pengguna terhapus'
    WHERE sender_id = v_rec.user_id;

    -- Tandai job penghapusan selesai sebelum cascade delete user
    UPDATE public.account_deletions
    SET is_permanently_deleted = true,
        permanently_deleted_at = now(),
        user_id = NULL
    WHERE id = v_rec.id;

    -- Hapus akun dari auth.users (cascade ke profiles, tokens, follows, posts, dll.)
    DELETE FROM auth.users WHERE id = v_rec.user_id;
    v_purged := v_purged + 1;
  END LOOP;

  RETURN v_purged;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Retensi Data PRD 10 (Notifikasi 90h, Chat Sesi 12b, Laporan/Audit 12b, Konten 30h, OTP)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.run_retention_cleanup_jobs()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notifs int := 0;
  v_session_chats int := 0;
  v_reports int := 0;
  v_audits int := 0;
  v_retained int := 0;
  v_otp int := 0;
BEGIN
  WITH d_notif AS (
    DELETE FROM public.notifications
    WHERE created_at < (now() - interval '90 days')
    RETURNING id
  ) SELECT count(*)::int INTO v_notifs FROM d_notif;

  WITH old_session_convs AS (
    SELECT conversation_id
    FROM public.play_sessions
    WHERE status = 'selesai'
      AND completed_at IS NOT NULL
      AND completed_at < (now() - interval '12 months')
      AND conversation_id IS NOT NULL
  ),
  d_conv AS (
    DELETE FROM public.conversations c
    USING old_session_convs o
    WHERE c.id = o.conversation_id
    RETURNING c.id
  ) SELECT count(*)::int INTO v_session_chats FROM d_conv;

  WITH d_rep AS (
    DELETE FROM public.reports
    WHERE created_at < (now() - interval '12 months')
      AND status IN ('resolved', 'dismissed')
    RETURNING id
  ) SELECT count(*)::int INTO v_reports FROM d_rep;

  WITH d_aud AS (
    DELETE FROM public.audit_log
    WHERE created_at < (now() - interval '12 months')
    RETURNING id
  ) SELECT count(*)::int INTO v_audits FROM d_aud;

  WITH d_ret AS (
    DELETE FROM public.retained_moderated_content
    WHERE retain_until <= now()
    RETURNING id
  ) SELECT count(*)::int INTO v_retained FROM d_ret;

  WITH d_otp AS (
    DELETE FROM public.otp_request_logs
    WHERE created_at < (now() - interval '24 hours')
    RETURNING id
  ) SELECT count(*)::int INTO v_otp FROM d_otp;

  DELETE FROM public.otp_security_state
  WHERE updated_at < (now() - interval '30 days')
    AND (locked_until IS NULL OR locked_until < now());

  RETURN jsonb_build_object(
    'notificationsDeleted', v_notifs,
    'sessionChatsDeleted', v_session_chats,
    'reportsDeleted', v_reports,
    'auditLogsDeleted', v_audits,
    'retainedContentDeleted', v_retained,
    'otpLogsDeleted', v_otp
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. Daftarkan Jadwal pg_cron (jika ekstensi tersedia)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
    CREATE EXTENSION IF NOT EXISTS pg_cron;

    IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
      PERFORM cron.unschedule(jobname)
      FROM cron.job
      WHERE jobname IN (
        'horas-session-lifecycle',
        'horas-expiry-jobs',
        'horas-account-purge',
        'horas-retention-cleanup'
      );

      PERFORM cron.schedule('horas-session-lifecycle', '*/15 * * * *', $cron$SELECT public.run_session_lifecycle_jobs();$cron$);
      PERFORM cron.schedule('horas-expiry-jobs', '0 * * * *', $cron$SELECT public.run_expiry_jobs();$cron$);
      PERFORM cron.schedule('horas-account-purge', '15 2 * * *', $cron$SELECT public.run_account_purge_jobs();$cron$);
      PERFORM cron.schedule('horas-retention-cleanup', '30 3 * * *', $cron$SELECT public.run_retention_cleanup_jobs();$cron$);
    END IF;
  END IF;
END $$;
