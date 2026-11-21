import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide Block;
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/features/home/presentation/ber07_comments_page.dart';
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:material_ui/material_ui.dart';

enum _ProfileContentTab { posts, photos, gallery }

/// SEK-04 Profil Orang Lain bergaya Instagram & Threads (`SEK-R4`, `SEK-R5`, `SEK-R6`, `PSN-R1`, `AC-05`, `AC-06`).
class Sek04PersonProfilePage extends ConsumerStatefulWidget {
  const Sek04PersonProfilePage({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<Sek04PersonProfilePage> createState() =>
      _Sek04PersonProfilePageState();
}

class _Sek04PersonProfilePageState
    extends ConsumerState<Sek04PersonProfilePage> {
  bool _isLoading = true;
  bool _isBusyAction = false;
  _ProfileContentTab _selectedTab = _ProfileContentTab.posts;
  AppError? _error;
  PersonSummary? _person;
  Follow? _followStatus;
  ConnectionRequest? _outgoingRequest;
  ConnectionRequest? _incomingRequest;
  bool _ignoredIncoming = false;
  List<Post> _posts = const <Post>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadProfile);
  }

  Future<void> _loadProfile() async {
    if (widget.userId.trim().isEmpty) {
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

    final profileRepo = ref.read(profileRepositoryProvider);
    final followRepo = ref.read(followRepositoryProvider);
    final connRepo = ref.read(connectionRepositoryProvider);
    final postRepo = ref.read(postRepositoryProvider);

    final personRes = await profileRepo.getPersonSummary(widget.userId);
    if (!mounted) return;

    if (personRes is Err<PersonSummary>) {
      setState(() {
        _isLoading = false;
        _error = personRes.failure;
        _person = null;
      });
      return;
    }

    final person = (personRes as Ok<PersonSummary>).value;
    final followFuture = followRepo.getFollowStatus(person.id);
    final outgoingFuture = connRepo.getOutgoingRequests();
    final incomingFuture = connRepo.getIncomingRequests();
    final postsFuture = postRepo.getUserPosts(person.id);

    final followRes = await followFuture;
    final outgoingRes = await outgoingFuture;
    final incomingRes = await incomingFuture;
    final postsRes = await postsFuture;
    if (!mounted) return;

    final outgoing = outgoingRes is Ok<List<ConnectionRequest>>
        ? outgoingRes.value.where((r) => r.receiver.id == person.id).firstOrNull
        : null;
    final incoming = incomingRes is Ok<List<ConnectionRequest>>
        ? incomingRes.value.where((r) => r.sender.id == person.id).firstOrNull
        : null;

    setState(() {
      _isLoading = false;
      _person = person;
      _followStatus = followRes is Ok<Follow?> ? followRes.value : null;
      _outgoingRequest = outgoing;
      _incomingRequest = incoming;
      _posts = postsRes is Ok<List<Post>> ? postsRes.value : const <Post>[];
    });
  }

  Future<void> _toggleFollow() async {
    final person = _person;
    if (person == null || _isBusyAction) return;
    setState(() => _isBusyAction = true);
    final followRepo = ref.read(followRepositoryProvider);

    if (_followStatus != null) {
      final res = await followRepo.unfollowUser(person.id);
      if (!mounted) return;
      if (res is Err<void>) {
        setState(() => _isBusyAction = false);
        AppToast.show(
          context,
          message: res.failure.message,
          variant: AppToastVariant.error,
        );
        return;
      }
      setState(() => _isBusyAction = false);
      await _loadProfile();
      return;
    }

    final res = await followRepo.followUser(person.id);
    if (!mounted) return;
    setState(() => _isBusyAction = false);
    if (res is Err<Follow>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _loadProfile();
  }

  Future<void> _openKenalanSheet() async {
    final person = _person;
    if (person == null) return;
    final sent = await AppBottomSheet.show<bool>(
      context,
      title: AppStrings.sek04SheetKenalanTitle,
      child: _KenalanRequestSheetBody(targetUserId: person.id),
    );
    if (sent == true && mounted) {
      AppToast.show(
        context,
        message: AppStrings.sek04KenalanSentToast,
        variant: AppToastVariant.success,
      );
      await _loadProfile();
    }
  }

  Future<void> _respondIncoming(bool accept) async {
    final req = _incomingRequest;
    if (req == null || _isBusyAction) return;
    setState(() => _isBusyAction = true);
    final res = await ref
        .read(connectionRepositoryProvider)
        .respondToConnectionRequest(requestId: req.id, accept: accept);
    if (!mounted) return;
    setState(() => _isBusyAction = false);
    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: accept
          ? AppStrings.sek04KenalanAcceptedToast
          : AppStrings.sek04KenalanRejectedToast,
      variant: AppToastVariant.success,
    );
    await _loadProfile();
  }

  Future<void> _confirmRemoveConnection() async {
    final person = _person;
    if (person == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.sek04RemoveConnectionConfirmTitle,
      message: AppStrings.sek04RemoveConnectionConfirmBody,
      confirmLabel: AppStrings.sek04RemoveConnectionAction,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusyAction = true);
    final res = await ref
        .read(connectionRepositoryProvider)
        .removeConnection(person.id);
    if (!mounted) return;
    setState(() => _isBusyAction = false);
    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _loadProfile();
  }

  Future<void> _handleMessageAction() async {
    final person = _person;
    if (person == null || !person.canMessage) return;

    if (person.isConnected ||
        person.isFollowing ||
        person.isFollowedBy ||
        _followStatus != null) {
      await context.push('${AppPages.psn03.routePath}?userId=${person.id}');
      return;
    }

    // PSN-R1 & PSN-R2: Konteks bersama masuk sebagai Permintaan pesan (1 pesan awal)
    final sent = await AppBottomSheet.show<bool>(
      context,
      title: AppStrings.sek04MessageSheetTitle,
      child: _FirstMessageRequestSheetBody(targetUserId: person.id),
    );
    if (sent == true && mounted) {
      AppToast.show(
        context,
        message: AppStrings.sek04MessageSentNotice,
        variant: AppToastVariant.success,
      );
      await context.push(AppPages.psn02.routePath);
    }
  }

  Future<void> _confirmBlock() async {
    final person = _person;
    if (person == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.sek04BlockConfirmTitle,
      message: AppStrings.sek04BlockConfirmBody,
      confirmLabel: AppStrings.sek04MenuBlock,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final res = await ref.read(blockRepositoryProvider).blockUser(person.id);
    if (!mounted) return;
    if (res is Err<Block>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await ref.read(nearbyControllerProvider.notifier).loadInitial();
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _muteAccount() async {
    final person = _person;
    if (person == null) return;
    final res = await ref.read(blockRepositoryProvider).blockUser(person.id);
    if (!mounted) return;
    if (res is Err<Block>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await ref.read(nearbyControllerProvider.notifier).loadInitial();
    if (mounted) {
      AppToast.show(
        context,
        message: AppStrings.sek04MuteSuccessToast,
        variant: AppToastVariant.success,
      );
      context.pop();
    }
  }

  Future<void> _submitKinshipConfirmation(
    PersonSummary person,
    PartuturanResult partuturan,
  ) async {
    final res = await ref
        .read(taromboRepositoryProvider)
        .sendKinshipClaim(
          targetUserId: person.id,
          claimedTermForTarget: partuturan.istilah ?? '',
          note: partuturan.penjelasanJalur,
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
      message: AppStrings.sek04KinshipConfirmToast,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _submitNotThisFeedback(
    PersonSummary person,
    PartuturanResult partuturan,
  ) async {
    final res = await ref
        .read(partuturanRepositoryProvider)
        .submitNotThisFeedback(
          targetMarga: person.marga,
          shownTerm: partuturan.istilah,
        );
    if (!mounted) return;
    if (res is Err<PartuturanFeedback>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.sek04KinshipFeedbackToast,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _toggleLikePost(String postId) async {
    final res = await ref.read(postRepositoryProvider).toggleLike(postId);
    if (!mounted) return;
    res.fold(
      onOk: (updated) {
        setState(() {
          _posts = _posts
              .map((p) => p.id == updated.id ? updated : p)
              .toList(growable: false);
        });
      },
      onErr: (err) => AppToast.show(
        context,
        message: err.message,
        variant: AppToastVariant.error,
      ),
    );
  }

  Future<void> _toggleSavePost(String postId) async {
    final res = await ref.read(postRepositoryProvider).toggleSavePost(postId);
    if (!mounted) return;
    res.fold(
      onOk: (updated) {
        setState(() {
          _posts = _posts
              .map((p) => p.id == updated.id ? updated : p)
              .toList(growable: false);
        });
      },
      onErr: (err) => AppToast.show(
        context,
        message: err.message,
        variant: AppToastVariant.error,
      ),
    );
  }

  Future<void> _openProfileMenuSheet() async {
    final colors = context.colors;
    final typo = context.typo;

    await AppBottomSheet.show<void>(
      context,
      title: _person?.displayName ?? AppStrings.sek04Title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.volume_off_outlined, color: colors.text),
            title: Text(AppStrings.sek04MenuMute, style: typo.bodyStrong),
            onTap: () {
              Navigator.of(context).pop();
              _muteAccount();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined, color: colors.danger),
            title: Text(
              AppStrings.sek04MenuReport,
              style: typo.bodyStrong.copyWith(color: colors.danger),
            ),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/report');
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.block_rounded, color: colors.danger),
            title: Text(
              AppStrings.sek04MenuBlock,
              style: typo.bodyStrong.copyWith(color: colors.danger),
            ),
            onTap: () {
              Navigator.of(context).pop();
              _confirmBlock();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(_person?.displayName ?? AppStrings.sek04Title),
        actions: _person == null
            ? null
            : <Widget>[
                IconButton(
                  tooltip: AppStrings.ber01MenuTooltip,
                  onPressed: _openProfileMenuSheet,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    }

    if (_error != null || _person == null) {
      return StateView.fromError(
        _error ??
            const UnavailableError(
              message: AppStrings.stateContentUnavailableMessage,
            ),
        onRetry: _loadProfile,
        onBack: () => context.pop(),
      );
    }

    final person = _person!;
    final colors = context.colors;
    final typo = context.typo;
    final partuturan = person.partuturan;
    final hidePrivateContent =
        person.isPrivateAccount && !person.isConnected && !person.isFollowing;

    final followLabel = _followStatus == null
        ? (person.isFollowedBy ? AppStrings.termFollback : AppStrings.termIkuti)
        : _followStatus!.isPendingApproval
        ? AppStrings.sek04FollowPending
        : AppStrings.termMengikuti;
    final canDirectChat =
        person.isConnected ||
        person.isFollowing ||
        person.isFollowedBy ||
        _followStatus != null;

    final authRepo = ref.read(authRepositoryProvider);
    final now = authRepo.currentTime;
    final currentUid = authRepo.currentUserId;
    final photoPosts = _posts
        .where((p) => p.media.isNotEmpty)
        .toList(growable: false);
    final visiblePosts = _selectedTab == _ProfileContentTab.photos
        ? photoPosts
        : _posts;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.sm,
              AppSpacing.screenMargin,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header Profil ala IG/Threads
                Row(
                  children: <Widget>[
                    AppAvatar(
                      name: person.displayName,
                      seed: person.avatarSeed,
                      size: 80,
                      showBorder: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        PhotoLightboxPage.show(
                          context,
                          seeds: <String>[person.avatarSeed],
                          title: person.displayName,
                          isCircular: true,
                        );
                      },
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            person.displayName,
                            style: typo.h2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm + 2,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.1),
                                  borderRadius: AppRadius.pillRadius,
                                ),
                                child: Text(
                                  '${person.marga} · ${person.subEthnic.displayName}',
                                  style: typo.micro.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (person.isSameMarga) const SemargaLabel(),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.location_on_outlined,
                                size: AppSizes.iconXs,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${person.city} · ${person.proximity.displayLabel}',
                                  style: typo.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (person.isFollowedBy) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: <Widget>[
                                Icon(
                                  _followStatus != null &&
                                          !_followStatus!.isPendingApproval
                                      ? Icons.sync_alt_rounded
                                      : Icons.person_outline_rounded,
                                  size: AppSizes.iconXs,
                                  color: colors.accent,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  _followStatus != null &&
                                          !_followStatus!.isPendingApproval
                                      ? AppStrings.sek04MutualFollowNotice
                                      : AppStrings.sek04FollowsYouNotice,
                                  style: typo.micro.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                if (!hidePrivateContent &&
                    person.bio.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(person.bio, style: typo.body),
                ],

                const SizedBox(height: AppSpacing.md),

                // Kartu Partuturan Ringkas & Elegan (AC-03, AC-04, SEK-R6)
                if (partuturan != null && !partuturan.modeNetral) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.chipInactive.withValues(alpha: 0.65),
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        PartuturanBadge(
                          result: partuturan,
                          onTap: () => context.push(
                            '${AppPages.tar05.routePath}?userId=${person.id}',
                          ),
                        ),
                        if (partuturan.penjelasanJalur.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          Text(partuturan.penjelasanJalur, style: typo.caption),
                        ],
                        if (partuturan.confidence !=
                            PartuturanConfidence.tinggi) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: AppButton(
                                  label: AppStrings.sek04KinshipAcceptQuestion,
                                  variant: AppButtonVariant.secondary,
                                  compact: true,
                                  onPressed: () => _submitKinshipConfirmation(
                                    person,
                                    partuturan,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              AppButton(
                                label: AppStrings.sek04KinshipRejectQuestion,
                                variant: AppButtonVariant.text,
                                compact: true,
                                onPressed: () =>
                                    _submitNotThisFeedback(person, partuturan),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else if (partuturan != null &&
                    partuturan.modeNetral) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.chipInactive.withValues(alpha: 0.6),
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      AppStrings.sek04NeutralModeHint,
                      style: typo.caption,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Banner Permintaan Kenalan Masuk (Terima / Tolak / Abaikan)
                if (_incomingRequest != null && !_ignoredIncoming) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.06),
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppStrings.sek04IncomingRequestBanner,
                          style: typo.bodyStrong,
                        ),
                        if (_incomingRequest!
                            .introMessage
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _incomingRequest!.introMessage,
                            style: typo.body,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: AppButton(
                                label: AppStrings.sek04AcceptBtn,
                                compact: true,
                                isDisabled: _isBusyAction,
                                onPressed: () => _respondIncoming(true),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: AppButton(
                                label: AppStrings.sek04RejectBtn,
                                variant: AppButtonVariant.secondary,
                                compact: true,
                                isDisabled: _isBusyAction,
                                onPressed: () => _respondIncoming(false),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            AppButton(
                              label: AppStrings.sek04IgnoreBtn,
                              variant: AppButtonVariant.text,
                              compact: true,
                              isDisabled: _isBusyAction,
                              onPressed: () =>
                                  setState(() => _ignoredIncoming = true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Baris Tombol Seragam Gaya IG: [Follback / Ikuti / Mengikuti] + [Pesan]
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        label: followLabel,
                        variant: _followStatus == null
                            ? AppButtonVariant.primary
                            : AppButtonVariant.tonal,
                        compact: true,
                        isDisabled: _isBusyAction,
                        leadingIcon: _followStatus == null
                            ? Icons.person_add_alt_1_outlined
                            : Icons.check_rounded,
                        onPressed: _toggleFollow,
                      ),
                    ),
                    // AC-06 & PSN-R1: Tombol Pesan HANYA tampil bila person.canMessage == true
                    if (person.canMessage) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: canDirectChat
                              ? AppStrings.termPesan
                              : '${AppStrings.termPesan} (${AppStrings.sek04MessageRequestBadge})',
                          variant: AppButtonVariant.tonal,
                          compact: true,
                          isDisabled: _isBusyAction,
                          leadingIcon: Icons.chat_bubble_outline_rounded,
                          onPressed: _handleMessageAction,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Aksi Kenalan / Terhubung seragam
                if (person.isConnected)
                  AppButton(
                    label: AppStrings.termTerhubung,
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    isExpanded: true,
                    isDisabled: _isBusyAction,
                    leadingIcon: Icons.handshake_outlined,
                    onPressed: _confirmRemoveConnection,
                  )
                else if (_outgoingRequest != null)
                  const AppButton(
                    label: AppStrings.sek04ConnectionSent,
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    isExpanded: true,
                    isDisabled: true,
                  )
                else if (_incomingRequest == null || _ignoredIncoming)
                  AppButton(
                    label: AppStrings.termKenalan,
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    isExpanded: true,
                    isDisabled: _isBusyAction,
                    leadingIcon: Icons.waving_hand_outlined,
                    onPressed: _openKenalanSheet,
                  ),

                if (!hidePrivateContent) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _InfoRowList(person: person),
                ],
              ],
            ),
          ),
          if (hidePrivateContent)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                0,
                AppSpacing.screenMargin,
                AppSpacing.screenMargin,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: colors.chipInactive.withValues(alpha: 0.45),
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.65),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline_rounded,
                      size: AppSizes.iconXl,
                      color: colors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(AppStrings.sek04PrivateAccountTitle, style: typo.h3),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.sek04PrivateAccountSubtitle,
                      style: typo.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            // Tab gaya Threads + Instagram: Postingan | Foto | Galeri Grid
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.border.withValues(alpha: 0.45),
                    width: AppSizes.strokeThin,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _ProfileSegmentTab(
                      label: AppStrings.sek04PostsTab,
                      icon: Icons.view_agenda_outlined,
                      selected: _selectedTab == _ProfileContentTab.posts,
                      onTap: () => setState(
                        () => _selectedTab = _ProfileContentTab.posts,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ProfileSegmentTab(
                      label: AppStrings.sek04PhotosTab,
                      icon: Icons.photo_library_outlined,
                      selected: _selectedTab == _ProfileContentTab.photos,
                      onTap: () => setState(
                        () => _selectedTab = _ProfileContentTab.photos,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ProfileSegmentTab(
                      label: AppStrings.sek04GalleryTab,
                      icon: Icons.grid_on_rounded,
                      selected: _selectedTab == _ProfileContentTab.gallery,
                      onTap: () => setState(
                        () => _selectedTab = _ProfileContentTab.gallery,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: AppSizes.strokeThin,
              thickness: AppSizes.strokeThin,
              color: colors.border.withValues(alpha: 0.45),
            ),
            if (_selectedTab == _ProfileContentTab.gallery)
              photoPosts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenMargin,
                        vertical: AppSpacing.xxl,
                      ),
                      child: Center(
                        child: Text(
                          AppStrings.sek04NoPhotosYet,
                          style: typo.caption,
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(2),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                      itemCount: photoPosts.length,
                      itemBuilder: (context, idx) {
                        final post = photoPosts[idx];
                        final firstMedia = post.media.first;
                        return GestureDetector(
                          onTap: () => context.push(
                            '${AppPages.ber06.routePath}?id=${post.id}',
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              PlaceholderImage(
                                seed: firstMedia.seed,
                                borderRadius: BorderRadius.zero,
                              ),
                              if (post.media.length > 1)
                                const Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Icon(
                                    Icons.collections_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    )
            else if (visiblePosts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                  vertical: AppSpacing.xxl,
                ),
                child: Center(
                  child: Text(
                    _selectedTab == _ProfileContentTab.photos
                        ? AppStrings.sek04NoPhotosYet
                        : AppStrings.sek04NoPostsYet,
                    style: typo.caption,
                  ),
                ),
              )
            else
              for (var i = 0; i < visiblePosts.length; i++) ...<Widget>[
                PostCard(
                  post: visiblePosts[i],
                  now: now,
                  isOwnPost: visiblePosts[i].author.id == currentUid,
                  onAuthorTap: () {},
                  onTapCard: () => context.push(
                    '${AppPages.ber06.routePath}?id=${visiblePosts[i].id}',
                  ),
                  onLikeTap: () => _toggleLikePost(visiblePosts[i].id),
                  onLikesCountTap: () => context.push(
                    '${AppPages.ber08.routePath}?id=${visiblePosts[i].id}',
                  ),
                  onCommentTap: () => Ber07CommentsPage.showSheet(
                    context,
                    postId: visiblePosts[i].id,
                  ),
                  onSaveTap: () => _toggleSavePost(visiblePosts[i].id),
                  onReportTap: () => context.push('/report'),
                  onMuteTap: _muteAccount,
                  onBlockTap: _confirmBlock,
                ),
                if (i < visiblePosts.length - 1)
                  Divider(
                    height: AppSizes.strokeThin,
                    thickness: AppSizes.strokeThin,
                    color: colors.border.withValues(alpha: 0.45),
                  ),
              ],
          ],
        ],
      ),
    );
  }
}

class _ProfileSegmentTab extends StatelessWidget {
  const _ProfileSegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.text : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: selected ? colors.text : colors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: selected
                    ? typo.captionStrong
                    : typo.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRowList extends StatelessWidget {
  const _InfoRowList({required this.person});

  final PersonSummary person;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (person.visibleMotherMarga != null &&
          person.visibleMotherMarga!.trim().isNotEmpty)
        (AppStrings.sek04MotherMargaLabel, person.visibleMotherMarga!),
      if (person.visibleSubdistrict != null &&
          person.visibleSubdistrict!.trim().isNotEmpty)
        (AppStrings.sek04SubdistrictLabel, person.visibleSubdistrict!),
      if (person.visibleAgeGroup != null &&
          person.visibleAgeGroup!.trim().isNotEmpty)
        (AppStrings.sek04AgeGroupLabel, person.visibleAgeGroup!),
      if (person.campusOrOffice != null &&
          person.campusOrOffice!.trim().isNotEmpty)
        (AppStrings.sek04CampusOfficeLabel, person.campusOrOffice!),
      if (person.hobbies.isNotEmpty)
        (AppStrings.sek04HobbiesLabel, person.hobbies.join(', ')),
      if (person.sharedCommunitiesCount > 0)
        (
          AppStrings.sek01SegmentKomunitas,
          AppStrings.sek02SharedCommunitiesCount(person.sharedCommunitiesCount),
        ),
    ];

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final typo = context.typo;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.chipInactive.withValues(alpha: 0.45),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < rows.length; i++) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 2, child: Text(rows[i].$1, style: typo.caption)),
                Expanded(
                  flex: 3,
                  child: Text(rows[i].$2, style: typo.captionStrong),
                ),
              ],
            ),
            if (i < rows.length - 1)
              Divider(
                height: AppSpacing.md,
                color: colors.border.withValues(alpha: 0.45),
              ),
          ],
        ],
      ),
    );
  }
}

class _KenalanRequestSheetBody extends ConsumerStatefulWidget {
  const _KenalanRequestSheetBody({required this.targetUserId});

  final String targetUserId;

  @override
  ConsumerState<_KenalanRequestSheetBody> createState() =>
      _KenalanRequestSheetBodyState();
}

class _KenalanRequestSheetBodyState
    extends ConsumerState<_KenalanRequestSheetBody> {
  final TextEditingController _introCtrl = TextEditingController(
    text: AppStrings.sek04QuickGreetings.first,
  );
  bool _sending = false;
  String? _errorMsg;

  @override
  void dispose() {
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _errorMsg = null;
    });
    final res = await ref
        .read(connectionRepositoryProvider)
        .sendConnectionRequest(
          targetUserId: widget.targetUserId,
          introMessage: _introCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _sending = false);

    if (res is Err<ConnectionRequest>) {
      setState(() => _errorMsg = res.failure.message);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(AppStrings.sek04SheetKenalanSubtitle, style: typo.caption),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final greeting in AppStrings.sek04QuickGreetings)
              AppChip(
                label: greeting,
                isSelected: _introCtrl.text == greeting,
                onTap: () => setState(() => _introCtrl.text = greeting),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _introCtrl,
          hintText: AppStrings.sek04IntroHint,
          maxLines: 3,
          maxLength: AppLimits.connectionIntroMaxChars,
          onChanged: (_) => setState(() {}),
        ),
        if (_errorMsg != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(_errorMsg!, style: typo.caption.copyWith(color: colors.danger)),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppStrings.sek04SendKenalanBtn,
          isLoading: _sending,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _FirstMessageRequestSheetBody extends ConsumerStatefulWidget {
  const _FirstMessageRequestSheetBody({required this.targetUserId});

  final String targetUserId;

  @override
  ConsumerState<_FirstMessageRequestSheetBody> createState() =>
      _FirstMessageRequestSheetBodyState();
}

class _FirstMessageRequestSheetBodyState
    extends ConsumerState<_FirstMessageRequestSheetBody> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _sending = false;
  String? _errorMsg;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _errorMsg = null;
    });
    final res = await ref
        .read(chatRepositoryProvider)
        .sendFirstMessageToUser(
          targetUserId: widget.targetUserId,
          text: _msgCtrl.text,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res is Err<Message>) {
      setState(() => _errorMsg = res.failure.message);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(AppStrings.sek04MessageRequestNotice, style: typo.caption),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _msgCtrl,
          hintText: AppStrings.sek04IntroHint,
          maxLines: 3,
          maxLength: AppLimits.messageTextMaxChars,
        ),
        if (_errorMsg != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(_errorMsg!, style: typo.caption.copyWith(color: colors.danger)),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppStrings.sek04SendFirstMessageBtn,
          isLoading: _sending,
          onPressed: _send,
        ),
      ],
    );
  }
}
