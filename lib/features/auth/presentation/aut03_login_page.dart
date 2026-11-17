import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/features/auth/presentation/auth_flow_controller.dart';
import 'package:material_ui/material_ui.dart';

/// AUT-03 Masuk: Masuk dengan Email yang sudah terdaftar di database, Akun Google,
/// atau Nomor HP (opsional salah satu, tanpa pilihan kode negara).
class Aut03LoginPage extends ConsumerStatefulWidget {
  const Aut03LoginPage({super.key});

  @override
  ConsumerState<Aut03LoginPage> createState() => _Aut03LoginPageState();
}

class _Aut03LoginPageState extends ConsumerState<Aut03LoginPage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    final input = _phoneController.text.trim();
    final controller = ref.read(authFlowControllerProvider.notifier);

    if (input.contains('@')) {
      final profil = await controller.signInWithEmailOrGoogle(input);
      if (profil != null && mounted) {
        if (profil.onboardingCompleted) {
          context.go(AppPages.berandaPath);
        } else {
          context.go(AppPages.aut06.routePath);
        }
      }
      return;
    }

    final ok = await controller.sendOtpForLogin(input);
    if (ok && mounted) {
      context.go(AppPages.aut05.routePath);
    }
  }

  Future<void> _onGoogleSignInPressed() async {
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
    final controller = ref.read(authFlowControllerProvider.notifier);
    final profil = await controller.signInWithEmailOrGoogle(selectedEmail);
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

    final err = state.error;
    if (err is OfflineError) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.aut03Title, style: typo.h2)),
        body: StateView.offline(onRetry: _onSendOtp),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.aut03Title, style: typo.h2)),
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
              const SizedBox(height: AppSpacing.lg),
              const Center(
                child: HorasLogo(
                  showRoof: true,
                  showTagline: true,
                  wordmarkFontSize: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(AppStrings.aut03Title, style: typo.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.aut03Subheading,
                style: typo.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: AppStrings.aut03PhoneLabel,
                hintText: AppStrings.aut03PhoneHint,
                controller: _phoneController,
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.person_outline_rounded,
                errorText: err?.message,
                onChanged: controller.setNationalPhone,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Tautan kecil "Nomor tidak bisa diakses?" ke AUT-07 (bukan Lupa Password)
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: AppStrings.aut03LostNumberLink,
                  variant: AppButtonVariant.text,
                  onPressed: () => context.push(AppPages.aut07.routePath),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              AppButton(
                label: AppStrings.aut03SendOtpBtn,
                isExpanded: true,
                isLoading: state.isLoading,
                onPressed: _onSendOtp,
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: <Widget>[
                  Expanded(child: Divider(color: colors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      AppStrings.aut03OrDivider,
                      style: typo.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                  Expanded(child: Divider(color: colors.border)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              AppButton(
                label: AppStrings.aut03GoogleBtn,
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                leadingIcon: Icons.account_circle_outlined,
                onPressed: _onGoogleSignInPressed,
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(AppStrings.aut03ToRegisterPrefix, style: typo.caption),
                  AppButton(
                    label: AppStrings.aut03ToRegisterAction,
                    variant: AppButtonVariant.text,
                    onPressed: () => context.push(AppPages.aut04.routePath),
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
