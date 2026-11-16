import 'package:horas/core/config/feature_flags.dart';

/// Modul utama aplikasi HORAS sesuai PRD 5.
enum AppModule {
  auth('AUT', 'Autentikasi'),
  home('BER', 'Beranda'),
  nearby('SEK', 'Sekitar'),
  tarombo('TAR', 'Tarombo'),
  play('MAN', 'Main'),
  messages('PSN', 'Pesan'),
  account('AKN', 'Akun'),
  system('SIS', 'Sistem');

  const AppModule(this.code, this.label);

  final String code;
  final String label;
}

/// Spesifikasi metadata satu halaman dari inventaris 75 halaman PRD 5.1.
final class PageSpec {
  const PageSpec({
    required this.id,
    required this.title,
    required this.purpose,
    required this.module,
    required this.phase,
    required this.routePath,
    this.isEnabledByFlags,
  });

  /// ID halaman PRD (contoh: `BER-01`, `SEK-04`, `PSN-01`).
  final String id;

  /// Nama halaman Bahasa Indonesia dari `AppStrings`.
  final String title;

  /// Tujuan halaman sesuai tabel PRD 5.1.
  final String purpose;

  /// Modul pemilik halaman.
  final AppModule module;

  /// Fase rilis (1 = MVP, 2 = rilis berikutnya, 3 = rilis lanjutan).
  final int phase;

  /// Pola path rute untuk `go_router` dan deep link `horas://app<routePath>`.
  final String routePath;

  /// Pemeriksa opsional apakah halaman Fase 2 diizinkan oleh [FeatureFlags].
  final bool Function(FeatureFlags flags)? isEnabledByFlags;

  bool isAvailable(FeatureFlags flags) {
    if (isEnabledByFlags != null) {
      return isEnabledByFlags!(flags);
    }
    return phase == 1;
  }
}
