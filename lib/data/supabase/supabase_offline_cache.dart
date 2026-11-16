import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache offline lokal (AC-15) serta antrean pesan & unggahan untuk jaringan lemah (PRD 11).
///
/// Menyimpan:
/// - Halaman pertama Feed Beranda (`posts`)
/// - Profil saya (`my_profile`)
/// - Daftar percakapan (`conversations`)
/// - Daftar sesi Main (`sessions`)
/// - Ruleset Partuturan (`partuturan_rulesets`)
/// - Antrean pesan offline & progres unggahan media agar bisa dikirim ulang / dilanjutkan.
final class SupabaseOfflineCache {
  SupabaseOfflineCache([this._prefs]);

  final SharedPreferences? _prefs;
  final Map<String, String> _memoryFallback = <String, String>{};

  String? _readStr(String key) =>
      _prefs?.getString(key) ?? _memoryFallback[key];
  Future<void> _writeStr(String key, String value) async {
    _memoryFallback[key] = value;
    await _prefs?.setString(key, value);
  }

  Future<void> _removeKey(String key) async {
    _memoryFallback.remove(key);
    await _prefs?.remove(key);
  }

  static const String _kFeedPage1 = 'horas_offline_feed_p1_v1';
  static const String _kMyProfile = 'horas_offline_my_profile_v1';
  static const String _kConversations = 'horas_offline_conversations_v1';
  static const String _kSessions = 'horas_offline_sessions_v1';
  static const String _kPartuturanRules = 'horas_offline_partuturan_rules_v1';
  static const String _kMsgOutbox = 'horas_offline_msg_outbox_v1';
  static const String _kPendingUploads = 'horas_offline_pending_uploads_v1';

  /// Penanda apakah data yang sedang dilihat berasal dari cache saat perangkat offline.
  final ValueNotifier<bool> isShowingCachedData = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastCachedAt = ValueNotifier<DateTime?>(null);

  void markLiveSync() {
    isShowingCachedData.value = false;
    lastCachedAt.value = DateTime.now().toUtc();
  }

  void markServingCache([DateTime? cachedAt]) {
    isShowingCachedData.value = true;
    if (cachedAt != null) lastCachedAt.value = cachedAt;
  }

  // ── 1. Cache Halaman-1 Feed, Profil, Percakapan, Sesi ─────────────────────

  Future<void> saveJsonList(String key, List<Map<String, Object?>> rows) async {
    final wrapper = <String, Object?>{
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'rows': rows,
    };
    await _writeStr(key, jsonEncode(wrapper));
  }

  ({List<Map<String, Object?>> rows, DateTime? cachedAt}) readJsonList(
    String key,
  ) {
    final raw = _readStr(key);
    if (raw == null || raw.isEmpty) {
      return (rows: const <Map<String, Object?>>[], cachedAt: null);
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final cachedAt = DateTime.tryParse(
        (decoded['cachedAt'] as String?) ?? '',
      );
      final list = ((decoded['rows'] as List<Object?>?) ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
      return (rows: list, cachedAt: cachedAt);
    } on Object {
      return (rows: const <Map<String, Object?>>[], cachedAt: null);
    }
  }

  Future<void> saveFeedPage1(List<Map<String, Object?>> rows) =>
      saveJsonList(_kFeedPage1, rows);
  ({List<Map<String, Object?>> rows, DateTime? cachedAt}) readFeedPage1() =>
      readJsonList(_kFeedPage1);

  Future<void> saveConversations(List<Map<String, Object?>> rows) =>
      saveJsonList(_kConversations, rows);
  ({List<Map<String, Object?>> rows, DateTime? cachedAt}) readConversations() =>
      readJsonList(_kConversations);

  Future<void> saveSessions(List<Map<String, Object?>> rows) =>
      saveJsonList(_kSessions, rows);
  ({List<Map<String, Object?>> rows, DateTime? cachedAt}) readSessions() =>
      readJsonList(_kSessions);

  Future<void> saveMyProfileJson(Map<String, Object?> profileJson) async {
    await _writeStr(
      _kMyProfile,
      jsonEncode(<String, Object?>{
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'profile': profileJson,
      }),
    );
  }

  Map<String, Object?>? readMyProfileJson() {
    final raw = _readStr(_kMyProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final p = decoded['profile'];
      if (p is Map<Object?, Object?>) {
        return p.map((k, v) => MapEntry(k.toString(), v));
      }
    } on Object {
      return null;
    }
    return null;
  }

  // ── 2. Ruleset Partuturan Cache (< 200ms) ─────────────────────────────────

  Future<void> savePartuturanRules(Map<String, String> rulesBySubSuku) async {
    await _writeStr(_kPartuturanRules, jsonEncode(rulesBySubSuku));
  }

  Map<String, String> readPartuturanRules() {
    final raw = _readStr(_kPartuturanRules);
    if (raw == null || raw.isEmpty) return const <String, String>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } on Object {
      return const <String, String>{};
    }
  }

  // ── 3. Antrean Outbox Pesan Offline (Tugas 4) ─────────────────────────────

  List<Map<String, Object?>> readMessageOutbox() =>
      readJsonList(_kMsgOutbox).rows.toList(growable: true);

  Future<void> enqueueOfflineMessage(Map<String, Object?> item) async {
    final list = readMessageOutbox();
    list.add(item);
    await saveJsonList(_kMsgOutbox, list);
  }

  Future<void> replaceMessageOutbox(List<Map<String, Object?>> items) async {
    await saveJsonList(_kMsgOutbox, items);
  }

  // ── 4. State Unggahan Media Resumable (Tugas 5) ───────────────────────────

  Map<String, Map<String, Object?>> readPendingUploads() {
    final raw = _readStr(_kPendingUploads);
    if (raw == null || raw.isEmpty) return <String, Map<String, Object?>>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      return decoded.map(
        (k, v) => MapEntry(
          k,
          (v as Map<Object?, Object?>).map(
            (ik, iv) => MapEntry(ik.toString(), iv),
          ),
        ),
      );
    } on Object {
      return <String, Map<String, Object?>>{};
    }
  }

  Future<void> savePendingUpload(
    String clientKey,
    Map<String, Object?> info,
  ) async {
    final all = readPendingUploads();
    all[clientKey] = info;
    await _writeStr(_kPendingUploads, jsonEncode(all));
  }

  Future<void> removePendingUpload(String clientKey) async {
    final all = readPendingUploads();
    if (all.remove(clientKey) != null) {
      await _writeStr(_kPendingUploads, jsonEncode(all));
    }
  }

  Future<void> clearAllUserCaches() async {
    await _removeKey(_kFeedPage1);
    await _removeKey(_kMyProfile);
    await _removeKey(_kConversations);
    await _removeKey(_kSessions);
    await _removeKey(_kMsgOutbox);
    await _removeKey(_kPendingUploads);
    isShowingCachedData.value = false;
  }

  void dispose() {
    isShowingCachedData.dispose();
    lastCachedAt.dispose();
  }
}
