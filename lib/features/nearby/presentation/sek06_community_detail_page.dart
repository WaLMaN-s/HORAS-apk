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
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:horas/features/nearby/presentation/nearby_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-06 Detail Komunitas (`SEK-R7` .. `SEK-R11`, `AC-13`).
///
/// Kegiatan komunitas adalah Fase 2 (`FeatureFlags.events == false`) dan disembunyikan.
class Sek06CommunityDetailPage extends ConsumerStatefulWidget {
  const Sek06CommunityDetailPage({required this.communityId, super.key});

  final String communityId;

  @override
  ConsumerState<Sek06CommunityDetailPage> createState() =>
      _Sek06CommunityDetailPageState();
}

class _Sek06CommunityDetailPageState
    extends ConsumerState<Sek06CommunityDetailPage> {
  bool _isLoading = true;
  bool _isBusy = false;
  AppError? _error;
  Community? _community;
  List<Membership> _members = const <Membership>[];
  List<Announcement> _announcements = const <Announcement>[];
  JoinRequest? _myPendingJoinRequest;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (widget.communityId.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _error = const UnavailableError(
          message: AppStrings.stateContentUnavailableMessage,
        );
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final commRepo = ref.read(communityRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);
    _currentUserId = authRepo.currentUserId;

    final commRes = await commRepo.getCommunityById(widget.communityId);
    if (!mounted) return;
    if (commRes is Err<Community>) {
      setState(() {
        _isLoading = false;
        _error = commRes.failure;
        _community = null;
      });
      return;
    }

    final comm = (commRes as Ok<Community>).value;
    final membersFuture = commRepo.getMembers(comm.id);
    final announcementsFuture = commRepo.getAnnouncements(comm.id);
    final myReqsFuture = commRepo.getMyJoinRequests();

    final membersRes = await membersFuture;
    final annRes = await announcementsFuture;
    final myReqsRes = await myReqsFuture;
    if (!mounted) return;

    final pending = myReqsRes is Ok<List<JoinRequest>>
        ? myReqsRes.value.where((r) => r.communityId == comm.id).firstOrNull
        : null;

    setState(() {
      _isLoading = false;
      _community = comm;
      _members = membersRes is Ok<List<Membership>>
          ? membersRes.value
          : const <Membership>[];
      _announcements = annRes is Ok<List<Announcement>>
          ? annRes.value
          : const <Announcement>[];
      _myPendingJoinRequest = pending;
    });
  }

  Future<void> _joinCommunity() async {
    final comm = _community;
    if (comm == null || _isBusy) return;
    setState(() => _isBusy = true);

    final res = await ref
        .read(communityRepositoryProvider)
        .joinCommunity(comm.id);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (res is Err<JoinRequest?>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    await ref.read(nearbyControllerProvider.notifier).loadInitial();
    await _load();
  }

  Future<void> _leaveCommunity() async {
    final comm = _community;
    if (comm == null || _isBusy) return;

    // SEK-R8: Pemilik harus menyerahkan kepemilikan sebelum keluar
    if (comm.ownerId == _currentUserId) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(AppStrings.sek06OwnerMustTransferTitle),
          content: const Text(AppStrings.sek06OwnerMustTransferBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(AppStrings.actionCancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await context.push('${AppPages.sek08.routePath}?id=${comm.id}');
                if (mounted) await _load();
              },
              child: const Text(AppStrings.sek06OwnerTransferAction),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.sek06LeaveConfirmTitle,
      message: AppStrings.sek06LeaveConfirmBody,
      confirmLabel: AppStrings.sek06LeaveBtn,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final res = await ref
        .read(communityRepositoryProvider)
        .leaveCommunity(comm.id);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await ref.read(nearbyControllerProvider.notifier).loadInitial();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_community?.name ?? AppStrings.sek06Title)),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    }

    if (_error != null || _community == null) {
      return StateView.fromError(
        _error ??
            const UnavailableError(
              message: AppStrings.stateContentUnavailableMessage,
            ),
        onRetry: _load,
        onBack: () => context.pop(),
      );
    }

    final comm = _community!;
    final colors = context.colors;
    final typo = context.typo;

    final isMember = _members.any((m) => m.user.id == _currentUserId);
    final isOwnerOrManager =
        comm.ownerId == _currentUserId ||
        comm.managerIds.contains(_currentUserId);

    final accessLabel = switch (comm.accessType) {
      CommunityAccessType.open => AppStrings.sek05AccessOpen,
      CommunityAccessType.approvalRequired => AppStrings.sek05AccessApproval,
      CommunityAccessType.closed => AppStrings.sek05AccessClosed,
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppAvatar(
                name: comm.name,
                seed: comm.avatarSeed,
                size: AppSizes.avatarXl,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(comm.name, style: typo.h2),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${comm.type.label} · ${comm.city} · ${AppStrings.sek05MemberCount(comm.memberCount)}',
                      style: typo.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.chipInactive,
                            borderRadius: AppRadius.pillRadius,
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(accessLabel, style: typo.micro),
                        ),
                        if (comm.type == CommunityType.punguanMarga ||
                            comm.isVerified)
                          VerifiedBadge(
                            isVerified: comm.isVerified,
                            showLabel: true,
                            showUnverifiedLabel:
                                comm.type == CommunityType.punguanMarga,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comm.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(comm.description, style: typo.body),
          ],
          const SizedBox(height: AppSpacing.lg),

          // Tombol aksi Gabung / Menunggu persetujuan / Chat / Kelola / Keluar
          if (!isMember) ...<Widget>[
            if (comm.accessType == CommunityAccessType.closed)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.chipInactive,
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Text(
                  AppStrings.sek06ClosedCommunityHint,
                  style: typo.caption,
                ),
              )
            else if (_myPendingJoinRequest != null) ...<Widget>[
              const AppButton(
                label: AppStrings.sek06WaitingApprovalBtn,
                variant: AppButtonVariant.secondary,
                isDisabled: true,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(AppStrings.sek06ApprovalExpiryHint, style: typo.micro),
            ] else
              AppButton(
                label: comm.accessType == CommunityAccessType.open
                    ? AppStrings.sek06JoinBtn
                    : AppStrings.sek06RequestJoinBtn,
                isLoading: _isBusy,
                onPressed: _joinCommunity,
              ),
          ] else ...<Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: () => context.push(
                    '${AppPages.psn04.routePath}?id=${comm.conversationId ?? 'conv-${comm.id}'}',
                  ),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text(AppStrings.sek06GroupChatBtn),
                ),
                if (isOwnerOrManager)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.push(
                        '${AppPages.sek08.routePath}?id=${comm.id}',
                      );
                      if (mounted) await _load();
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text(AppStrings.sek06ManageBtn),
                  ),
                TextButton(
                  onPressed: _isBusy ? null : _leaveCommunity,
                  child: Text(
                    AppStrings.sek06LeaveBtn,
                    style: typo.bodyStrong.copyWith(color: colors.danger),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: AppStrings.sek06AnnouncementsSection),
          const SizedBox(height: AppSpacing.sm),
          if (_announcements.isEmpty)
            Text(AppStrings.sek06NoAnnouncements, style: typo.caption)
          else
            for (final ann in _announcements)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: Text(ann.title, style: typo.h3)),
                          if (ann.isPinned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: AppRadius.pillRadius,
                              ),
                              child: Text(
                                AppStrings.sek06PinnedBadge,
                                style: typo.micro.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(ann.body, style: typo.body),
                    ],
                  ),
                ),
              ),

          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: AppStrings.sek06MembersSection),
          const SizedBox(height: AppSpacing.sm),
          for (final membership in _members)
            PersonNearbyCard(
              person: membership.user,
              trailing: Text(switch (membership.role) {
                CommunityRole.owner => AppStrings.sek08RoleOwner,
                CommunityRole.manager => AppStrings.sek08RoleManager,
                CommunityRole.member => AppStrings.sek08RoleMember,
              }, style: typo.micro.copyWith(color: colors.primary)),
              onTap: () {
                if (membership.user.id != _currentUserId) {
                  context.push(
                    '${AppPages.sek04.routePath}?id=${membership.user.id}',
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
