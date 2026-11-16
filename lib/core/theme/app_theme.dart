import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/theme/horas_colors.dart';
import 'package:horas/core/theme/horas_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Pembangun [ThemeData] Light dan Dark untuk aplikasi HORAS (Tahap 4).
abstract final class AppTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    colors: HorasColors.light,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    colors: HorasColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required HorasColors colors,
  }) {
    final typo = HorasTypography.forColor(colors.text, colors.textMuted);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.buttonPrimary,
      onPrimary: colors.onPrimary,
      secondary: colors.accent,
      onSecondary: colors.onPrimary,
      error: colors.danger,
      onError: colors.onPrimary,
      surface: colors.surface,
      onSurface: colors.text,
      outline: colors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: HorasTypography.uiFontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surface,
      dividerColor: colors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typo.h2,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: AppSizes.strokeThin,
        space: AppSizes.strokeThin,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.text,
        contentTextStyle: typo.body.copyWith(color: colors.surface),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonRadius,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTopRadius,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
        titleTextStyle: typo.h2,
        contentTextStyle: typo.body,
      ),
      textTheme: TextTheme(
        displayLarge: typo.display,
        headlineLarge: typo.h1,
        headlineMedium: typo.h2,
        titleLarge: typo.h3,
        bodyLarge: typo.body,
        bodyMedium: typo.body,
        bodySmall: typo.caption,
        labelLarge: typo.bodyStrong,
        labelSmall: typo.micro,
      ),
      extensions: <ThemeExtension<dynamic>>[
        colors,
        typo,
      ],
    );
  }
}

/// Ekstensi akses cepat token warna dan tipografi dari [BuildContext].
extension HorasThemeContextX on BuildContext {
  HorasColors get colors =>
      Theme.of(this).extension<HorasColors>() ?? HorasColors.light;

  HorasTypography get typo =>
      Theme.of(this).extension<HorasTypography>() ??
      HorasTypography.forColor(colors.text, colors.textMuted);
}
