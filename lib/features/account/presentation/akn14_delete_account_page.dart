import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-14 Hapus Akun: masa tunggu 30 hari, serah komunitas, konfirmasi OTP (`AKN-R8`, `AC-12`, Alur A8).
class Akn14DeleteAccountPage extends ConsumerStatefulWidget {
  const Akn14DeleteAccountPage({super.key});

  @override
  ConsumerState<Akn14DeleteAccountPage> createState() =>
      _Akn14DeleteAccountPageState();
}

class _Akn14DeleteAccountPageState
    extends ConsumerState<Akn14DeleteAccountPage> {
  final _otpController = TextEditingController();
  AccountDeletion? _deletion;
  List<Community> _ownedCommunities = const <Community>[];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = ref.read(authRepositoryProvider).currentUserId;
    final delRes = await ref
        .read(accountLifecycleRepositoryProvider)
        .getAccountDeletionStatus();
    final commRes = await ref
        .read(communityRepositoryProvider)
        .getCommunities();
    if (!mounted) return;

    final owned = commRes is Ok<List<Community>>
        ? commRes.value.where((c) => c.ownerId == uid).toList(growable: false)
        : const <Community>[];

    setState(() {
      _deletion = delRes is Ok<AccountDeletion?> ? delRes.value : null;
      _ownedCommunities = owned;
      _isLoading = false;
    });
  }

  Future<void> _requestDeletion() async {
    FocusScope.of(context).unfocus();
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.akn14Title,
      message: AppStrings.akn14ConsequenceBody,
      confirmLabel: AppStrings.akn14ConfirmBtn,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final res = await ref
        .read(accountLifecycleRepositoryProvider)
        .requestAccountDeletion(otpCode: _otpController.text.trim());
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (res is Err<AccountDeletion>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    setState(() => _deletion = (res as Ok<AccountDeletion>).value);
    AppToast.show(
      context,
      message: AppStrings.akn14PendingBanner,
      variant: AppToastVariant.warning,
    );
  }

  Future<void> _cancelDeletion() async {
    setState(() => _isSubmitting = true);
    final res = await ref
        .read(accountLifecycleRepositoryProvider)
        .cancelAccountDeletion();
    if (!mounted) return;
    setState(() {
      _deletion = res is Ok<AccountDeletion?> ? res.value : null;
      _isSubmitting = false;
    });
    AppToast.show(
      context,
      message: AppStrings.akn14CancelledScreenTitle,
      variant: AppToastVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final hasPending =
        _deletion != null &&
        !_deletion!.isCancelled &&
        !_deletion!.isPermanentlyDeleted;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn14Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppStrings.akn14ConsequenceTitle,
                            style: typo.h3.copyWith(color: colors.danger),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            AppStrings.akn14ConsequenceBody,
                            style: typo.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (_ownedCommunities.isNotEmpty) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.confidenceAmberSurface,
                        borderRadius: AppRadius.cardRadius,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Kamu masih memiliki ${_ownedCommunities.length} komunitas (${_ownedCommunities.map((c) => c.name).join(', ')}). Serahkan kepemilikan terlebih dahulu.',
                            style: typo.caption,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: AppStrings.akn14TransferCommunityBtn,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => context
                                .push(
                                  '${AppPages.sek08.routePath}?communityId=${_ownedCommunities.first.id}',
                                )
                                .ignore(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (_deletion != null && _deletion!.isCancelled) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadius.cardRadius,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppStrings.akn14CancelledScreenTitle,
                            style: typo.bodyStrong.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppStrings.akn14CancelledScreenBody,
                            style: typo.body,
                          ),
                        ],
                      ),
                    ),
                  ] else if (hasPending) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.danger.withValues(alpha: 0.12),
                        borderRadius: AppRadius.cardRadius,
                      ),
                      child: Text(
                        AppStrings.akn14PendingBanner,
                        style: typo.body.copyWith(color: colors.danger),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: AppStrings.akn14CancelDeletionBtn,
                      isExpanded: true,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _cancelDeletion,
                    ),
                  ] else ...<Widget>[
                    AppTextField(
                      controller: _otpController,
                      label: AppStrings.akn14OtpLabel,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: AppStrings.akn14ConfirmBtn,
                      isDestructive: true,
                      isExpanded: true,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _requestDeletion,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
