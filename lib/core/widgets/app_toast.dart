import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Varian pemberitahuan singkat [AppToast] (Tahap 5).
enum AppToastVariant { info, success, warning, error }

/// Helper untuk menampilkan pesan mengambang (toast/snackbar) bertema HORAS.
abstract final class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    AppToastVariant variant = AppToastVariant.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = context.colors;
    final typo = context.typo;

    final (Color bgColor, IconData icon) = switch (variant) {
      AppToastVariant.info => (colors.text, Icons.info_outline_rounded),
      AppToastVariant.success => (
        colors.success,
        Icons.check_circle_outline_rounded,
      ),
      AppToastVariant.warning => (
        colors.confidenceAmber,
        Icons.warning_amber_rounded,
      ),
      AppToastVariant.error => (colors.danger, Icons.error_outline_rounded),
    };

    final fgColor = variant == AppToastVariant.info
        ? colors.surface
        : colors.onPrimary;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.lg),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          content: Row(
            children: <Widget>[
              Icon(icon, size: AppSizes.iconMd, color: fgColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: typo.body.copyWith(color: fgColor),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
