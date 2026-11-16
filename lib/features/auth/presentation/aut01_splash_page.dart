import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// AUT-01 Splash: Logo + ornamen Gorga, memeriksa sesi login, lalu merutekan ke
/// Pengenalan (`AUT-02`), lanjutan Onboarding (`AUT-06`), Beranda (`BER-01`),
/// atau layar akun ditangguhkan dengan jalur banding (PRD 5.1, 6.1).
class Aut01SplashPage extends ConsumerStatefulWidget {
  const Aut01SplashPage({super.key});

  @override
  ConsumerState<Aut01SplashPage> createState() => _Aut01SplashPageState();
}

class _Aut01SplashPageState extends ConsumerState<Aut01SplashPage> {
  bool _isSuspended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateSession());
  }

  void _evaluateSession() {
    if (!mounted) return;
    final authRepo = ref.read(authRepositoryProvider);
    final profile = authRepo.currentSessionProfile;

    if (profile == null) {
      context.go(AppPages.aut02.routePath);
      return;
    }

    if (profile.accountStatus == AccountStatus.suspended ||
        profile.accountStatus == AccountStatus.restricted ||
        profile.accountStatus == AccountStatus.permanentlyBanned) {
      setState(() => _isSuspended = true);
      return;
    }

    if (!profile.onboardingCompleted) {
      context.go(AppPages.aut06.routePath);
      return;
    }

    context.go(AppPages.berandaPath);
  }

  Future<void> _showAppealSheet() async {
    final controller = TextEditingController();
    final authRepo = ref.read(authRepositoryProvider);
    final reportRepo = ref.read(reportRepositoryProvider);

    await AppBottomSheet.show<void>(
      context,
      title: AppStrings.actionSubmitAppeal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppStrings.stateAccountRestrictedAppealInfo,
            style: context.typo.body,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: AppStrings.sis05Title,
            hintText: AppStrings.sis05Purpose,
            controller: controller,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: AppStrings.actionSubmitAppeal,
            isExpanded: true,
            onPressed: () async {
              final nav = Navigator.of(context);
              await reportRepo.submitAppeal(
                sanctionCreatedAt: authRepo.currentTime,
                reasonText: controller.text,
              );
              if (mounted) {
                nav.pop();
                AppToast.show(
                  context,
                  message: AppStrings.aut07RecoveryStatusBadge,
                  variant: AppToastVariant.success,
                );
              }
            },
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (_isSuspended) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.appName, style: typo.h2)),
        body: StateView.accountRestricted(
          generalReason: AppStrings.stateAccountRestrictedDefaultReason,
          onAppeal: _showAppealSheet,
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.splashRed,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.screenMargin,
              right: AppSpacing.screenMargin,
              child: GorgaOrnament(
                width: double.infinity,
                height: 24,
                color: colors.onPrimary,
                opacity: 0.35,
              ),
            ),
            Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    HorasLogo(
                      showRoof: true,
                      showTagline: false,
                      wordmarkFontSize: 44,
                      color: colors.onPrimary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.appTagline,
                      textAlign: TextAlign.center,
                      style: typo.bodyStrong.copyWith(color: colors.onPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      AppStrings.aut01CheckingSession,
                      style: typo.caption.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: AppSpacing.lg,
              left: AppSpacing.screenMargin,
              right: AppSpacing.screenMargin,
              child: GorgaOrnament(
                width: double.infinity,
                height: 24,
                color: colors.onPrimary,
                opacity: 0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
