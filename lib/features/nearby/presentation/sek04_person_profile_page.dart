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
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-04 Profil Orang Lain (`SEK-R4`, `SEK-R5`, `SEK-R6`, `PSN-R1`, `AC-05`, `AC-06`).
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

    if (person.isConnected) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_person?.displayName ?? AppStrings.sek04Title),
        actions: _person == null
            ? null
            : <Widget>[
                PopupMenuButton<String>(
                  tooltip: AppStrings.ber01MenuTooltip,
                  onSelected: (value) async {
                    switch (value) {
                      case 'report':
                        await context.push('/report');
                      case 'mute':
                        await _muteAccount();
                      case 'block':
                        await _confirmBlock();
                    }
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'report',
                      child: Text(AppStrings.sek04MenuReport),
                    ),
                    PopupMenuItem<String>(
                      value: 'mute',
                      child: Text(AppStrings.sek04MenuMute),
                    ),
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Text(AppStrings.sek04MenuBlock),
                    ),
                  ],
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
        ? AppStrings.termIkuti
        : _followStatus!.isPendingApproval
        ? AppStrings.sek04FollowPending
        : AppStrings.termMengikuti;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: <Widget>[
          // Header Profil (nama, foto, marga, kota, rentang jarak — selalu tampil walau privat)
          Row(
            children: <Widget>[
              AppAvatar(
                name: person.displayName,
                seed: person.avatarSeed,
                size: AppSizes.avatarXl,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(person.displayName, style: typo.h2),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${person.marga} · ${person.subEthnic.displayName}',
                      style: typo.bodyStrong.copyWith(color: colors.primary),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${person.city} · ${person.proximity.displayLabel}',
                      style: typo.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Badge Partuturan & Semarga (AC-03, AC-04, SEK-R6)
          if (partuturan != null && !partuturan.modeNetral) ...<Widget>[
            PartuturanBadge(
              result: partuturan,
              onTap: () => context.push(
                '${AppPages.tar05.routePath}?userId=${person.id}',
              ),
            ),
            if (partuturan.penjelasanJalur.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(partuturan.penjelasanJalur, style: typo.caption),
            ],
            if (partuturan.confidence !=
                PartuturanConfidence.tinggi) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () =>
                        _submitKinshipConfirmation(person, partuturan),
                    child: const Text(AppStrings.sek04KinshipAcceptQuestion),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () => _submitNotThisFeedback(person, partuturan),
                    child: const Text(AppStrings.sek04KinshipRejectQuestion),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ] else if (partuturan != null && partuturan.modeNetral) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.border),
              ),
              child: Text(AppStrings.sek04NeutralModeHint, style: typo.caption),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (person.isSameMarga) ...<Widget>[
            const SemargaLabel(),
            const SizedBox(height: AppSpacing.md),
          ],

          // Banner Permintaan Kenalan Masuk (Terima / Tolak / Abaikan)
          if (_incomingRequest != null && !_ignoredIncoming) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.sek04IncomingRequestBanner,
                    style: typo.bodyStrong,
                  ),
                  if (_incomingRequest!.introMessage.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(_incomingRequest!.introMessage, style: typo.body),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: _isBusyAction
                            ? null
                            : () => _respondIncoming(true),
                        child: const Text(AppStrings.sek04AcceptBtn),
                      ),
                      OutlinedButton(
                        onPressed: _isBusyAction
                            ? null
                            : () => _respondIncoming(false),
                        child: const Text(AppStrings.sek04RejectBtn),
                      ),
                      TextButton(
                        onPressed: _isBusyAction
                            ? null
                            : () => setState(() => _ignoredIncoming = true),
                        child: const Text(AppStrings.sek04IgnoreBtn),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Tombol Aksi: Ikuti, Kenalan, Pesan (PSN-R1, AC-06)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 112),
                child: _followStatus == null
                    ? OutlinedButton.icon(
                        onPressed: _isBusyAction ? null : _toggleFollow,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(followLabel),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _isBusyAction ? null : _toggleFollow,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(followLabel),
                      ),
              ),
              if (person.isConnected)
                FilledButton.tonalIcon(
                  onPressed: _isBusyAction ? null : _confirmRemoveConnection,
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text(AppStrings.termTerhubung),
                )
              else if (_outgoingRequest != null)
                const OutlinedButton(
                  onPressed: null,
                  child: Text(AppStrings.sek04ConnectionSent),
                )
              else if (_incomingRequest == null || _ignoredIncoming)
                ElevatedButton.icon(
                  onPressed: _isBusyAction ? null : _openKenalanSheet,
                  icon: const Icon(Icons.waving_hand_outlined),
                  label: const Text(AppStrings.termKenalan),
                ),
              // AC-06 & PSN-R1: Tombol Pesan HANYA tampil bila person.canMessage == true
              if (person.canMessage)
                ElevatedButton.icon(
                  onPressed: _isBusyAction ? null : _handleMessageAction,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(
                    person.isConnected
                        ? AppStrings.termPesan
                        : '${AppStrings.termPesan} (${AppStrings.sek04MessageRequestBadge})',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Konten Profil berdasarkan status Privat / Privasi Per Bidang (PRD 7.1)
          if (hidePrivateContent) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.border),
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
          ] else ...<Widget>[
            if (person.bio.trim().isNotEmpty) ...<Widget>[
              Text(AppStrings.sek04BioSectionTitle, style: typo.h3),
              const SizedBox(height: AppSpacing.xs),
              Text(person.bio, style: typo.body),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(AppStrings.sek04InfoSectionTitle, style: typo.h3),
            const SizedBox(height: AppSpacing.sm),
            _InfoRowList(person: person),
            if (_posts.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              Text(AppStrings.ber01Title, style: typo.h3),
              const SizedBox(height: AppSpacing.sm),
              for (final post in _posts)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    title: Text(
                      post.text.isEmpty ? AppStrings.ber06Title : post.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: post.cityTag != null ? Text(post.cityTag!) : null,
                    onTap: () => context.push(
                      '${AppPages.ber06.routePath}?id=${post.id}',
                    ),
                  ),
                ),
            ],
          ],
        ],
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border),
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
                  child: Text(rows[i].$2, style: typo.bodyStrong),
                ),
              ],
            ),
            if (i < rows.length - 1) const Divider(height: AppSpacing.lg),
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
