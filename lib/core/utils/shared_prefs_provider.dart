import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider untuk [SharedPreferences]; dapat di-override saat bootstrap atau pengujian.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});
