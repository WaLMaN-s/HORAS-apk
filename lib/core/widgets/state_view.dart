import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/app_button.dart';
import 'package:horas/core/widgets/skeleton_box.dart';
import 'package:material_ui/material_ui.dart';

/// Jenis status standar halaman sesuai PRD 5.2 (Tahap 5).
enum StateViewVariant {
  loading,
  empty,
  offline,
  serverError,
  permissionDenied,
  contentUnavailable,
  accountRestricted,
}

/// Komponen status standar halaman PRD 5.2.
class StateView extends StatelessWidget {
  const StateView._({
    required this.variant,
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.referenceCode,
    this.cachedChild,
    this.skeletonItemCount = 3,
  });

  /// Memetakan [AppError] secara langsung ke varian [StateView] yang sesuai (Prompt 2 Bagian B).
  factory StateView.fromError(
    AppError error, {
    Key? key,
    VoidCallback? onRetry,
    VoidCallback? onOpenSettings,
    VoidCallback? onAppeal,
    VoidCallback? onBack,
    Widget? cachedChild,
  }) {
    return switch (error) {
      OfflineError(:final message) => StateView.offline(
        key: key,
        message: message,
        onRetry: onRetry ?? () {},
        cachedChild: cachedChild,
      ),
      ServerError(:final message, :final referenceCode) =>
        StateView.serverError(
          key: key,
          message: message,
          referenceCode: referenceCode,
          onRetry: onRetry,
        ),
      PermissionDeniedError(:final message) => StateView.permissionDenied(
        key: key,
        benefitMessage: message,
        onOpenSettings: onOpenSettings ?? () {},
        onContinueWithoutPermission: onBack,
      ),
      UnavailableError() => StateView.contentUnavailable(
        key: key,
        onBack: onBack,
      ),
      SuspendedError(:final message) => StateView.accountRestricted(
        key: key,
        generalReason: message,
        onAppeal: onAppeal ?? () {},
      ),
      RateLimitedError(:final message) => StateView.empty(
        key: key,
        message: message,
        actionLabel: AppStrings.actionRetry,
        onAction: onRetry ?? () {},
      ),
      ValidationError(:final message) => StateView.empty(
        key: key,
        message: message,
        actionLabel: AppStrings.actionRetry,
        onAction: onRetry ?? () {},
      ),
    };
  }

  /// 1. Memuat: kerangka (skeleton), bukan putaran layar penuh.
  const StateView.loading({Key? key, int itemCount = 3})
    : this._(
        key: key,
        variant: StateViewVariant.loading,
        skeletonItemCount: itemCount,
      );

  /// 2. Kosong: satu kalimat penjelas dan satu tombol aksi.
  const StateView.empty({
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Key? key,
    String? title,
  }) : this._(
         key: key,
         variant: StateViewVariant.empty,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
       );

  /// 3. Tanpa koneksi: pesan jelas, tombol Coba lagi, tampilkan data tersimpan bila ada (AC-15).
  const StateView.offline({
    required VoidCallback onRetry,
    Key? key,
    String? message,
    Widget? cachedChild,
  }) : this._(
         key: key,
         variant: StateViewVariant.offline,
         title: AppStrings.stateOfflineTitle,
         message: message ?? AppStrings.stateOfflineMessage,
         actionLabel: AppStrings.actionRetry,
         onAction: onRetry,
         cachedChild: cachedChild,
       );

  /// 4. Error server: pesan umum dan kode referensi untuk dukungan.
  const StateView.serverError({
    required String referenceCode,
    Key? key,
    VoidCallback? onRetry,
    String? message,
  }) : this._(
         key: key,
         variant: StateViewVariant.serverError,
         title: AppStrings.stateServerErrorTitle,
         message: message ?? AppStrings.stateServerErrorMessage,
         referenceCode: referenceCode,
         actionLabel: AppStrings.actionRetry,
         onAction: onRetry,
       );

  /// 5. Izin ditolak: jelaskan manfaatnya, tawarkan buka pengaturan, tetap bisa lanjut tanpa izin bila memungkinkan.
  const StateView.permissionDenied({
    required String benefitMessage,
    required VoidCallback onOpenSettings,
    Key? key,
    String? title,
    VoidCallback? onContinueWithoutPermission,
  }) : this._(
         key: key,
         variant: StateViewVariant.permissionDenied,
         title: title ?? AppStrings.statePermissionDeniedTitle,
         message: benefitMessage,
         actionLabel: AppStrings.actionOpenSettings,
         onAction: onOpenSettings,
         secondaryActionLabel: AppStrings.actionContinueWithoutPermission,
         onSecondaryAction: onContinueWithoutPermission,
       );

  /// 6. Konten tidak tersedia: pesan netral tanpa membocorkan alasan (dihapus/privat/diblokir).
  const StateView.contentUnavailable({Key? key, VoidCallback? onBack})
    : this._(
        key: key,
        variant: StateViewVariant.contentUnavailable,
        title: AppStrings.stateContentUnavailableTitle,
        message: AppStrings.stateContentUnavailableMessage,
        actionLabel: AppStrings.actionBackToHome,
        onAction: onBack,
      );

  /// 7. Akun dibatasi atau ditangguhkan: alasan umum + jalur banding (SIS-R4).
  const StateView.accountRestricted({
    required String generalReason,
    required VoidCallback onAppeal,
    Key? key,
  }) : this._(
         key: key,
         variant: StateViewVariant.accountRestricted,
         title: AppStrings.stateAccountRestrictedTitle,
         message: generalReason,
         actionLabel: AppStrings.actionSubmitAppeal,
         onAction: onAppeal,
       );

  final StateViewVariant variant;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final String? referenceCode;
  final Widget? cachedChild;
  final int skeletonItemCount;

  @override
  Widget build(BuildContext context) {
    if (variant == StateViewVariant.loading) {
      return _buildSkeletonList(context);
    }

    if (variant == StateViewVariant.offline && cachedChild != null) {
      return _buildOfflineWithCache(context);
    }

    final colors = context.colors;
    final typo = context.typo;

    final IconData iconData = switch (variant) {
      StateViewVariant.loading => Icons.hourglass_empty_rounded,
      StateViewVariant.empty => Icons.inbox_outlined,
      StateViewVariant.offline => Icons.wifi_off_rounded,
      StateViewVariant.serverError => Icons.cloud_off_rounded,
      StateViewVariant.permissionDenied => Icons.shield_outlined,
      StateViewVariant.contentUnavailable => Icons.visibility_off_outlined,
      StateViewVariant.accountRestricted => Icons.gpp_maybe_outlined,
    };

    final Color iconColor = switch (variant) {
      StateViewVariant.serverError ||
      StateViewVariant.accountRestricted => colors.danger,
      StateViewVariant.offline ||
      StateViewVariant.permissionDenied => colors.confidenceAmber,
      _ => colors.primary,
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: AppSizes.avatarLg,
              height: AppSizes.avatarLg,
              decoration: BoxDecoration(
                color: colors.chipInactive,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: AppSizes.iconXl, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (title != null) ...<Widget>[
              Text(title!, textAlign: TextAlign.center, style: typo.h2),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: typo.body.copyWith(color: colors.textMuted),
              ),
            if (variant == StateViewVariant.accountRestricted) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.stateAccountRestrictedAppealInfo,
                textAlign: TextAlign.center,
                style: typo.caption,
              ),
            ],
            if (referenceCode != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: colors.chipInactive,
                  borderRadius: AppRadius.buttonRadius,
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  AppStrings.stateServerErrorReference(referenceCode!),
                  style: typo.captionStrong,
                ),
              ),
            ],
            if (onAction != null && actionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
            if (onSecondaryAction != null &&
                secondaryActionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: secondaryActionLabel!,
                variant: AppButtonVariant.text,
                onPressed: onSecondaryAction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(skeletonItemCount, (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == skeletonItemCount - 1 ? 0 : AppSpacing.md,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SkeletonBox(height: AppSizes.avatarSm, isCircle: true),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SkeletonBox(width: 140, height: 14),
                            SizedBox(height: AppSpacing.xs),
                            SkeletonBox(width: 90, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  SkeletonBox(width: double.infinity, height: 64),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOfflineWithCache(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.all(AppSpacing.screenMargin),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.confidenceAmberSurface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: colors.confidenceAmber),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.wifi_off_rounded,
                size: AppSizes.iconMd,
                color: colors.confidenceAmber,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.stateOfflineCachedBanner,
                  style: typo.captionStrong.copyWith(color: colors.text),
                ),
              ),
              if (onAction != null && actionLabel != null)
                AppButton(
                  label: actionLabel!,
                  variant: AppButtonVariant.text,
                  onPressed: onAction,
                ),
            ],
          ),
        ),
        Expanded(child: cachedChild!),
      ],
    );
  }
}
