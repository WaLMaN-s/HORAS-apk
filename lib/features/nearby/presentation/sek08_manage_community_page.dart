import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-08 Kelola Komunitas (`SEK-R8`, `SEK-R9`, `SEK-R10`, `SEK-R11`).
///
/// Memuat tab Anggota, Permintaan gabung, Peran (Pemilik & Pengurus maks 10),
/// Pengumuman (sematan maks 3), dialog keluarkan anggota, serahkan kepemilikan,
/// dan tautan "Ajukan Verifikasi" menuju rute `/verification` placeholder (`SIS-06`).
class Sek08ManageCommunityPage extends ConsumerStatefulWidget {
  const Sek08ManageCommunityPage({required this.communityId, super.key});

  final String communityId;

  @override
  ConsumerState<Sek08ManageCommunityPage> createState() =>
      _Sek08ManageCommunityPageState();
}

class _Sek08ManageCommunityPageState
    extends ConsumerState<Sek08ManageCommunityPage> {
  final TextEditingController _annTitleCtrl = TextEditingController();
  final TextEditingController _annBodyCtrl = TextEditingController();
  bool _annPinned = false;
  bool _isLoading = true;
  bool _isBusy = false;
  AppError? _error;

  Community? _community;
  List<Membership> _members = const <Membership>[];
  List<JoinRequest> _requests = const <JoinRequest>[];
  List<Announcement> _announcements = const <Announcement>[];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _annTitleCtrl.dispose();
    _annBodyCtrl.dispose();
    super.dispose();
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
    _currentUserId = ref.read(authRepositoryProvider).currentUserId;

    final commRes = await commRepo.getCommunityById(widget.communityId);
    if (!mounted) return;
    if (commRes is Err<Community>) {
      setState(() {
        _isLoading = false;
        _error = commRes.failure;
      });
      return;
    }

    final comm = (commRes as Ok<Community>).value;
    final membersFuture = commRepo.getMembers(comm.id);
    final reqsFuture = commRepo.getPendingJoinRequests(comm.id);
    final annFuture = commRepo.getAnnouncements(comm.id);

    final membersRes = await membersFuture;
    final reqsRes = await reqsFuture;
    final annRes = await annFuture;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _community = comm;
      _members = membersRes is Ok<List<Membership>>
          ? membersRes.value
          : const <Membership>[];
      _requests = reqsRes is Ok<List<JoinRequest>>
          ? reqsRes.value
          : const <JoinRequest>[];
      _announcements = annRes is Ok<List<Announcement>>
          ? annRes.value
          : const <Announcement>[];
    });
  }

  Future<void> _respondJoin(JoinRequest req, bool approve) async {
    setState(() => _isBusy = true);
    final res = await ref
        .read(communityRepositoryProvider)
        .respondJoinRequest(joinRequestId: req.id, approve: approve);
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
    await _load();
  }

  Future<void> _setRole(Membership member, CommunityRole role) async {
    final comm = _community;
    if (comm == null) return;
    setState(() => _isBusy = true);
    final res = await ref
        .read(communityRepositoryProvider)
        .setMemberRole(
          communityId: comm.id,
          targetUserId: member.user.id,
          role: role,
        );
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
    await _load();
  }

  Future<void> _confirmKick(Membership member) async {
    final comm = _community;
    if (comm == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.sek08KickConfirmTitle,
      message: AppStrings.sek08KickConfirmBody(member.user.displayName),
      confirmLabel: AppStrings.sek08KickMember,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final res = await ref
        .read(communityRepositoryProvider)
        .removeMember(communityId: comm.id, targetUserId: member.user.id);
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
    await _load();
  }

  Future<void> _confirmTransferOwnership(Membership member) async {
    final comm = _community;
    if (comm == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.sek08TransferConfirmTitle,
      message: AppStrings.sek08TransferConfirmBody(member.user.displayName),
      confirmLabel: AppStrings.sek08TransferOwner,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final res = await ref
        .read(communityRepositoryProvider)
        .transferOwnership(
          communityId: comm.id,
          newOwnerUserId: member.user.id,
        );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (res is Err<Community>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _load();
  }

  Future<void> _publishAnnouncement() async {
    final comm = _community;
    if (comm == null) return;
    setState(() => _isBusy = true);
    final res = await ref
        .read(communityRepositoryProvider)
        .createAnnouncement(
          communityId: comm.id,
          title: _annTitleCtrl.text,
          body: _annBodyCtrl.text,
          isPinned: _annPinned,
        );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (res is Err<Announcement>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    _annTitleCtrl.clear();
    _annBodyCtrl.clear();
    _annPinned = false;
    await _load();
  }

  Future<void> _togglePin(Announcement ann) async {
    final comm = _community;
    if (comm == null) return;
    final res = await ref
        .read(communityRepositoryProvider)
        .togglePinAnnouncement(communityId: comm.id, announcementId: ann.id);
    if (!mounted) return;
    if (res is Err<Announcement>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.sek08Title),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: AppStrings.sek08TabMembers),
              Tab(text: AppStrings.sek08TabRequests),
              Tab(text: AppStrings.sek08TabRoles),
              Tab(text: AppStrings.sek08TabAnnouncements),
            ],
          ),
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    }
    if (_error != null || _community == null) {
      return StateView.fromError(_error!, onRetry: _load);
    }

    final comm = _community!;
    final isOwner = comm.ownerId == _currentUserId;
    final colors = context.colors;
    final typo = context.typo;
    final managersCount = _members
        .where((m) => m.role == CommunityRole.manager)
        .length;
    final pinnedCount = _announcements.where((a) => a.isPinned).length;

    return Column(
      children: <Widget>[
        // Bar info & lencana verifikasi + tautan Ajukan Verifikasi (SEK-R9)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      comm.name,
                      style: typo.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
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
              ),
              if (!comm.isVerified)
                TextButton(
                  onPressed: () => context.push('/verification'),
                  child: const Text(AppStrings.sek08RequestVerificationBtn),
                ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: <Widget>[
              // Tab 1: Anggota (termasuk dialog keluarkan anggota)
              ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final m = _members[index];
                  final roleLabel = switch (m.role) {
                    CommunityRole.owner => AppStrings.sek08RoleOwner,
                    CommunityRole.manager => AppStrings.sek08RoleManager,
                    CommunityRole.member => AppStrings.sek08RoleMember,
                  };
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: AppAvatar(
                        name: m.user.displayName,
                        seed: m.user.avatarSeed,
                      ),
                      title: Text(m.user.displayName, style: typo.bodyStrong),
                      subtitle: Text(
                        '${m.user.marga} · $roleLabel',
                        style: typo.caption,
                      ),
                      trailing: m.user.id == comm.ownerId
                          ? null
                          : PopupMenuButton<String>(
                              tooltip: AppStrings.ber01MenuTooltip,
                              onSelected: (val) async {
                                switch (val) {
                                  case 'promote':
                                    await _setRole(m, CommunityRole.manager);
                                  case 'demote':
                                    await _setRole(m, CommunityRole.member);
                                  case 'transfer':
                                    await _confirmTransferOwnership(m);
                                  case 'kick':
                                    await _confirmKick(m);
                                }
                              },
                              itemBuilder: (_) => <PopupMenuEntry<String>>[
                                if (isOwner && m.role != CommunityRole.manager)
                                  const PopupMenuItem<String>(
                                    value: 'promote',
                                    child: Text(AppStrings.sek08PromoteManager),
                                  ),
                                if (isOwner && m.role == CommunityRole.manager)
                                  const PopupMenuItem<String>(
                                    value: 'demote',
                                    child: Text(AppStrings.sek08DemoteMember),
                                  ),
                                if (isOwner)
                                  const PopupMenuItem<String>(
                                    value: 'transfer',
                                    child: Text(AppStrings.sek08TransferOwner),
                                  ),
                                const PopupMenuItem<String>(
                                  value: 'kick',
                                  child: Text(AppStrings.sek08KickMember),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),

              // Tab 2: Permintaan Gabung
              _requests.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screenMargin),
                        child: Text(
                          AppStrings.sek08NoJoinRequests,
                          style: typo.caption,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.screenMargin),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final req = _requests[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: <Widget>[
                                AppAvatar(
                                  name: req.applicant.displayName,
                                  seed: req.applicant.avatarSeed,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        req.applicant.displayName,
                                        style: typo.bodyStrong,
                                      ),
                                      Text(
                                        '${req.applicant.marga} · ${req.applicant.city}',
                                        style: typo.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isBusy
                                      ? null
                                      : () => _respondJoin(req, false),
                                  child: const Text(
                                    AppStrings.sek08RejectJoinBtn,
                                  ),
                                ),
                                FilledButton(
                                  onPressed: _isBusy
                                      ? null
                                      : () => _respondJoin(req, true),
                                  child: const Text(
                                    AppStrings.sek08ApproveJoinBtn,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

              // Tab 3: Peran (Pemilik & Pengurus maks 10)
              ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: <Widget>[
                  Text(
                    '${AppStrings.sek08ManagersLimitNote} ($managersCount/${AppLimits.maxCommunityManagers})',
                    style: typo.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final m in _members.where(
                    (m) =>
                        m.role == CommunityRole.owner ||
                        m.role == CommunityRole.manager,
                  ))
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: AppAvatar(
                          name: m.user.displayName,
                          seed: m.user.avatarSeed,
                        ),
                        title: Text(m.user.displayName, style: typo.bodyStrong),
                        subtitle: Text(
                          m.role == CommunityRole.owner
                              ? AppStrings.sek08RoleOwner
                              : AppStrings.sek08RoleManager,
                          style: typo.caption,
                        ),
                        trailing: isOwner && m.role == CommunityRole.manager
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  TextButton(
                                    onPressed: _isBusy
                                        ? null
                                        : () => _confirmTransferOwnership(m),
                                    child: const Text(
                                      AppStrings.sek08TransferOwner,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _isBusy
                                        ? null
                                        : () =>
                                              _setRole(m, CommunityRole.member),
                                    child: const Text(
                                      AppStrings.sek08DemoteMember,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                ],
              ),

              // Tab 4: Pengumuman (Sematan maks 3)
              ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: <Widget>[
                  Text(
                    '${AppStrings.sek08PinnedLimitNote} ($pinnedCount/${AppLimits.maxPinnedAnnouncements})',
                    style: typo.caption,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _annTitleCtrl,
                    label: AppStrings.sek08AnnouncementTitleLabel,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _annBodyCtrl,
                    label: AppStrings.sek08AnnouncementBodyLabel,
                    maxLines: 3,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.sek08PinAnnouncementToggle),
                    value: _annPinned,
                    onChanged: (v) => setState(() => _annPinned = v),
                  ),
                  AppButton(
                    label: AppStrings.sek08PublishAnnouncementBtn,
                    isLoading: _isBusy,
                    onPressed: _publishAnnouncement,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final ann in _announcements)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(ann.title, style: typo.bodyStrong),
                        subtitle: Text(ann.body, style: typo.caption),
                        trailing: IconButton(
                          tooltip: AppStrings.sek08PinToggleBtn,
                          onPressed: () => _togglePin(ann),
                          icon: Icon(
                            ann.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            color: ann.isPinned
                                ? colors.primary
                                : colors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
