import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/tarombo/presentation/tarombo_controller.dart';
import 'package:material_ui/material_ui.dart';

/// TAR-04 Detail Anggota Tarombo (`TAR-R3`, `TAR-R4`).
class Tar04MemberDetailPage extends ConsumerStatefulWidget {
  const Tar04MemberDetailPage({required this.memberId, super.key});

  final String memberId;

  @override
  ConsumerState<Tar04MemberDetailPage> createState() =>
      _Tar04MemberDetailPageState();
}

class _Tar04MemberDetailPageState extends ConsumerState<Tar04MemberDetailPage> {
  List<PersonSummary> _potentialLinks = const <PersonSummary>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadPotentialLinks);
  }

  Future<void> _loadPotentialLinks() async {
    if (widget.memberId.isEmpty) return;
    final res = await ref
        .read(taromboRepositoryProvider)
        .findPotentialLinksForMember(widget.memberId);
    if (!mounted) return;
    if (res is Ok<List<PersonSummary>>) {
      setState(() => _potentialLinks = res.value);
    }
  }

  Future<void> _confirmDelete(FamilyMember member) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.tar04DeleteConfirmTitle,
      message: AppStrings.tar04DeleteConfirmBody,
      confirmLabel: AppStrings.tar04DeleteBtn,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final res = await ref
        .read(taromboControllerProvider.notifier)
        .deleteMember(member.id);
    if (!mounted) return;
    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    context.pop();
  }

  Future<void> _showLinkDialog(
    FamilyMember member,
    PersonSummary candidate,
  ) async {
    final sendConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.tar04LinkDialogTitle),
        content: Text(AppStrings.tar04LinkDialogBody(candidate.displayName)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.tar04LinkSendBtn),
          ),
        ],
      ),
    );
    if (sendConfirm != true || !mounted) return;

    final res = await ref
        .read(taromboControllerProvider.notifier)
        .sendClaim(
          targetUserId: candidate.id,
          claimedTerm: member.relationType.label,
          note: AppStrings.tar04LinkDialogTitle,
        );
    if (!mounted) return;
    if (res is Err<PartuturanClaim>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.tar04LinkSentToast,
      variant: AppToastVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taromboControllerProvider);
    final member = state.members
        .where((m) => m.id == widget.memberId)
        .firstOrNull;
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: Text(member?.fullName ?? AppStrings.tar04Title)),
      body: state.isLoading
          ? const SingleChildScrollView(child: StateView.loading(itemCount: 3))
          : member == null
          ? StateView.fromError(
              const UnavailableError(
                message: AppStrings.stateContentUnavailableMessage,
              ),
              onBack: () => context.pop(),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        member.relationType.label,
                        style: typo.captionStrong,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(member.fullName, style: typo.h2),
                      const Divider(height: AppSpacing.xl),
                      _DetailItem(
                        label: AppStrings.tar03MargaLabel,
                        value: member.marga,
                      ),
                      _DetailItem(
                        label: AppStrings.tar03GenderLabel,
                        value: member.gender.label,
                      ),
                      _DetailItem(
                        label: AppStrings.tar03BirthYearLabel,
                        value: member.birthYear != null
                            ? '${member.birthYear}'
                            : AppStrings.tar04NotListed,
                      ),
                      _DetailItem(
                        label: AppStrings.tar03LifeStatusLabel,
                        value: member.lifeStatus.label,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.chipInactive,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    AppStrings.tar04PrivacyNotice,
                    style: typo.caption,
                  ),
                ),
                // TAR-R4: Tawarkan penautan berbasis konfirmasi kedua pihak bila kandidat akun terdaftar ditemukan
                if (_potentialLinks.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  for (final candidate in _potentialLinks)
                    AppButton(
                      label:
                          '${AppStrings.tar04LinkPromptBtn}: ${candidate.displayName}',
                      variant: AppButtonVariant.secondary,
                      leadingIcon: Icons.link_rounded,
                      onPressed: () => _showLinkDialog(member, candidate),
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        label: AppStrings.tar04EditBtn,
                        variant: AppButtonVariant.secondary,
                        leadingIcon: Icons.edit_outlined,
                        onPressed: () => context.push(
                          '${AppPages.tar03.routePath}?id=${member.id}',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: AppStrings.tar04DeleteBtn,
                        variant: AppButtonVariant.secondary,
                        isDestructive: true,
                        leadingIcon: Icons.delete_outline_rounded,
                        onPressed: () => _confirmDelete(member),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 2, child: Text(label, style: typo.caption)),
          Expanded(flex: 3, child: Text(value, style: typo.bodyStrong)),
        ],
      ),
    );
  }
}
