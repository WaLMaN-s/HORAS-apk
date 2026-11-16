import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_router.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/theme_mode_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Root widget aplikasi HORAS (Tahap 3, 4, 6).
class HorasApp extends ConsumerWidget {
  const HorasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const <Locale>[Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
