import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/utils/shared_prefs_provider.dart';
import 'package:material_ui/material_ui.dart';

/// Kunci penyimpanan mode tema di `SharedPreferences` (Tahap 4).
const String kThemeModePrefsKey = 'horas.theme_mode';

/// Pengendali mode tema tampilan (mengikuti sistem secara bawaan, dapat diganti pengguna).
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs?.getString(kThemeModePrefsKey);
    return _parse(saved);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(kThemeModePrefsKey, mode.name);
  }

  Future<void> cycleThemeMode() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setThemeMode(next);
  }

  static ThemeMode _parse(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

/// Provider global untuk mode tema aplikasi.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
