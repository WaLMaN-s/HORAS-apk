import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/features/auth/presentation/auth_flow_controller.dart';
import 'package:material_ui/material_ui.dart';

/// AUT-04 Daftar: Dua persetujuan terpisah (Kebijakan Privasi + Syarat Layanan;
/// Pedoman Komunitas) dan pernyataan usia 17+, tanpa isian profil di layar ini (AUT-R4).
///
/// Dokumen dibuka dari `assets/legal/*.md` bertanda "Draf, perlu tinjauan hukum".
class Aut04RegisterPage extends ConsumerStatefulWidget {
  const Aut04RegisterPage({super.key});

  @override
  ConsumerState<Aut04RegisterPage> createState() => _Aut04RegisterPageState();
}

class _Aut04RegisterPageState extends ConsumerState<Aut04RegisterPage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _openLegalDocumentSheet({
    required String title,
    required String assetPath,
  }) async {
    String content;
    try {
      content = await rootBundle.loadString(assetPath);
    } on Object {
      content =
          '# $title\n\n${AppStrings.aut04LegalDraftBadge}\n\nDokumen hukum sedang dimuat.';
    }
    if (!mounted) return;

    await AppBottomSheet.show<void>(
      context,
      title: title,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppChip(
              label: AppStrings.aut04LegalDraftBadge,
              isSelected: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(content, style: context.typo.body),
          ],
        ),
      ),
    );
  }

  Future<void> _onRegisterSubmit() async {
    final input = _phoneController.text.trim();
    final controller = ref.read(authFlowControllerProvider.notifier);

    if (input.contains('@')) {
      final profil = await controller.signInWithEmailOrGoogle(
        input,
        requireRegistrationConsents: true,
      );
      if (profil != null && mounted) {
        if (profil.onboardingCompleted) {
          context.go(AppPages.berandaPath);
        } else {
          context.go(AppPages.aut06.routePath);
        }
      }
      return;
    }

    final ok = await controller.submitRegistrationConsentsAndSendOtp(input);
    if (ok && mounted) {
      context.go(AppPages.aut05.routePath);
    }
  }

  Future<void> _onGoogleRegisterPressed() async {
    final controller = ref.read(authFlowControllerProvider.notifier);
    final state = ref.read(authFlowControllerProvider);
    if (!state.allRegistrationConsentsChecked) {
      controller.setPrivacyConsent(true);
      controller.setGuidelinesConsent(true);
      controller.setAge17Confirmed(true);
    }

    final emailCtrl = TextEditingController(
      text: _phoneController.text.contains('@')
          ? _phoneController.text.trim()
          : '',
    );
    final selectedEmail = await AppBottomSheet.show<String>(
      context,
      title: AppStrings.aut03GoogleSheetTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            label: AppStrings.aut03GoogleEmailLabel,
            hintText: AppStrings.aut03GoogleEmailHint,
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            leadingIcon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: AppStrings.aut03GoogleContinueBtn,
            isExpanded: true,
            leadingIcon: Icons.account_circle_outlined,
            onPressed: () {
              Navigator.of(context).pop(emailCtrl.text.trim());
            },
          ),
        ],
      ),
    );

    if (selectedEmail == null || selectedEmail.isEmpty || !mounted) return;
    _phoneController.text = selectedEmail;
    final profil = await controller.signInWithEmailOrGoogle(
      selectedEmail,
      requireRegistrationConsents: true,
    );
    if (profil != null && mounted) {
      if (profil.onboardingCompleted) {
        context.go(AppPages.berandaPath);
      } else {
        context.go(AppPages.aut06.routePath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authFlowControllerProvider);
    final controller = ref.read(authFlowControllerProvider.notifier);
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.aut04Title, style: typo.h2)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const GorgaOrnament(width: double.infinity, height: 18),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.aut04Title, style: typo.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.aut04Subheading,
                style: typo.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Input Email atau Nomor HP (Tanpa pilihan kode negara)
              AppTextField(
                label: AppStrings.aut03PhoneLabel,
                hintText: AppStrings.aut03PhoneHint,
                controller: _phoneController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.person_add_alt_1_outlined,
                onChanged: controller.setNationalPhone,
              ),
              const SizedBox(height: AppSpacing.md),

              AppButton(
                label: AppStrings.aut03GoogleBtn,
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                leadingIcon: Icons.account_circle_outlined,
                onPressed: _onGoogleRegisterPressed,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 1. Persetujuan Kebijakan Privasi + Syarat Layanan
              _ConsentCard(
                checked: state.privacyAndTermsAccepted,
                label: AppStrings.aut04ConsentPrivacyLabel,
                readDocButtonLabel: AppStrings.aut04ReadPrivacyBtn,
                onChanged: controller.setPrivacyConsent,
                onReadDocTap: () => _openLegalDocumentSheet(
                  title: AppStrings.aut04ReadPrivacyBtn,
                  assetPath: 'assets/legal/kebijakan_privasi_dan_syarat.md',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 2. Persetujuan Pedoman Komunitas
              _ConsentCard(
                checked: state.communityGuidelinesAccepted,
                label: AppStrings.aut04ConsentGuidelinesLabel,
                readDocButtonLabel: AppStrings.aut04ReadGuidelinesBtn,
                onChanged: controller.setGuidelinesConsent,
                onReadDocTap: () => _openLegalDocumentSheet(
                  title: AppStrings.aut04ReadGuidelinesBtn,
                  assetPath: 'assets/legal/pedoman_komunitas.md',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 3. Pernyataan Usia 17+
              _ConsentCard(
                checked: state.age17PlusConfirmed,
                label: AppStrings.aut04ConsentAge17Label,
                onChanged: controller.setAge17Confirmed,
              ),

              if (state.error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  state.error!.message,
                  style: typo.captionStrong.copyWith(color: colors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              AppButton(
                label: AppStrings.aut04ContinueToOtpBtn,
                isExpanded: true,
                isLoading: state.isLoading,
                onPressed: _onRegisterSubmit,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(AppStrings.aut04ToLoginPrefix, style: typo.caption),
                  AppButton(
                    label: AppStrings.aut04ToLoginAction,
                    variant: AppButtonVariant.text,
                    onPressed: () => context.push(AppPages.aut03.routePath),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.checked,
    required this.label,
    required this.onChanged,
    this.readDocButtonLabel,
    this.onReadDocTap,
  });

  final bool checked;
  final String label;
  final ValueChanged<bool> onChanged;
  final String? readDocButtonLabel;
  final VoidCallback? onReadDocTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: checked ? colors.accent : colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () => onChanged(!checked),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: AppSizes.minTouchTarget,
                  height: AppSizes.minTouchTarget,
                  child: Checkbox(
                    value: checked,
                    activeColor: colors.buttonPrimary,
                    onChanged: (val) => onChanged(val ?? false),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(label, style: typo.body)),
              ],
            ),
          ),
          if (readDocButtonLabel != null && onReadDocTap != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSizes.minTouchTarget),
              child: AppButton(
                label: readDocButtonLabel!,
                variant: AppButtonVariant.text,
                leadingIcon: Icons.article_outlined,
                onPressed: onReadDocTap,
              ),
            ),
        ],
      ),
    );
  }
}
