import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:horas/core/config/app_config.dart';
import 'package:horas/data/mock/mock_seed_data.dart';
import 'package:horas/data/supabase/supabase_offline_cache.dart';
import 'package:horas/domain/models/sub_ethnic.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/partuturan/partuturan_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Layanan Partuturan Supabase (Tugas 7):
/// - Mengambil ruleset dari tabel `partuturan_rulesets` lalu menyimpannya di cache lokal
/// - Fallback ke aset `assets/partuturan/toba.v0.json`
/// - Menghitung selisih generasi lewat RPC `generation_delta(viewer_id, target_id)`
///   agar `birth_year` pengguna lain tidak pernah dikirim ke klien.
final class SupabasePartuturanService {
  SupabasePartuturanService({
    required this.client,
    required this.cache,
    required this.appConfig,
  });

  final SupabaseClient client;
  final SupabaseOfflineCache cache;
  final AppConfig appConfig;

  Map<String, PartuturanRuleSet>? _memoryRuleSets;

  /// Mengembalikan map sub-suku -> [PartuturanRuleSet] dari memori/cache dalam < 200 ms,
  /// lalu menyinkronkan pembaruan dari `partuturan_rulesets` secara aman.
  Future<Map<String, PartuturanRuleSet>> getRuleSets({
    bool refreshFromRemote = true,
  }) async {
    if (_memoryRuleSets != null && _memoryRuleSets!.isNotEmpty) {
      return _memoryRuleSets!;
    }

    final cachedRaw = cache.readPartuturanRules();
    final loaded = <String, PartuturanRuleSet>{};
    for (final entry in cachedRaw.entries) {
      try {
        loaded[entry.key] = PartuturanRuleSet.fromJsonString(entry.value);
      } on Object {
        // Lewati entri rusak.
      }
    }

    if (loaded.isEmpty) {
      await _loadAssetFallback(loaded);
    }
    _memoryRuleSets = loaded;

    if (refreshFromRemote) {
      try {
        final rows = await client
            .from('partuturan_rulesets')
            .select('sub_ethnic, version, validated, reviewed_by, rules_json')
            .eq('is_active', true);

        final serialized = Map<String, String>.of(cachedRaw);
        for (final row in rows) {
          final sub = (row['sub_ethnic'] as String? ?? '').toLowerCase();
          final rawJsonObj = row['rules_json'];
          if (sub.isEmpty || rawJsonObj is! Map) continue;
          final normalized = Map<String, Object?>.from(rawJsonObj);
          normalized['version'] = row['version'] ?? normalized['version'];
          normalized['validated'] = row['validated'] ?? normalized['validated'];
          normalized['reviewedBy'] =
              row['reviewed_by'] ?? normalized['reviewedBy'];
          normalized['subSuku'] = sub;
          loaded[sub] = PartuturanRuleSet.fromJson(normalized);
          serialized[sub] = jsonEncode(normalized);
        }
        _memoryRuleSets = loaded;
        await cache.savePartuturanRules(serialized);
      } on Object {
        // Pertahankan cache / fallback aset bila offline.
      }
    }

    return _memoryRuleSets!;
  }

  /// Resolusi selisih generasi lewat RPC server `generation_delta(viewer_id, target_id)`.
  Future<GenerationInfo> resolveGenerationDelta({
    required String viewerId,
    required String targetId,
  }) async {
    try {
      final delta = await client.rpc<int?>(
        'generation_delta',
        params: <String, Object?>{'viewer_id': viewerId, 'target_id': targetId},
      );
      if (delta == null) return const GenerationInfo.unknown();
      return GenerationInfo(delta: delta, source: GenerationSource.sundut);
    } on Object {
      return const GenerationInfo.unknown();
    }
  }

  Future<PartuturanEngine> createEngine({
    bool refreshFromRemote = false,
  }) async {
    final sets = await getRuleSets(refreshFromRemote: refreshFromRemote);
    return PartuturanEngine(
      ruleSetsBySubSuku: sets,
      allowDraftRules: appConfig.allowDraftRules,
    );
  }

  Future<void> _loadAssetFallback(Map<String, PartuturanRuleSet> into) async {
    try {
      final raw = await rootBundle.loadString('assets/partuturan/toba.v0.json');
      into[SubEthnic.toba.name] = PartuturanRuleSet.fromJsonString(raw);
    } on Object {
      into[SubEthnic.toba.name] = PartuturanRuleSet.fromJsonString(
        MockSeedData.tobaV0RulesJson,
      );
    }
  }
}
