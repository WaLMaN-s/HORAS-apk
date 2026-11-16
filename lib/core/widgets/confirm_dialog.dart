import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/app_button.dart';
import 'package:material_ui/material_ui.dart';

/// Dialog konfirmasi tindakan penting/merusak dengan tombol berlabel jelas (PRD 5.2, Tahap 5).
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    super.key,
    this.cancelLabel = AppStrings.actionCancel,
    this.isDestructive = false,
    this.onConfirm,
    this.onCancel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  /// Menampilkan dialog konfirmasi dan mengembalikan `true` bila pengguna menekan tombol konfirmasi.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = AppStrings.actionCancel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;

    return AlertDialog(
      title: Text(title, style: typo.h2),
      content: Text(message, style: typo.body),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton(
                label: cancelLabel,
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                onPressed:
                    onCancel ?? () => Navigator.of(context).maybePop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: confirmLabel,
                variant: AppButtonVariant.primary,
                isDestructive: isDestructive,
                isExpanded: true,
                onPressed:
                    onConfirm ?? () => Navigator.of(context).maybePop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
