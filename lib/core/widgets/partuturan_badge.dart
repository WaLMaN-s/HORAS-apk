import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:material_ui/material_ui.dart';

/// Badge partuturan sesuai tingkat keyakinan (PRD 1.2, TAR-R5, TAR-R6, Prompt 2 Bagian F).
///
/// - `tinggi`: maroon solid (`colors.primary` + `colors.onPrimary`)
/// - `sedang`: outline amber + `"Kemungkinan: X"` (`colors.confidenceAmber`)
/// - `rendah`: abu-abu (`colors.chipInactive` + `colors.textMuted`)
/// - `modeNetral == true`: tidak tampil (`SizedBox.shrink()`)
class PartuturanBadge extends StatelessWidget {
  const PartuturanBadge({
    required this.result,
    super.key,
    this.showDraftIndicator = false,
    this.onTap,
  });

  final PartuturanResult result;
  final bool showDraftIndicator;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badgeText = result.displayBadgeText;
    if (result.modeNetral || badgeText == null) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final typo = context.typo;

    final (
      Color bgColor,
      Color fgColor,
      Color borderColor,
    ) = switch (result.confidence) {
      PartuturanConfidence.tinggi => (
        colors.primary,
        colors.onPrimary,
        colors.primary,
      ),
      PartuturanConfidence.sedang => (
        colors.confidenceAmberSurface,
        colors.confidenceAmber,
        colors.confidenceAmber,
      ),
      PartuturanConfidence.rendah => (
        colors.chipInactive,
        colors.textMuted,
        colors.border,
      ),
    };

    final badgeContent = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(
          color: borderColor,
          width: result.confidence == PartuturanConfidence.sedang
              ? AppSizes.strokeMedium
              : AppSizes.strokeThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            switch (result.confidence) {
              PartuturanConfidence.tinggi => Icons.verified_user_rounded,
              PartuturanConfidence.sedang => Icons.account_tree_outlined,
              PartuturanConfidence.rendah => Icons.help_outline_rounded,
            },
            size: AppSizes.iconXs,
            color: fgColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              badgeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.micro.copyWith(color: fgColor),
            ),
          ),
          if (showDraftIndicator && result.isDraftRule) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.pillRadius,
                border: Border.all(color: colors.border),
              ),
              child: Text(
                AppStrings.partuturanDraftRuleBadge,
                style: typo.micro.copyWith(
                  color: colors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: badgeText,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: AppRadius.pillRadius,
              child: badgeContent,
            )
          : badgeContent,
    );
  }
}

/// Label "Semarga (dongan tubu)" beserta penjelasan singkat bahwa ini adalah
/// informasi kekerabatan, bukan pembatasan (SEK-R6, AC-04, Prompt 2 Bagian F).
///
/// Tetap tampil meskipun pengguna berada di mode netral.
class SemargaLabel extends StatelessWidget {
  const SemargaLabel({super.key, this.showExplanation = true});

  final bool showExplanation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Semantics(
      label: '${AppStrings.semargaFullLabel}. ${AppStrings.semargaDescription}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.chipInactive,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.people_alt_outlined,
                  size: AppSizes.iconSm,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  AppStrings.semargaFullLabel,
                  style: typo.captionStrong.copyWith(color: colors.primary),
                ),
              ],
            ),
            if (showExplanation) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                AppStrings.semargaDescription,
                style: typo.micro.copyWith(color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
