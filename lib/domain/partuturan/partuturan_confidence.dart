import 'package:horas/core/l10n/app_strings.dart';

/// Tiga tingkat keyakinan hasil partuturan (PRD 1.2, TAR-R5).
enum PartuturanConfidence {
  /// Jalur tarombo terkonfirmasi kedua pihak.
  high,

  /// Inferensi marga + generasi; wajib diawali label "Kemungkinan:" (TAR-R5).
  medium,

  /// Data kurang; wajib berlabel "Belum bisa dipastikan" (TAR-R5).
  low,
}

/// Representasi hasil perhitungan mesin aturan partuturan data-driven (TAR-R5, TAR-R6).
///
/// Memastikan aturan bisnis TAR-R5: hasil [PartuturanConfidence.medium] dan
/// [PartuturanConfidence.low] tidak pernah disajikan sebagai pernyataan fakta.
sealed class PartuturanEvaluation {
  const PartuturanEvaluation();

  /// Teks tampilan UI yang mematuhi TAR-R5.
  String? get displayBadgeText;
}

/// Mode netral ketika sub-suku belum memiliki aturan tervalidasi (TAR-R6, AC-04).
final class NeutralPartuturanEvaluation extends PartuturanEvaluation {
  const NeutralPartuturanEvaluation({required this.isSameMarga});

  final bool isSameMarga;

  @override
  String? get displayBadgeText => null;
}

/// Hasil partuturan aktif dengan tingkat keyakinan eksplisit.
final class ResolvedPartuturanEvaluation extends PartuturanEvaluation {
  const ResolvedPartuturanEvaluation({
    required this.confidence,
    required this.ruleVersion,
    this.callTerm,
  });

  final PartuturanConfidence confidence;
  final String? callTerm;
  final String ruleVersion;

  @override
  String get displayBadgeText {
    final term = (callTerm ?? '').trim();
    return switch (confidence) {
      PartuturanConfidence.high =>
        term.isEmpty
            ? AppStrings.partuturanLowLabel
            : AppStrings.partuturanHighLabel(term),
      PartuturanConfidence.medium =>
        term.isEmpty
            ? AppStrings.partuturanLowLabel
            : AppStrings.partuturanMediumLabel(term),
      PartuturanConfidence.low => AppStrings.partuturanLowLabel,
    };
  }
}
