# AGENTS.md: wajib dibaca di awal setiap sesi

Aplikasi **HORAS** (Satu Aplikasi, Satu Keluarga Orang Batak). Flutter/Dart, Android dan iOS.

## Sumber kebenaran (urutan prioritas)
1. `docs/PRD.md`: isi, aturan bisnis (ID seperti `AUT-R1`), alur, istilah, batas angka.
2. `docs/reference/ui-reference.png`: **gaya visual saja**. Bila bertentangan dengan PRD, PRD menang.
   Koreksi dari gambar: tanpa "Lupa Password", tanpa login Google/Apple, tanpa jarak presisi (km); Story dan video = Fase 2.
3. `docs/DECISIONS.md` (keputusan dan asumsi), `docs/CONVENTIONS.md` (pola kode), `docs/PROGRESS.md` (status halaman).

## Larangan PRD (tidak boleh dilanggar)
- Tanpa sandi. Login hanya nomor HP + OTP (AUT-R1). Tanpa login sosial di Fase 1.
- Data orang lain **tidak pernah** memuat jarak presisi, koordinat, nomor HP, atau usia pasti (SEK-R2, AC-07). Jarak hanya rentang ("Di kotamu").
- Tanpa pencocokan jodoh (SEK-R6). Tanpa taruhan/judi (MAN-R7). Tanpa telepon/video, tanpa kirim lokasi presisi (PSN-R9).
- Hasil partuturan Sedang/Rendah tidak boleh ditulis sebagai fakta (TAR-R5). Aturan partuturan data-driven, bukan hardcode (TAR-R6).
- UI Fase 2 tidak tampil bila `FeatureFlags` terkait `false`.

## Aturan arsitektur
- `lib/core` (config, theme, router, widgets, errors, utils, l10n), `lib/domain` (models, repositories abstrak, policies, partuturan), `lib/data` (mock, supabase), `lib/features/<modul>/presentation`.
- UI **hanya** berbicara ke antarmuka repository (domain) lewat provider Riverpod. UI tidak pernah meng-import `lib/data/**`.
- Tanpa build_runner/codegen. Model immutable ditulis manual (sealed class/record Dart 3).
- Tanpa nilai warna/ukuran/font hardcode di widget: pakai token `context.colors`, `context.typo`, `AppSpacing`, `AppRadius`, `AppSizes`.
- Semua teks UI dari `AppStrings` (`lib/core/l10n/app_strings.dart`). Istilah baku PRD 7.3 hanya dari sana.
- Ikon interaktif wajib punya label Semantics/tooltip; target sentuh minimal 44.

## Definisi Selesai (setiap tugas)
1. `dart format .`
2. `flutter analyze` → 0 isu
3. `flutter test` → lulus
4. `flutter build apk --debug` → sukses
5. `docs/PROGRESS.md` dan `docs/DECISIONS.md` diperbarui
6. `git commit` dengan pesan konvensional (`feat:`, `fix:`, `chore:` ...)

## Bila PRD ambigu
Pilih rekomendasi PRD (bagian 15.2), atau opsi **paling aman untuk privasi**, lalu catat di `docs/DECISIONS.md`.

## Lingkungan
Flutter: `~/development/flutter/bin/flutter`, JDK 17: `~/development/jdk-17`, Android SDK: `~/Android/Sdk` (lihat DECISIONS D-001).
