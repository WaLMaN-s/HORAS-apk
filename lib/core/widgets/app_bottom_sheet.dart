import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Helper bottom sheet standar HORAS dengan pegangan geser, judul, dan tombol tutup berlabel Semantics (Tahap 5).
abstract final class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTopRadius,
      ),
      builder: (sheetContext) => _BottomSheetContainer(
        title: title,
        child: child,
      ),
    );
  }
}

class _BottomSheetContainer extends StatelessWidget {
  const _BottomSheetContainer({
    required this.child,
    this.title,
  });

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenMargin,
        right: AppSpacing.screenMargin,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: AppSpacing.xxl + AppSpacing.sm,
              height: AppSpacing.xs,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: AppRadius.pillRadius,
              ),
            ),
          ),
          if (title != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(title!, style: typo.h2),
                ),
                Semantics(
                  button: true,
                  label: AppStrings.semanticsClose,
                  child: IconButton(
                    constraints: const BoxConstraints(
                      minWidth: AppSizes.minTouchTarget,
                      minHeight: AppSizes.minTouchTarget,
                    ),
                    tooltip: AppStrings.semanticsClose,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: AppSizes.iconMd,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
          ] else
            const SizedBox(height: AppSpacing.md),
          Flexible(child: child),
        ],
      ),
    );
  }
}
