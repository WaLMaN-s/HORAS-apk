import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/messages/presentation/messages_controller.dart';
import 'package:material_ui/material_ui.dart';

/// PSN-01 Daftar Pesan (`PSN-R1`..`PSN-R6`, `PSN-R9`).
///
/// Grup buatan pengguna adalah Fase 2 (`FeatureFlags.userGroups == false`) dan
/// disembunyikan dari layar ini pada MVP.
class Psn01ConversationsPage extends ConsumerWidget {
  const Psn01ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsListProvider);
    final controller = ref.read(conversationsListProvider.notifier);
    final flags = ref.watch(featureFlagsProvider);
    final now = ref.read(authRepositoryProvider).currentTime;
    final colors = context.colors;
    final typo = context.typo;

    Widget body;
    if (state.isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (state.error != null) {
      body = StateView.fromError(state.error!, onRetry: controller.loadInitial);
    } else if (state.conversations.isEmpty && state.requests.isEmpty) {
      body = StateView.empty(
        message: AppStrings.psn01EmptyMessage,
        actionLabel: AppStrings.psn01EmptyAction,
        onAction: () => context.go(AppPages.sek01.routePath),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.loadInitial,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            // Pintu masuk Permintaan Pesan (PSN-02)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.confidenceAmberSurface,
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    color: colors.confidenceAmber,
                  ),
                ),
                title: Text(
                  AppStrings.psn01RequestsBannerTitle,
                  style: typo.bodyStrong,
                ),
                subtitle: Text(
                  state.pendingRequestsCount > 0
                      ? AppStrings.psn01RequestsCountLabel(
                          state.pendingRequestsCount,
                        )
                      : AppStrings.psn02EmptyMessage,
                  style: typo.caption.copyWith(color: colors.textMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (state.pendingRequestsCount > 0)
                      Badge(label: Text('${state.pendingRequestsCount}')),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () async {
                  await context.push(AppPages.psn02.routePath);
                  await controller.loadInitial();
                },
              ),
            ),

            // Fase 2 guard: grup buatan pengguna disembunyikan saat flag off.
            if (flags.userGroups) const SizedBox.shrink(),

            ...state.conversations.map((conv) {
              final isMuted =
                  conv.mutedUntil != null && conv.mutedUntil!.isAfter(now);
              final lastMsg = conv.lastMessage;
              final preview = lastMsg == null
                  ? ''
                  : lastMsg.isDeletedForEveryone
                  ? AppStrings.psn01DeletedPreview
                  : lastMsg.text.isNotEmpty
                  ? lastMsg.text
                  : AppStrings.psn01PhotoPreview;

              final targetRoute = conv.type == ConversationType.direct
                  ? '${AppPages.psn03.routePath}?conversationId=${conv.id}'
                  : '${AppPages.psn04.routePath}?conversationId=${conv.id}';

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: conv.type == ConversationType.direct
                      ? AppAvatar(name: conv.title, seed: conv.id)
                      : CircleAvatar(
                          backgroundColor: colors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(
                            conv.type == ConversationType.sessionGroup
                                ? Icons.sports_tennis_outlined
                                : Icons.groups_outlined,
                            color: colors.primary,
                          ),
                        ),
                  title: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          conv.title,
                          style: typo.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMuted)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: Tooltip(
                            message: AppStrings.psn01MutedTooltip,
                            child: Icon(
                              Icons.volume_off_rounded,
                              size: 16,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      if (conv.isReadOnly)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: Text(
                            AppStrings.psn01ReadOnlyBadge,
                            style: typo.micro.copyWith(color: colors.textMuted),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.caption.copyWith(color: colors.textMuted),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        ChatFormatters.formatShortTime(conv.updatedAt, now),
                        style: typo.micro.copyWith(color: colors.textMuted),
                      ),
                      if (conv.unreadCount > 0) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Badge(label: Text('${conv.unreadCount}')),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await context.push(targetRoute);
                    await controller.loadInitial();
                  },
                ),
              );
            }),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.psn01Title)),
      body: SafeArea(child: body),
    );
  }
}
