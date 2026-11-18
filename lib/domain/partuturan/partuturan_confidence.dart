import 'package:horas/core/l10n/app_strings.dart';

/// Jenis kelamin pengguna untuk evaluasi silsilah dan partuturan (AUT-R5, TAR-R1).
enum UserGender {
  male('male', 'Laki-laki'),
  female('female', 'Perempuan');

  const UserGender(this.jsonCode, this.label);

  final String jsonCode;
  final String label;

  static UserGender fromJson(String? raw) {
    return raw == 'female' ? UserGender.female : UserGender.male;
  }
}

/// Sumber perhitungan selisih generasi di sisi "server" (Prompt 2 Bagian F).
///
/// Mesin partuturan di klien tidak pernah menerima tahun lahir orang lain (PRD 7.1).
enum GenerationSource {
  sundut('sundut'),
  tahunLahir('tahunLahir'),
  tidakDiketahui('tidakDiketahui');

  const GenerationSource(this.jsonCode);

  final String jsonCode;

  static GenerationSource fromJson(String? raw) {
    return switch (raw) {
      'sundut' => GenerationSource.sundut,
      'tahunLahir' => GenerationSource.tahunLahir,
      _ => GenerationSource.tidakDiketahui,
    };
  }
}

/// Informasi selisih generasi dan rentang selisih usia yang dihitung oleh `GenerationResolver`
/// tanpa membocorkan tahun lahir pasti ke DTO orang lain.
///
/// `delta == 1` berarti target satu generasi di atas pelihat;
/// `delta == 0` berarti generasi sejajar;
/// `delta == -1` berarti satu generasi di bawah pelihat.
/// `ageDifferenceYears` positif berarti target lebih tua N tahun dari pelihat;
/// negatif berarti target lebih muda N tahun dari pelihat.
final class GenerationInfo {
  const GenerationInfo({
    required this.source,
    this.delta,
    this.ageDifferenceYears,
  });

  const GenerationInfo.unknown()
    : delta = null,
      ageDifferenceYears = null,
      source = GenerationSource.tidakDiketahui;

  final int? delta;
  final int? ageDifferenceYears;
  final GenerationSource source;

  bool get isKnown =>
      delta != null && source != GenerationSource.tidakDiketahui;

  Map<String, Object?> toJson() => <String, Object?>{
    'delta': delta,
    'ageDifferenceYears': ageDifferenceYears,
    'source': source.jsonCode,
  };

  factory GenerationInfo.fromJson(Map<String, Object?> json) {
    return GenerationInfo(
      delta: json['delta'] as int?,
      ageDifferenceYears: json['ageDifferenceYears'] as int?,
      source: GenerationSource.fromJson(json['source'] as String?),
    );
  }
}

/// Tiga tingkat keyakinan hasil partuturan (PRD 1.2, TAR-R5).
enum PartuturanConfidence {
  /// Jalur tarombo terkonfirmasi kedua pihak.
  tinggi,

  /// Inferensi marga + generasi; wajib diawali label "Kemungkinan:" (TAR-R5).
  sedang,

  /// Data kurang; wajib berlabel "Belum bisa dipastikan" (TAR-R5).
  rendah;

  static const PartuturanConfidence high = PartuturanConfidence.tinggi;
  static const PartuturanConfidence medium = PartuturanConfidence.sedang;
  static const PartuturanConfidence low = PartuturanConfidence.rendah;

  static PartuturanConfidence fromJson(String? raw) {
    return switch (raw?.toLowerCase()) {
      'tinggi' || 'high' => PartuturanConfidence.tinggi,
      'sedang' || 'medium' => PartuturanConfidence.sedang,
      _ => PartuturanConfidence.rendah,
    };
  }
}

/// Hasil evaluasi mesin partuturan data-driven (TAR-R5, TAR-R6, Prompt 2 Bagian F).
///
/// Mematuhi TAR-R5:
/// - `tinggi` hanya bila jalur tarombo dikonfirmasi kedua pihak: `"Dia adalah <istilah>mu"`
/// - `sedang` dari inferensi marga + generasi: `"Kemungkinan: <istilah>"` (berlabel "Perkiraan")
/// - `rendah` bila data kurang: "Belum bisa dipastikan" + pertanyaan pelengkap (berlabel "Perkiraan")
/// - `modeNetral == true` bila sub-suku belum punya aturan tervalidasi (atau aturan draf dimatikan).
final class PartuturanResult {
  const PartuturanResult({
    required this.confidence,
    required this.penjelasanJalur,
    required this.versiAturan,
    required this.modeNetral,
    this.istilah,
    this.pertanyaanPelengkap,
    this.isDraftRule = false,
    this.isSemarga = false,
  });

  final PartuturanConfidence confidence;
  final String? istilah;
  final String penjelasanJalur;
  final String? pertanyaanPelengkap;
  final String versiAturan;
  final bool modeNetral;
  final bool isDraftRule;
  final bool isSemarga;

  /// Hasil Sedang dan Rendah selalu berlabel "Perkiraan" dan tidak pernah disajikan sebagai fakta (TAR-R5, TAR-R9).
  bool get isEstimate =>
      !modeNetral && confidence != PartuturanConfidence.tinggi;

  String? get estimateLabel => isEstimate ? AppStrings.termPerkiraan : null;

  /// Teks tampilan pada badge partuturan; `null` apabila `modeNetral == true`.
  String? get displayBadgeText {
    if (modeNetral) {
      return null;
    }
    final cleanTerm = (istilah ?? '').trim();
    return switch (confidence) {
      PartuturanConfidence.tinggi =>
        cleanTerm.isEmpty
            ? AppStrings.partuturanLowLabel
            : AppStrings.partuturanHighLabel(cleanTerm),
      PartuturanConfidence.sedang =>
        cleanTerm.isEmpty
            ? AppStrings.partuturanLowLabel
            : AppStrings.partuturanMediumLabel(cleanTerm),
      PartuturanConfidence.rendah => AppStrings.partuturanLowLabel,
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'confidence': confidence.name,
    'istilah': istilah,
    'penjelasanJalur': penjelasanJalur,
    'pertanyaanPelengkap': pertanyaanPelengkap,
    'versiAturan': versiAturan,
    'modeNetral': modeNetral,
    'isDraftRule': isDraftRule,
    'isSemarga': isSemarga,
  };

  factory PartuturanResult.fromJson(Map<String, Object?> json) {
    return PartuturanResult(
      confidence: PartuturanConfidence.fromJson(json['confidence'] as String?),
      istilah: json['istilah'] as String?,
      penjelasanJalur: (json['penjelasanJalur'] as String?) ?? '',
      pertanyaanPelengkap: json['pertanyaanPelengkap'] as String?,
      versiAturan: (json['versiAturan'] as String?) ?? '0.0.0',
      modeNetral: (json['modeNetral'] as bool?) ?? true,
      isDraftRule: (json['isDraftRule'] as bool?) ?? false,
      isSemarga: (json['isSemarga'] as bool?) ?? false,
    );
  }
}
