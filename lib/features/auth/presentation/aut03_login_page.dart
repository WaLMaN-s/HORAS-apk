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

/// AUT-03 Masuk: Input nomor HP dengan kode negara (+62 bawaan, daftar negara diaspora),
/// validasi E.164, hanya OTP (tanpa sandi, tanpa Google/Apple, tanpa Lupa password),
/// dan tautan kecil "Nomor tidak bisa diakses?" ke `AUT-07` (AUT-R1, AUT-R8).
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
    final controller = ref.read(authFlowControllerProvider.notifier);
    final ok = await controller.sendOtpForLogin(_phoneController.text);
    if (ok && mounted) {
      context.go(AppPages.aut05.routePath);
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

              // Pemilih kode negara (+62 bawaan + negara diaspora)
              Text(AppStrings.aut03CountryLabel, style: typo.captionStrong),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final opt in kSupportedCountryDialOptions)
                    AppChip(
                      label: opt.countryName,
                      isSelected: state.countryDialCode == opt.dialCode,
                      onTap: () => controller.setCountryDialCode(opt.dialCode),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label:
                    '${AppStrings.aut03PhoneLabel} (${state.countryDialCode})',
                hintText: AppStrings.aut03PhoneHint,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                leadingIcon: Icons.phone_android_rounded,
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
