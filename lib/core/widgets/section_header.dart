import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Header bagian dengan judul, subjudul opsional, dan tombol aksi kanan (Tahap 5).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final effectiveActionLabel = actionLabel ?? AppStrings.actionSeeAll;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: typo.h3),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: typo.caption),
              ],
            ],
          ),
        ),
        if (onActionTap != null)
          Semantics(
            button: true,
            label: '$effectiveActionLabel $title',
            child: InkWell(
              onTap: onActionTap,
              borderRadius: AppRadius.buttonRadius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                  minWidth: AppSizes.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        effectiveActionLabel,
                        style: typo.captionStrong.copyWith(
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: AppSizes.iconSm,
                        color: colors.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
