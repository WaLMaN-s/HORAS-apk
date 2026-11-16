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
