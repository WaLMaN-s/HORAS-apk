import 'package:flutter/services.dart' show HapticFeedback;
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Varian gaya [AppButton] (Tahap 5 + penyempurnaan premium IG/Threads).
enum AppButtonVariant { primary, tonal, secondary, text }

/// Tombol standar HORAS dengan dukungan varian `primary`, `tonal`, `secondary`, `text`,
/// animasi tekan lembut (*press scale*), umpan balik haptik, serta status `normal`,
/// `loading`, dan `disabled`.
class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    super.key,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isDisabled = false,
    this.isExpanded = false,
    this.isDestructive = false,
    this.compact = false,
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
  final bool compact;
  final IconData? leadingIcon;
  final String? semanticsLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  bool get _canTap =>
      !widget.isDisabled && !widget.isLoading && widget.onPressed != null;

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) return;
    setState(() => _isPressed = value);
  }

  void _handleTap() {
    if (!_canTap) return;
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final Color bgColor;
    final Color fgColor;
    final BorderSide borderSide;

    final activePrimaryColor = widget.isDestructive
        ? colors.danger
        : colors.buttonPrimary;
    final activeTextColor = widget.isDestructive
        ? colors.danger
        : colors.accent;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bgColor = _canTap ? activePrimaryColor : colors.chipInactive;
        fgColor = _canTap ? colors.onPrimary : colors.textMuted;
        borderSide = BorderSide.none;
      case AppButtonVariant.tonal:
        bgColor = widget.isDestructive
            ? colors.danger.withValues(alpha: 0.12)
            : colors.chipInactive;
        fgColor = _canTap
            ? (widget.isDestructive ? colors.danger : colors.text)
            : colors.textMuted;
        borderSide = BorderSide(
          color: colors.border.withValues(alpha: 0.55),
          width: AppSizes.strokeThin,
        );
      case AppButtonVariant.secondary:
        bgColor = colors.surface;
        fgColor = _canTap ? colors.text : colors.textMuted;
        borderSide = BorderSide(
          color: _canTap ? colors.border : colors.chipInactive,
          width: AppSizes.strokeThin,
        );
      case AppButtonVariant.text:
        bgColor = const Color(0x00000000);
        fgColor = _canTap ? activeTextColor : colors.textMuted;
        borderSide = BorderSide.none;
    }

    final textStyle = (widget.compact ? typo.captionStrong : typo.bodyStrong)
        .copyWith(color: fgColor);

    final Widget childContent = Row(
      mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.isLoading) ...<Widget>[
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
        ] else if (widget.leadingIcon != null) ...<Widget>[
          Icon(
            widget.leadingIcon,
            size: widget.compact ? AppSizes.iconSm - 1 : AppSizes.iconSm,
            color: fgColor,
          ),
          SizedBox(width: widget.compact ? AppSpacing.xs + 2 : AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );

    final button = AnimatedScale(
      scale: (_isPressed && _canTap) ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: AppSizes.minTouchTarget,
          minWidth: widget.isExpanded
              ? double.infinity
              : AppSizes.minTouchTarget,
        ),
        child: Material(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
            side: borderSide,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _canTap ? _handleTap : null,
            onHighlightChanged: _canTap ? _setPressed : null,
            borderRadius: AppRadius.buttonRadius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? AppSpacing.md : AppSpacing.lg,
                vertical: widget.compact
                    ? AppSpacing.sm
                    : AppSpacing.sm + AppSpacing.xs,
              ),
              child: childContent,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _canTap,
      label: widget.semanticsLabel ?? widget.label,
      child: button,
    );
  }
}
