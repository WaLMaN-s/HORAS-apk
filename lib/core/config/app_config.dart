import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lingkungan eksekusi aplikasi HORAS.
enum AppEnvironment {
  dev,
  beta,
  prod;

  static AppEnvironment fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'beta':
      case 'staging':
        return AppEnvironment.beta;
      case 'dev':
      case 'development':
      default:
        return AppEnvironment.dev;
    }
  }
}

/// Konfigurasi aplikasi dari `--dart-define`.
///
/// - `ENV`: `dev` | `beta` | `prod` (bawaan `dev`)
/// - `USE_MOCK_BACKEND`: bawaan `true`
/// - `ALLOW_DRAFT_RULES`: bawaan `true` kecuali saat `ENV == prod`
/// - `SUPABASE_URL` & `SUPABASE_ANON_KEY`: wajib saat `USE_MOCK_BACKEND=false`
final class AppConfig {
  const AppConfig({
    required this.env,
    required this.useMockBackend,
    required this.allowDraftRules,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  factory AppConfig.fromEnvironment() {
    const rawEnv = String.fromEnvironment('ENV', defaultValue: 'dev');
    final env = AppEnvironment.fromString(rawEnv);

    const useMockBackend = bool.fromEnvironment(
      'USE_MOCK_BACKEND',
      defaultValue: true,
    );

    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );

    const hasExplicitDraftRules = bool.hasEnvironment('ALLOW_DRAFT_RULES');
    const rawAllowDraft = bool.fromEnvironment(
      'ALLOW_DRAFT_RULES',
      defaultValue: true,
    );
    final allowDraftRules = hasExplicitDraftRules
        ? rawAllowDraft
        : env != AppEnvironment.prod;

    return AppConfig(
      env: env,
      useMockBackend: useMockBackend,
      allowDraftRules: allowDraftRules,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  final AppEnvironment env;
  final bool useMockBackend;
  final bool allowDraftRules;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isSupabaseConfigured =>
      !useMockBackend &&
      supabaseUrl.trim().isNotEmpty &&
      supabaseAnonKey.trim().isNotEmpty;

  bool get isProd => env == AppEnvironment.prod;
  bool get isBeta => env == AppEnvironment.beta;
  bool get isDev => env == AppEnvironment.dev;

  AppConfig copyWith({
    AppEnvironment? env,
    bool? useMockBackend,
    bool? allowDraftRules,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) {
    return AppConfig(
      env: env ?? this.env,
      useMockBackend: useMockBackend ?? this.useMockBackend,
      allowDraftRules: allowDraftRules ?? this.allowDraftRules,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          other.env == env &&
          other.useMockBackend == useMockBackend &&
          other.allowDraftRules == allowDraftRules &&
          other.supabaseUrl == supabaseUrl &&
          other.supabaseAnonKey == supabaseAnonKey;

  @override
  int get hashCode => Object.hash(
    env,
    useMockBackend,
    allowDraftRules,
    supabaseUrl,
    supabaseAnonKey,
  );
}

/// Provider global untuk [AppConfig].
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
