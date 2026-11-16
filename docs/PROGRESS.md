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
| Tarombo | TAR | 8 | 7 | 1 | 0 |
| Main | MAN | 9 | 9 | 0 | 0 |
| Pesan | PSN | 6 | 6 | 0 | 0 |
| Akun | AKN | 15 | 15 | 0 | 0 |
| Sistem | SIS | 8 | 8 | 0 | 0 |
| **Total** |  | **75** | **69** | **6** | **24** |

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
| TAR-01 | Dashboard Tarombo | Ringkasan identitas, kelengkapan, saran kerabat, permintaan konfirmasi | 1 | `/tarombo` | Belum |
| TAR-02 | Pohon silsilah | Tampilan pohon; ringkas 3 generasi di fase 1, penuh di fase 3 | 1 | `/tarombo/pohon` | Belum |
| TAR-03 | Tambah/ubah anggota keluarga | Fase 1: ayah, ibu, kakek dari ayah; penuh di fase 3 | 1 | `/tarombo/anggota-form` | Belum |
| TAR-04 | Detail anggota | Data satu anggota tarombo | 1 | `/tarombo/anggota-detail` | Belum |
| TAR-05 | Detail hubungan | Panggilan, penjelasan jalur, tingkat keyakinan | 1 | `/tarombo/hubungan-detail` | Belum |
| TAR-06 | Cek partuturan | Pilih dua orang, lihat hubungannya | 1 | `/tarombo/cek-partuturan` | Belum |
| TAR-07 | Konfirmasi hubungan | Kirim/terima/tolak pengakuan kerabat | 1 | `/tarombo/konfirmasi` | Belum |
| TAR-08 | Kamus partuturan | Cari istilah dan maknanya | 2 | `/tarombo/kamus` | Belum |

### 5. Main (MAN)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| MAN-01 | Main (utama) | Daftar sesi di sekitar | 1 | `/main` | Belum |
| MAN-02 | Filter sesi | Olahraga, hari, level, jarak, biaya | 1 | `/main/filter` | Belum |
| MAN-03 | Buat sesi | Formulir sesi | 1 | `/main/sesi-buat` | Belum |
| MAN-04 | Detail sesi | Info, gabung/keluar | 1 | `/main/sesi-detail` | Belum |
| MAN-05 | Peserta dan daftar tunggu | Daftar peserta dengan badge | 1 | `/main/peserta` | Belum |
| MAN-06 | Patungan | Biaya per orang dan status bayar | 1 | `/main/patungan` | Belum |
| MAN-07 | Daftar lapangan | Lapangan yang sering dipakai | 1 | `/main/lapangan` | Belum |
| MAN-08 | Detail/usul lapangan | Info lapangan, usulkan lapangan baru | 1 | `/main/lapangan-detail` | Belum |
| MAN-09 | Riwayat sesi saya | Sesi yang dibuat dan diikuti | 1 | `/main/riwayat` | Belum |

### 6. Pesan (PSN)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| PSN-01 | Daftar pesan | Semua percakapan | 1 | `/pesan` | Belum |
| PSN-02 | Permintaan pesan | Pesan dari orang yang belum terhubung | 1 | `/pesan/permintaan` | Belum |
| PSN-03 | Chat pribadi | Percakapan satu lawan satu | 1 | `/pesan/pribadi` | Belum |
| PSN-04 | Chat grup | Grup komunitas dan sesi | 1 | `/pesan/grup` | Belum |
| PSN-05 | Info percakapan | Anggota, bisukan, keluar, lapor | 1 | `/pesan/info` | Belum |
| PSN-06 | Penampil media | Foto dalam chat | 1 | `/pesan/media` | Belum |

### 7. Akun (AKN)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| AKN-01 | Profil saya | Tampilan profil sendiri | 1 | `/akun` | Belum |
| AKN-02 | Edit profil | Ubah bio, foto, domisili, hobi | 1 | `/akun/edit` | Belum |
| AKN-03 | Postingan saya | Daftar postingan sendiri | 1 | `/akun/postingan-saya` | Belum |
| AKN-04 | Tersimpan | Postingan yang disimpan | 1 | `/akun/tersimpan` | Belum |
| AKN-05 | Pengikut | Daftar pengikut | 1 | `/akun/pengikut` | Belum |
| AKN-06 | Mengikuti | Daftar yang diikuti | 1 | `/akun/mengikuti` | Belum |
| AKN-07 | Pengaturan | Menu pengaturan utama, mode gelap | 1 | `/akun/pengaturan` | Belum |
| AKN-08 | Privasi | Visibilitas per bidang | 1 | `/akun/privasi` | Belum |
| AKN-09 | Keamanan | Perangkat aktif, ganti nomor | 1 | `/akun/keamanan` | Belum |
| AKN-10 | Pengaturan notifikasi | Preferensi per jenis, jam tenang | 1 | `/akun/notifikasi-preferensi` | Belum |
| AKN-11 | Pengguna diblokir | Daftar dan buka blokir | 1 | `/akun/diblokir` | Belum |
| AKN-12 | Kenalan saya | Daftar terhubung dan permintaan | 1 | `/akun/kenalan` | Belum |
| AKN-13 | Data saya | Unduh data | 1 | `/akun/data-saya` | Belum |
| AKN-14 | Hapus akun | Alur penghapusan | 1 | `/akun/hapus-akun` | Belum |
| AKN-15 | Tentang HORAS | Versi, lisensi, kebijakan | 1 | `/akun/tentang` | Belum |

### 8. Sistem (SIS)
| ID | Nama Halaman | Tujuan | Fase | Rute | Status |
| --- | --- | --- | --- | --- | --- |
| SIS-01 | Notifikasi | Daftar notifikasi dalam aplikasi | 1 | `/sistem/notifikasi` | Belum |
| SIS-02 | Laporkan | Formulir laporan untuk pengguna, konten, komunitas, sesi | 1 | `/sistem/laporkan` | Belum |
| SIS-03 | Status laporan saya | Riwayat dan hasil laporan | 1 | `/sistem/laporan-status` | Belum |
| SIS-04 | Pusat bantuan | Artikel dan pertanyaan umum | 1 | `/sistem/bantuan` | Belum |
| SIS-05 | Hubungi dukungan | Kirim keluhan | 1 | `/sistem/dukungan` | Belum |
| SIS-06 | Ajukan verifikasi | Verifikasi komunitas (gereja di fase 2) | 1 | `/sistem/verifikasi-ajukan` | Belum |
| SIS-07 | Status verifikasi | Status pengajuan | 1 | `/sistem/verifikasi-status` | Belum |
| SIS-08 | Pedoman komunitas | Aturan perilaku | 1 | `/sistem/pedoman` | Belum |

---

## Bagian Placeholder (`SegeraPage`)
Halaman yang masih dirender menggunakan `SegeraPage` (51 halaman; `AUT-01` .. `AUT-07` selesai di Prompt 3, `BER-01`/`04..10` di Prompt 4, `SEK-01..08`/`12` di Prompt 5):
- `BER-02` .. `BER-03` (`HomeModulePageRouter` - Fase 2 belum diaktifkan)
- `SEK-09` .. `SEK-11` (`NearbyModulePageRouter` - Fase 2 belum diaktifkan)
- `TAR-01` .. `TAR-08` (`TaromboModulePlaceholderPage`)
- `MAN-01` .. `MAN-09` (`PlayModulePlaceholderPage`)
- `PSN-01` .. `PSN-06` (`MessagesModulePlaceholderPage`)
- `AKN-01` .. `AKN-15` (`AccountModulePlaceholderPage`)
- `SIS-01` .. `SIS-08` (`SystemModulePlaceholderPage`)

Setiap kali sebuah modul dibangun pada sesi berikutnya, halaman yang selesai dipindahkan dari `SegeraPage` ke implementasi penuhnya dan dihapus dari daftar Placeholder ini.

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
