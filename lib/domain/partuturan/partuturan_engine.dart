import 'dart:convert';

import 'package:horas/domain/models/sub_ethnic.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';

/// Hubungan marga target terhadap marga di profil pelihat dalam berkas aturan JSON.
enum TargetMargaRelationType {
  sameAsViewerMarga('sameAsViewerMarga'),
  sameAsViewerMotherMarga('sameAsViewerMotherMarga');

  const TargetMargaRelationType(this.jsonCode);

  final String jsonCode;

  static TargetMargaRelationType? tryParse(String? raw) {
    for (final item in TargetMargaRelationType.values) {
      if (item.jsonCode == raw) {
        return item;
      }
    }
    return null;
  }
}

/// Satu entri aturan di dalam berkas JSON partuturan (`assets/partuturan/<subsuku>.v0.json`).
final class PartuturanRuleEntry {
  const PartuturanRuleEntry({
    required this.id,
    required this.targetMargaRelation,
    required this.viewerGenderCondition,
    required this.targetGenderCondition,
    required this.generationDelta,
    required this.requireGenerationKnown,
    required this.istilah,
    required this.confidence,
    required this.explanationTemplate,
    this.followUpQuestion,
  });

  final String id;
  final TargetMargaRelationType targetMargaRelation;
  final String viewerGenderCondition; // 'male' | 'female' | 'any'
  final String targetGenderCondition; // 'male' | 'female' | 'any'
  final int? generationDelta;
  final bool requireGenerationKnown;
  final String istilah;
  final PartuturanConfidence confidence;
  final String explanationTemplate;
  final String? followUpQuestion;

  factory PartuturanRuleEntry.fromJson(Map<String, Object?> json) {
    final rel = TargetMargaRelationType.tryParse(
      json['targetMargaRelation'] as String?,
    );
    if (rel == null) {
      throw FormatException(
        'Invalid targetMargaRelation in rule ${json['id']}',
      );
    }
    return PartuturanRuleEntry(
      id: (json['id'] as String?) ?? 'rule',
      targetMargaRelation: rel,
      viewerGenderCondition: (json['viewerGender'] as String?) ?? 'any',
      targetGenderCondition: (json['targetGender'] as String?) ?? 'any',
      generationDelta: json['generationDelta'] as int?,
      requireGenerationKnown: (json['requireGenerationKnown'] as bool?) ?? true,
      istilah: (json['istilah'] as String?) ?? '',
      confidence: PartuturanConfidence.fromJson(json['confidence'] as String?),
      explanationTemplate: (json['explanationTemplate'] as String?) ?? '',
      followUpQuestion: json['followUpQuestion'] as String?,
    );
  }

  bool matches({
    required TargetMargaRelationType relation,
    required UserGender viewerGender,
    required UserGender targetGender,
    required GenerationInfo generationInfo,
  }) {
    if (targetMargaRelation != relation) {
      return false;
    }
    if (viewerGenderCondition != 'any' &&
        viewerGenderCondition != viewerGender.jsonCode) {
      return false;
    }
    if (targetGenderCondition != 'any' &&
        targetGenderCondition != targetGender.jsonCode) {
      return false;
    }
    if (requireGenerationKnown && !generationInfo.isKnown) {
      return false;
    }
    if (generationDelta != null && generationInfo.delta != generationDelta) {
      return false;
    }
    return true;
  }
}

/// Set aturan partuturan satu sub-suku yang dimuat dari JSON berversi (TAR-R6).
final class PartuturanRuleSet {
  const PartuturanRuleSet({
    required this.version,
    required this.subSuku,
    required this.validated,
    required this.defaultLowExplanation,
    required this.defaultLowQuestion,
    required this.missingMotherMargaQuestion,
    required this.missingGenerationQuestion,
    required this.rules,
    this.reviewedBy,
  });

  final String version;
  final String subSuku;
  final bool validated;
  final String? reviewedBy;
  final String defaultLowExplanation;
  final String defaultLowQuestion;
  final String missingMotherMargaQuestion;
  final String missingGenerationQuestion;
  final List<PartuturanRuleEntry> rules;

  factory PartuturanRuleSet.fromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, Object?>;
    return PartuturanRuleSet.fromJson(decoded);
  }

  factory PartuturanRuleSet.fromJson(Map<String, Object?> json) {
    final rawRules = (json['rules'] as List<Object?>?) ?? const <Object?>[];
    return PartuturanRuleSet(
      version: (json['version'] as String?) ?? '0.0.0',
      subSuku: ((json['subSuku'] as String?) ?? '').toLowerCase(),
      validated: (json['validated'] as bool?) ?? false,
      reviewedBy: json['reviewedBy'] as String?,
      defaultLowExplanation: (json['defaultLowExplanation'] as String?) ?? '',
      defaultLowQuestion: (json['defaultLowQuestion'] as String?) ?? '',
      missingMotherMargaQuestion:
          (json['missingMotherMargaQuestion'] as String?) ?? '',
      missingGenerationQuestion:
          (json['missingGenerationQuestion'] as String?) ?? '',
      rules: rawRules
          .whereType<Map<String, Object?>>()
          .map(PartuturanRuleEntry.fromJson)
          .toList(growable: false),
    );
  }
}

/// Input murni untuk evaluasi mesin partuturan (tanpa tahun lahir orang lain — PRD 7.1).
final class PartuturanEvaluationInput {
  const PartuturanEvaluationInput({
    required this.viewerMarga,
    required this.viewerGender,
    required this.subEthnic,
    required this.targetMarga,
    required this.targetGender,
    required this.generationInfo,
    this.viewerMotherMarga,
    this.confirmedKinshipTerm,
  });

  final String viewerMarga;
  final UserGender viewerGender;
  final String? viewerMotherMarga;
  final SubEthnic subEthnic;
  final String targetMarga;
  final UserGender targetGender;
  final GenerationInfo generationInfo;

  /// Hanya terisi apabila ada klaim hubungan kerabat yang dikonfirmasi kedua pihak (TAR-R5, TAR-R7).
  final String? confirmedKinshipTerm;
}

/// Mesin aturan partuturan data-driven (TAR-R5, TAR-R6, Prompt 2 Bagian F).
///
/// Seluruh istilah partuturan dibaca dari [PartuturanRuleSet] JSON berversi,
/// tidak ada istilah partuturan yang dikodekan keras di kode Dart.
final class PartuturanEngine {
  const PartuturanEngine({
    required Map<String, PartuturanRuleSet> ruleSetsBySubSuku,
    required this.allowDraftRules,
  }) : _ruleSets = ruleSetsBySubSuku;

  final Map<String, PartuturanRuleSet> _ruleSets;
  final bool allowDraftRules;

  static String _norm(String? marga) => (marga ?? '').trim().toLowerCase();

  PartuturanResult evaluate(PartuturanEvaluationInput input) {
    final vMarga = _norm(input.viewerMarga);
    final tMarga = _norm(input.targetMarga);
    final mMarga = _norm(input.viewerMotherMarga);
    final isSemarga = vMarga.isNotEmpty && vMarga == tMarga;

    final subKey = input.subEthnic.name.toLowerCase();
    final ruleSet = _ruleSets[subKey];

    // TAR-R6 & AC-04: sub-suku tanpa berkas aturan, atau aturan belum tervalidasi saat
    // allowDraftRules == false, berjalan di mode netral (tanpa badge partuturan; Semarga tetap).
    if (ruleSet == null || (!ruleSet.validated && !allowDraftRules)) {
      return PartuturanResult(
        confidence: PartuturanConfidence.rendah,
        penjelasanJalur: '',
        versiAturan: ruleSet?.version ?? 'neutral',
        modeNetral: true,
        isDraftRule: false,
        isSemarga: isSemarga,
      );
    }

    final isDraft = !ruleSet.validated;

    // TAR-R5 & TAR-R7: Tingkat Tinggi HANYA bila ada jalur tarombo / klaim yang dikonfirmasi kedua pihak.
    final confirmedTerm = (input.confirmedKinshipTerm ?? '').trim();
    if (confirmedTerm.isNotEmpty) {
      return PartuturanResult(
        confidence: PartuturanConfidence.tinggi,
        istilah: confirmedTerm,
        penjelasanJalur: 'Hubungan kekerabatan telah dikonfirmasi oleh kedua pihak dalam Tarombo.',
        versiAturan: ruleSet.version,
        modeNetral: false,
        isDraftRule: isDraft,
        isSemarga: isSemarga,
      );
    }

    // Tentukan relasi marga target terhadap marga pelihat / marga ibu pelihat
    TargetMargaRelationType? relation;
    if (isSemarga) {
      relation = TargetMargaRelationType.sameAsViewerMarga;
    } else if (mMarga.isNotEmpty && tMarga == mMarga) {
      relation = TargetMargaRelationType.sameAsViewerMotherMarga;
    }

    if (relation != null) {
      for (final rule in ruleSet.rules) {
        if (rule.matches(
          relation: relation,
          viewerGender: input.viewerGender,
          targetGender: input.targetGender,
          generationInfo: input.generationInfo,
        )) {
          final explanation = _interpolate(
            rule.explanationTemplate,
            viewerMarga: input.viewerMarga,
            viewerMotherMarga: input.viewerMotherMarga ?? '',
            targetMarga: input.targetMarga,
          );
          // Inferensi dari aturan maksimal menghasilkan tingkat Sedang (TAR-R5).
          final effectiveConfidence =
              rule.confidence == PartuturanConfidence.tinggi
              ? PartuturanConfidence.sedang
              : rule.confidence;
          return PartuturanResult(
            confidence: effectiveConfidence,
            istilah: rule.istilah,
            penjelasanJalur: explanation,
            pertanyaanPelengkap: rule.followUpQuestion,
            versiAturan: ruleSet.version,
            modeNetral: false,
            isDraftRule: isDraft,
            isSemarga: isSemarga,
          );
        }
      }
    }

    // TAR-R1 & TAR-R5: Data kurang atau kasus belum tercakup di aturan -> tingkat Rendah + pertanyaan pelengkap.
    final String followUp;
    if (mMarga.isEmpty) {
      followUp = ruleSet.missingMotherMargaQuestion;
    } else if (!input.generationInfo.isKnown) {
      followUp = ruleSet.missingGenerationQuestion;
    } else {
      followUp = ruleSet.defaultLowQuestion;
    }

    return PartuturanResult(
      confidence: PartuturanConfidence.rendah,
      penjelasanJalur: ruleSet.defaultLowExplanation,
      pertanyaanPelengkap: followUp,
      versiAturan: ruleSet.version,
      modeNetral: false,
      isDraftRule: isDraft,
      isSemarga: isSemarga,
    );
  }

  static String _interpolate(
    String template, {
    required String viewerMarga,
    required String viewerMotherMarga,
    required String targetMarga,
  }) {
    return template
        .replaceAll('{viewerMarga}', viewerMarga)
        .replaceAll('{viewerMotherMarga}', viewerMotherMarga)
        .replaceAll('{targetMarga}', targetMarga);
  }
}

/// Penghitung selisih generasi di sisi "server" (repository) sehingga klien tidak
/// pernah menerima tahun lahir orang lain (PRD 7.1, Prompt 2 Bagian F).
final class GenerationResolver {
  const GenerationResolver();

  /// Menghitung [GenerationInfo] dari sundut eksplisit (prioritas 1) atau perkiraan
  /// rentang tahun lahir di sisi server (~25 tahun per generasi).
  GenerationInfo resolve({
    int? viewerSundut,
    int? targetSundut,
    int? viewerBirthYear,
    int? targetBirthYear,
  }) {
    if (viewerSundut != null && targetSundut != null) {
      // Sundut lebih kecil berarti generasi lebih tua (di atas pelihat -> delta positif).
      return GenerationInfo(
        delta: viewerSundut - targetSundut,
        source: GenerationSource.sundut,
      );
    }
    if (viewerBirthYear != null && targetBirthYear != null) {
      final yearDiff = viewerBirthYear - targetBirthYear;
      if (yearDiff >= 15) {
        final gensAbove = ((yearDiff + 10) ~/ 25).clamp(1, 3);
        return GenerationInfo(
          delta: gensAbove,
          source: GenerationSource.tahunLahir,
        );
      }
      if (yearDiff <= -15) {
        final gensBelow = ((-yearDiff + 10) ~/ 25).clamp(1, 3);
        return GenerationInfo(
          delta: -gensBelow,
          source: GenerationSource.tahunLahir,
        );
      }
      return const GenerationInfo(
        delta: 0,
        source: GenerationSource.tahunLahir,
      );
    }
    return const GenerationInfo.unknown();
  }
}
