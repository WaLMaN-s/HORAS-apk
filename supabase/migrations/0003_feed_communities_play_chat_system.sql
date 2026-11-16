-- =============================================================================
-- 0003_feed_communities_play_chat_system.sql
-- Komunitas, Beranda (posts, post_media, comments, likes, saved_posts),
-- Main/Olahraga (play_sessions, participants, waitlist, reliability_marks),
-- Pesan & Realtime (conversations, messages, message_requests),
-- Notifikasi, Moderasi & Keamanan, Layanan Akun, dan Help Articles.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Komunitas (SEK, KOM) & Percakapan Induk
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type public.conversation_type NOT NULL DEFAULT 'direct',
  title text NOT NULL DEFAULT '',
  community_id uuid,
  session_id uuid,
  is_read_only boolean NOT NULL DEFAULT false,
  last_message_preview text NOT NULL DEFAULT '',
  last_message_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.communities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type public.community_type NOT NULL DEFAULT 'minat',
  access_type public.community_access_type NOT NULL DEFAULT 'open',
  city text NOT NULL DEFAULT '',
  marga_name text,
  description text NOT NULL DEFAULT '',
  rules_text text NOT NULL DEFAULT '',
  avatar_seed text NOT NULL DEFAULT '',
  avatar_path text,
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  member_count integer NOT NULL DEFAULT 1,
  is_verified boolean NOT NULL DEFAULT false,
  is_inactive_flagged boolean NOT NULL DEFAULT false,
  conversation_id uuid UNIQUE REFERENCES public.conversations(id) ON DELETE SET NULL,
  last_manager_active_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_communities_access_city ON public.communities(access_type, city);
CREATE INDEX IF NOT EXISTS idx_communities_owner ON public.communities(owner_id);
CREATE INDEX IF NOT EXISTS idx_communities_name_trgm ON public.communities USING gin (name gin_trgm_ops);

DROP TRIGGER IF EXISTS trg_communities_updated_at ON public.communities;
CREATE TRIGGER trg_communities_updated_at
  BEFORE UPDATE ON public.communities
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS public.community_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role public.community_role NOT NULL DEFAULT 'member',
  joined_at timestamptz NOT NULL DEFAULT now(),
  last_active_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (community_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_comm_memberships_user ON public.community_memberships(user_id);

CREATE TABLE IF NOT EXISTS public.community_join_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  note text NOT NULL DEFAULT '',
  status public.join_request_status NOT NULL DEFAULT 'pending',
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  responded_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_comm_join_pending
  ON public.community_join_requests(community_id, user_id)
  WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS public.community_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL,
  is_pinned boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comm_announcements_comm ON public.community_announcements(community_id, is_pinned DESC, created_at DESC);

DROP TRIGGER IF EXISTS trg_comm_announcements_updated_at ON public.community_announcements;
CREATE TRIGGER trg_comm_announcements_updated_at
  BEFORE UPDATE ON public.community_announcements
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Beranda: Postingan, Media (EXIF-stripped), Komentar, Suka, Tersimpan
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id uuid REFERENCES public.communities(id) ON DELETE CASCADE,
  text text NOT NULL DEFAULT '',
  visibility public.post_visibility NOT NULL DEFAULT 'publik',
  moderation_status public.post_moderation_status NOT NULL DEFAULT 'published',
  like_count integer NOT NULL DEFAULT 0,
  comment_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_posts_text_len CHECK (char_length(text) <= 2000)
);

CREATE INDEX IF NOT EXISTS idx_posts_feed ON public.posts(moderation_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_author_time ON public.posts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_community_time ON public.posts(community_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_posts_updated_at ON public.posts;
CREATE TRIGGER trg_posts_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS public.post_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  mime_type text NOT NULL DEFAULT 'image/jpeg',
  width integer,
  height integer,
  size_bytes integer NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  exif_stripped boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_post_media_post ON public.post_media(post_id, sort_order);

CREATE TABLE IF NOT EXISTS public.comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  parent_comment_id uuid REFERENCES public.comments(id) ON DELETE CASCADE,
  text text NOT NULL,
  is_removed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_comments_text_len CHECK (char_length(btrim(text)) BETWEEN 1 AND 1000)
);

CREATE INDEX IF NOT EXISTS idx_comments_post_time ON public.comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_comments_author_time ON public.comments(author_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_likes_user ON public.likes(user_id);

CREATE TABLE IF NOT EXISTS public.saved_posts (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

-- ---------------------------------------------------------------------------
-- 3. Main Olahraga & Catatan Keandalan (AC-08, AC-09, PRD 15.3)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.play_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id uuid REFERENCES public.communities(id) ON DELETE SET NULL,
  court_id uuid REFERENCES public.courts(id) ON DELETE RESTRICT,
  conversation_id uuid UNIQUE REFERENCES public.conversations(id) ON DELETE SET NULL,
  title text NOT NULL,
  sport public.sport_type NOT NULL,
  skill_level public.skill_level NOT NULL DEFAULT 'santai',
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  max_slots integer NOT NULL CHECK (max_slots BETWEEN 2 AND 50),
  fee_per_person_rupiah integer NOT NULL DEFAULT 0 CHECK (fee_per_person_rupiah BETWEEN 0 AND 1000000),
  notes text NOT NULL DEFAULT '' CHECK (char_length(notes) <= 300),
  visibility public.session_visibility NOT NULL DEFAULT 'terbuka',
  join_mode public.session_join_mode NOT NULL DEFAULT 'langsung_masuk',
  status public.session_status NOT NULL DEFAULT 'terjadwal',
  schedule_updated_at timestamptz,
  completed_at timestamptz,
  chat_read_only_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_sessions_end_after_start CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_sessions_status_start ON public.play_sessions(status, start_time);
CREATE INDEX IF NOT EXISTS idx_sessions_host_status ON public.play_sessions(host_id, status);

DROP TRIGGER IF EXISTS trg_play_sessions_updated_at ON public.play_sessions;
CREATE TRIGGER trg_play_sessions_updated_at
  BEFORE UPDATE ON public.play_sessions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS public.session_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.play_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status public.participant_status NOT NULL DEFAULT 'joined',
  joined_at timestamptz NOT NULL DEFAULT now(),
  promoted_from_waitlist_at timestamptz,
  left_at timestamptz,
  UNIQUE (session_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_session_participants_session ON public.session_participants(session_id, status);

CREATE TABLE IF NOT EXISTS public.session_waitlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.play_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  queued_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_session_waitlist_fifo ON public.session_waitlist(session_id, queued_at ASC);

CREATE TABLE IF NOT EXISTS public.session_payment_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.play_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount_rupiah integer NOT NULL DEFAULT 0 CHECK (amount_rupiah >= 0 AND amount_rupiah <= 1000000),
  is_paid boolean NOT NULL DEFAULT false,
  marked_paid_at timestamptz,
  marked_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  UNIQUE (session_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.reliability_marks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.play_sessions(id) ON DELETE CASCADE,
  reason public.reliability_reason NOT NULL,
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reliability_marks_user_time ON public.reliability_marks(user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 4. Pesan & Permintaan Pesan (PSN-R1..R10, Realtime)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversation_participants (
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  unread_count integer NOT NULL DEFAULT 0,
  muted_until timestamptz,
  last_read_at timestamptz,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_participants_user ON public.conversation_participants(user_id);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  sender_fallback_label text NOT NULL DEFAULT 'Pengguna terhapus',
  text text NOT NULL DEFAULT '',
  attachment_path text,
  attachment_bytes integer CHECK (attachment_bytes IS NULL OR (attachment_bytes > 0 AND attachment_bytes <= 5242880)),
  reply_to_message_id uuid REFERENCES public.messages(id) ON DELETE SET NULL,
  deleted_for_everyone boolean NOT NULL DEFAULT false,
  deleted_for_everyone_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_messages_text_len CHECK (char_length(text) <= 2000)
);

CREATE INDEX IF NOT EXISTS idx_messages_conv_time ON public.messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_time ON public.messages(sender_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.message_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  first_message_id uuid REFERENCES public.messages(id) ON DELETE SET NULL,
  status public.message_request_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  UNIQUE (sender_id, recipient_id)
);

CREATE INDEX IF NOT EXISTS idx_msg_requests_recipient ON public.message_requests(recipient_id, status);
CREATE INDEX IF NOT EXISTS idx_msg_requests_sender_time ON public.message_requests(sender_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 5. Notifikasi & Preferensi (PRD 9, 90 hari retensi)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type public.notification_type NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  action_route text,
  deliver_after timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_time ON public.notifications(user_id, is_read, created_at DESC);

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  sosial_enabled boolean NOT NULL DEFAULT true,
  komunitas_enabled boolean NOT NULL DEFAULT true,
  main_olahraga_enabled boolean NOT NULL DEFAULT true,
  pesan_enabled boolean NOT NULL DEFAULT true,
  quiet_hours_start integer NOT NULL DEFAULT 22,
  quiet_hours_end integer NOT NULL DEFAULT 6,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 6. Laporan, Retensi Moderasi (30 hari), Strike (90 hari), Banding (14 hari),
--    Verifikasi, Support, Pemulihan Akun, Ekspor Data (48h/7d), Hapus Akun (30d)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_type public.report_target_type NOT NULL,
  target_id text NOT NULL,
  category public.report_category NOT NULL,
  note text NOT NULL DEFAULT '' CHECK (char_length(note) <= 500),
  status public.report_status NOT NULL DEFAULT 'queued',
  assigned_moderator_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_note text,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reports_reporter_time ON public.reports(reporter_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_status_time ON public.reports(status, created_at ASC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_reports_active_per_target
  ON public.reports(reporter_id, target_type, target_id)
  WHERE status IN ('queued', 'in_review');

-- Salinan pesan/postingan terlapor disimpan maks 30 hari (PRD 10)
CREATE TABLE IF NOT EXISTS public.retained_moderated_content (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  target_type public.report_target_type NOT NULL,
  target_id text NOT NULL,
  snapshot_json jsonb NOT NULL,
  retain_until timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_retained_content_until ON public.retained_moderated_content(retain_until);

CREATE TABLE IF NOT EXISTS public.strikes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason text NOT NULL,
  report_id uuid REFERENCES public.reports(id) ON DELETE SET NULL,
  issued_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '90 days'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_strikes_user_time ON public.strikes(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.appeals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  strike_id uuid NOT NULL REFERENCES public.strikes(id) ON DELETE CASCADE,
  reason text NOT NULL,
  status public.appeal_status NOT NULL DEFAULT 'submitted',
  reviewer_note text,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_appeals_user ON public.appeals(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.verification_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_path text NOT NULL DEFAULT '',
  organization_name text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  status public.verification_status NOT NULL DEFAULT 'pending',
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verif_requests_comm ON public.verification_requests(community_id, status);

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category text NOT NULL,
  subject text NOT NULL,
  message text NOT NULL,
  status public.support_ticket_status NOT NULL DEFAULT 'open',
  assigned_to uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON public.support_tickets(user_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_support_tickets_updated_at ON public.support_tickets;
CREATE TRIGGER trg_support_tickets_updated_at
  BEFORE UPDATE ON public.support_tickets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS public.account_recovery_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  old_phone_e164 text NOT NULL,
  new_phone_e164 text NOT NULL,
  approximate_registration_period text NOT NULL,
  marga text NOT NULL,
  known_friends_text text NOT NULL,
  status public.recovery_status NOT NULL DEFAULT 'submitted',
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  review_note text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.data_export_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status public.export_job_status NOT NULL DEFAULT 'queued',
  download_path text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  ready_at timestamptz,
  expires_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_data_export_jobs_user_time ON public.data_export_jobs(user_id, requested_at DESC);

CREATE TABLE IF NOT EXISTS public.account_deletions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason text NOT NULL DEFAULT '',
  requested_at timestamptz NOT NULL DEFAULT now(),
  scheduled_permanent_deletion_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  is_cancelled boolean NOT NULL DEFAULT false,
  cancelled_at timestamptz,
  is_permanently_deleted boolean NOT NULL DEFAULT false,
  permanently_deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.help_articles (
  id text PRIMARY KEY,
  category text NOT NULL,
  question text NOT NULL,
  answer text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 7. Trigger counter & otomatis Notification Preferences
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_profile_notif_prefs()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_created_notif_prefs ON public.profiles;
CREATE TRIGGER on_profile_created_notif_prefs
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_profile_notif_prefs();

CREATE OR REPLACE FUNCTION public.sync_post_counters()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_TABLE_NAME = 'likes' THEN
    IF TG_OP = 'INSERT' THEN
      UPDATE public.posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
      UPDATE public.posts SET like_count = GREATEST(0, like_count - 1) WHERE id = OLD.post_id;
    END IF;
  ELSIF TG_TABLE_NAME = 'comments' THEN
    IF TG_OP = 'INSERT' THEN
      UPDATE public.posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
      UPDATE public.posts SET comment_count = GREATEST(0, comment_count - 1) WHERE id = OLD.post_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_likes_counters ON public.likes;
CREATE TRIGGER trg_likes_counters
  AFTER INSERT OR DELETE ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.sync_post_counters();

DROP TRIGGER IF EXISTS trg_comments_counters ON public.comments;
CREATE TRIGGER trg_comments_counters
  AFTER INSERT OR DELETE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.sync_post_counters();

CREATE OR REPLACE FUNCTION public.sync_community_member_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.communities SET member_count = (
      SELECT count(*)::int FROM public.community_memberships WHERE community_id = NEW.community_id
    ) WHERE id = NEW.community_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.communities SET member_count = (
      SELECT count(*)::int FROM public.community_memberships WHERE community_id = OLD.community_id
    ) WHERE id = OLD.community_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_comm_memberships_count ON public.community_memberships;
CREATE TRIGGER trg_comm_memberships_count
  AFTER INSERT OR DELETE ON public.community_memberships
  FOR EACH ROW EXECUTE FUNCTION public.sync_community_member_count();

-- ---------------------------------------------------------------------------
-- 8. Realtime publication untuk messages, notifications, conversations
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'conversations'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
    END IF;
  END IF;
END $$;
