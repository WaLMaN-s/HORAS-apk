-- =============================================================================
-- 0001_extensions_roles_and_references.sql
-- Ekstensi, enum domain HORAS, peran sistem (app_role), tabel referensi
-- (marga, wilayah, courts, partuturan_rulesets), dan audit_log.
-- Idempoten: aman dijalankan ulang.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------------
-- Helper pembuatan enum idempoten
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.app_role AS ENUM ('user', 'moderator', 'adat_reviewer', 'support', 'admin');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_gender' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.user_gender AS ENUM ('male', 'female');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sub_ethnic' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.sub_ethnic AS ENUM ('toba', 'karo', 'simalungun', 'pakpak', 'angkola', 'mandailing');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'account_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.account_status AS ENUM ('active', 'restricted', 'suspended', 'permanently_banned');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'field_visibility' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.field_visibility AS ENUM ('everyone', 'connected_only', 'only_me');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'connection_allowance' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.connection_allowance AS ENUM ('everyone', 'same_community', 'no_one');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'account_visibility_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.account_visibility_type AS ENUM ('public_account', 'private_account');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'family_relation_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.family_relation_type AS ENUM ('ayah', 'ibu', 'opung_suhut', 'opung_bao', 'saudara_kandung', 'anak');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'life_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.life_status AS ENUM ('hidup', 'almarhum');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'partuturan_claim_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.partuturan_claim_status AS ENUM ('pending', 'confirmed', 'rejected');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'partuturan_confidence' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.partuturan_confidence AS ENUM ('tinggi', 'sedang', 'rendah');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'post_visibility' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.post_visibility AS ENUM ('publik', 'komunitas', 'kenalan');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'post_moderation_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.post_moderation_status AS ENUM ('published', 'under_review', 'removed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'community_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.community_type AS ENUM ('punguan_marga', 'kota', 'kampus_profesi', 'minat');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'community_access_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.community_access_type AS ENUM ('open', 'approval_required', 'closed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'community_role' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.community_role AS ENUM ('owner', 'manager', 'member');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'join_request_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.join_request_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sport_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.sport_type AS ENUM ('badminton', 'futsal', 'basket', 'voli', 'tenis_meja', 'jogging', 'lainnya');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'skill_level' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.skill_level AS ENUM ('pemula', 'menengah', 'mahir', 'santai');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'session_visibility' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.session_visibility AS ENUM ('terbuka', 'komunitas', 'kenalan');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'session_join_mode' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.session_join_mode AS ENUM ('langsung_masuk', 'persetujuan_host');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'session_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.session_status AS ENUM ('terjadwal', 'berlangsung', 'selesai', 'dibatalkan');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'participant_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.participant_status AS ENUM ('joined', 'waitlisted', 'left_before_start', 'no_show', 'pending_approval', 'rejected');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reliability_reason' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.reliability_reason AS ENUM ('late_leave', 'no_show');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'court_moderation_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.court_moderation_status AS ENUM ('approved', 'pending_review', 'rejected');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'conversation_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.conversation_type AS ENUM ('direct', 'community', 'session');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_request_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.message_request_status AS ENUM ('pending', 'accepted', 'declined');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.notification_type AS ENUM ('sosial', 'komunitas', 'main_olahraga', 'pesan', 'sistem_keamanan');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_target_type' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.report_target_type AS ENUM ('user', 'post', 'comment', 'message', 'community', 'session', 'court');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_category' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.report_category AS ENUM ('ujaran_kebencian_sara', 'pelecehan', 'penipuan_judi', 'spam_tautan', 'identitas_palsu', 'konten_tidak_pantas');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.report_status AS ENUM ('queued', 'in_review', 'resolved', 'dismissed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'appeal_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.appeal_status AS ENUM ('submitted', 'reviewing', 'accepted', 'rejected');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.verification_status AS ENUM ('pending', 'approved', 'rejected');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'export_job_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.export_job_status AS ENUM ('queued', 'processing', 'ready', 'failed', 'expired');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'support_ticket_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.support_ticket_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'recovery_status' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.recovery_status AS ENUM ('submitted', 'verifying', 'approved', 'rejected');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Fungsi utilitas standar updated_at
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Role pengguna (user, moderator, adat_reviewer, support, admin)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_roles (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  assigned_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_role ON public.user_roles(role);

-- ---------------------------------------------------------------------------
-- Tabel referensi marga baku (AUT-R6)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.marga (
  id text PRIMARY KEY,
  name text NOT NULL UNIQUE,
  sub_ethnic public.sub_ethnic NOT NULL,
  is_verified boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marga_sub_ethnic ON public.marga(sub_ethnic);

-- ---------------------------------------------------------------------------
-- Tabel referensi wilayah kota & kecamatan (assets/data/wilayah.json)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.wilayah (
  id text PRIMARY KEY,
  name text NOT NULL,
  province text NOT NULL,
  subdistricts text[] NOT NULL DEFAULT '{}'::text[],
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wilayah_name ON public.wilayah(name);

-- ---------------------------------------------------------------------------
-- Tabel referensi lapangan olahraga (MAN)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.courts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address text NOT NULL,
  city text NOT NULL,
  supported_sports public.sport_type[] NOT NULL DEFAULT '{}'::public.sport_type[],
  estimated_price_text text NOT NULL DEFAULT '',
  opening_hours text NOT NULL DEFAULT '',
  image_seed text NOT NULL DEFAULT '',
  photo_path text,
  moderation_status public.court_moderation_status NOT NULL DEFAULT 'approved',
  suggested_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_courts_city_status ON public.courts(city, moderation_status);

DROP TRIGGER IF EXISTS trg_courts_updated_at ON public.courts;
CREATE TRIGGER trg_courts_updated_at
  BEFORE UPDATE ON public.courts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Aturan Partuturan berversi (TAR-R6, PRD 15.3)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.partuturan_rulesets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sub_ethnic public.sub_ethnic NOT NULL,
  version text NOT NULL,
  validated boolean NOT NULL DEFAULT false,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  rules_json jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sub_ethnic, version)
);

CREATE INDEX IF NOT EXISTS idx_partuturan_rulesets_active ON public.partuturan_rulesets(sub_ethnic, is_active);

DROP TRIGGER IF EXISTS trg_partuturan_rulesets_updated_at ON public.partuturan_rulesets;
CREATE TRIGGER trg_partuturan_rulesets_updated_at
  BEFORE UPDATE ON public.partuturan_rulesets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Audit log tindakan admin/moderator/reviewer (PRD 10: retensi 12 bulan)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_role public.app_role NOT NULL DEFAULT 'user',
  action text NOT NULL,
  target_type text NOT NULL,
  target_id text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON public.audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON public.audit_log(actor_id, created_at DESC);
