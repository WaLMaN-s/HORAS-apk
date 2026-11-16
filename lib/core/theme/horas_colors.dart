import 'package:material_ui/material_ui.dart';

/// Token warna aplikasi HORAS sebagai [ThemeExtension] (Tahap 4).
///
/// Seluruh widget wajib mengambil warna lewat `context.colors`, bukan hardcode.
@immutable
final class HorasColors extends ThemeExtension<HorasColors> {
  const HorasColors({
    required this.primary,
    required this.primaryDark,
    required this.splashRed,
    required this.background,
    required this.surface,
    required this.chipInactive,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.verifiedBlue,
    required this.ratingGold,
    required this.success,
    required this.danger,
    required this.confidenceAmber,
    required this.confidenceAmberSurface,
    required this.buttonPrimary,
    required this.accent,
    required this.onPrimary,
    required this.shadow,
  });

  /// Palet terang sesuai spesifikasi Tahap 4 (kontras teks >= 4.5:1).
  static const HorasColors light = HorasColors(
    primary: Color(0xFF8A1C27),
    primaryDark: Color(0xFF6B1420),
    splashRed: Color(0xFFA82230),
    background: Color(0xFFFBF7F3),
    surface: Color(0xFFFFFFFF),
    chipInactive: Color(0xFFF3ECE8),
    border: Color(0xFFEADFD8),
    text: Color(0xFF1F1A1A),
    textMuted: Color(0xFF6B6260),
    verifiedBlue: Color(0xFF1D9BF0),
    ratingGold: Color(0xFFE8A317),
    success: Color(0xFF2E7D4F),
    danger: Color(0xFFC62828),
    confidenceAmber: Color(0xFF8C5300),
    confidenceAmberSurface: Color(0xFFFFF3DC),
    buttonPrimary: Color(0xFF8A1C27),
    accent: Color(0xFF8A1C27),
    onPrimary: Color(0xFFFFFFFF),
    shadow: Color(0x0D1F1A1A),
  );

  /// Palet gelap sesuai spesifikasi Tahap 4 (kontras teks >= 4.5:1).
  static const HorasColors dark = HorasColors(
    primary: Color(0xFF8A1C27),
    primaryDark: Color(0xFF6B1420),
    splashRed: Color(0xFFA82230),
    background: Color(0xFF141010),
    surface: Color(0xFF221A1A),
    chipInactive: Color(0xFF2D2323),
    border: Color(0xFF3A2E2E),
    text: Color(0xFFF5EFEA),
    textMuted: Color(0xFFB5A9A4),
    verifiedBlue: Color(0xFF1D9BF0),
    ratingGold: Color(0xFFE8A317),
    success: Color(0xFF54B67B),
    danger: Color(0xFFEF5350),
    confidenceAmber: Color(0xFFFFC266),
    confidenceAmberSurface: Color(0xFF382812),
    buttonPrimary: Color(0xFFC62828),
    accent: Color(0xFFF26B6B),
    onPrimary: Color(0xFFFFFFFF),
    shadow: Color(0x33000000),
  );

  /// Token warna juga disediakan tepat dengan nilai referensi `#7A7270` untuk konstanta brand.
  static const Color referenceLightTextMuted = Color(0xFF7A7270);

  final Color primary;
  final Color primaryDark;
  final Color splashRed;
  final Color background;
  final Color surface;
  final Color chipInactive;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color verifiedBlue;
  final Color ratingGold;
  final Color success;
  final Color danger;

  /// Warna amber untuk tingkat keyakinan partuturan Sedang (TAR-R5).
  final Color confidenceAmber;
  final Color confidenceAmberSurface;

  /// Warna tombol utama (#8A1C27 di light, #C62828 di dark).
  final Color buttonPrimary;

  /// Warna aksen interaktif (#8A1C27 di light, #F26B6B di dark).
  final Color accent;

  /// Warna teks/ikon di atas permukaan tombol utama.
  final Color onPrimary;

  /// Warna bayangan sangat lembut.
  final Color shadow;

  @override
  HorasColors copyWith({
    Color? primary,
    Color? primaryDark,
    Color? splashRed,
    Color? background,
    Color? surface,
    Color? chipInactive,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? verifiedBlue,
    Color? ratingGold,
    Color? success,
    Color? danger,
    Color? confidenceAmber,
    Color? confidenceAmberSurface,
    Color? buttonPrimary,
    Color? accent,
    Color? onPrimary,
    Color? shadow,
  }) {
    return HorasColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      splashRed: splashRed ?? this.splashRed,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      chipInactive: chipInactive ?? this.chipInactive,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      verifiedBlue: verifiedBlue ?? this.verifiedBlue,
      ratingGold: ratingGold ?? this.ratingGold,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      confidenceAmber: confidenceAmber ?? this.confidenceAmber,
      confidenceAmberSurface:
          confidenceAmberSurface ?? this.confidenceAmberSurface,
      buttonPrimary: buttonPrimary ?? this.buttonPrimary,
      accent: accent ?? this.accent,
      onPrimary: onPrimary ?? this.onPrimary,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  HorasColors lerp(ThemeExtension<HorasColors>? other, double t) {
    if (other is! HorasColors) {
      return this;
    }
    return HorasColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      splashRed: Color.lerp(splashRed, other.splashRed, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      chipInactive: Color.lerp(chipInactive, other.chipInactive, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      verifiedBlue: Color.lerp(verifiedBlue, other.verifiedBlue, t)!,
      ratingGold: Color.lerp(ratingGold, other.ratingGold, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      confidenceAmber: Color.lerp(confidenceAmber, other.confidenceAmber, t)!,
      confidenceAmberSurface: Color.lerp(
        confidenceAmberSurface,
        other.confidenceAmberSurface,
        t,
      )!,
      buttonPrimary: Color.lerp(buttonPrimary, other.buttonPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
