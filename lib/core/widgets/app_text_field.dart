import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Kolom input teks standar HORAS dengan status `default`, `focus`, dan `error` (Tahap 5).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.leadingIcon,
    this.suffixIcon,
    this.suffixSemanticsLabel,
    this.onSuffixTap,
    this.onChanged,
    this.onSubmitted,
  });

  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final IconData? leadingIcon;
  final IconData? suffixIcon;
  final String? suffixSemanticsLabel;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _internalFocusNode;
  bool _hasFocus = false;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _hasFocus = _effectiveFocusNode.hasFocus;
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      _hasFocus = _effectiveFocusNode.hasFocus;
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_handleFocusChange);
    _internalFocusNode?.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  bool get _hasError =>
      widget.errorText != null && widget.errorText!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final borderColor = _hasError
        ? colors.danger
        : (_hasFocus ? colors.accent : colors.border);

    final borderWidth = (_hasFocus || _hasError)
        ? AppSizes.strokeMedium
        : AppSizes.strokeThin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            widget.label!,
            style: typo.captionStrong.copyWith(
              color: _hasError ? colors.danger : colors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.enabled ? colors.surface : colors.chipInactive,
            borderRadius: AppRadius.buttonRadius,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: typo.body,
            cursorColor: colors.accent,
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              hintStyle: typo.body.copyWith(color: colors.textMuted),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              border: InputBorder.none,
              prefixIcon: widget.leadingIcon != null
                  ? Icon(
                      widget.leadingIcon,
                      size: AppSizes.iconMd,
                      color: _hasFocus ? colors.accent : colors.textMuted,
                    )
                  : null,
              suffixIcon: widget.suffixIcon != null
                  ? Semantics(
                      button: widget.onSuffixTap != null,
                      label:
                          widget.suffixSemanticsLabel ??
                          AppStrings.semanticsClearInput,
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSizes.minTouchTarget,
                          minHeight: AppSizes.minTouchTarget,
                        ),
                        tooltip:
                            widget.suffixSemanticsLabel ??
                            AppStrings.semanticsClearInput,
                        onPressed: widget.onSuffixTap,
                        icon: Icon(
                          widget.suffixIcon,
                          size: AppSizes.iconSm,
                          color: colors.textMuted,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (_hasError) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: typo.caption.copyWith(color: colors.danger),
          ),
        ] else if (widget.helperText != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.helperText!, style: typo.caption),
        ],
      ],
    );
  }
}
