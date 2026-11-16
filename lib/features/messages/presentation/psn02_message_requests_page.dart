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
import 'package:horas/features/messages/presentation/messages_controller.dart';
import 'package:material_ui/material_ui.dart';

/// PSN-02 Permintaan Pesan (`PSN-R2`, `PSN-R8`, `AC-16`).
class Psn02MessageRequestsPage extends ConsumerStatefulWidget {
  const Psn02MessageRequestsPage({super.key});

  @override
  ConsumerState<Psn02MessageRequestsPage> createState() =>
      _Psn02MessageRequestsPageState();
}

class _Psn02MessageRequestsPageState
    extends ConsumerState<Psn02MessageRequestsPage> {
  List<MessageRequest> _requests = const <MessageRequest>[];
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await ref.read(chatRepositoryProvider).getMessageRequests();
    if (!mounted) return;
    if (res is Err<List<MessageRequest>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _requests = (res as Ok<List<MessageRequest>>).value;
      _isLoading = false;
    });
  }

  Future<void> _respond(
    MessageRequest req,
    MessageRequestStatus decision,
  ) async {
    if (decision == MessageRequestStatus.blocked) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: AppStrings.sek04BlockConfirmTitle,
        message: AppStrings.sek04BlockConfirmBody,
        confirmLabel: AppStrings.psn02BlockBtn,
        isDestructive: true,
      );
      if (confirmed != true || !mounted) return;
    }

    final res = await ref
        .read(chatRepositoryProvider)
        .respondMessageRequest(requestId: req.id, decision: decision);
    if (!mounted) return;
    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    await ref.read(conversationsListProvider.notifier).loadInitial();
    if (!mounted) return;
    if (decision == MessageRequestStatus.accepted) {
      context.pushReplacement(
        '${AppPages.psn03.routePath}?conversationId=${req.conversationId}',
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_requests.isEmpty) {
      body = StateView.empty(
        message: AppStrings.psn02EmptyMessage,
        actionLabel: AppStrings.actionRetry,
        onAction: _load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(
              AppStrings.psn02OneMessageLimitHint,
              style: typo.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._requests.map((req) {
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          AppAvatar(
                            name: req.sender.displayName,
                            seed: req.sender.avatarSeed,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${req.sender.displayName} · ${req.sender.marga}',
                                  style: typo.bodyStrong,
                                ),
                                Text(
                                  req.sharedContextDescription,
                                  style: typo.caption.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (req.sender.partuturan != null)
                            PartuturanBadge(result: req.sender.partuturan!),
                        ],
                      ),
                      if (req.firstMessage.hasScamWarning) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.danger.withValues(alpha: 0.12),
                            borderRadius: AppRadius.cardRadius,
                            border: Border.all(color: colors.danger),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.warning_amber_rounded,
                                color: colors.danger,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  AppStrings.psn03ScamWarningBanner,
                                  style: typo.caption.copyWith(
                                    color: colors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.chipInactive,
                          borderRadius: AppRadius.cardRadius,
                        ),
                        child: Text(req.firstMessage.text, style: typo.body),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: AppButton(
                              label: AppStrings.psn02AcceptBtn,
                              onPressed: () =>
                                  _respond(req, MessageRequestStatus.accepted),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppButton(
                              label: AppStrings.psn02DeleteBtn,
                              variant: AppButtonVariant.secondary,
                              onPressed: () =>
                                  _respond(req, MessageRequestStatus.deleted),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppButton(
                              label: AppStrings.psn02BlockBtn,
                              variant: AppButtonVariant.secondary,
                              isDestructive: true,
                              onPressed: () =>
                                  _respond(req, MessageRequestStatus.blocked),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.psn02Title)),
      body: SafeArea(child: body),
    );
  }
}
