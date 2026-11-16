import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/features/tarombo/presentation/tarombo_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Gerbang persetujuan pertama kali mengisi Tarombo (`TAR-R2`).
///
/// Terpisah dari persetujuan pendaftaran dan hanya muncul sekali sebelum pengguna
/// mengisi data keluarga (pihak lain) untuk pertama kali.
Future<bool> ensureTaromboConsent(BuildContext context, WidgetRef ref) async {
  if (ref.read(taromboRepositoryProvider).hasGivenConsent) {
    return true;
  }

  final accepted = await AppBottomSheet.show<bool>(
    context,
    title: AppStrings.tarConsentTitle,
    child: const _TaromboConsentSheetBody(),
  );
  return accepted ?? false;
}

class _TaromboConsentSheetBody extends ConsumerStatefulWidget {
  const _TaromboConsentSheetBody();

  @override
  ConsumerState<_TaromboConsentSheetBody> createState() =>
      _TaromboConsentSheetBodyState();
}

class _TaromboConsentSheetBodyState
    extends ConsumerState<_TaromboConsentSheetBody> {
  bool _saving = false;

  Future<void> _accept() async {
    setState(() => _saving = true);
    final res = await ref
        .read(taromboControllerProvider.notifier)
        .giveConsent();
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.isOk) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.chipInactive,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: colors.border),
          ),
          child: Text(AppStrings.tarConsentBody, style: typo.body),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppStrings.tarConsentAcceptBtn,
          isLoading: _saving,
          isExpanded: true,
          onPressed: _accept,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: AppStrings.tarConsentCancelBtn,
          variant: AppButtonVariant.text,
          isExpanded: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
