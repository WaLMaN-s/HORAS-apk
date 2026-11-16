import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/app.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/router/app_router.dart';
import 'package:horas/core/utils/push_notification_service.dart';
import 'package:horas/core/utils/shared_prefs_provider.dart';
import 'package:horas/data/supabase/supabase_repositories.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final config = AppConfig.fromEnvironment();

  SupabaseClient? liveClient;
  if (!config.useMockBackend) {
    if (!config.isSupabaseConfigured) {
      throw StateError(
        'SUPABASE_URL dan SUPABASE_ANON_KEY wajib diberikan via --dart-define '
        'saat USE_MOCK_BACKEND=false.',
      );
    }
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSupabaseLocalStorage(),
      ),
    );
    liveClient = Supabase.instance.client;
  }

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  if (!config.useMockBackend) {
    final authRepo = container.read(authRepositoryProvider);
    if (authRepo is SupabaseAuthRepository) {
      await authRepo.restoreSessionProfile();
    }
  }

  // Graceful fallback: aplikasi tetap berjalan penuh bila Firebase/google-services.json belum ada.
  final pushService = PushNotificationService();
  await pushService.initialize(
    supabaseClient: liveClient,
    onDeepLinkTap: (routePath) {
      container.read(appRouterProvider).go(routePath);
    },
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const HorasApp()),
  );
}
