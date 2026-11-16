import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/tarombo/presentation/tarombo_controller.dart';
import 'package:material_ui/material_ui.dart';

/// TAR-07 Konfirmasi Hubungan (`TAR-R7`): kirim klaim "Kami kerabat", terima/tolak
/// klaim masuk tanpa pemberitahuan penolakan, dan pantau klaim menunggu.
class Tar07ConfirmationsPage extends ConsumerStatefulWidget {
  const Tar07ConfirmationsPage({
    super.key,
    this.initialTargetUserId,
    this.initialClaimedTerm,
  });

  final String? initialTargetUserId;
  final String? initialClaimedTerm;

  @override
  ConsumerState<Tar07ConfirmationsPage> createState() =>
      _Tar07ConfirmationsPageState();
}

class _Tar07ConfirmationsPageState
    extends ConsumerState<Tar07ConfirmationsPage> {
  final TextEditingController _noteCtrl = TextEditingController();
  List<PersonSummary> _candidates = const <PersonSummary>[];
  String? _selectedTargetId;
  String _selectedTerm = AppStrings.tar07CommonTerms.first;
  bool _sending = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if ((widget.initialClaimedTerm ?? '').trim().isNotEmpty) {
      _selectedTerm = widget.initialClaimedTerm!.trim();
    }
    Future<void>.microtask(_loadCandidates);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    final myId = ref.read(authRepositoryProvider).currentUserId;
    final res = await ref
        .read(searchRepositoryProvider)
        .searchPeople(query: '');
    if (!mounted) return;
    if (res is Ok<List<PersonSummary>>) {
      final filtered = res.value
          .where((p) => p.id != myId)
          .toList(growable: false);
      setState(() {
        _candidates = filtered;
        if ((widget.initialTargetUserId ?? '').isNotEmpty &&
            filtered.any((p) => p.id == widget.initialTargetUserId)) {
          _selectedTargetId = widget.initialTargetUserId;
        } else if (filtered.isNotEmpty) {
          _selectedTargetId = filtered.first.id;
        }
      });
    }
  }

  Future<void> _sendClaim() async {
    if (_selectedTargetId == null) return;
    setState(() {
      _sending = true;
      _errorMsg = null;
    });

    final res = await ref
        .read(taromboControllerProvider.notifier)
        .sendClaim(
          targetUserId: _selectedTargetId!,
          claimedTerm: _selectedTerm,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _sending = false);

    if (res is Err<PartuturanClaim>) {
      setState(() => _errorMsg = res.failure.message);
      return;
    }
    _noteCtrl.clear();
    AppToast.show(
      context,
      message: AppStrings.tar07ClaimSentToast,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _respond(PartuturanClaim claim, bool accept) async {
    final res = await ref
        .read(taromboControllerProvider.notifier)
        .respondClaim(claimId: claim.id, accept: accept);
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
      message: accept
          ? AppStrings.tar07ClaimAcceptedToast
          : AppStrings.tar07ClaimRejectedToast,
      variant: AppToastVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taromboControllerProvider);
    final colors = context.colors;
    final typo = context.typo;
    final initialTabIndex = (widget.initialTargetUserId ?? '').isNotEmpty
        ? 2
        : 0;

    final termOptions = <String>{
      ...AppStrings.tar07CommonTerms,
      _selectedTerm,
    }.toList(growable: false);

    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.tar07Title),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: AppStrings.tar07TabIncoming),
              Tab(text: AppStrings.tar07TabWaiting),
              Tab(text: AppStrings.tar07TabSendNew),
            ],
          ),
        ),
        body: state.isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : state.error != null
            ? StateView.fromError(
                state.error!,
                onRetry: ref.read(taromboControllerProvider.notifier).loadAll,
              )
            : TabBarView(
                children: <Widget>[
                  // Tab 1: Klaim Masuk
                  state.incomingClaims.isEmpty
                      ? StateView.empty(
                          message: AppStrings.tar07EmptyIncoming,
                          actionLabel: AppStrings.actionRetry,
                          onAction: ref
                              .read(taromboControllerProvider.notifier)
                              .loadAll,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(
                            AppSpacing.screenMargin,
                          ),
                          itemCount: state.incomingClaims.length,
                          itemBuilder: (context, index) {
                            final c = state.incomingClaims[index];
                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${c.sender.displayName} (${c.sender.marga})',
                                      style: typo.h3,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      c.claimedTermForReceiver,
                                      style: typo.bodyStrong.copyWith(
                                        color: colors.primary,
                                      ),
                                    ),
                                    if ((c.note ?? '').isNotEmpty) ...<Widget>[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(c.note!, style: typo.caption),
                                    ],
                                    const SizedBox(height: AppSpacing.md),
                                    Row(
                                      children: <Widget>[
                                        FilledButton(
                                          onPressed: () => _respond(c, true),
                                          child: const Text(
                                            AppStrings.sek04AcceptBtn,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        OutlinedButton(
                                          onPressed: () => _respond(c, false),
                                          child: const Text(
                                            AppStrings.sek04RejectBtn,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                  // Tab 2: Klaim Terkirim (Menunggu)
                  state.outgoingClaims.isEmpty
                      ? StateView.empty(
                          message: AppStrings.tar07EmptyWaiting,
                          actionLabel: AppStrings.actionRetry,
                          onAction: ref
                              .read(taromboControllerProvider.notifier)
                              .loadAll,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(
                            AppSpacing.screenMargin,
                          ),
                          itemCount: state.outgoingClaims.length,
                          itemBuilder: (context, index) {
                            final c = state.outgoingClaims[index];
                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: ListTile(
                                leading: AppAvatar(
                                  name: c.receiver.displayName,
                                  seed: c.receiver.avatarSeed,
                                ),
                                title: Text(
                                  '${c.receiver.displayName} · ${c.claimedTermForReceiver}',
                                  style: typo.bodyStrong,
                                ),
                                subtitle: Text(
                                  c.note ?? c.receiver.marga,
                                  style: typo.caption,
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.chipInactive,
                                    borderRadius: AppRadius.pillRadius,
                                  ),
                                  child: Text(
                                    AppStrings.tar07WaitingBadge,
                                    style: typo.micro,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  // Tab 3: Kirim Klaim Baru
                  ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    children: <Widget>[
                      Text(
                        AppStrings.tar07SelectTargetLabel,
                        style: typo.bodyStrong,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTargetId,
                        decoration: const InputDecoration(),
                        items: <DropdownMenuItem<String>>[
                          for (final p in _candidates)
                            DropdownMenuItem<String>(
                              value: p.id,
                              child: Text('${p.displayName} (${p.marga})'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _selectedTargetId = v),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        AppStrings.tar07SelectTermLabel,
                        style: typo.bodyStrong,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTerm,
                        decoration: const InputDecoration(),
                        items: <DropdownMenuItem<String>>[
                          for (final t in termOptions)
                            DropdownMenuItem<String>(value: t, child: Text(t)),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedTerm = v);
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _noteCtrl,
                        label: AppStrings.tar07NoteLabel,
                        maxLines: 3,
                      ),
                      if (_errorMsg != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _errorMsg!,
                          style: typo.caption.copyWith(color: colors.danger),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: AppStrings.tar07SendClaimBtn,
                        isLoading: _sending,
                        onPressed: _sendClaim,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
