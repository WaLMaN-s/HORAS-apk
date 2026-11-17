-- 0008_phase_2.sql: Skema, RLS, dan RPC untuk Fitur Fase 2
-- Modul: Story 24 Jam, Kegiatan + RSVP, Direktori Gereja, Kamus Partuturan, Video, Voice Note, Stiker

-- 1. Kolom tambahan pada tabel yang sudah ada
ALTER TABLE public.post_media ADD COLUMN IF NOT EXISTS is_video BOOLEAN DEFAULT FALSE;
ALTER TABLE public.post_media ADD COLUMN IF NOT EXISTS duration_seconds INTEGER DEFAULT 0;

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS voice_note_seed TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS voice_note_duration_seconds INTEGER;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS sticker_seed TEXT;

ALTER TABLE public.play_sessions ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE;
ALTER TABLE public.play_sessions ADD COLUMN IF NOT EXISTS recurring_interval TEXT;

ALTER TABLE public.courts ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.courts ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 2. Cerita 24 Jam (BER-02, BER-03, BER-R12)
CREATE TABLE IF NOT EXISTS public.stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  media_seed TEXT NOT NULL,
  caption TEXT DEFAULT '',
  is_video BOOLEAN DEFAULT FALSE,
  duration_seconds INTEGER DEFAULT 5,
  viewer_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_stories_author_expires ON public.stories(author_id, expires_at);

CREATE TABLE IF NOT EXISTS public.story_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(story_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS idx_story_views_story ON public.story_views(story_id);

-- RLS Stories (BER-R12: hanya untuk pengikut, daftar penonton hanya terlihat pembuat)
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Stories dapat dilihat pembuat dan pengikut aktif"
  ON public.stories FOR SELECT
  USING (
    author_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.follows
      WHERE follower_id = auth.uid() AND following_id = author_id
    )
  );

CREATE POLICY "Pemilik dapat membuat story"
  ON public.stories FOR INSERT
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "Pemilik dapat menghapus story sendiri"
  ON public.stories FOR DELETE
  USING (author_id = auth.uid());

CREATE POLICY "Daftar penonton hanya dapat dilihat pembuat story (BER-R12)"
  ON public.story_views FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.stories s
      WHERE s.id = story_id AND s.author_id = auth.uid()
    )
  );

CREATE POLICY "Pengguna dapat mencatat riwayat tonton story"
  ON public.story_views FOR INSERT
  WITH CHECK (viewer_id = auth.uid());

-- 3. Direktori Gereja (SEK-10, SEK-11, SEK-R13)
CREATE TABLE IF NOT EXISTS public.churches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  denomination TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  service_schedules JSONB DEFAULT '[]'::jsonb,
  contact_phone TEXT DEFAULT '',
  contact_email TEXT DEFAULT '',
  is_verified BOOLEAN DEFAULT FALSE,
  member_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_churches_city_denom ON public.churches(city, denomination);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_church_id UUID REFERENCES public.churches(id) ON DELETE SET NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_home_church_visible BOOLEAN DEFAULT FALSE;

ALTER TABLE public.churches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Direktori gereja dapat dibaca publik"
  ON public.churches FOR SELECT
  USING (true);

CREATE POLICY "Pengguna terautentikasi dapat mengusulkan gereja"
  ON public.churches FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- 4. Kegiatan Komunitas & Gereja (SEK-09, SEK-R12)
CREATE TABLE IF NOT EXISTS public.community_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  location_name TEXT NOT NULL,
  map_link TEXT,
  capacity INTEGER,
  attendee_count INTEGER DEFAULT 0,
  is_cancelled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_community_events_comm ON public.community_events(community_id, start_time);

CREATE TABLE IF NOT EXISTS public.event_rsvps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.community_events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('none', 'hadir', 'mungkin', 'tidak')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_rsvps_event ON public.event_rsvps(event_id);

ALTER TABLE public.community_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_rsvps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anggota dan publik dapat melihat kegiatan komunitas terbuka"
  ON public.community_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.communities c
      WHERE c.id = community_id AND (
        c.access_type = 'open' OR
        EXISTS (
          SELECT 1 FROM public.community_members cm
          WHERE cm.community_id = c.id AND cm.user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "Pengurus dapat membuat kegiatan komunitas"
  ON public.community_events FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.community_members cm
      WHERE cm.community_id = community_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'manager')
    )
  );

CREATE POLICY "Pengurus dapat memperbarui atau membatalkan kegiatan"
  ON public.community_events FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.community_members cm
      WHERE cm.community_id = community_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'manager')
    )
  );

CREATE POLICY "RSVP kegiatan dapat dilihat peserta dan pengurus"
  ON public.event_rsvps FOR SELECT
  USING (true);

CREATE POLICY "Pengguna dapat mengelola RSVP sendiri"
  ON public.event_rsvps FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 5. Kamus Partuturan Multi Sub-Suku (TAR-08, TAR-R6)
CREATE TABLE IF NOT EXISTS public.partuturan_dictionary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  term TEXT NOT NULL,
  meaning TEXT NOT NULL,
  example TEXT NOT NULL,
  sub_ethnic TEXT NOT NULL,
  category TEXT DEFAULT 'Umum',
  status TEXT DEFAULT 'active',
  is_validated BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_partuturan_dict_sub ON public.partuturan_dictionary(sub_ethnic, term);

ALTER TABLE public.partuturan_dictionary ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Kamus partuturan dapat dibaca publik"
  ON public.partuturan_dictionary FOR SELECT
  USING (true);
