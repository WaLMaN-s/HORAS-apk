import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Chip berbentuk pill (bulat penuh) untuk filter, sub-suku, atau badge partuturan (Tahap 4 & 5).
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    super.key,
    this.isSelected = false,
    this.onTap,
    this.leadingIcon,
    this.customBackgroundColor,
    this.customForegroundColor,
    this.semanticsLabel,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final Color? customBackgroundColor;
  final Color? customForegroundColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final bgColor =
        customBackgroundColor ??
        (isSelected ? colors.buttonPrimary : colors.chipInactive);
    final fgColor =
        customForegroundColor ?? (isSelected ? colors.onPrimary : colors.text);

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: semanticsLabel ?? label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSizes.minTouchTarget,
          minWidth: AppSizes.minTouchTarget,
        ),
        child: Material(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.pillRadius,
            side: BorderSide(
              color: isSelected ? bgColor : colors.border,
              width: AppSizes.strokeThin,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.pillRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (leadingIcon != null) ...<Widget>[
                    Icon(leadingIcon, size: AppSizes.iconSm, color: fgColor),
                    const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.captionStrong.copyWith(color: fgColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
