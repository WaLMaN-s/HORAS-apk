import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Varian gaya [AppButton] (Tahap 5).
enum AppButtonVariant { primary, secondary, text }

/// Tombol standar HORAS dengan dukungan varian `primary`, `secondary`, `text`
/// serta status `normal`, `loading`, dan `disabled`.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    super.key,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isDisabled = false,
    this.isExpanded = false,
    this.isDestructive = false,
    this.leadingIcon,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isDisabled;
  final bool isExpanded;
  final bool isDestructive;
  final IconData? leadingIcon;
  final String? semanticsLabel;

  bool get _canTap => !isDisabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final Color bgColor;
    final Color fgColor;
    final BorderSide borderSide;

    final activePrimaryColor = isDestructive
        ? colors.danger
        : colors.buttonPrimary;
    final activeTextColor = isDestructive ? colors.danger : colors.accent;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = _canTap ? activePrimaryColor : colors.chipInactive;
        fgColor = _canTap ? colors.onPrimary : colors.textMuted;
        borderSide = BorderSide.none;
      case AppButtonVariant.secondary:
        bgColor = colors.surface;
        fgColor = _canTap ? colors.text : colors.textMuted;
        borderSide = BorderSide(
          color: _canTap ? colors.border : colors.chipInactive,
          width: AppSizes.strokeMedium,
        );
      case AppButtonVariant.text:
        bgColor = const Color(0x00000000);
        fgColor = _canTap ? activeTextColor : colors.textMuted;
        borderSide = BorderSide.none;
    }

    final Widget childContent = Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (isLoading) ...<Widget>[
          SizedBox(
            width: AppSizes.iconSm,
            height: AppSizes.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.strokeThick,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
              semanticsLabel: AppStrings.semanticsLoading,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (leadingIcon != null) ...<Widget>[
          Icon(leadingIcon, size: AppSizes.iconSm, color: fgColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.bodyStrong.copyWith(color: fgColor),
          ),
        ),
      ],
    );

    final button = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: AppSizes.minTouchTarget,
        minWidth: isExpanded ? double.infinity : AppSizes.minTouchTarget,
      ),
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.buttonRadius,
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _canTap ? onPressed : null,
          borderRadius: AppRadius.buttonRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
            child: childContent,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _canTap,
      label: semanticsLabel ?? label,
      child: button,
    );
  }
}
