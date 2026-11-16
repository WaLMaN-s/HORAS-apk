import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Helper pengujian widget yang membungkus komponen dengan [ProviderScope] dan [AppTheme].
Future<void> pumpHorasWidget(
  WidgetTester tester,
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}
