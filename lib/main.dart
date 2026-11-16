import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/app.dart';
import 'package:horas/core/utils/shared_prefs_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const HorasApp(),
    ),
  );
}
