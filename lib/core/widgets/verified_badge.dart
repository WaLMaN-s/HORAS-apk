import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Lencana status verifikasi komunitas/gereja/profil sesuai PRD 1.2, 7.3, dan SEK-R9.
///
/// Menampilkan lencana biru [AppStrings.termTerverifikasi] bila `isVerified == true`,
/// atau label netral [AppStrings.termBelumDiverifikasi] bila `isVerified == false`
/// dan `showUnverifiedLabel == true`.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.isVerified = true,
    this.showLabel = false,
    this.showUnverifiedLabel = true,
    this.iconSize = AppSizes.iconSm,
  });

  final bool isVerified;
  final bool showLabel;
  final bool showUnverifiedLabel;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (isVerified) {
      return Semantics(
        label: AppStrings.semanticsVerified,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.verified_rounded,
              size: iconSize,
              color: colors.verifiedBlue,
            ),
            if (showLabel) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              Text(
                AppStrings.termTerverifikasi,
                style: typo.micro.copyWith(color: colors.verifiedBlue),
              ),
            ],
          ],
        ),
      );
    }

    if (!showUnverifiedLabel) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: AppStrings.semanticsUnverified,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.chipInactive,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(color: colors.border),
        ),
        child: Text(
          AppStrings.termBelumDiverifikasi,
          style: typo.micro.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}
