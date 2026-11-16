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
import 'package:material_ui/material_ui.dart';

/// MAN-05 Peserta & Daftar Tunggu FIFO (`MAN-R3`, `MAN-R4`, `MAN-R5`, `MAN-R6`, `AC-08`).
class Man05ParticipantsPage extends ConsumerStatefulWidget {
  const Man05ParticipantsPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<Man05ParticipantsPage> createState() =>
      _Man05ParticipantsPageState();
}

class _Man05ParticipantsPageState extends ConsumerState<Man05ParticipantsPage> {
  PlaySession? _session;
  List<Participant> _participants = const <Participant>[];
  List<WaitlistEntry> _waitlist = const <WaitlistEntry>[];
  Map<String, int> _reliabilityCountsByUser = const <String, int>{};
  bool _isLoading = true;
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
    final currentUserId = ref.read(authRepositoryProvider).currentUserId;

    final sessionRes = await sessionRepo.getSessionById(widget.sessionId);
    if (!mounted) return;
    if (sessionRes is Err<PlaySession>) {
      setState(() {
        _isLoading = false;
        _error = sessionRes.failure;
      });
      return;
    }

    final session = (sessionRes as Ok<PlaySession>).value;
    final participantsRes = await sessionRepo.getParticipants(widget.sessionId);
    final waitlistRes = await sessionRepo.getWaitlist(widget.sessionId);
    final participants = participantsRes is Ok<List<Participant>>
        ? participantsRes.value
        : const <Participant>[];
    final waitlist = waitlistRes is Ok<List<WaitlistEntry>>
        ? waitlistRes.value
        : const <WaitlistEntry>[];

    // MAN-R4: Catatan keandalan hanya terlihat oleh host, bukan publik.
    final counts = <String, int>{};
    if (currentUserId == session.host.id) {
      final userIds = <String>{
        ...participants.map((p) => p.user.id),
        ...waitlist.map((w) => w.user.id),
      };
      for (final uid in userIds) {
        if (uid == session.host.id) continue;
        final marksRes = await sessionRepo.getReliabilityMarksForHost(uid);
        if (marksRes is Ok<List<ReliabilityMark>>) {
          counts[uid] = marksRes.value.length;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _participants = participants;
      _waitlist = waitlist;
      _reliabilityCountsByUser = counts;
      _isLoading = false;
    });
  }

  Future<void> _respondRequest(String participantId, bool approve) async {
    final res = await ref
        .read(sessionRepositoryProvider)
        .respondToJoinRequest(
          sessionId: widget.sessionId,
          participantId: participantId,
          approve: approve,
        );
    if (!mounted) return;
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

  Future<void> _markAttendance(String participantId, bool attended) async {
    final res = await ref
        .read(sessionRepositoryProvider)
        .markAttendance(
          sessionId: widget.sessionId,
          participantId: participantId,
          attended: attended,
        );
    if (!mounted) return;
    if (res is Err<Participant>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _load();
  }

  Future<void> _removeParticipant(String participantId) async {
    final res = await ref
        .read(sessionRepositoryProvider)
        .removeParticipant(
          sessionId: widget.sessionId,
          participantId: participantId,
        );
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(authRepositoryProvider).currentUserId;
    final colors = context.colors;
    final typo = context.typo;

    Widget body;
    if (_isLoading) {
      body = const StateView.loading(itemCount: 4);
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
      final isHost = currentUserId == session.host.id;
      final pending = _participants
          .where((p) => p.status == ParticipantStatus.pendingHostApproval)
          .toList(growable: false);
      final joined = _participants
          .where((p) => p.status == ParticipantStatus.joined)
          .toList(growable: false);

      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          if (pending.isNotEmpty && isHost) ...<Widget>[
            const SectionHeader(title: AppStrings.man05PendingRequestsSection),
            const SizedBox(height: AppSpacing.sm),
            ...pending.map(
              (p) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _PersonHeaderRow(
                        user: p.user,
                        hostReliabilityCount:
                            _reliabilityCountsByUser[p.user.id],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: AppButton(
                              label: AppStrings.man05ApproveBtn,
                              onPressed: () => _respondRequest(p.id, true),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppButton(
                              label: AppStrings.man05RejectBtn,
                              variant: AppButtonVariant.secondary,
                              isDestructive: true,
                              onPressed: () => _respondRequest(p.id, false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          const SectionHeader(title: AppStrings.man05JoinedSection),
          const SizedBox(height: AppSpacing.sm),
          ...joined.map((p) {
            final isParticipantHost = p.user.id == session.host.id;
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _PersonHeaderRow(
                            user: p.user,
                            hostReliabilityCount: isHost && !isParticipantHost
                                ? _reliabilityCountsByUser[p.user.id]
                                : null,
                          ),
                        ),
                        if (isParticipantHost)
                          const AppChip(
                            label: AppStrings.man05HostBadge,
                            isSelected: true,
                          )
                        else if (p.attended == true)
                          AppChip(
                            label: AppStrings.man05AttendedBadge,
                            customBackgroundColor: colors.primary.withValues(
                              alpha: 0.12,
                            ),
                            customForegroundColor: colors.primary,
                          )
                        else if (p.attended == false)
                          AppChip(
                            label: AppStrings.man05AbsentBadge,
                            customBackgroundColor: colors.danger.withValues(
                              alpha: 0.12,
                            ),
                            customForegroundColor: colors.danger,
                          )
                        else
                          const AppChip(label: AppStrings.man05JoinedBadge),
                      ],
                    ),
                    if (isHost &&
                        !isParticipantHost &&
                        session.status != SessionStatus.cancelled) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          AppChip(
                            label: AppStrings.man05MarkAttended,
                            isSelected: p.attended == true,
                            onTap: () => _markAttendance(p.id, true),
                          ),
                          AppChip(
                            label: AppStrings.man05MarkAbsent,
                            isSelected: p.attended == false,
                            onTap: () => _markAttendance(p.id, false),
                          ),
                          if (session.status == SessionStatus.upcoming)
                            AppChip(
                              label: AppStrings.man05KickBtn,
                              customBackgroundColor: colors.danger.withValues(
                                alpha: 0.12,
                              ),
                              customForegroundColor: colors.danger,
                              onTap: () => _removeParticipant(p.id),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: AppStrings.man05WaitlistSection),
          const SizedBox(height: AppSpacing.sm),
          if (_waitlist.isEmpty)
            Text(
              AppStrings.man05EmptyWaitlist,
              style: typo.body.copyWith(color: colors.textMuted),
            )
          else
            ..._waitlist.map(
              (entry) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      AppChip(
                        label: AppStrings.man04WaitlistPositionBadge(
                          entry.position,
                        ),
                        customBackgroundColor: colors.confidenceAmberSurface,
                        customForegroundColor: colors.confidenceAmber,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _PersonHeaderRow(
                          user: entry.user,
                          hostReliabilityCount: isHost
                              ? _reliabilityCountsByUser[entry.user.id]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.man05Title)),
      body: SafeArea(child: body),
    );
  }
}

class _PersonHeaderRow extends StatelessWidget {
  const _PersonHeaderRow({required this.user, this.hostReliabilityCount});

  final PersonSummary user;
  final int? hostReliabilityCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context
          .push('${AppPages.sek04.routePath}?userId=${user.id}')
          .ignore(),
      child: Row(
        children: <Widget>[
          AppAvatar(name: user.displayName, seed: user.avatarSeed),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${user.displayName} · ${user.marga}',
                  style: context.typo.bodyStrong,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    if (user.partuturan != null)
                      PartuturanBadge(
                        result: user.partuturan!,
                        onTap: () => context
                            .push(
                              '${AppPages.tar05.routePath}?userId=${user.id}',
                            )
                            .ignore(),
                      ),
                    if (hostReliabilityCount != null &&
                        hostReliabilityCount! > 0)
                      Text(
                        AppStrings.man05HostReliabilityCount(
                          hostReliabilityCount!,
                        ),
                        style: context.typo.caption.copyWith(
                          color: context.colors.confidenceAmber,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
