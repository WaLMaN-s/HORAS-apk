import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Penyimpanan sesi JWT Supabase Auth yang dienkripsi di `flutter_secure_storage` (Tugas 3).
final class SecureSupabaseLocalStorage extends LocalStorage {
  SecureSupabaseLocalStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _sessionKey = 'horas_supabase_persist_session_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    try {
      final raw = await _storage.read(key: _sessionKey);
      return raw != null && raw.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: _sessionKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _sessionKey);
  }
}
