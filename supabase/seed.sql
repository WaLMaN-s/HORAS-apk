-- =============================================================================
-- supabase/seed.sql
-- Benih data HORAS: 43 wilayah, 65 marga, ruleset Partuturan Toba v0, 5 artikel FAQ,
-- 10 lapangan, 12 pengguna sampel (+ auth.users & identitas HP uji), 10 komunitas
-- (termasuk com-10 closed untuk uji AC-13), postingan, sesi Main, & jejaring sosial.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. 43 Wilayah Kota & Kecamatan (assets/data/wilayah.json)
-- ---------------------------------------------------------------------------
INSERT INTO public.wilayah (id, name, province, subdistricts) VALUES
  ('mdn', 'Medan', 'Sumatera Utara', ARRAY['Medan Baru', 'Medan Selayang', 'Medan Helvetia', 'Medan Sunggal', 'Medan Denai', 'Medan Tuntungan', 'Medan Kota', 'Medan Perjuangan']),
  ('pms', 'Pematangsiantar', 'Sumatera Utara', ARRAY['Siantar Timur', 'Siantar Barat', 'Siantar Utara', 'Siantar Selatan', 'Siantar Marihat', 'Siantar Sitalasari']),
  ('blg', 'Balige', 'Sumatera Utara', ARRAY['Balige', 'Laguboti', 'Soposurung', 'Porsea', 'Sigumpar']),
  ('trt', 'Tarutung', 'Sumatera Utara', ARRAY['Tarutung', 'Sipoholon', 'Siatas Barita', 'Siborongborong', 'Pahae Julu']),
  ('sdk', 'Sidikalang', 'Sumatera Utara', ARRAY['Sidikalang', 'Sitinjo', 'Parbuluan', 'Sumbul', 'Silima Pungga-Pungga']),
  ('kbj', 'Kabanjahe', 'Sumatera Utara', ARRAY['Kabanjahe', 'Berastagi', 'Tigapanah', 'Simpang Empat', 'Merek']),
  ('dls', 'Doloksanggul', 'Sumatera Utara', ARRAY['Doloksanggul', 'Lintong Nihuta', 'Pollung', 'Paranginan', 'Baktiraja']),
  ('pgr', 'Pangururan', 'Sumatera Utara', ARRAY['Pangururan', 'Simanindo', 'Nainggolan', 'Onan Runggu', 'Palipi']),
  ('rtp', 'Rantauprapat', 'Sumatera Utara', ARRAY['Rantau Utara', 'Rantau Selatan', 'Bilah Barat', 'Bilah Hulu']),
  ('psp', 'Padangsidimpuan', 'Sumatera Utara', ARRAY['Padangsidimpuan Utara', 'Padangsidimpuan Selatan', 'Padangsidimpuan Tenggara']),
  ('sbg', 'Sibolga', 'Sumatera Utara', ARRAY['Sibolga Kota', 'Sibolga Utara', 'Sibolga Selatan', 'Pandan']),
  ('bnj', 'Binjai', 'Sumatera Utara', ARRAY['Binjai Kota', 'Binjai Timur', 'Binjai Utara', 'Binjai Selatan']),
  ('tbt', 'Tebing Tinggi', 'Sumatera Utara', ARRAY['Tebing Tinggi Kota', 'Rambutan', 'Padang Hulu', 'Bajenis']),
  ('lbp', 'Lubuk Pakam', 'Sumatera Utara', ARRAY['Lubuk Pakam', 'Tanjung Morawa', 'Percut Sei Tuan', 'Pancur Batu']),
  ('gnt', 'Gunungtua', 'Sumatera Utara', ARRAY['Padang Bolak', 'Portibi', 'Halongonan']),
  ('kis', 'Kisaran', 'Sumatera Utara', ARRAY['Kisaran Barat', 'Kisaran Timur', 'Air Joman']),
  ('jkp', 'Jakarta Pusat', 'DKI Jakarta', ARRAY['Menteng', 'Cempaka Putih', 'Kemayoran', 'Senen', 'Tanah Abang']),
  ('jks', 'Jakarta Selatan', 'DKI Jakarta', ARRAY['Tebet', 'Pasar Minggu', 'Kebayoran Baru', 'Cilandak', 'Jagakarsa', 'Setiabudi']),
  ('jkt', 'Jakarta Timur', 'DKI Jakarta', ARRAY['Cawang', 'Kramat Jati', 'Duren Sawit', 'Pulo Gadung', 'Rawamangun', 'Matraman', 'Cipayung']),
  ('jkb', 'Jakarta Barat', 'DKI Jakarta', ARRAY['Grogol Petamburan', 'Kebon Jeruk', 'Palmerah', 'Cengkareng', 'Kalideres']),
  ('jku', 'Jakarta Utara', 'DKI Jakarta', ARRAY['Kelapa Gading', 'Tanjung Priok', 'Koja', 'Cilincing', 'Penjaringan']),
  ('bdg', 'Bandung', 'Jawa Barat', ARRAY['Coblong', 'Sukajadi', 'Buahbatu', 'Lengkong', 'Antapani', 'Cibeunying Kaler']),
  ('bks', 'Bekasi', 'Jawa Barat', ARRAY['Bekasi Selatan', 'Bekasi Barat', 'Bekasi Timur', 'Rawalumbu', 'Jatiasih', 'Pondok Gede']),
  ('dpk', 'Depok', 'Jawa Barat', ARRAY['Beji', 'Cimanggis', 'Sukmajaya', 'Pancoran Mas', 'Cinere']),
  ('bgr', 'Bogor', 'Jawa Barat', ARRAY['Bogor Tengah', 'Bogor Utara', 'Bogor Timur', 'Tanah Sareal', 'Cibinong']),
  ('tng', 'Tangerang', 'Banten', ARRAY['Karawaci', 'Ciledug', 'Cipondoh', 'Tangerang', 'Jatiuwung']),
  ('tgs', 'Tangerang Selatan', 'Banten', ARRAY['Serpong', 'Bintaro', 'Ciputat', 'Pamulang', 'Pondok Aren']),
  ('btm', 'Batam', 'Kepulauan Riau', ARRAY['Batam Kota', 'Batu Aji', 'Sagulung', 'Sekupang', 'Lubuk Baja', 'Nongsa']),
  ('tpi', 'Tanjungpinang', 'Kepulauan Riau', ARRAY['Tanjungpinang Barat', 'Tanjungpinang Timur', 'Bukit Bestari']),
  ('pkb', 'Pekanbaru', 'Riau', ARRAY['Tampan', 'Marpoyan Damai', 'Payung Sekaki', 'Sukajadi', 'Rumbai']),
  ('dmi', 'Dumai', 'Riau', ARRAY['Dumai Timur', 'Dumai Barat', 'Dumai Kota', 'Mandau']),
  ('pdg', 'Padang', 'Sumatera Barat', ARRAY['Padang Barat', 'Padang Utara', 'Kuranji']),
  ('plg', 'Palembang', 'Sumatera Selatan', ARRAY['Ilir Timur I', 'Ilir Barat I', 'Sukarami', 'Kemuning']),
  ('jmb', 'Jambi', 'Jambi', ARRAY['Kota Baru', 'Telanaipura', 'Jambi Selatan']),
  ('bdl', 'Bandar Lampung', 'Lampung', ARRAY['Rajabasa', 'Kedaton', 'Tanjung Karang Pusat', 'Sukarame']),
  ('sby', 'Surabaya', 'Jawa Timur', ARRAY['Gubeng', 'Wonokromo', 'Sukolilo', 'Rungkut', 'Tegalsari']),
  ('mlg', 'Malang', 'Jawa Timur', ARRAY['Lowokwaru', 'Klojen', 'Blimbing']),
  ('ygk', 'Yogyakarta', 'DI Yogyakarta', ARRAY['Depok Sleman', 'Gondokusuman', 'Mlati', 'Umbulharjo']),
  ('smg', 'Semarang', 'Jawa Tengah', ARRAY['Tembalang', 'Banyumanik', 'Semarang Tengah', 'Pedurungan']),
  ('dps', 'Denpasar', 'Bali', ARRAY['Denpasar Selatan', 'Denpasar Barat', 'Kuta']),
  ('bpn', 'Balikpapan', 'Kalimantan Timur', ARRAY['Balikpapan Selatan', 'Balikpapan Kota', 'Balikpapan Utara']),
  ('ptk', 'Pontianak', 'Kalimantan Barat', ARRAY['Pontianak Selatan', 'Pontianak Kota']),
  ('mks', 'Makassar', 'Sulawesi Selatan', ARRAY['Panakkukang', 'Rappocini', 'Tamalanrea'])
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. 65 Marga Baku (MockSeedData.standardMargas)
-- ---------------------------------------------------------------------------
INSERT INTO public.marga (id, name, sub_ethnic, is_verified) VALUES
  ('marga-01', 'Simanjuntak', 'toba', true),
  ('marga-02', 'Sitorus', 'toba', true),
  ('marga-03', 'Nainggolan', 'toba', true),
  ('marga-04', 'Siregar', 'toba', true),
  ('marga-05', 'Hutabarat', 'toba', true),
  ('marga-06', 'Panggabean', 'toba', true),
  ('marga-07', 'Sihombing', 'toba', true),
  ('marga-08', 'Silaban', 'toba', true),
  ('marga-09', 'Napitupulu', 'toba', true),
  ('marga-10', 'Tampubolon', 'toba', true),
  ('marga-11', 'Siahaan', 'toba', true),
  ('marga-12', 'Panjaitan', 'toba', true),
  ('marga-13', 'Marpaung', 'toba', true),
  ('marga-14', 'Pardede', 'toba', true),
  ('marga-15', 'Pasaribu', 'toba', true),
  ('marga-16', 'Sinaga', 'toba', true),
  ('marga-17', 'Situmorang', 'toba', true),
  ('marga-18', 'Manurung', 'toba', true),
  ('marga-19', 'Butarbutar', 'toba', true),
  ('marga-20', 'Aritonang', 'toba', true),
  ('marga-21', 'Rajagukguk', 'toba', true),
  ('marga-22', 'Gultom', 'toba', true),
  ('marga-23', 'Pakpahan', 'toba', true),
  ('marga-24', 'Samosir', 'toba', true),
  ('marga-25', 'Harianja', 'toba', true),
  ('marga-26', 'Lumbantobing', 'toba', true),
  ('marga-27', 'Hutagalung', 'toba', true),
  ('marga-28', 'Hutapea', 'toba', true),
  ('marga-29', 'Siburian', 'toba', true),
  ('marga-30', 'Nababan', 'toba', true),
  ('marga-31', 'Silalahi', 'toba', true),
  ('marga-32', 'Tambunan', 'toba', true),
  ('marga-33', 'Siagian', 'toba', true),
  ('marga-34', 'Silitonga', 'toba', true),
  ('marga-35', 'Manullang', 'toba', true),
  ('marga-36', 'Simamora', 'toba', true),
  ('marga-37', 'Sinurat', 'toba', true),
  ('marga-38', 'Ambarita', 'toba', true),
  ('marga-39', 'Turnip', 'toba', true),
  ('marga-40', 'Sitompul', 'toba', true),
  ('marga-41', 'Simatupang', 'toba', true),
  ('marga-42', 'Sibuea', 'toba', true),
  ('marga-43', 'Hutauruk', 'toba', true),
  ('marga-44', 'Tanjung', 'toba', true),
  ('marga-45', 'Bakkara', 'toba', true),
  ('marga-46', 'Parhusip', 'toba', true),
  ('marga-47', 'Lumbangaol', 'toba', true),
  ('marga-48', 'Sitinjak', 'toba', true),
  ('marga-49', 'Nadeak', 'toba', true),
  ('marga-50', 'Simbolon', 'toba', true),
  ('marga-51', 'Ginting', 'karo', true),
  ('marga-52', 'Sembiring', 'karo', true),
  ('marga-53', 'Tarigan', 'karo', true),
  ('marga-54', 'Karokaro', 'karo', true),
  ('marga-55', 'Peranginangin', 'karo', true),
  ('marga-56', 'Damanik', 'simalungun', true),
  ('marga-57', 'Saragih', 'simalungun', true),
  ('marga-58', 'Purba', 'simalungun', true),
  ('marga-59', 'Girsang', 'simalungun', true),
  ('marga-60', 'Bancin', 'pakpak', true),
  ('marga-61', 'Berutu', 'pakpak', true),
  ('marga-62', 'Padang', 'pakpak', true),
  ('marga-63', 'Harahap', 'angkola', true),
  ('marga-64', 'Siregar Baumi', 'angkola', true),
  ('marga-65', 'Nasution', 'mandailing', true),
  ('marga-66', 'Lubis', 'mandailing', true),
  ('marga-67', 'Pulungan', 'mandailing', true)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Ruleset Partuturan Toba v0 (assets/partuturan/toba.v0.json)
-- ---------------------------------------------------------------------------
INSERT INTO public.partuturan_rulesets (id, sub_ethnic, version, validated, reviewed_by, is_active, rules_json)
VALUES (
  '30000000-0000-4000-8000-000000000001',
  'toba',
  '0.1.0-draft',
  false,
  NULL,
  true,
  $${
    "version": "0.1.0-draft",
    "subSuku": "toba",
    "validated": false,
    "reviewedBy": null,
    "defaultLowExplanation": "Data silsilah atau marga ibu belum lengkap untuk menarik jalur partuturan secara pasti.",
    "defaultLowQuestion": "Apa marga ibu dan kira-kira berada di generasi (sundut) ke berapa dibanding dirimu?",
    "missingMotherMargaQuestion": "Lengkapi marga ibu pada profilmu agar jalur hula-hula/tulang dapat dihitung.",
    "missingGenerationQuestion": "Apakah beliau satu generasi di atasmu, sebaya (satu sundut), atau satu generasi di bawahmu?",
    "rules": [
      {
        "id": "toba-marga-ibu-atas-1-pria",
        "targetMargaRelation": "sameAsViewerMotherMarga",
        "viewerGender": "any",
        "targetGender": "male",
        "generationDelta": 1,
        "requireGenerationKnown": true,
        "istilah": "Tulang",
        "confidence": "sedang",
        "explanationTemplate": "Marga {targetMarga} sama dengan marga ibumu ({viewerMotherMarga}) dan berada satu generasi di atasmu (jalur hula-hula).",
        "followUpQuestion": "Apakah beliau saudara laki-laki kandung atau semarga segenerasi dengan ibumu?"
      },
      {
        "id": "toba-marga-ibu-atas-1-wanita",
        "targetMargaRelation": "sameAsViewerMotherMarga",
        "viewerGender": "any",
        "targetGender": "female",
        "generationDelta": 1,
        "requireGenerationKnown": true,
        "istilah": "Nantulang",
        "confidence": "sedang",
        "explanationTemplate": "Berada satu generasi di atasmu pada kelompok marga ibumu ({viewerMotherMarga}).",
        "followUpQuestion": "Apakah beliau terkait langsung dengan jalur marga ibumu?"
      },
      {
        "id": "toba-marga-ibu-sebaya-pria-ke-pria",
        "targetMargaRelation": "sameAsViewerMotherMarga",
        "viewerGender": "male",
        "targetGender": "male",
        "generationDelta": 0,
        "requireGenerationKnown": true,
        "istilah": "Lae",
        "confidence": "sedang",
        "explanationTemplate": "Marga {targetMarga} sama dengan marga ibumu ({viewerMotherMarga}) pada generasi yang sejajar.",
        "followUpQuestion": "Apakah ayah beliau adalah Tulangmu?"
      },
      {
        "id": "toba-marga-ibu-sebaya-pria-ke-wanita",
        "targetMargaRelation": "sameAsViewerMotherMarga",
        "viewerGender": "male",
        "targetGender": "female",
        "generationDelta": 0,
        "requireGenerationKnown": true,
        "istilah": "Pariban",
        "confidence": "sedang",
        "explanationTemplate": "Boru dari marga ibumu ({viewerMotherMarga}) pada generasi yang sejajar.",
        "followUpQuestion": "Apakah beliau putri dari Tulangmu (boru ni tulang)?"
      },
      {
        "id": "toba-semarga-atas-1-pria",
        "targetMargaRelation": "sameAsViewerMarga",
        "viewerGender": "any",
        "targetGender": "male",
        "generationDelta": 1,
        "requireGenerationKnown": true,
        "istilah": "Amangtua / Amanguda",
        "confidence": "sedang",
        "explanationTemplate": "Semarga ({viewerMarga}, dongan tubu) dan berada satu generasi (sundut) di atasmu.",
        "followUpQuestion": "Apakah garis kakek beliau lebih tua (Amangtua) atau lebih muda (Amanguda) dari garis ayahmu?"
      },
      {
        "id": "toba-semarga-sebaya-pria-pria",
        "targetMargaRelation": "sameAsViewerMarga",
        "viewerGender": "male",
        "targetGender": "male",
        "generationDelta": 0,
        "requireGenerationKnown": true,
        "istilah": "Haha / Anggi",
        "confidence": "sedang",
        "explanationTemplate": "Semarga ({viewerMarga}, dongan tubu) pada generasi yang sejajar.",
        "followUpQuestion": "Apakah jalur sundut beliau lebih tua (Abang/Haha) atau lebih muda (Anggi)?"
      },
      {
        "id": "toba-semarga-sebaya-wanita-wanita",
        "targetMargaRelation": "sameAsViewerMarga",
        "viewerGender": "female",
        "targetGender": "female",
        "generationDelta": 0,
        "requireGenerationKnown": true,
        "istilah": "Haha / Anggi Boru",
        "confidence": "sedang",
        "explanationTemplate": "Sama-sama boru {viewerMarga} pada generasi yang sejajar.",
        "followUpQuestion": "Apakah urutan keluarga beliau lebih tua atau lebih muda darimu?"
      },
      {
        "id": "toba-semarga-sebaya-beda-gender",
        "targetMargaRelation": "sameAsViewerMarga",
        "viewerGender": "any",
        "targetGender": "any",
        "generationDelta": 0,
        "requireGenerationKnown": true,
        "istilah": "Ito",
        "confidence": "sedang",
        "explanationTemplate": "Semarga ({viewerMarga}) antara laki-laki dan perempuan pada generasi yang sejajar.",
        "followUpQuestion": "Apakah kalian berada pada sundut yang sama dalam tarombo {viewerMarga}?"
      }
    ]
  }$$::jsonb
) ON CONFLICT (sub_ethnic, version) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. 5 Artikel Pusat Bantuan & FAQ (assets/data/bantuan.json)
-- ---------------------------------------------------------------------------
INSERT INTO public.help_articles (id, category, question, answer, sort_order) VALUES
  ('faq-01', 'Akun & Privasi', 'Mengapa marga, sub-suku, dan jenis kelamin saya terkunci?', 'Untuk menjaga keaslian data tarombo dan mencegah penyalahgunaan identitas marga, perubahan marga, sub-suku, atau jenis kelamin hanya diproses melalui menu Hubungi Dukungan.', 1),
  ('faq-02', 'Akun & Privasi', 'Apakah nomor HP atau jarak presisi saya terlihat orang lain?', 'Tidak pernah. HORAS tidak membagikan nomor HP, tahun lahir pasti, koordinat GPS, atau jarak kilometer presisi ke pengguna lain. Jarak hanya tampil dalam rentang umum seperti Di kotamu.', 2),
  ('faq-03', 'Tarombo & Partuturan', 'Mengapa beberapa panggilan bertuliskan ''Kemungkinan: ...''?', 'Hasil tingkat Sedang dihitung dari marga dan perkiraan generasi tanpa jalur keluarga terkonfirmasi, sehingga selalu diberi label Kemungkinan / Perkiraan. Keyakinan menjadi Tinggi setelah kedua pihak mengonfirmasi klaim kerabat.', 3),
  ('faq-04', 'Main & Patungan', 'Bagaimana aturan keluar mendadak atau daftar tunggu di Main?', 'Jika kamu naik dari daftar tunggu, kamu bebas keluar dalam 1 jam tanpa catatan keandalan. Keluar < 3 jam sebelum sesi atau tidak hadir menambah catatan; 3 catatan dalam 30 hari membatasi gabung sesi baru selama 7 hari.', 4),
  ('faq-05', 'Moderasi & Keamanan', 'Bagaimana cara melaporkan pelanggaran dan mengajukan banding?', 'Gunakan menu Laporkan pada profil, postingan, komentar, pesan, komunitas, sesi, atau lapangan. Identitas pelapor dirahasiakan. Jika terkena sanksi, banding dapat diajukan dalam 14 hari lewat Hubungi Dukungan.', 5)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Pengguna Sampel + Auth Users (u-01 .. u-12)
-- ---------------------------------------------------------------------------
INSERT INTO auth.users (
  id, instance_id, aud, role, phone, phone_confirmed_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES
  ('00000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000001', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000002', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000003', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000004', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000005', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000006', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000007', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000007', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000008', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000008', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000009', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000009', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000010', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000010', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000011', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now()),
  ('00000000-0000-4000-8000-000000000012', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '628121000012', now(), '', '', '', '', '{"provider":"phone","providers":["phone"]}', '{}', now() - interval '60 days', now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
SELECT id, id, id::text, jsonb_build_object('sub', id::text, 'phone', phone), 'phone', now(), now(), now()
FROM auth.users
WHERE id::text LIKE '00000000-0000-4000-8000-0000000000%'
ON CONFLICT DO NOTHING;

-- Lengkapi profil mock (triggered skeleton row sudah terbuat otomatis)
UPDATE public.profiles SET
  phone_e164 = v.phone_e164,
  display_name = v.display_name,
  gender = v.gender::public.user_gender,
  birth_year = v.birth_year,
  marga = v.marga,
  sub_ethnic = v.sub_ethnic::public.sub_ethnic,
  mother_marga = v.mother_marga,
  city = v.city,
  subdistrict = v.subdistrict,
  sundut = v.sundut,
  hobbies = v.hobbies,
  campus_or_office = v.campus_or_office,
  bio = v.bio,
  avatar_seed = 'avatar-u-' || lpad(v.num::text, 2, '0') || '-' || v.marga,
  onboarding_completed = true,
  created_at = now() - interval '60 days'
FROM (VALUES
  (1,  '00000000-0000-4000-8000-000000000001'::uuid, '+628121000001', 'Rudi Simanjuntak', 'male', 1996, 'Simanjuntak', 'toba', 'Sitorus', 'Medan', 'Medan Baru', 16, ARRAY['Badminton','Kopi','Musik Batak'], 'USU Medan', 'Anak rantau balik kampung. Horas dongan sahuta!'),
  (2,  '00000000-0000-4000-8000-000000000002'::uuid, '+628121000002', 'Dewi Simanjuntak', 'female', 1997, 'Simanjuntak', 'toba', 'Nainggolan', 'Medan', 'Medan Baru', 16, ARRAY['Badminton','Kuliner'], 'RS Adam Malik', 'Senang berkumpul di punguan dan olahraga sore.'),
  (3,  '00000000-0000-4000-8000-000000000003'::uuid, '+628121000003', 'Bona Sitorus', 'male', 1970, 'Sitorus', 'toba', 'Panjaitan', 'Medan', 'Medan Selayang', 15, ARRAY['Catur','Tenis Meja'], 'BUMN Medan', 'Pengurus punguan dan pemerhati silsilah keluarga.'),
  (4,  '00000000-0000-4000-8000-000000000004'::uuid, '+628121000004', 'Agus Nainggolan', 'male', 1995, 'Nainggolan', 'toba', 'Simanjuntak', 'Medan', 'Medan Helvetia', 16, ARRAY['Futsal','Badminton'], 'Polmed', 'Ayo main futsal bareng tiap akhir pekan!'),
  (5,  '00000000-0000-4000-8000-000000000005'::uuid, '+628121000005', 'Rina Sitorus', 'female', 1998, 'Sitorus', 'toba', 'Siregar', 'Medan', 'Medan Baru', 16, ARRAY['Jogging','Fotografi'], 'Unimed', 'Suka memotret suasana Danau Toba.'),
  (6,  '00000000-0000-4000-8000-000000000006'::uuid, '+628121000006', 'Togar Hutabarat', 'male', 1993, 'Hutabarat', 'toba', 'Panggabean', 'Medan', 'Medan Sunggal', 16, ARRAY['Basket','Kopi'], 'Pelindo Belawan', 'Kopi Sidikalang dulu baru olahraga.'),
  (7,  '00000000-0000-4000-8000-000000000007'::uuid, '+628121000007', 'Sondang Panggabean', 'female', 1972, 'Panggabean', 'toba', 'Sihombing', 'Medan', 'Medan Kota', 15, ARRAY['Paduan Suara','Kuliner'], 'SMA Negeri Medan', 'Aktif di kegiatan sosial dan arisan marga.'),
  (8,  '00000000-0000-4000-8000-000000000008'::uuid, '+628121000008', 'Brema Ginting', 'male', 1996, 'Ginting', 'karo', 'Sembiring', 'Medan', 'Medan Tuntungan', 16, ARRAY['Badminton','Mendaki'], 'USU Medan', 'Mejuah-juah! Suka badminton dan naik Sibayak.'),
  (9,  '00000000-0000-4000-8000-000000000009'::uuid, '+628121000009', 'Lestari Damanik', 'female', 1999, 'Damanik', 'simalungun', 'Saragih', 'Medan', 'Medan Denai', 16, ARRAY['Voli','Membaca'], 'Nommensen Medan', 'Horas! Mahasiswi perantau dari Siantar di Medan.'),
  (10, '00000000-0000-4000-8000-000000000010'::uuid, '+628121000010', 'Hendra Siahaan', 'male', 1968, 'Siahaan', 'toba', 'Tampubolon', 'Medan', 'Medan Perjuangan', 15, ARRAY['Tenis Meja','Musik Batak'], 'Wiraswasta Medan', 'Selalu siap menyambut naposo di Medan.'),
  (11, '00000000-0000-4000-8000-000000000011'::uuid, '+628121000011', 'David Sihombing', 'male', 1994, 'Sihombing', 'toba', 'Simanjuntak', 'Jakarta Selatan', 'Tebet', 16, ARRAY['Badminton','Futsal'], 'SCBD Jakarta', 'Anak rantau di Tebet, rutin tepok bulu tiap Rabu.'),
  (12, '00000000-0000-4000-8000-000000000012'::uuid, '+628121000012', 'Nadia Silaban', 'female', 1997, 'Silaban', 'toba', 'Sitorus', 'Jakarta Selatan', 'Pasar Minggu', 16, ARRAY['Jogging','Kopi'], 'Kuningan Jakarta', 'Suka lari pagi dan diskusi budaya di Jakarta.')
) AS v(num, uid, phone_e164, display_name, gender, birth_year, marga, sub_ethnic, mother_marga, city, subdistrict, sundut, hobbies, campus_or_office, bio)
WHERE public.profiles.id = v.uid;

-- Peran staf contoh
INSERT INTO public.user_roles (user_id, role) VALUES
  ('00000000-0000-4000-8000-000000000003', 'adat_reviewer'),
  ('00000000-0000-4000-8000-000000000010', 'moderator')
ON CONFLICT (user_id, role) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. 10 Lapangan Olahraga
-- ---------------------------------------------------------------------------
INSERT INTO public.courts (id, name, address, city, supported_sports, estimated_price_text, opening_hours, image_seed, moderation_status) VALUES
  ('10000000-0000-4000-8000-000000000001', 'GOR Manunggal Medan', 'Jl. Gatot Subroto, Medan Helvetia', 'Medan', ARRAY['badminton','voli']::public.sport_type[], 'Perkiraan Rp60.000/jam', '07.00 - 23.00 WIB', 'court-gor-manunggal', 'approved'),
  ('10000000-0000-4000-8000-000000000002', 'Lapangan Futsal Setia Budi', 'Jl. Setia Budi, Medan Selayang', 'Medan', ARRAY['futsal']::public.sport_type[], 'Perkiraan Rp120.000/jam', '08.00 - 24.00 WIB', 'court-setia-budi', 'approved'),
  ('10000000-0000-4000-8000-000000000003', 'GOR Cempaka Putih & Tebet Arena', 'Jl. Tebet Timur Dalam, Jakarta Selatan', 'Jakarta Selatan', ARRAY['badminton','basket']::public.sport_type[], 'Perkiraan Rp90.000/jam', '06.00 - 23.00 WIB', 'court-tebet-arena', 'approved'),
  ('10000000-0000-4000-8000-000000000004', 'Velodrome Sport Center Rawamangun', 'Jl. Balap Sepeda, Rawamangun', 'Jakarta Timur', ARRAY['futsal','badminton','jogging']::public.sport_type[], 'Perkiraan Rp100.000/jam', '06.00 - 22.00 WIB', 'court-rawamangun', 'approved'),
  ('10000000-0000-4000-8000-000000000005', 'Sasakawa & Saraga Sport Bandung', 'Jl. Siliwangi, Coblong, Bandung', 'Bandung', ARRAY['basket','jogging','futsal']::public.sport_type[], 'Perkiraan Rp75.000/jam', '06.00 - 21.00 WIB', 'court-saraga-bdg', 'approved'),
  ('10000000-0000-4000-8000-000000000006', 'GOR Lodaya Bandung', 'Jl. Lodaya, Lengkong, Bandung', 'Bandung', ARRAY['badminton','tenis_meja']::public.sport_type[], 'Perkiraan Rp65.000/jam', '07.00 - 22.00 WIB', 'court-lodaya-bdg', 'approved'),
  ('10000000-0000-4000-8000-000000000007', 'GOR Banda Baru Batam Center', 'Kawasan Batam Kota, Batam', 'Batam', ARRAY['badminton','tenis_meja']::public.sport_type[], 'Perkiraan Rp70.000/jam', '08.00 - 23.00 WIB', 'court-banda-baru', 'approved'),
  ('10000000-0000-4000-8000-000000000008', 'Arena Futsal Imperium Batu Aji', 'Jl. Brigjen Katamso, Batu Aji, Batam', 'Batam', ARRAY['futsal','voli']::public.sport_type[], 'Perkiraan Rp110.000/jam', '09.00 - 23.00 WIB', 'court-imperium-btm', 'approved'),
  ('10000000-0000-4000-8000-000000000009', 'GOR Merdeka Pematangsiantar', 'Jl. Merdeka, Siantar Barat', 'Pematangsiantar', ARRAY['badminton','voli','tenis_meja']::public.sport_type[], 'Perkiraan Rp50.000/jam', '07.00 - 22.00 WIB', 'court-merdeka-pms', 'approved'),
  ('10000000-0000-4000-8000-000000000010', 'Lapangan Horbo & Taman Bunga Siantar', 'Jl. Sudirman, Siantar Barat', 'Pematangsiantar', ARRAY['jogging','basket']::public.sport_type[], 'Perkiraan Rp0 (Fasilitas Umum)', '05.30 - 21.00 WIB', 'court-taman-bunga-pms', 'approved')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. Komunitas + Grup Chat & Keanggotaan (termasuk com-10 closed AC-13)
-- ---------------------------------------------------------------------------
INSERT INTO public.conversations (id, type, title) VALUES
  ('21000000-0000-4000-8000-000000000001', 'community', 'Punguan Simanjuntak Sitolu Sada Ina Medan'),
  ('21000000-0000-4000-8000-000000000002', 'community', 'Punguan Raja Sitorus & Boru Medan'),
  ('21000000-0000-4000-8000-000000000003', 'community', 'Naposo Bulung & Badminton Medan'),
  ('21000000-0000-4000-8000-000000000010', 'community', 'Keluarga Internal Ompung Raja Huta')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.communities (
  id, name, type, access_type, city, marga_name, description, avatar_seed, owner_id, is_verified, conversation_id
) VALUES
  ('20000000-0000-4000-8000-000000000001', 'Punguan Simanjuntak Sitolu Sada Ina Medan', 'punguan_marga', 'open', 'Medan', 'Simanjuntak', 'Keluarga besar pomparan Simanjuntak, boru, dan bere di Kota Medan.', 'com-simanjuntak-mdn', '00000000-0000-4000-8000-000000000001', true, '21000000-0000-4000-8000-000000000001'),
  ('20000000-0000-4000-8000-000000000002', 'Punguan Raja Sitorus & Boru Medan', 'punguan_marga', 'approval_required', 'Medan', 'Sitorus', 'Wadah silaturahmi pomparan Raja Sitorus se-Kota Medan.', 'com-sitorus-mdn', '00000000-0000-4000-8000-000000000003', false, '21000000-0000-4000-8000-000000000002'),
  ('20000000-0000-4000-8000-000000000003', 'Naposo Bulung & Badminton Medan', 'minat', 'open', 'Medan', NULL, 'Komunitas olahraga badminton, futsal, dan ngopi naposo di Medan.', 'com-naposo-mdn', '00000000-0000-4000-8000-000000000004', true, '21000000-0000-4000-8000-000000000003'),
  ('20000000-0000-4000-8000-000000000010', 'Keluarga Internal Ompung Raja Huta', 'punguan_marga', 'closed', 'Medan', 'Hutabarat', 'Komunitas keluarga internal tertutup khusus keturunan langsung.', 'com-internal-closed', '00000000-0000-4000-8000-000000000006', false, '21000000-0000-4000-8000-000000000010')
ON CONFLICT (id) DO NOTHING;

UPDATE public.conversations SET community_id = '20000000-0000-4000-8000-000000000001' WHERE id = '21000000-0000-4000-8000-000000000001';
UPDATE public.conversations SET community_id = '20000000-0000-4000-8000-000000000002' WHERE id = '21000000-0000-4000-8000-000000000002';
UPDATE public.conversations SET community_id = '20000000-0000-4000-8000-000000000003' WHERE id = '21000000-0000-4000-8000-000000000003';
UPDATE public.conversations SET community_id = '20000000-0000-4000-8000-000000000010' WHERE id = '21000000-0000-4000-8000-000000000010';

INSERT INTO public.community_memberships (community_id, user_id, role) VALUES
  ('20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'owner'),
  ('20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002', 'manager'),
  ('20000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000003', 'owner'),
  ('20000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000005', 'manager'),
  ('20000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000004', 'owner'),
  ('20000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'manager'),
  ('20000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000006', 'owner')
ON CONFLICT (community_id, user_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 8. Jejaring Sosial Awal & Postingan Sampel
-- ---------------------------------------------------------------------------
INSERT INTO public.connections (user_a, user_b) VALUES
  ('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002'),
  ('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000003')
ON CONFLICT (user_a, user_b) DO NOTHING;

INSERT INTO public.posts (id, author_id, community_id, text, visibility, moderation_status) VALUES
  ('40000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Horas dongan! Minggu depan kita adakan latihan badminton bareng di GOR Manunggal Medan.', 'publik', 'published'),
  ('40000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000003', NULL, 'Salam sehat untuk semua perantau. Jangan lupa lengkapi marga ibu di profil agar partuturan lebih akurat.', 'publik', 'published')
ON CONFLICT (id) DO NOTHING;
