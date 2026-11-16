# Status Progres Halaman HORAS (Inventaris 75 Halaman PRD 5.1)

Keterangan status:
- **Belum**: belum dibangun fitur akhirnya (saat ini dirender dengan `SegeraPage` di rute terdaftarkan).
- **Berjalan**: sedang dikerjakan.
- **Selesai**: halaman dan seluruh status standar PRD 5.2 telah diimplementasikan serta diuji.

## Lapisan Domain, Kebijakan, Mesin Partuturan & Data Tiruan (Prompt 2 — Selesai)
- **Model Domain (`lib/domain/models/`):** 35+ model immutable manual; pemisahan tegas `Profil` (milik sendiri) dan `PersonSummary` (dilihat orang lain, bebas nomor HP/tahun lahir/koordinat/jarak km).
- **Antarmuka Repository (`lib/domain/repositories/`):** 23 kontrak abstrak + pemetaan `AppError` ke `StateView.fromError`.
- **Kebijakan (`lib/domain/policies/horas_policies.dart`):** Fungsi murni berbasis `Clock` untuk seluruh batas angka PRD 7.2.
- **Mesin Partuturan (`lib/domain/partuturan/` & `assets/partuturan/toba.v0.json`):** Data-driven, `GenerationResolver`, `PartuturanBadge`, `SemargaLabel`.
- **Data Tiruan & Wilayah (`lib/data/mock/` & `assets/data/wilayah.json`):** 42 pengguna fiktif, 65 marga baku, 43 kota, 10 komunitas, 12 sesi, 10 lapangan, 30 postingan, stream chat & notifikasi otomatis, serta `DebugPanelSheet` non-prod.

## Ringkasan Modul
| Modul | Kode | Jumlah Halaman | Fase 1 | Fase 2 | Selesai |
| --- | --- | --- | --- | --- | --- |
| Autentikasi | AUT | 7 | 7 | 0 | 7 |
| Beranda | BER | 10 | 8 | 2 | 8 |
| Sekitar | SEK | 12 | 9 | 3 | 9 |
| Tarombo | TAR | 8 | 7 | 1 | 7 |
| Main | MAN | 9 | 9 | 0 | 9 |
| Pesan | PSN | 6 | 6 | 0 | 6 |
| Akun | AKN | 15 | 15 | 0 | 15 |
| Sistem | SIS | 8 | 8 | 0 | 8 |
| **Total** |  | **75** | **69** | **6** | **69** |

---

## Checklist 75 Halaman (PRD 5.1)

### 1. Autentikasi (AUT)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| AUT-01 | Splash | Memuat aplikasi, memeriksa sesi login | 1 | `/auth/splash` | Selesai |
| AUT-02 | Pengenalan | Tiga layar nilai produk (kenal, tarombo, main) | 1 | `/auth/pengenalan` | Selesai |
| AUT-03 | Masuk | Input nomor HP | 1 | `/auth/masuk` | Selesai |
| AUT-04 | Daftar | Persetujuan kebijakan, pedoman, konfirmasi usia 17+ | 1 | `/auth/daftar` | Selesai |
| AUT-05 | Verifikasi OTP | Input kode 6 digit | 1 | `/auth/otp` | Selesai |
| AUT-06 | Onboarding profil | Empat langkah: nama dan foto, jenis kelamin dan tahun lahir, marga dan sub-suku, domisili dan minat | 1 | `/auth/onboarding` | Selesai |
| AUT-07 | Pemulihan akun | Mengganti nomor atau memulihkan akses | 1 | `/auth/pemulihan` | Selesai |

### 2. Beranda (BER)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| BER-01 | Feed | Daftar postingan (tanpa baris story, Fase 2 off) | 1 | `/beranda` | Selesai |
| BER-02 | Penampil story | Menonton story (Fase 2) | 2 | `/beranda/story-lihat` | Belum |
| BER-03 | Buat story | Membuat story foto/video (Fase 2) | 2 | `/beranda/story-buat` | Belum |
| BER-04 | Buat postingan | Teks, foto, visibilitas | 1 | `/beranda/postingan-buat` | Selesai |
| BER-05 | Pilih dan edit media | Pangkas dan urutkan foto (video di fase 2) | 1 | `/beranda/media-edit` | Selesai |
| BER-06 | Detail postingan | Satu postingan lengkap | 1 | `/beranda/postingan-detail` | Selesai |
| BER-07 | Komentar | Daftar dan tulis komentar | 1 | `/beranda/komentar` | Selesai |
| BER-08 | Daftar suka | Siapa yang menyukai | 1 | `/beranda/suka` | Selesai |
| BER-09 | Pencarian | Kolom cari, riwayat, saran | 1 | `/beranda/cari` | Selesai |
| BER-10 | Hasil pencarian | Tab Orang dan Komunitas (Gereja/Postingan Fase 2 off) | 1 | `/beranda/cari-hasil` | Selesai |

### 3. Sekitar (SEK)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| SEK-01 | Sekitar (utama) | Segmen Orang dan Komunitas (Gereja Fase 2 off) | 1 | `/sekitar` | Selesai |
| SEK-02 | Daftar orang sekitar | Kartu orang dengan badge partuturan | 1 | `/sekitar/orang` | Selesai |
| SEK-03 | Filter orang | Marga, kota, kampus/kantor, hobi | 1 | `/sekitar/orang-filter` | Selesai |
| SEK-04 | Profil orang lain | Profil, badge, aksi Ikuti/Kenalan/Pesan | 1 | `/sekitar/profil` | Selesai |
| SEK-05 | Daftar komunitas | Jelajah dan cari komunitas | 1 | `/sekitar/komunitas` | Selesai |
| SEK-06 | Detail komunitas | Info, anggota, pengumuman (kegiatan Fase 2 off) | 1 | `/sekitar/komunitas-detail` | Selesai |
| SEK-07 | Buat komunitas | Formulir pembuatan | 1 | `/sekitar/komunitas-buat` | Selesai |
| SEK-08 | Kelola komunitas | Anggota, permintaan gabung, peran, pengumuman | 1 | `/sekitar/komunitas-kelola` | Selesai |
| SEK-09 | Detail kegiatan | Info kegiatan dan RSVP (Fase 2) | 2 | `/sekitar/kegiatan-detail` | Belum |
| SEK-10 | Daftar gereja | Direktori dan filter (Fase 2) | 2 | `/sekitar/gereja` | Belum |
| SEK-11 | Detail gereja | Jadwal, kontak, kegiatan, jemaat di HORAS (Fase 2) | 2 | `/sekitar/gereja-detail` | Belum |
| SEK-12 | Pencarian Sekitar | Cari orang dan komunitas (gereja di fase 2) | 1 | `/sekitar/cari` | Selesai |

### 4. Tarombo (TAR)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| TAR-01 | Dashboard Tarombo | Ringkasan identitas, kelengkapan, saran kerabat, permintaan konfirmasi | 1 | `/tarombo` | Selesai |
| TAR-02 | Pohon silsilah | Tampilan pohon; ringkas 3 generasi di fase 1, penuh di fase 3 | 1 | `/tarombo/pohon` | Selesai |
| TAR-03 | Tambah/ubah anggota keluarga | Fase 1: ayah, ibu, kakek dari ayah & kakek dari ibu | 1 | `/tarombo/anggota-form` | Selesai |
| TAR-04 | Detail anggota | Data satu anggota tarombo | 1 | `/tarombo/anggota-detail` | Selesai |
| TAR-05 | Detail hubungan | Panggilan, penjelasan jalur, tingkat keyakinan | 1 | `/tarombo/hubungan-detail` | Selesai |
| TAR-06 | Cek partuturan | Pilih dua orang, lihat hubungannya | 1 | `/tarombo/cek-partuturan` | Selesai |
| TAR-07 | Konfirmasi hubungan | Kirim/terima/tolak pengakuan kerabat | 1 | `/tarombo/konfirmasi` | Selesai |
| TAR-08 | Kamus partuturan | Cari istilah dan maknanya (Fase 2) | 2 | `/tarombo/kamus` | Belum |

### 5. Main (MAN)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| MAN-01 | Main (utama) | Daftar sesi di sekitar | 1 | `/main` | Selesai |
| MAN-02 | Filter sesi | Olahraga, hari, level, jarak, biaya | 1 | `/main/filter` | Selesai |
| MAN-03 | Buat sesi | Formulir sesi | 1 | `/main/sesi-buat` | Selesai |
| MAN-04 | Detail sesi | Info, gabung/keluar | 1 | `/main/sesi-detail` | Selesai |
| MAN-05 | Peserta dan daftar tunggu | Daftar peserta dengan badge | 1 | `/main/peserta` | Selesai |
| MAN-06 | Patungan | Biaya per orang dan status bayar | 1 | `/main/patungan` | Selesai |
| MAN-07 | Daftar lapangan | Lapangan yang sering dipakai | 1 | `/main/lapangan` | Selesai |
| MAN-08 | Detail/usul lapangan | Info lapangan, usulkan lapangan baru | 1 | `/main/lapangan-detail` | Selesai |
| MAN-09 | Riwayat sesi saya | Sesi yang dibuat dan diikuti | 1 | `/main/riwayat` | Selesai |

### 6. Pesan (PSN)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| PSN-01 | Daftar pesan | Semua percakapan | 1 | `/pesan` | Selesai |
| PSN-02 | Permintaan pesan | Pesan dari orang yang belum terhubung | 1 | `/pesan/permintaan` | Selesai |
| PSN-03 | Chat pribadi | Percakapan satu lawan satu | 1 | `/pesan/pribadi` | Selesai |
| PSN-04 | Chat grup | Grup komunitas dan sesi | 1 | `/pesan/grup` | Selesai |
| PSN-05 | Info percakapan | Anggota, bisukan, keluar, lapor | 1 | `/pesan/info` | Selesai |
| PSN-06 | Penampil media | Foto dalam chat | 1 | `/pesan/media` | Selesai |

### 7. Akun (AKN)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| AKN-01 | Profil saya | Tampilan profil sendiri | 1 | `/akun` | Selesai |
| AKN-02 | Edit profil | Ubah bio, foto, domisili, hobi | 1 | `/akun/edit` | Selesai |
| AKN-03 | Postingan saya | Daftar postingan sendiri | 1 | `/akun/postingan-saya` | Selesai |
| AKN-04 | Tersimpan | Postingan yang disimpan | 1 | `/akun/tersimpan` | Selesai |
| AKN-05 | Pengikut | Daftar pengikut | 1 | `/akun/pengikut` | Selesai |
| AKN-06 | Mengikuti | Daftar yang diikuti | 1 | `/akun/mengikuti` | Selesai |
| AKN-07 | Pengaturan | Menu pengaturan utama, mode gelap | 1 | `/akun/pengaturan` | Selesai |
| AKN-08 | Privasi | Visibilitas per bidang | 1 | `/akun/privasi` | Selesai |
| AKN-09 | Keamanan | Perangkat aktif, ganti nomor | 1 | `/akun/keamanan` | Selesai |
| AKN-10 | Pengaturan notifikasi | Preferensi per jenis, jam tenang | 1 | `/akun/notifikasi-preferensi` | Selesai |
| AKN-11 | Pengguna diblokir | Daftar dan buka blokir | 1 | `/akun/diblokir` | Selesai |
| AKN-12 | Kenalan saya | Daftar terhubung dan permintaan | 1 | `/akun/kenalan` | Selesai |
| AKN-13 | Data saya | Unduh data | 1 | `/akun/data-saya` | Selesai |
| AKN-14 | Hapus akun | Alur penghapusan | 1 | `/akun/hapus-akun` | Selesai |
| AKN-15 | Tentang HORAS | Versi, lisensi, kebijakan | 1 | `/akun/tentang` | Selesai |

### 8. Sistem (SIS)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| SIS-01 | Notifikasi | Daftar notifikasi dalam aplikasi | 1 | `/sistem/notifikasi` | Selesai |
| SIS-02 | Laporkan | Formulir laporan untuk pengguna, konten, komunitas, sesi | 1 | `/sistem/laporkan` | Selesai |
| SIS-03 | Status laporan saya | Riwayat dan hasil laporan | 1 | `/sistem/laporan-status` | Selesai |
| SIS-04 | Pusat bantuan | Artikel dan pertanyaan umum | 1 | `/sistem/bantuan` | Selesai |
| SIS-05 | Hubungi dukungan | Kirim keluhan | 1 | `/sistem/dukungan` | Selesai |
| SIS-06 | Ajukan verifikasi | Verifikasi komunitas (gereja di fase 2) | 1 | `/sistem/verifikasi-ajukan` | Selesai |
| SIS-07 | Status verifikasi | Status pengajuan | 1 | `/sistem/verifikasi-status` | Selesai |
| SIS-08 | Pedoman komunitas | Aturan perilaku | 1 | `/sistem/pedoman` | Selesai |

---

## Bagian Placeholder (`SegeraPage`)
Daftar halaman Fase 1 yang masih memakai placeholder `SegeraPage`: **Kosong (0 halaman Fase 1 tersisa — seluruh 69 halaman Fase 1 selesai di Prompt 9)**.
*(6 halaman Fase 2 — `BER-02`, `BER-03`, `SEK-09`, `SEK-10`, `SEK-11`, `TAR-08` — tetap dinonaktifkan oleh `FeatureFlags` sampai Prompt 12.)*

---

## Bagian Fase 2 (Dijaga oleh `FeatureFlags`)
Seluruh flag di `lib/core/config/feature_flags.dart` bernilai `false` secara bawaan dan baru dibuka di Prompt 12. Selama flag bernilai `false`, tautan UI Fase 2 disembunyikan dan akses rute langsung menampilkan `StateView.contentUnavailable`:

| Flag di `FeatureFlags` | Halaman / Fitur Terkait | Status Flag Saat Ini |
| --- | --- | --- |
| `stories` | `BER-02` Penampil story, `BER-03` Buat story, baris story di `BER-01` | `false` |
| `video` | Dukungan video di `BER-03`, `BER-04`, `BER-05` | `false` |
| `hashtags` | Tagar (`#hashtag`) di `BER-04` dan pencarian `BER-10` | `false` |
| `events` | `SEK-09` Detail kegiatan & RSVP di komunitas/gereja | `false` |
| `church` | `SEK-10` Daftar gereja, `SEK-11` Detail gereja, tab Gereja di `SEK-01`/`BER-10`, verifikasi gereja di `SIS-06` | `false` |
| `partuturanDictionary` | `TAR-08` Kamus partuturan | `false` |
| `voiceNote` | Pesan suara di `PSN-03` dan `PSN-04` | `false` |
| `stickers` | Stiker di `PSN-03` dan `PSN-04` | `false` |
| `userGroups` | Grup chat buatan pengguna di luar komunitas/sesi otomatis (`PSN-R5`) | `false` |
| `recurringSessions` | Opsi sesi berulang di `MAN-03` | `false` |
| `courtMap` | Tampilan peta lapangan di `MAN-07` | `false` |

---

## Backend Supabase (Lokal & Siap Cloud)
- **Skema & RLS:** 6 migrasi bernomor (`supabase/migrations/0001..0006`) + `supabase/seed.sql` (43 wilayah, 67 entri marga baku + sub-suku, ruleset Partuturan Toba v0, 5 FAQ, 10 lapangan, 12 pengguna sampel, 10/sampel komunitas termasuk komunitas tertutup).
- **Edge Functions:** `auth-otp-guard` (`AUT-R2` 5/jam & 60s cooldown, `AUT-R3` kunci 1 jam setelah 5x salah, `AUT-R9` maks 3 perangkat aktif) dan `process-image` (re-encode piksel & hapus metadata EXIF/GPS).
- **Jadwal (`pg_cron`):** Lifecycle sesi (+2j selesai, +24j chat read-only), kedaluwarsa kenalan/komunitas/ekspor, purge akun hari ke-30 (`AC-12`), serta retensi PRD bagian 10.
- **Dokumentasi & Pengujian:** `docs/API.md` memetakan seluruh 23 repository Flutter; diuji dengan `supabase test db` (15/15 lulus) dan `deno test` (`process-image` strip EXIF/GPS, OTP guard, AC-12 purge: 3/3 lulus).

## Integrasi Supabase Flutter (`USE_MOCK_BACKEND=false`)
- Seluruh 23 antarmuka repository (`lib/data/supabase/*`) terpasang di `repository_providers.dart` melalui `--dart-define=USE_MOCK_BACKEND=false`, `SUPABASE_URL`, dan `SUPABASE_ANON_KEY`.
- Token di `flutter_secure_storage`, unggahan media terkompres & bebas EXIF via `process-image` (backoff + resume), Realtime chat & notifikasi (auto-reconnect + outbox offline), cache offline (`AC-15`), Partuturan cache-first (`< 200ms`) + RPC `generation_delta`, serta `PushNotificationService` FCM dengan graceful fallback saat `google-services.json` belum tersedia.
- Migrasi `0007_contract_parity.sql` + contract test suite (`test/contract/repository_contract_test.dart`) memverifikasi paritas Mock vs Supabase lokal.

## Penyempurnaan UI Chat (`PSN-01`..`PSN-04`)
- Menata ulang menu pesan (`psn01_conversations_page.dart`), permintaan pesan (`psn02_message_requests_page.dart`), gelembung obrolan & bilah ketik (`chat_thread_widgets.dart`), serta ruang obrolan privat/grup (`psn03_private_chat_page.dart`, `psn04_group_chat_page.dart`) menjadi tata letak rapat bergaya Instagram DM tanpa kartu dan jarak berlebih, dengan pengelompokan gelembung pesan pengirim yang sama (< 5 menit).
