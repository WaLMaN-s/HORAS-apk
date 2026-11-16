-- =============================================================================
-- 0002_core_profiles_social_tarombo.sql
-- Profil pengguna, pengaturan privasi, perangkat aktif (AUT-R9), OTP guard state,
-- jejaring sosial (follows, connection_requests, connections, blocks),
-- serta Tarombo & Partuturan claims/feedback (PRD 15.3).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Profil utama (phone_e164 & birth_year TIDAK PERNAH diekspos ke pengguna lain)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_e164 text UNIQUE,
  display_name text NOT NULL DEFAULT '',
  gender public.user_gender NOT NULL DEFAULT 'male',
  birth_year integer NOT NULL DEFAULT 1998,
  marga text NOT NULL DEFAULT '',
  is_custom_marga boolean NOT NULL DEFAULT false,
  sub_ethnic public.sub_ethnic NOT NULL DEFAULT 'toba',
  mother_marga text,
  city text NOT NULL DEFAULT '',
  subdistrict text NOT NULL DEFAULT '',
  sundut integer,
  home_church text,
  bio text NOT NULL DEFAULT '',
  hobbies text[] NOT NULL DEFAULT '{}'::text[],
  campus_or_office text,
  website_url text,
  avatar_seed text NOT NULL DEFAULT '',
  avatar_path text,
  account_status public.account_status NOT NULL DEFAULT 'active',
  suspended_until timestamptz,
  restricted_until timestamptz,
  display_name_changed_at timestamptz,
  followers_count integer NOT NULL DEFAULT 0,
  following_count integer NOT NULL DEFAULT 0,
  connections_count integer NOT NULL DEFAULT 0,
  onboarding_completed boolean NOT NULL DEFAULT false,
  legal_consent jsonb,
  onboarding_draft jsonb,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_profiles_bio_len CHECK (char_length(bio) <= 150),
  CONSTRAINT chk_profiles_birth_year CHECK (
    birth_year >= (EXTRACT(YEAR FROM now())::int - 110)
    AND birth_year <= (EXTRACT(YEAR FROM now())::int - 17)
  ),
  CONSTRAINT chk_profiles_display_name_onboarded CHECK (
    NOT onboarding_completed OR (char_length(btrim(display_name)) BETWEEN 2 AND 40)
  )
);

CREATE INDEX IF NOT EXISTS idx_profiles_city_subdistrict ON public.profiles(city, subdistrict);
CREATE INDEX IF NOT EXISTS idx_profiles_marga_subethnic ON public.profiles(marga, sub_ethnic);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_profiles_display_name_trgm ON public.profiles USING gin (display_name gin_trgm_ops);

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Pengaturan Privasi (PRD 7.1 strict defaults)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_privacy_settings (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  mother_marga public.field_visibility NOT NULL DEFAULT 'connected_only',
  show_age_group boolean NOT NULL DEFAULT false,
  subdistrict public.field_visibility NOT NULL DEFAULT 'connected_only',
  joined_communities public.field_visibility NOT NULL DEFAULT 'connected_only',
  home_church public.field_visibility NOT NULL DEFAULT 'only_me',
  tarombo public.field_visibility NOT NULL DEFAULT 'only_me',
  discoverable_in_nearby_and_search boolean NOT NULL DEFAULT true,
  who_can_send_connection_request public.connection_allowance NOT NULL DEFAULT 'everyone',
  allow_messages_from_shared_context boolean NOT NULL DEFAULT true,
  send_read_receipts boolean NOT NULL DEFAULT true,
  account_type public.account_visibility_type NOT NULL DEFAULT 'public_account',
  updated_at timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_user_privacy_settings_updated_at ON public.user_privacy_settings;
CREATE TRIGGER trg_user_privacy_settings_updated_at
  BEFORE UPDATE ON public.user_privacy_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Perangkat Aktif (AUT-R9: maks 3) & Riwayat Masuk (AKN-R4)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_key text NOT NULL,
  device_name text NOT NULL,
  platform text NOT NULL DEFAULT 'android',
  logged_in_at timestamptz NOT NULL DEFAULT now(),
  last_active_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  UNIQUE (user_id, device_key)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_active ON public.user_devices(user_id, logged_in_at)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS public.login_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id uuid REFERENCES public.user_devices(id) ON DELETE SET NULL,
  device_name text NOT NULL,
  platform text NOT NULL DEFAULT 'android',
  city_label text NOT NULL DEFAULT '',
  logged_in_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_login_history_user ON public.login_history(user_id, logged_in_at DESC);

-- ---------------------------------------------------------------------------
-- 4. State OTP Guard (AUT-R2 & AUT-R3, hanya diakses service_role/Edge Function)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.otp_security_state (
  phone_e164 text PRIMARY KEY,
  wrong_attempts integer NOT NULL DEFAULT 0,
  locked_until timestamptz,
  last_requested_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.otp_request_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_e164 text NOT NULL,
  action text NOT NULL CHECK (action IN ('send', 'verify_ok', 'verify_fail', 'locked')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_request_logs_phone_time
  ON public.otp_request_logs(phone_e164, created_at DESC);

-- ---------------------------------------------------------------------------
-- 5. Mengikuti (200/hari), Kenalan (10/hari, 30d expiry & cooldown), Blokir
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.follows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  followee_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_follows_not_self CHECK (follower_id <> followee_id),
  CONSTRAINT uq_follows_pair UNIQUE (follower_id, followee_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower_time ON public.follows(follower_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_follows_followee ON public.follows(followee_id);

CREATE TABLE IF NOT EXISTS public.connection_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  intro_message text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected', 'expired', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  responded_at timestamptz,
  CONSTRAINT chk_conn_req_not_self CHECK (requester_id <> recipient_id),
  CONSTRAINT chk_conn_req_intro_len CHECK (char_length(intro_message) <= 200)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_conn_req_pending
  ON public.connection_requests(requester_id, recipient_id)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_conn_req_requester_time
  ON public.connection_requests(requester_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conn_req_recipient_status
  ON public.connection_requests(recipient_id, status);

CREATE TABLE IF NOT EXISTS public.connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  connected_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_connections_order CHECK (user_a < user_b),
  CONSTRAINT uq_connections_pair UNIQUE (user_a, user_b)
);

CREATE INDEX IF NOT EXISTS idx_connections_user_b ON public.connections(user_b);

CREATE TABLE IF NOT EXISTS public.blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_blocks_not_self CHECK (blocker_id <> blocked_id),
  CONSTRAINT uq_blocks_pair UNIQUE (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON public.blocks(blocked_id);

-- ---------------------------------------------------------------------------
-- 6. Tarombo & Klaim Partuturan (PRD 15.3)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.family_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  relation public.family_relation_type NOT NULL,
  name text NOT NULL,
  marga text NOT NULL DEFAULT '',
  birth_year integer,
  life_status public.life_status NOT NULL DEFAULT 'hidup',
  linked_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_family_members_owner ON public.family_members(owner_id);

DROP TRIGGER IF EXISTS trg_family_members_updated_at ON public.family_members;
CREATE TRIGGER trg_family_members_updated_at
  BEFORE UPDATE ON public.family_members
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS public.partuturan_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  claimed_istilah text NOT NULL,
  generation_delta integer,
  lineage_note text NOT NULL DEFAULT '',
  status public.partuturan_claim_status NOT NULL DEFAULT 'pending',
  confirmed_at timestamptz,
  rejected_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_partuturan_claim_not_self CHECK (proposer_id <> target_id)
);

CREATE INDEX IF NOT EXISTS idx_partuturan_claims_pair
  ON public.partuturan_claims(proposer_id, target_id, status);
CREATE INDEX IF NOT EXISTS idx_partuturan_claims_target
  ON public.partuturan_claims(target_id, status);

DROP TRIGGER IF EXISTS trg_partuturan_claims_updated_at ON public.partuturan_claims;
CREATE TRIGGER trg_partuturan_claims_updated_at
  BEFORE UPDATE ON public.partuturan_claims
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS public.partuturan_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  suggested_istilah text NOT NULL,
  is_accurate boolean NOT NULL DEFAULT false,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partuturan_feedback_target ON public.partuturan_feedback(target_id);

-- ---------------------------------------------------------------------------
-- 7. Trigger otomatis saat auth user & profile dibuat, dan counter sosial
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, phone_e164, avatar_seed)
  VALUES (
    NEW.id,
    NULLIF(NEW.phone, ''),
    'avatar-' || substring(NEW.id::text FROM 1 FOR 8)
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'user')
  ON CONFLICT (user_id, role) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

CREATE OR REPLACE FUNCTION public.handle_new_profile_defaults()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_privacy_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_created_defaults ON public.profiles;
CREATE TRIGGER on_profile_created_defaults
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_profile_defaults();

-- Counter trigger untuk follows
CREATE OR REPLACE FUNCTION public.sync_follow_counters()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
    UPDATE public.profiles SET followers_count = followers_count + 1 WHERE id = NEW.followee_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET following_count = GREATEST(0, following_count - 1) WHERE id = OLD.follower_id;
    UPDATE public.profiles SET followers_count = GREATEST(0, followers_count - 1) WHERE id = OLD.followee_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_follows_counters ON public.follows;
CREATE TRIGGER trg_follows_counters
  AFTER INSERT OR DELETE ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.sync_follow_counters();

-- Counter trigger untuk connections
CREATE OR REPLACE FUNCTION public.sync_connection_counters()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles SET connections_count = connections_count + 1 WHERE id IN (NEW.user_a, NEW.user_b);
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles SET connections_count = GREATEST(0, connections_count - 1) WHERE id IN (OLD.user_a, OLD.user_b);
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_connections_counters ON public.connections;
CREATE TRIGGER trg_connections_counters
  AFTER INSERT OR DELETE ON public.connections
  FOR EACH ROW EXECUTE FUNCTION public.sync_connection_counters();
