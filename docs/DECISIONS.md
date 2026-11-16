# Log Keputusan dan Asumsi Arsitektur (DECISIONS.md)

Dokumen ini mencatat seluruh keputusan teknis, asumsi produk saat PRD ambigu, dan penambahan paket.

## D-001 · Lingkungan Pengembangan Lokal (16 Nov 2026)
- **Konteks:** Mesin pengembangan berjalan di Arch Linux x86_64 tanpa instalasi awal Flutter, JDK, atau Android SDK.
- **Keputusan:** Memasang seluruh toolchain di direktori pengguna (tanpa `sudo`):
  - JDK 17 (Eclipse Temurin 17.0.21) di `~/development/jdk-17`
  - Android SDK (`cmdline-tools;latest`, `platform-tools`, `platforms;android-35`, `platforms;android-36`, `build-tools;35.0.0`, `build-tools;36.0.0`) di `~/Android/Sdk`
  - Flutter SDK stable 3.50.0 (Dart 3.14.0) di `~/development/flutter`
- **Konsekuensi:** Build APK Android berjalan penuh secara lokal. Konfigurasi iOS (`IPHONEOS_DEPLOYMENT_TARGET = 15.0`, `CFBundleURLTypes` `horas://`) telah disiapkan di `ios/`, namun kompilasi IPA hanya dapat dijalankan di macOS/Xcode.

## D-002 · Paket `material_ui` dan `flutter_localizations` pada Flutter 3.50 (16 Nov 2026)
- **Konteks:** Pada Flutter 3.47+ / 3.50.0, `package:flutter/material.dart` telah dideprekasi oleh tim Flutter dan dipindahkan ke paket resmi `package:material_ui/material_ui.dart` (ditambahkan otomatis oleh `flutter create`).
- **Keputusan:**
  1. Menggunakan `import 'package:material_ui/material_ui.dart';` di seluruh widget agar `flutter analyze` menghasilkan **0 warning/deprecation**.
  2. Menambahkan `flutter_localizations` (SDK Flutter) di `pubspec.yaml` untuk mendukung lokalisasi Bahasa Indonesia (`Locale('id', 'ID')`).

## D-003 · Pembundelan Font Resmi Google Fonts secara Luring (16 Nov 2026)
- **Konteks:** Tahap 4 mewajibkan `Playfair Display` khusus untuk wordmark "Horas" dan `Plus Jakarta Sans` untuk seluruh antarmuka pengguna, dibundel ke `assets/fonts/`.
- **Keputusan:** Mengunduh berkas TTF resmi dari Google Fonts (`PlusJakartaSans` Regular/Medium/SemiBold/Bold/ExtraBold dan `PlayfairDisplay` Bold/ExtraBold/Black) beserta lisensi OFL ke `assets/fonts/` dan mendaftarkannya di `pubspec.yaml`. Tidak memerlukan akses jaringan saat aplikasi berjalan.

## D-004 · Application ID `id.horas.app` Bersifat Permanen & `compileSdk = 37` (16 Nov 2026)
- **Konteks:** Tahap 2 menetapkan Application ID `id.horas.app`, Android `minSdk = 26` (Android 8.0), iOS deployment target `15.0`, dan label aplikasi `"HORAS"`. Plugin `permission_handler_android` membutuhkan kompilasi terhadap Android SDK 37.
- **Keputusan & Catatan Penting:**
  1. `applicationId = "id.horas.app"` di `android/app/build.gradle.kts` dan `PRODUCT_BUNDLE_IDENTIFIER = id.horas.app` di `ios/Runner.xcodeproj/project.pbxproj` **tidak dapat diubah setelah aplikasi dipublikasikan di Google Play Store / Apple App Store** tanpa membuat entri aplikasi baru dan kehilangan pengguna lama.
  2. `compileSdk = 37` ditetapkan di `android/app/build.gradle.kts` dengan `minSdk = 26` tetap terjaga untuk kompatibilitas Android 8.0+.

## D-005 · Keputusan Terbuka PRD 15.2 dan Prinsip Privasi Ketat (16 Nov 2026)
- **Konteks:** Bagian 15.2 PRD mencantumkan keputusan terbuka K1–K10.
- **Keputusan:** Mengikuti seluruh rekomendasi PRD 15.2 dan opsi paling aman untuk privasi:
  - **K1 (Login):** Hanya nomor HP + OTP, tanpa sandi dan tanpa "Lupa Password" (`AUT-R1`).
  - **K2 & K3 (Beranda v1 & Story):** Beranda v1 hanya feed ringan (teks & foto); Story dan video dikunci di balik `FeatureFlags.stories = false` dan `FeatureFlags.video = false`.
  - **K4 (Ikuti & Terhubung):** Keduanya dipertahankan dengan pemisahan tegas (`Ikuti` satu arah untuk feed, `Terhubung/Kenalan` dua arah untuk chat & privasi).
  - **K5 (Aturan Partuturan):** Mesin aturan bersifat data-driven (`TAR-R6`), di Fase 1 hanya sub-suku Toba yang aktif penuh; sub-suku lain berjalan di mode netral tanpa badge partuturan sampai divalidasi reviewer adat.
  - **K7 (Gereja Asal):** Opt-in, bawaan `Hanya saya` (`FieldVisibility.onlyMe`).
  - **Privasi Lokasi & Usia (`SEK-R2`, `AC-07`):** Data orang lain tidak pernah memuat koordinat GPS, jarak presisi (km), nomor HP, atau tanggal/usia pasti.

## D-006 · Kontras Warna Teks Teredam & Amber Keyakinan Sedang (16 Nov 2026)
- **Konteks:** Tahap 4 mensyaratkan kontras teks minimal 4.5:1 di mode terang maupun gelap, serta warna amber untuk tingkat keyakinan partuturan Sedang (`TAR-R5`).
- **Keputusan:**
  - Menyediakan token `confidenceAmber` (`#8C5300` di atas `#FFF3DC` pada Light; `#FFC266` di atas `#382812` pada Dark) yang memenuhi rasio kontras WCAG AA >= 4.5:1.
  - Menyesuaikan `textMuted` Light ke `#6B6260` di atas `#FBF7F3` (rasio kontras > 5.2:1) sambil menyimpan konstanta referensi `#7A7270` di `HorasColors.referenceLightTextMuted`.

## D-007 · Persistensi Lokal Data Tiruan (16 Nov 2026)
- **Konteks:** Prompt 2 Bagian C menetapkan aturan persistensi untuk backend tiruan (`lib/data/mock/`).
- **Keputusan:** Persistensi lokal melalui `SharedPreferences` hanya menyimpan sesi login (`horas.mock.session_user_id`), profil milik sendiri (`horas.mock.own_profile`), dan pengaturan privasi (`horas.mock.own_privacy`). Seluruh entitas tiruan lainnya (postingan, komunitas, sesi main, chat, notifikasi, klaim) disimpan in-memory di `MockStore` dan di-reset ke data benih saat aplikasi dimulai ulang atau saat tombol Reset di Panel Debug ditekan.

## D-008 · Aturan Partuturan Toba v0 Berstatus Draf (`validated: false`) (16 Nov 2026)
- **Konteks:** Mesin partuturan (`lib/domain/partuturan/partuturan_engine.dart`) bersifat 100% data-driven dari berkas JSON berversi `assets/partuturan/toba.v0.json` tanpa istilah partuturan yang di-hardcode di kode Dart (`TAR-R6`, keputusan `K5`).
- **Keputusan:**
  1. Berkas `assets/partuturan/toba.v0.json` hanya memuat pola dasar Toba yang jelas (kelompok semarga/dongan tubu dan jalur marga ibu/hula-hula 1 generasi di atas atau sebaya) dan ditandai `"validated": false`, `"reviewedBy": null`.
  2. Seluruh kasus yang belum tercakup atau datanya kurang dikembalikan sebagai keyakinan `rendah` (`"Belum bisa dipastikan"`) disertai pertanyaan pelengkap, tanpa mengarang istilah.
  3. Aturan wajib divalidasi oleh reviewer adat Toba sebelum peluncuran publik (`ENV=prod` secara bawaan mematikan aturan draf lewat `allowDraftRules = false`, sehingga otomatis masuk ke mode netral sampai `validated: true`).

## D-009 · Modul Autentikasi, Persetujuan Hukum, dan Pencocokan Kota Kasar (16 Nov 2026)
- **Konteks:** Prompt 3 mengimplementasikan `AUT-01` sampai `AUT-07`, layar penjelas manfaat izin (`AUT-R10`), dan guard router.
- **Keputusan:**
  1. **Tanpa Sandi & Tanpa Login Sosial (`AUT-R1`):** `AUT-03` dan `AUT-04` hanya menerima nomor HP (dengan kode negara diaspora) dan kode OTP 6 digit (`Pinput`). Tidak ada field sandi, tombol Google/Apple, maupun tautan "Lupa Password".
  2. **Dokumen Legal Draf (`AUT-R4`, PRD 12):** `assets/legal/kebijakan_privasi_dan_syarat.md` dan `assets/legal/pedoman_komunitas.md` diberi label `"Draf, perlu tinjauan hukum"`. Persetujuan keduanya dan pernyataan usia 17+ disimpan di `LegalConsentRecord` lengkap dengan versi dan cap waktu.
  3. **Lokasi Perkiraan Tanpa Simpan Koordinat (`AUT-R10`):** `AndroidManifest.xml` hanya meminta `ACCESS_COARSE_LOCATION` dan secara eksplisit menghapus `ACCESS_FINE_LOCATION` (`tools:node="remove"`). Koordinat kasar dicocokkan di perangkat ke nama kota terdekat di `wilayah.json` lewat `CoarseLocationCityMatcher` lalu langsung dibuang.
  4. **Token Sesi Aman:** Token akses disimpan dan dihapus saat `logout()` melalui `flutter_secure_storage`.

## D-010 · Modul Beranda v1 (16 Nov 2026)
- **Konteks:** Prompt 4 mengimplementasikan modul Beranda (`BER-01`, `BER-04`..`BER-10`), alur A6, AC-10, dan AC-15.
- **Keputusan:**
  1. **Cache Feed Offline Halaman Pertama (`AC-15`):** Halaman pertama feed (`BER-01`) beserta `PersonSummary` minimal (tanpa field sensitif) disimpan lokal via `SharedPreferences` (`kMockFeedCachePrefsKey`) untuk fallback offline beserta penanda offline dan tombol `Coba lagi`.
  2. **Hapus EXIF Klien + Server (`AC-10`):** `BER-05` mengompres gambar di klien dengan `FlutterImageCompress(..., keepExif: false)` dan memvalidasi ukuran sebelum kompres maksimal 10 MB; lapisan mock server (`MockPostRepository`) ikut membersihkan parameter/metadata lokasi EXIF sebelum menyajikan berkas media.
  3. **Bisukan/Blokir & Lapor (`BER-06`):** Aksi bisukan akun dan blokir pada kartu/detail postingan langsung menggunakan `BlockRepository` yang sudah ada agar konsisten dengan kebijakan moderasi. Aksi Laporkan diarahkan ke rute `/report` (alias ke placeholder `SIS-02` sampai modul Sistem dikerjakan).
  4. **Fitur Fase 2 Disembunyikan (`FeatureFlags`):** `BER-02` dan `BER-03` (Story) tidak ditampilkan di `BER-01` dan tetap diarahkan ke `SegeraPage` saat flag `stories` bernilai `false`. Pada `BER-10`, hanya tab **Orang** dan **Komunitas** yang tampil karena flag `church` dan pencarian postingan penuh belum dibuka.

## D-011 · Modul Sekitar v1 (16 Nov 2026)
- **Konteks:** Prompt 5 mengimplementasikan `SEK-01`..`SEK-08` dan `SEK-12`, alur A2/A5, `PSN-R1`, `AC-05`, `AC-06`, `AC-07`, dan `AC-13`.
- **Keputusan:**
  1. **Area Berbasis Profil / Pilihan Manual (`SEK-R1`, `AC-07`):** Daftar dan pencarian Sekitar tidak pernah membaca GPS di tampilan kartu maupun DTO. Area memakai kota pada profil atau kota pilihan manual pelihat (misalnya kota tujuan pindah), dan jarak hanya ditampilkan sebagai rentang (`Di kotamu` / `Di kecamatanmu`).
  2. **Pesan Konteks Bersama vs Tanpa Konteks (`PSN-R1`, `AC-06`):** Pada `SEK-04`, tombol `Pesan` disembunyikan total apabila belum Terhubung dan tidak berbagi komunitas/sesi yang mengizinkan pesan. Untuk konteks bersama non-terhubung, tombol `Pesan (Permintaan pesan)` membuka lembar kirim pesan pertama via `ChatRepository.sendFirstMessageToUser`.
  3. **Grup Chat Komunitas via `ChatRepository` (`SEK-R11`):** `MockCommunityRepository` kini berkolaborasi langsung dengan `ChatRepository` (`createCommunityGroupChat`, `addParticipantToCommunityChat`, `removeParticipantFromCommunityChat`) agar pembuatan komunitas dan penerimaan anggota otomatis memperbarui percakapan grup komunitas.
  4. **Rute Placeholder & Fase 2 (`SEK-09`..`SEK-11`):** Tautan `"Ajukan Verifikasi"` di `SEK-08` memakai alias rute `/verification` menuju placeholder `SIS-06`, sedangkan `Laporkan` di `SEK-04` menuju `/report` (`SIS-02`). Tab/jenis Gereja dan bagian Kegiatan komunitas tetap disembunyikan selama `FeatureFlags.church` dan `FeatureFlags.events` bernilai `false`.

## D-012 · Modul Tarombo v1 & Kakek dari Ibu pada Fase 1 (16 Nov 2026)
- **Konteks:** Prompt 6 mengimplementasikan `TAR-01`..`TAR-07`, `TAR-R1`..`TAR-R12`, alur A3, `AC-03`, dan `AC-04`.
- **Keputusan:**
  1. **Izinkan Kakek dari Ibu di `TAR-03` Fase 1:** Meskipun deskripsi singkat `TAR-03` menyebut ayah, ibu, dan kakek dari ayah, `TAR-R11` menghitung kelengkapan dari 5 butir (marga ibu, ayah, ibu, kakek dari ayah, kakek dari ibu). Maka `TAR-03` Fase 1 mengizinkan input `Kakek dari Ibu (Ompung Bao)` agar kelengkapan 100% dapat dicapai.
  2. **Persetujuan Terpisah `TAR-R2` & Privasi `TAR-R10`:** Mengisi data keluarga memerlukan persetujuan terpisah sekali seumur hidup sebelum `TAR-03` dibuka. Privasi `Tarombo` bawaan adalah `Hanya saya`, dengan pengaturan visibilitas per bagian (`marga ibu` dan `nama orang tua`) serta tombol hapus seluruh data tarombo dengan `ConfirmDialog`.
  3. **Penautan Akun Kerabat Tidak Otomatis (`TAR-R4`):** Saat anggota tarombo cocok dengan akun HORAS terdaftar (`findPotentialLinksForMember`), `TAR-04` hanya menawarkan dialog konfirmasi penautan dua pihak (`sendKinshipClaim`) dan tidak pernah menautkan otomatis.
  4. **Pintu Masuk `PartuturanBadge` ke `TAR-05`:** Seluruh `PartuturanBadge` pada kartu/profil (`SEK-02`, `SEK-04`, `BER-01`, `BER-08`, `BER-10`, dan `TAR-01`) menavigasi ke `TAR-05` (`/tarombo/hubungan-detail?userId=...`); sub-suku mode netral tidak menampilkan badge. Kamus Partuturan (`TAR-08`) tetap pada `SegeraPage` (Fase 2 off).

## D-013 · Modul Main v1 & Pengingat Lokal Jam Tenang (16 Nov 2026)
- **Konteks:** Prompt 7 mengimplementasikan `MAN-01`..`MAN-09`, `MAN-R1`..`MAN-R11`, alur A4, `AC-08`, dan `AC-09`.
- **Keputusan:**
  1. **Pengingat Lokal & Jam Tenang 22.00–06.00 (`MAN-R11`, `AKN-R5`):** Jadwal H-1 pukul 19.00 dan 2 jam sebelum sesi mulai dihitung lewat fungsi murni `HorasPolicies.computeSessionReminders` dan digeser otomatis ke pukul 06.00 bila jatuh di jam tenang 22.00–06.00 (`HorasPolicies.adjustReminderForQuietHours`). Penjadwalan memakai `flutter_local_notifications` + `flutter_timezone` dengan *inexactAllowWhileIdle* dan fallback halus (`try/catch`) pada lingkungan tes/platform tanpa saluran notifikasi native. Core library desugaring (`desugar_jdk_libs:2.1.4`) diaktifkan di `android/app/build.gradle.kts`.
  2. **Chat Grup Sesi Otomatis & Siklus Hidup (`MAN-R9`):** `MockSessionRepository` berkolaborasi langsung dengan `ChatRepository` (`createSessionGroupChat`, `addParticipantToSessionChat`, `removeParticipantFromSessionChat`, `markConversationReadOnly`). Sesi otomatis berstatus `Selesai` 2 jam setelah `endTime`, dan chat grup menjadi baca-saja 24 jam setelah selesai.
  3. **Patungan Tanpa Rekening & Pembulatan Rp500 (`MAN-R7`):** `MAN-06` menghitung pembagian per orang dengan pembulatan ke atas kelipatan Rp500 (`HorasPolicies.calculatePatunganPerPerson`), hanya mencatat status peserta `"Sudah bayar"` dan konfirmasi host `"Konfirmasi Lunas"` tanpa kolom rekening atau integrasi pembayaran apa pun.
  4. **Fitur Fase 2 Disembunyikan (`FeatureFlags`):** Opsi sesi berulang di `MAN-03` dan tampilan peta lapangan di `MAN-07` tidak ditampilkan selama `recurringSessions` dan `courtMap` bernilai `false`; `MAN-08` membuka lokasi lapangan ke aplikasi peta eksternal via `url_launcher`.

## D-014 · Modul Pesan v1, Balasan Otomatis Tiruan, & Pengelompokan Notifikasi (16 Nov 2026)
- **Konteks:** Prompt 8 mengimplementasikan `PSN-01`..`PSN-06`, `PSN-R1`..`PSN-R9`, `AC-06`, dan `AC-16`.
- **Keputusan:**
  1. **Lencana Hidup Bilah Atas (`unreadCountsProvider`):** Menambahkan `unreadCountsProvider` di `repository_providers.dart` yang menggabungkan stream `ChatRepository.watchConversations()` dan `NotificationRepository.watchNotifications()` untuk memperbarui lencana Pesan dan Notifikasi pada bilah atas secara reaktif tanpa ketergantungan UI ke `lib/data/**`.
  2. **Balasan Otomatis Non-Prod & Panel Debug (`MockChatRepository`):** Pada build non-prod, `sendMessage` pada percakapan pribadi menjadwalkan balasan otomatis singkat berbasis sapaan partuturan yang mengalir lewat `Stream` dan dapat dimatikan via sakelar baru di `DebugPanelSheet`. Timer balasan dibatalkan saat `MockStore.dispose()` agar tes widget bebas sisa timer.
  3. **Pengelompokan Notifikasi & Retensi Laporan 30 Hari (`PSN-R4`):** Notifikasi pesan baru (`NotificationType.newMessage`) dikelompokkan per `conversationId` di `MockStore.pushGroupedMessageNotification`. Pesan yang dilaporkan (`ReportTargetType.message`) disimpan salinannya ke `retainedReportedMessages` hingga 30 hari walau pengirim menghapus pesan untuk saya/semua.
  4. **Fitur Fase 2 & Larangan `PSN-R9`:** Tombol voice note (`voiceNote`), stiker (`stickers`), dan buat grup baru (`userGroups`) disembunyikan selama flag `false`; tidak ada tombol telepon/video maupun kirim lokasi presisi di `PSN-03`/`PSN-04`.

## D-015 · Modul Akun & Sistem v1, BlockPolicy Terpusat, & Siklus Hidup Data (16 Nov 2026)
- **Konteks:** Prompt 9 menyelesaikan seluruh halaman Fase 1 yang tersisa (`AKN-01`..`AKN-15`, `SIS-01`..`SIS-08`), mengganti placeholder `/report`, `/verification`, dan Notifikasi, serta menyempurnakan `AC-11`, `AC-12`, dan `AC-14`.
- **Keputusan:**
  1. **`BlockPolicy` Terpusat (`lib/domain/policies/block_policy.dart`, `AKN-R6`, `AC-11`):** Seluruh pengecekan blokir dua arah dan penyaringan pemblokiran di grup (`hasUserBlocked`) dipusatkan pada `BlockPolicy` yang dipakai oleh `MockStore` dan seluruh repository (profil, postingan, komentar, pencarian, Sekitar, chat pribadi, daftar suka, serta pesan grup).
  2. **Pengaturan Privasi & Notifikasi Terkunci (`AKN-08`, `AKN-10`, PRD 7.1 & 9):** Seluruh bidang `PrivacySettings` memiliki default ketat PRD 7.1 dan langsung diterapkan oleh `MockStore.toPersonSummary` / `MockChatRepository`. Pada `NotificationPreferences`, `NotificationType.accountSecurity`, `moderationAction`, dan `sessionUpdatedOrCancelled` terkunci aktif dan `accountSecurity` tidak terkena penundaan jam tenang 22.00–06.00.
  3. **Unduh ZIP Nyata & Siklus Hapus Akun 30 Hari (`AKN-13`, `AKN-14`, `AC-12`):** `MockAccountLifecycleRepository` memverifikasi OTP, menyusun arsip ZIP nyata berisi `profil.json`, `postingan.json`, dan `tarombo.json` lewat paket `archive` (`share_plus`), serta menghapus data permanen akun setelah melewati hari ke-30 sambil tetap mempertahankan jejak `"Pengguna terhapus"` di pesan chat lama.
  4. **Moderasi Tiruan di Panel Debug (`DebugPanelSheet`):** Mengingat panel moderator admin adalah aplikasi web terpisah di luar cakupan aplikasi mobile, penguji dapat memajukan status laporan (`Diterima → Ditinjau → Selesai`), memvalidasi pengajuan verifikasi komunitas, serta men-strike/suspend akun langsung dari `DebugPanelSheet`.

## D-016 · Penyempurnaan Tampilan Beranda Bergaya Threads (`BER-01`, `PostCard`, `BER-06`–`BER-10`) (16 Nov 2026)
- **Konteks:** Masukan pengguna menginginkan Beranda tampil bersih ala Threads (tanpa kotak kartu tebal di feed), menyediakan kotak postingan cepat di atas daftar, memungkinkan ketuk profil penulis/pengguna lain langsung dari postingan, dan galeri foto yang dapat digeser ke samping tanpa label/bingkai yang terlalu mencolok.
- **Keputusan:**
  1. **Tata Letak Threads pada `PostCard` & `BER-01`:** Menghapus kotak berbatas/bayangan kartu dan pemisah internal pada `PostCard`, diganti tata letak dua kolom datar ala Threads (`AppAvatar` di kiri, teks/media/aksi sejajar di kanan) di atas permukaan bersih dengan pemisah garis tipis antar item.
  2. **Kotak Postingan Cepat Halus (`_ThreadsQuickComposer`):** Menambahkan strip composer cepat yang datar dan menyatu di bagian teratas `BER-01` menuju `BER-04` (sambil tetap mempertahankan ikon `+` pada bilah atas sesuai PRD 4).
  3. **Ketuk Profil Pengguna Lain & Galeri Geser Bersih:** Menautkan ketukan avatar/nama penulis pada `PostCard`, `BER-07` komentar, `BER-08` daftar suka, serta hasil pencarian `BER-10` ke `SEK-04` (`?id=...`) atau tab `/akun` bila milik sendiri; karosel foto horizontal menggunakan `ListView` geser samping tanpa overlay teks/bingkai mencolok.

## D-017 · Pindahkan Pesan ke Tab Tengah & Tarombo ke Akun > Pengaturan (16 Nov 2026)
- **Konteks:** Masukan pengguna meminta **Tarombo** dipindahkan dari bilah navigasi bawah ke dalam menu **Akun → Pengaturan** (`AKN-07`), dan **Pesan** diturunkan menjadi pengganti di tab tengah bilah navigasi bawah (`index == 2`).
- **Keputusan:**
  1. **5 Tab Bilah Bawah (`MainShellScaffold` & `app_router.dart`):** Susunan tab bawah kini menjadi **Beranda**, **Sekitar**, **Pesan** (dengan lencana jumlah pesan belum dibaca langsung di ikon tab tengah), **Main**, dan **Akun**.
  2. **Akses Tarombo via Pengaturan (`AKN-07`):** Rute `AppPages.taromboPages` tetap tersedia sebagai rute teratas (`/tarombo`, `/tarombo/*`) sehingga `PartuturanBadge` (`TAR-05`) dan menu **Tarombo** di [Akn07SettingsPage](file:///home/man/HORAS-apk/lib/features/account/presentation/akn07_settings_page.dart) langsung membuka `TAR-01` dengan tombol kembali.
  3. **Bilah Atas Beranda:** Ikon pintasan Pesan pada bilah atas `BER-01` dihapus agar tidak ganda dengan tab tengah Pesan.

## D-018 · Ikon Peluncur APK Kustom Android & iOS (16 Nov 2026)
- **Konteks:** Pengguna menyediakan logo resmi aplikasi (`assets/branding/app_icon_source.jpeg`, 1254×1254 px) untuk menggantikan ikon peluncur bawaan Flutter.
- **Keputusan:** Menghasilkan seluruh resolusi ikon peluncur Android (`mipmap-mdpi` s.d. `mipmap-xxxhdpi`), Adaptive Icon (`mipmap-anydpi-v26/ic_launcher.xml` & `ic_launcher_round.xml` dengan `ic_launcher_foreground.png` dan latar `@color/ic_launcher_background` `#000000` agar emblem Rumah Bolon/gorga utuh di zona aman 66.7%), serta seluruh set ikon iOS di `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

## D-019 · Mode Gelap Threads, Profil Orang Lain (`SEK-04`) dengan Galeri Foto Geser Samping, & Kartu Ringkas Sekitar (16 Nov 2026)
- **Konteks:** Pengguna meminta mode gelap lebih pekat ala Threads, halaman profil orang lain (`SEK-04`) menampilkan postingan beserta foto-foto (dengan 2+ foto bisa digeser ke samping ala Threads), serta kartu orang di Sekitar lebih ringkas (cukup nama dan badge `Kemungkinan: ...`).
- **Keputusan:**
  1. **Palet Gelap Pekat (`HorasColors.dark`):** Menyesuaikan latar gelap ke `#0A0A0A`, permukaan ke `#101010`, chip ke `#1C1C1C`, garis batas ke `#262626`, teks utama `#F3F5F7`, dan teks sekunder `#8E9297` (rasio kontras > 5.9:1 WCAG AA).
  2. **Shared `PostCard` di `core/widgets/post_card.dart` & `SEK-04`:** Memindahkan `PostCard` dan `RelativeTimeFormatter` ke `lib/core/` agar `Sek04PersonProfilePage` dapat menampilkan tab `Postingan` dan `Foto` bergaya Threads lengkap dengan karosel 2+ foto geser horizontal, suka, komentar, dan simpan tanpa ketergantungan lintas fitur.
  3. **Kartu Orang Ringkas (`PersonNearbyCard`):** Merampingkan kartu orang pada `SEK-01`/`SEK-02`/`SEK-12` menjadi baris ringkas berisi avatar 40dp, nama, dan badge `Kemungkinan: ...` (atau marga/Semarga bila mode netral).

## D-020 · Tarombo di Edit Profil, Pengaturan dengan Keluar Akun, & Persistensi Login Ulang (16 Nov 2026)
- **Konteks:** Pengguna meminta Tarombo digabungkan ke `Edit Profil` (`AKN-02`), bagian `Saran Kerabat` dihapus dari Tarombo (hanya di daftar orang Sekitar), menu utama `Pengaturan` (`AKN-07`) menampilkan `Keluar dari Akun` bukan `Hapus Akun`, serta akun yang sudah tersimpan dapat login kembali setelah keluar atau restart.
- **Keputusan:**
  1. **Tarombo di `AKN-02 Edit Profil` & Tanpa Saran Kerabat:** Menanamkan panel kelengkapan 5 butir, ubah marga ibu, daftar anggota, serta pintasan Pohon/Tambah/Cek Partuturan/Konfirmasi langsung di `Akn02EditProfilePage` melalui `TaromboRepository`; menghapus bagian `Saran Kerabat` dari `Tar01DashboardPage` maupun `Akn02EditProfilePage`.
  2. **`Keluar dari Akun` di `AKN-07` & `Hapus Akun` di `AKN-09`:** Mengganti entri `Tarombo` dan `Hapus Akun` di `Akn07SettingsPage` menjadi `Keluar dari Akun` (menuju `AUT-03`), sambil memindahkan akses `AKN-14 Hapus Akun` ke `Akn09SecurityPage`.
  3. **Persistensi Multi-Akun (`kMockRegisteredAccountsPrefsKey`):** Memperbaiki `MockStore` agar seluruh akun yang terdaftar/diubah tetap tersimpan di `SharedPreferences` walau pengguna keluar (`logout()`), dipulihkan sebelum pemeriksaan `savedUserId`, serta menaikkan penghitung ID `_seq` agar tidak bentrok setelah restart.
