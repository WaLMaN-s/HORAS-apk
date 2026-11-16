import 'package:material_ui/material_ui.dart';

/// Skala tipografi aplikasi HORAS sebagai [ThemeExtension] (Tahap 4).
///
/// - Serif tebal (`PlayfairDisplay`) HANYA untuk wordmark "Horas".
/// - Seluruh UI memakai `PlusJakartaSans`.
/// - Skala: Display 32, H1 24, H2 20, H3 17, Body 15, Caption 13, Micro 11.
@immutable
final class HorasTypography extends ThemeExtension<HorasTypography> {
  const HorasTypography({
    required this.wordmark,
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.captionStrong,
    required this.micro,
  });

  static const String uiFontFamily = 'PlusJakartaSans';
  static const String wordmarkFontFamily = 'PlayfairDisplay';

  factory HorasTypography.forColor(Color textColor, Color mutedColor) {
    return HorasTypography(
      wordmark: TextStyle(
        fontFamily: wordmarkFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.3,
        color: textColor,
      ),
      display: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.5,
        color: textColor,
      ),
      h1: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
        color: textColor,
      ),
      h2: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
        color: textColor,
      ),
      h3: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: textColor,
      ),
      body: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: textColor,
      ),
      bodyStrong: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: textColor,
      ),
      caption: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: mutedColor,
      ),
      captionStrong: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: textColor,
      ),
      micro: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.2,
        color: mutedColor,
      ),
    );
  }

  /// Khusus wordmark "Horas" (Playfair Display).
  final TextStyle wordmark;

  /// Display 32.
  final TextStyle display;

  /// H1 24.
  final TextStyle h1;

  /// H2 20.
  final TextStyle h2;

  /// H3 17.
  final TextStyle h3;

  /// Body 15.
  final TextStyle body;

  /// Body 15 semi-tebal (tombol/label utama).
  final TextStyle bodyStrong;

  /// Caption 13.
  final TextStyle caption;

  /// Caption 13 semi-tebal.
  final TextStyle captionStrong;

  /// Micro 11.
  final TextStyle micro;

  @override
  HorasTypography copyWith({
    TextStyle? wordmark,
    TextStyle? display,
    TextStyle? h1,
    TextStyle? h2,
    TextStyle? h3,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? caption,
    TextStyle? captionStrong,
    TextStyle? micro,
  }) {
    return HorasTypography(
      wordmark: wordmark ?? this.wordmark,
      display: display ?? this.display,
      h1: h1 ?? this.h1,
      h2: h2 ?? this.h2,
      h3: h3 ?? this.h3,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      caption: caption ?? this.caption,
      captionStrong: captionStrong ?? this.captionStrong,
      micro: micro ?? this.micro,
    );
  }

  @override
  HorasTypography lerp(ThemeExtension<HorasTypography>? other, double t) {
    if (other is! HorasTypography) {
      return this;
    }
    return HorasTypography(
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      h1: TextStyle.lerp(h1, other.h1, t)!,
      h2: TextStyle.lerp(h2, other.h2, t)!,
      h3: TextStyle.lerp(h3, other.h3, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      captionStrong: TextStyle.lerp(captionStrong, other.captionStrong, t)!,
      micro: TextStyle.lerp(micro, other.micro, t)!,
    );
  }
}
