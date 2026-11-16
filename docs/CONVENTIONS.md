# Konvensi Kode HORAS

## Struktur folder
```
lib/
  main.dart                 # bootstrap: SharedPreferences, ProviderScope
  app.dart                  # MaterialApp.router, tema, locale
  core/
    config/                 # AppConfig (--dart-define), FeatureFlags, provider inti
    theme/                  # token warna (HorasColors), tipografi (HorasTypography), spasi/radius/ukuran, AppTheme, ThemeModeController
    router/                 # AppPages (registri 75 halaman), AppRouter (go_router), shell + bilah bawah, deep link
    widgets/                # komponen dasar (AppButton, StateView, ...)
    errors/                 # AppFailure (sealed), Result
    utils/                  # helper murni (ReferenceCode, preferences)
    l10n/                   # AppStrings: SATU-SATUNYA tempat teks UI
  domain/
    models/                 # model immutable (sealed class / final class + copyWith manual)
    repositories/           # antarmuka abstrak (abstract interface class)
    policies/               # aturan bisnis murni (batas PRD 7.2, privasi 7.1), tanpa Flutter
    partuturan/             # mesin aturan partuturan data-driven (TAR-R6)
  data/
    mock/                   # implementasi repository palsu (prompt 2)
    supabase/               # implementasi Supabase (prompt 11)
  features/<modul>/presentation/   # halaman (*_page.dart) + controller Riverpod (*_controller.dart)
test/                       # cermin struktur lib/
```
Modul: `auth`, `home` (Beranda), `nearby` (Sekitar), `tarombo`, `play` (Main), `messages` (Pesan), `account` (Akun), `system` (Sistem).

## Aturan dependensi
- `features` → `core`, `domain`. **Dilarang** `features` → `data`.
- `domain` tidak bergantung pada Flutter (Dart murni), kecuali `package:meta` bila perlu.
- `data` → `domain`. Pemilihan implementasi (mock/supabase) hanya di provider repository, berdasarkan `AppConfig.useMockBackend`.

## Penamaan
- File `snake_case.dart`; kelas `PascalCase`; provider `camelCaseProvider`.
- Halaman: `<Nama>Page`, controller: `<Nama>Controller` (Notifier/AsyncNotifier), state: `<Nama>State`.
- ID halaman PRD dipakai di registri (`AppPages`) dan komentar dokumentasi halaman, contoh `/// SEK-04 Profil orang lain`.
- Aturan bisnis dirujuk dengan ID PRD di komentar, contoh `// SEK-R5: kedaluwarsa 30 hari`.

## Teks, warna, ukuran
- Teks: `AppStrings.xxx`. Istilah baku PRD 7.3: `AppStrings.termIkuti`, `termKenalan`, dst.
- Warna: `context.colors.primary` (ThemeExtension `HorasColors`). Nilai hex hanya di `core/theme/horas_colors.dart`.
- Tipografi: `context.typo.h1` (ThemeExtension `HorasTypography`). Font hanya `PlusJakartaSans` (UI) dan `PlayfairDisplay` (wordmark).
- Ukuran: `AppSpacing` (grid 8), `AppRadius`, `AppSizes` (`minTouchTarget = 44`).

## Pola provider (Riverpod, tanpa codegen)
```dart
// domain/repositories/session_repository.dart
abstract interface class SessionRepository {
  Future<Result<Session>> fetch(String id);
}

// data/providers atau core/config: pemilihan implementasi
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMockBackend ? MockSessionRepository() : SupabaseSessionRepository(...);
});

// features/play/presentation/session_detail_controller.dart
final sessionDetailProvider =
    AsyncNotifierProvider.family<SessionDetailController, Session, String>(SessionDetailController.new);
```
- UI memakai `ref.watch(...)` untuk state, `ref.read(...notifier)` untuk aksi.
- Waktu selalu lewat `clock.now()` (paket `clock`) agar bisa diuji.

## Menambah repository
1. Buat antarmuka di `domain/repositories/<nama>_repository.dart` (kembalikan `Result<T>` / lempar `AppFailure`).
2. Buat implementasi mock di `data/mock/` dan (nanti) Supabase di `data/supabase/`.
3. Daftarkan `Provider<NamaRepository>` di `data/repository_providers.dart` yang memilih implementasi berdasarkan `AppConfig`.
4. Tulis uji unit untuk mock dan policy terkait; di uji widget, override provider dengan `mocktail`.

## Halaman baru
1. Ubah entri di `core/router/app_pages.dart` (ID PRD → builder halaman asli, bukan `SegeraPage`).
2. Setiap halaman wajib menangani status PRD 5.2 lewat `StateView`.
3. Perbarui `docs/PROGRESS.md` (status + hapus dari bagian Placeholder).
4. Halaman Fase 2 wajib dijaga `FeatureFlags` (router tidak mendaftarkan rute bila flag `false`).

## Pola uji
- `test/helpers/pump_app.dart`: `pumpApp(tester, widget)` membungkus `MaterialApp` dengan tema + `ProviderScope`.
- Widget test per komponen di `test/core/widgets/`.
- Uji unit untuk policy/domain murni (tanpa Flutter) di `test/domain/`.
- Animasi berulang (skeleton): gunakan `tester.pump(duration)`, bukan `pumpAndSettle`.
- Mock dengan `mocktail` (`class MockX extends Mock implements X {}`).

## Git
Pesan commit konvensional: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
