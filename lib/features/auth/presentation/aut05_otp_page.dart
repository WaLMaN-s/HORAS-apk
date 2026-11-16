import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/features/auth/presentation/auth_flow_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pinput/pinput.dart';

/// AUT-05 Verifikasi OTP (Pinput): 6 digit, hitung mundur kirim ulang 60 detik,
/// berlaku 5 menit, sisa percobaan, kunci 1 jam dengan pesan kapan boleh mencoba lagi (AC-01).
class Aut05OtpPage extends ConsumerStatefulWidget {
  const Aut05OtpPage({super.key});

  @override
  ConsumerState<Aut05OtpPage> createState() => _Aut05OtpPageState();
}

class _Aut05OtpPageState extends ConsumerState<Aut05OtpPage> {
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _onVerifyPressed() async {
    final code = _pinController.text.trim();
    if (code.length < AppLimits.otpDigits) return;

    final controller = ref.read(authFlowControllerProvider.notifier);
    final profil = await controller.verifyOtpCode(code);
    if (profil != null && mounted) {
      if (profil.onboardingCompleted) {
        context.go(AppPages.berandaPath);
      } else {
        context.go(AppPages.aut06.routePath);
      }
    }
  }

  Future<void> _onResendPressed() async {
    final controller = ref.read(authFlowControllerProvider.notifier);
    final phone = ref.read(authFlowControllerProvider).pendingPhoneE164;
    await controller.sendOtpForLogin(phone);
    if (mounted) {
      setState(() {});
    }
  }

  static String _formatClockTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh.$mm';
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(authFlowControllerProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final colors = context.colors;
    final typo = context.typo;

    final err = flowState.error;
    if (err is OfflineError) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.aut05Title, style: typo.h2)),
        body: StateView.offline(onRetry: _onVerifyPressed),
      );
    }

    final phone = flowState.pendingPhoneE164.isNotEmpty
        ? flowState.pendingPhoneE164
        : flowState.formatE164();
    final otpStatus = authRepo.getOtpStatusForPhone(phone);
    final now = authRepo.currentTime;

    final isLocked = otpStatus.lockedUntil != null;
    final resendSecondsLeft = otpStatus.resendReadyAt != null
        ? otpStatus.resendReadyAt!.difference(now).inSeconds.clamp(0, 60)
        : 0;
    final validityRemaining = otpStatus.issuedAt != null
        ? otpStatus.issuedAt!.add(AppLimits.otpValidity).difference(now)
        : AppLimits.otpValidity;
    final isExpired = validityRemaining.isNegative;

    final defaultPinTheme = PinTheme(
      width: AppSizes.minTouchTarget + AppSpacing.xs,
      height: AppSizes.minTouchTarget + AppSpacing.sm,
      textStyle: typo.h2,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.buttonRadius,
        border: Border.all(color: colors.border),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.buttonRadius,
        border: Border.all(color: colors.accent, width: AppSizes.strokeMedium),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.buttonRadius,
        border: Border.all(color: colors.danger, width: AppSizes.strokeMedium),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.aut05Title, style: typo.h2)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          children: <Widget>[
            const GorgaOrnament(width: double.infinity, height: 18),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.aut05Title, style: typo.h1),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.aut05SubtitleForPhone(phone),
              style: typo.body.copyWith(color: colors.textMuted),
            ),
            if (authRepo.isDevOtpHintEnabled) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.confidenceAmberSurface,
                  borderRadius: AppRadius.buttonRadius,
                  border: Border.all(color: colors.confidenceAmber),
                ),
                child: Text(
                  AppStrings.aut05DevHint,
                  style: typo.captionStrong.copyWith(
                    color: colors.confidenceAmber,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            Center(
              child: Pinput(
                length: AppLimits.otpDigits,
                controller: _pinController,
                enabled: !isLocked && !flowState.isLoading,
                showCursor: false,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                errorPinTheme: errorPinTheme,
                forceErrorState: err != null,
                onCompleted: (_) => _onVerifyPressed(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Status terkunci 1 jam (AC-01), kedaluwarsa, atau sisa percobaan
            if (isLocked)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.chipInactive,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: colors.danger),
                ),
                child: Text(
                  AppStrings.aut05LockedMessage(
                    _formatClockTime(otpStatus.lockedUntil!),
                  ),
                  style: typo.bodyStrong.copyWith(color: colors.danger),
                ),
              )
            else ...<Widget>[
              if (err != null) ...<Widget>[
                Text(
                  err.message,
                  textAlign: TextAlign.center,
                  style: typo.captionStrong.copyWith(color: colors.danger),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                AppStrings.aut05RemainingAttempts(
                  otpStatus.remainingAttempts,
                  AppLimits.otpMaxWrongAttempts,
                ),
                textAlign: TextAlign.center,
                style: typo.caption,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isExpired
                    ? AppStrings.aut05ExpiredNotice
                    : AppStrings.aut05ValidityNotice(
                        validityRemaining.inMinutes,
                        validityRemaining.inSeconds % 60,
                      ),
                textAlign: TextAlign.center,
                style: typo.caption.copyWith(
                  color: isExpired ? colors.danger : colors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            AppButton(
              label: AppStrings.aut05VerifyBtn,
              isExpanded: true,
              isLoading: flowState.isLoading,
              isDisabled: isLocked,
              onPressed: _onVerifyPressed,
            ),
            const SizedBox(height: AppSpacing.md),

            if (resendSecondsLeft > 0)
              Text(
                AppStrings.aut05ResendCountdown(resendSecondsLeft),
                textAlign: TextAlign.center,
                style: typo.caption,
              )
            else
              Center(
                child: AppButton(
                  label: AppStrings.aut05ResendBtn,
                  variant: AppButtonVariant.text,
                  isDisabled: isLocked,
                  onPressed: _onResendPressed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
