import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/features/auth/presentation/auth_flow_controller.dart';
import 'package:material_ui/material_ui.dart';

/// AUT-07 Pemulihan Akun (AUT-R8):
/// - Mode (a) Nomor lama masih dipegang: OTP ke nomor lama lalu nomor baru.
/// - Mode (b) Nomor lama hilang: formulir bukti kepemilikan (tanggal daftar, marga, beberapa kenalan)
///   dengan status "Ditinjau, target 3 hari kerja".
class Aut07RecoveryPage extends ConsumerStatefulWidget {
  const Aut07RecoveryPage({super.key});

  @override
  ConsumerState<Aut07RecoveryPage> createState() => _Aut07RecoveryPageState();
}

class _Aut07RecoveryPageState extends ConsumerState<Aut07RecoveryPage> {
  bool _isLostNumberMode = false;

  final TextEditingController _oldPhoneController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();
  final TextEditingController _oldOtpController = TextEditingController();
  final TextEditingController _newOtpController = TextEditingController();
  final TextEditingController _regDateController = TextEditingController();
  final TextEditingController _margaController = TextEditingController();
  final TextEditingController _friendsController = TextEditingController();

  @override
  void dispose() {
    _oldPhoneController.dispose();
    _newPhoneController.dispose();
    _oldOtpController.dispose();
    _newOtpController.dispose();
    _regDateController.dispose();
    _margaController.dispose();
    _friendsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(authFlowControllerProvider);
    final controller = ref.read(authFlowControllerProvider.notifier);
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.aut07Title, style: typo.h2)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          children: <Widget>[
            const GorgaOrnament(width: double.infinity, height: 18),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.aut07Title, style: typo.h1),
            const SizedBox(height: AppSpacing.md),

            // Pilihan Mode (a) Nomor Lama Aktif vs Mode (b) Nomor Lama Hilang
            Row(
              children: <Widget>[
                Expanded(
                  child: AppChip(
                    label: AppStrings.aut07ModeAccessibleTab,
                    isSelected: !_isLostNumberMode,
                    onTap: () {
                      controller.clearError();
                      setState(() => _isLostNumberMode = false);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppChip(
                    label: AppStrings.aut07ModeLostTab,
                    isSelected: _isLostNumberMode,
                    onTap: () {
                      controller.clearError();
                      setState(() => _isLostNumberMode = true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (!_isLostNumberMode)
              _buildAccessiblePhoneMode(context, flowState, controller)
            else
              _buildLostPhoneMode(context, flowState, controller),

            if (flowState.error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                flowState.error!.message,
                style: typo.captionStrong.copyWith(color: colors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessiblePhoneMode(
    BuildContext context,
    AuthFlowState flowState,
    AuthFlowController controller,
  ) {
    final colors = context.colors;
    final typo = context.typo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.aut07AccessibleDesc,
          style: typo.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: AppStrings.aut07OldPhoneLabel,
          hintText: '+628121000001',
          controller: _oldPhoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: AppStrings.aut07NewPhoneLabel,
          hintText: '+628129999888',
          controller: _newPhoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),

        if (!flowState.dualOtpSent)
          AppButton(
            label: AppStrings.aut07SendBothOtpBtn,
            isExpanded: true,
            isLoading: flowState.isLoading,
            onPressed: () => controller.sendDualOtpForPhoneChange(
              oldPhoneE164: flowState.formatE164(_oldPhoneController.text),
              newPhoneE164: flowState.formatE164(_newPhoneController.text),
            ),
          )
        else ...<Widget>[
          AppTextField(
            label: AppStrings.aut07OldOtpLabel,
            hintText: '123456',
            controller: _oldOtpController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: AppStrings.aut07NewOtpLabel,
            hintText: '123456',
            controller: _newOtpController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: AppStrings.aut07ConfirmChangePhoneBtn,
            isExpanded: true,
            isLoading: flowState.isLoading,
            onPressed: () async {
              final ok = await controller.verifyDualOtpAndChangePhone(
                oldPhoneE164: flowState.formatE164(_oldPhoneController.text),
                oldOtpCode: _oldOtpController.text,
                newPhoneE164: flowState.formatE164(_newPhoneController.text),
                newOtpCode: _newOtpController.text,
              );
              if (ok && context.mounted) {
                AppToast.show(
                  context,
                  message: AppStrings.aut07PhoneChangedSuccess,
                  variant: AppToastVariant.success,
                );
                context.go(AppPages.aut03.routePath);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildLostPhoneMode(
    BuildContext context,
    AuthFlowState flowState,
    AuthFlowController controller,
  ) {
    final colors = context.colors;
    final typo = context.typo;
    final submission = flowState.recoverySubmission;

    if (submission != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppChip(label: submission.statusLabel, isSelected: true),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.aut07RecoverySubmittedDesc, style: typo.body),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Marga: ${submission.marga} · Waktu daftar: ${submission.approximateRegistrationPeriod}',
              style: typo.caption,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.aut07LostDesc,
          style: typo.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: AppStrings.aut07OldPhoneLabel,
          hintText: '+628121000001',
          controller: _oldPhoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: AppStrings.aut07NewPhoneLabel,
          hintText: '+628129999888',
          controller: _newPhoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: AppStrings.aut07RegDateLabel,
          hintText: AppStrings.aut07RegDateHint,
          controller: _regDateController,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: AppStrings.aut07KnownMargaLabel,
          hintText: 'Simanjuntak',
          controller: _margaController,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: AppStrings.aut07KnownFriendsLabel,
          hintText: AppStrings.aut07KnownFriendsHint,
          controller: _friendsController,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: AppStrings.aut07SubmitRecoveryBtn,
          isExpanded: true,
          isLoading: flowState.isLoading,
          onPressed: () => controller.submitLostPhoneProof(
            oldPhoneE164: flowState.formatE164(_oldPhoneController.text),
            newPhoneE164: flowState.formatE164(_newPhoneController.text),
            approximateRegistrationPeriod: _regDateController.text,
            marga: _margaController.text,
            knownFriendsText: _friendsController.text,
          ),
        ),
      ],
    );
  }
}
