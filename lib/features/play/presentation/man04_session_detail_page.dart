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
import 'package:horas/domain/policies/horas_policies.dart';
import 'package:horas/features/play/presentation/play_controller.dart';
import 'package:horas/features/play/presentation/play_models.dart';
import 'package:material_ui/material_ui.dart';

/// MAN-04 Detail Sesi (`MAN-R2` .. `MAN-R9`, `MAN-R11`, `AC-08`, `AC-09`).
class Man04SessionDetailPage extends ConsumerStatefulWidget {
  const Man04SessionDetailPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<Man04SessionDetailPage> createState() =>
      _Man04SessionDetailPageState();
}

class _Man04SessionDetailPageState
    extends ConsumerState<Man04SessionDetailPage> {
  PlaySession? _session;
  List<Participant> _participants = const <Participant>[];
  List<WaitlistEntry> _waitlist = const <WaitlistEntry>[];
  List<ReliabilityMark> _myReliabilityMarks = const <ReliabilityMark>[];
  bool _isLoading = true;
  bool _isActionLoading = false;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (widget.sessionId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final sessionRepo = ref.read(sessionRepositoryProvider);
    final currentUserId = ref.read(authRepositoryProvider).currentUserId ?? '';

    final sessionRes = await sessionRepo.getSessionById(widget.sessionId);
    if (!mounted) return;
    if (sessionRes is Err<PlaySession>) {
      setState(() {
        _isLoading = false;
        _error = sessionRes.failure;
      });
      return;
    }

    final participantsRes = await sessionRepo.getParticipants(widget.sessionId);
    final waitlistRes = await sessionRepo.getWaitlist(widget.sessionId);
    final marksRes = currentUserId.isEmpty
        ? const Ok<List<ReliabilityMark>>(<ReliabilityMark>[])
        : await sessionRepo.getReliabilityMarksForHost(currentUserId);

    if (!mounted) return;
    setState(() {
      _session = (sessionRes as Ok<PlaySession>).value;
      _participants = participantsRes is Ok<List<Participant>>
          ? participantsRes.value
          : const <Participant>[];
      _waitlist = waitlistRes is Ok<List<WaitlistEntry>>
          ? waitlistRes.value
          : const <WaitlistEntry>[];
      _myReliabilityMarks = marksRes is Ok<List<ReliabilityMark>>
          ? marksRes.value
          : const <ReliabilityMark>[];
      _isLoading = false;
    });
  }

  Participant? _findMyParticipant(String currentUserId) {
    for (final p in _participants) {
      if (p.user.id == currentUserId && p.status != ParticipantStatus.removed) {
        return p;
      }
    }
    return null;
  }

  WaitlistEntry? _findMyWaitlist(String currentUserId) {
    for (final w in _waitlist) {
      if (w.user.id == currentUserId) return w;
    }
    return null;
  }

  Future<void> _handleJoin() async {
    final session = _session;
    if (session == null) return;
    setState(() => _isActionLoading = true);

    final res = await ref
        .read(sessionRepositoryProvider)
        .joinSession(session.id);
    if (!mounted) return;

    if (res is Err<({Participant? participant, WaitlistEntry? waitlist})>) {
      setState(() => _isActionLoading = false);
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    final payload =
        (res as Ok<({Participant? participant, WaitlistEntry? waitlist})>)
            .value;
    if (payload.participant?.status == ParticipantStatus.joined) {
      final now = ref.read(authRepositoryProvider).currentTime;
      await ref
          .read(sessionReminderServiceProvider)
          .scheduleForSession(session: session, now: now);
    }

    await ref.read(playControllerProvider.notifier).loadInitial();
    await _load();
    if (!mounted) return;
    setState(() => _isActionLoading = false);
  }

  Future<void> _handleLeave(Participant? myParticipant) async {
    final session = _session;
    if (session == null) return;
    final now = ref.read(authRepositoryProvider).currentTime;
    final isJoined = myParticipant?.status == ParticipantStatus.joined;
    final lateMarkApplies =
        isJoined &&
        HorasPolicies.shouldRecordLateLeaveMark(
          sessionStartTime: session.startTime,
          leaveTime: now,
          promotedFromWaitlistAt: myParticipant?.promotedFromWaitlistAt,
          scheduleUpdatedAt: session.scheduleUpdatedAt,
        );

    final confirmed = await ConfirmDialog.show(
      context,
      title: lateMarkApplies
          ? AppStrings.man04LateLeaveTitle
          : AppStrings.man04NormalLeaveTitle,
      message: lateMarkApplies
          ? AppStrings.man04LateLeaveBody
          : AppStrings.man04NormalLeaveBody,
      confirmLabel: AppStrings.man04LeaveBtn,
      isDestructive: lateMarkApplies,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    final res = await ref
        .read(sessionRepositoryProvider)
        .leaveSession(session.id);
    if (!mounted) return;

    if (res is Err<void>) {
      setState(() => _isActionLoading = false);
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    await ref.read(sessionReminderServiceProvider).cancelForSession(session.id);
    await ref.read(playControllerProvider.notifier).loadInitial();
    await _load();
    if (!mounted) return;
    setState(() => _isActionLoading = false);
  }

  Future<void> _handleCancelSession() async {
    final session = _session;
    if (session == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.man04CancelSessionTitle,
      message: AppStrings.man04CancelSessionBody,
      confirmLabel: AppStrings.man04CancelSessionBtn,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    final res = await ref
        .read(sessionRepositoryProvider)
        .cancelSession(session.id);
    if (!mounted) return;
    if (res is Err<PlaySession>) {
      setState(() => _isActionLoading = false);
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    await ref.read(sessionReminderServiceProvider).cancelForSession(session.id);
    await ref.read(playControllerProvider.notifier).loadInitial();
    await _load();
    if (!mounted) return;
    setState(() => _isActionLoading = false);
  }

  Future<void> _openEditScheduleSheet() async {
    final session = _session;
    if (session == null) return;
    final courtsRes = await ref
        .read(courtRepositoryProvider)
        .getCourts(city: session.city, sportType: session.sportType);
    if (!mounted) return;

    final courts = courtsRes is Ok<List<Court>>
        ? courtsRes.value
        : const <Court>[];
    var newStart = session.startTime;
    var newEnd = session.endTime;
    var newCourtId = session.courtId;

    final saved = await AppBottomSheet.show<bool>(
      context,
      title: AppStrings.man04EditScheduleDialogTitle,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppStrings.man04EditScheduleNote,
                style: ctx.typo.caption.copyWith(color: ctx.colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                PlayFormatters.formatTimeWindow(newStart, newEnd),
                style: ctx.typo.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppChip(
                    label: AppStrings.man04Delay1HourBtn,
                    onTap: () => setSheetState(() {
                      newStart = newStart.add(const Duration(hours: 1));
                      newEnd = newEnd.add(const Duration(hours: 1));
                    }),
                  ),
                  AppChip(
                    label: AppStrings.man04Delay1DayBtn,
                    onTap: () => setSheetState(() {
                      newStart = newStart.add(const Duration(days: 1));
                      newEnd = newEnd.add(const Duration(days: 1));
                    }),
                  ),
                ],
              ),
              if (courts.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: courts.any((c) => c.id == newCourtId)
                      ? newCourtId
                      : null,
                  decoration: const InputDecoration(
                    labelText: AppStrings.man03CourtSelectLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: courts
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setSheetState(() => newCourtId = value),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: AppStrings.actionSave,
                isExpanded: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true || !mounted) return;
    setState(() => _isActionLoading = true);
    final updateRes = await ref
        .read(sessionRepositoryProvider)
        .updateSessionSchedule(
          sessionId: session.id,
          startTime: newStart,
          endTime: newEnd,
          courtId: newCourtId,
        );
    if (!mounted) return;
    if (updateRes is Err<PlaySession>) {
      setState(() => _isActionLoading = false);
      AppToast.show(
        context,
        message: updateRes.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    final updated = (updateRes as Ok<PlaySession>).value;
    final now = ref.read(authRepositoryProvider).currentTime;
    await ref
        .read(sessionReminderServiceProvider)
        .scheduleForSession(session: updated, now: now);
    await ref.read(playControllerProvider.notifier).loadInitial();
    await _load();
    if (!mounted) return;
    setState(() => _isActionLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(authRepositoryProvider).currentUserId ?? '';
    final now = ref.read(authRepositoryProvider).currentTime;
    final colors = context.colors;
    final typo = context.typo;

    Widget body;
    if (_isLoading) {
      body = const StateView.loading(itemCount: 3);
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_session == null) {
      body = StateView.empty(
        message: AppStrings.stateEmptyDefaultTitle,
        actionLabel: AppStrings.semanticsBack,
        onAction: () => context.pop(),
      );
    } else {
      final session = _session!;
      final isHost = session.host.id == currentUserId;
      final myParticipant = _findMyParticipant(currentUserId);
      final myWaitlist = _findMyWaitlist(currentUserId);
      final reliabilityErr = HorasPolicies.checkSessionJoinReliability(
        userMarks: _myReliabilityMarks,
        now: now,
      );
      final isRestricted7Days = reliabilityErr is Err<void>;
      final isFull = session.participantCount >= session.maxSlots;
      final schedule = HorasPolicies.computeSessionReminders(
        sessionStartTime: session.startTime,
        now: now,
      );
      final reminderTimes = <DateTime>[
        if (schedule.reminderHMinus1 != null) schedule.reminderHMinus1!,
        if (schedule.reminder2HoursBefore != null)
          schedule.reminder2HoursBefore!,
      ];

      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          // Status badges
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppChip(label: session.sportType.label, isSelected: true),
              AppChip(label: session.skillLevel.label),
              if (session.isUpdated && session.status == SessionStatus.upcoming)
                AppChip(
                  label: AppStrings.man04StatusUpdatedBadge,
                  customBackgroundColor: colors.confidenceAmberSurface,
                  customForegroundColor: colors.confidenceAmber,
                ),
              if (session.status == SessionStatus.cancelled)
                AppChip(
                  label: AppStrings.man04StatusCancelledBadge,
                  customBackgroundColor: colors.danger.withValues(alpha: 0.12),
                  customForegroundColor: colors.danger,
                ),
              if (session.status == SessionStatus.completed)
                AppChip(
                  label: AppStrings.man04StatusCompletedBadge,
                  customBackgroundColor: colors.chipInactive,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text(session.title, style: typo.h2),
          const SizedBox(height: AppSpacing.md),

          // Host card
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => context
                  .push('${AppPages.sek04.routePath}?userId=${session.host.id}')
                  .ignore(),
              leading: AppAvatar(
                name: session.host.displayName,
                seed: session.host.avatarSeed,
              ),
              title: Text(
                '${session.host.displayName} · ${session.host.marga}',
                style: typo.bodyStrong,
              ),
              subtitle: const Text(AppStrings.man04HostLabel),
              trailing: session.host.partuturan != null
                  ? PartuturanBadge(
                      result: session.host.partuturan!,
                      onTap: () => context
                          .push(
                            '${AppPages.tar05.routePath}?userId=${session.host.id}',
                          )
                          .ignore(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Info waktu, lokasi, peserta, biaya
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    text: PlayFormatters.formatTimeWindow(
                      session.startTime,
                      session.endTime,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    text: session.visibleVenueText,
                  ),
                  if (!session.isJoinedByMe &&
                      !isHost &&
                      session.courtId == null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.man04ManualDetailHiddenHint,
                      style: typo.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _DetailRow(
                    icon: Icons.groups_outlined,
                    text: AppStrings.man01ParticipantsRatio(
                      session.participantCount,
                      session.maxSlots,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailRow(
                    icon: Icons.payments_outlined,
                    text: PlayFormatters.formatRupiah(
                      session.feePerPersonRupiah,
                      freeLabel: AppStrings.man01FreeFeeLabel,
                    ),
                  ),
                  if (session.notes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(AppStrings.man04NotesLabel, style: typo.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(session.notes, style: typo.body),
                  ],
                ],
              ),
            ),
          ),

          if (reminderTimes.isNotEmpty &&
              session.status == SessionStatus.upcoming &&
              (session.isJoinedByMe || isHost)) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.man04RemindersScheduledInfo(
                reminderTimes.map(PlayFormatters.formatClockTime).join(' & '),
              ),
              style: typo.caption.copyWith(color: colors.textMuted),
            ),
          ],

          // 7-day restriction banner (MAN-R4, AC-09)
          if (!isHost &&
              isRestricted7Days &&
              session.status == SessionStatus.upcoming) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.12),
                borderRadius: AppRadius.cardRadius,
              ),
              child: Text(
                AppStrings.man04Restricted7DaysBanner,
                style: typo.caption.copyWith(color: colors.danger),
              ),
            ),
          ],

          if (myParticipant?.status ==
              ParticipantStatus.pendingHostApproval) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.confidenceAmberSurface,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Text(
                AppStrings.man04WaitingHostApproval,
                style: typo.bodyStrong.copyWith(color: colors.confidenceAmber),
              ),
            ),
          ],

          if (myWaitlist != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.confidenceAmberSurface,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Text(
                AppStrings.man04WaitlistPositionBadge(myWaitlist.position),
                style: typo.bodyStrong.copyWith(color: colors.confidenceAmber),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Primary CTA for upcoming sessions
          if (session.status == SessionStatus.upcoming) ...<Widget>[
            if (isHost) ...<Widget>[
              AppButton(
                label: AppStrings.man04EditScheduleBtn,
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                isLoading: _isActionLoading,
                onPressed: _openEditScheduleSheet,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: AppStrings.man04CancelSessionBtn,
                variant: AppButtonVariant.secondary,
                isDestructive: true,
                isExpanded: true,
                isLoading: _isActionLoading,
                onPressed: _handleCancelSession,
              ),
            ] else if (myParticipant != null || myWaitlist != null) ...<Widget>[
              AppButton(
                label: AppStrings.man04LeaveBtn,
                variant: AppButtonVariant.secondary,
                isDestructive: true,
                isExpanded: true,
                isLoading: _isActionLoading,
                onPressed: () => _handleLeave(myParticipant),
              ),
            ] else ...<Widget>[
              AppButton(
                label: isFull
                    ? AppStrings.man04JoinWaitlistBtn
                    : AppStrings.man04JoinBtn,
                isExpanded: true,
                isDisabled: isRestricted7Days,
                isLoading: _isActionLoading,
                onPressed: isRestricted7Days ? null : _handleJoin,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],

          // Sub-routes: MAN-05 Peserta, MAN-06 Patungan, PSN-04 Chat Grup
          AppButton(
            label: AppStrings.man04ParticipantsBtn,
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            leadingIcon: Icons.group_outlined,
            onPressed: () async {
              await context.push(
                '${AppPages.man05.routePath}?sessionId=${session.id}',
              );
              await _load();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: AppStrings.man04PatunganBtn,
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            leadingIcon: Icons.calculate_outlined,
            onPressed: () async {
              await context.push(
                '${AppPages.man06.routePath}?sessionId=${session.id}',
              );
              await _load();
            },
          ),
          if (session.conversationId != null &&
              (session.isJoinedByMe || isHost)) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: AppStrings.man04SessionChatBtn,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              leadingIcon: Icons.chat_bubble_outline_rounded,
              onPressed: () => context
                  .push(
                    '${AppPages.psn04.routePath}?conversationId=${session.conversationId}',
                  )
                  .ignore(),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.man04Title)),
      body: SafeArea(child: body),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: context.colors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: context.typo.body)),
      ],
    );
  }
}
