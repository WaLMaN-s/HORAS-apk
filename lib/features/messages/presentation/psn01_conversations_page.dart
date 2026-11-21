import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/messages/presentation/messages_controller.dart';
import 'package:material_ui/material_ui.dart';

/// PSN-01 Daftar Pesan ala Instagram DM (`PSN-R1`..`PSN-R6`, `PSN-R9`).
///
/// Grup buatan pengguna adalah Fase 2 (`FeatureFlags.userGroups == false`) dan
/// disembunyikan dari layar ini pada MVP.
class Psn01ConversationsPage extends ConsumerWidget {
  const Psn01ConversationsPage({super.key, this.tabIndex});

  final int? tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsListProvider);
    final controller = ref.read(conversationsListProvider.notifier);
    final flags = ref.watch(featureFlagsProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final currentUid = authRepo.currentUserId;
    final now = authRepo.currentTime;
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ??
        ref.read(navigationBadgeRepositoryProvider).currentUnreadCounts();
    final scrollController = tabIndex != null
        ? ref
              .read(shellNavigationProvider.notifier)
              .scrollControllerForTab(tabIndex!)
        : null;
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
          controller: scrollController,
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.0),
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: <Widget>[
            // Baris header Pesan | Permintaan (gaya DM Instagram)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Text(AppStrings.psn01Title, style: typo.bodyStrong),
                  const Spacer(),
                  InkWell(
                    borderRadius: AppRadius.pillRadius,
                    onTap: () async {
                      await context.push(AppPages.psn02.routePath);
                      await controller.loadInitial();
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSizes.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              AppStrings.psn01RequestsBannerTitle,
                              style: typo.captionStrong.copyWith(
                                color: state.pendingRequestsCount > 0
                                    ? colors.primary
                                    : colors.textMuted,
                              ),
                            ),
                            if (state.pendingRequestsCount > 0) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: AppRadius.pillRadius,
                                ),
                                child: Text(
                                  '${state.pendingRequestsCount}',
                                  style: typo.micro.copyWith(
                                    color: colors.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Fase 2 guard: grup buatan pengguna disembunyikan saat flag off.
            if (flags.userGroups) const SizedBox.shrink(),

            ...state.conversations.map((conv) {
              final isMuted =
                  conv.mutedUntil != null && conv.mutedUntil!.isAfter(now);
              final isUnread = conv.unreadCount > 0;
              final lastMsg = conv.lastMessage;
              final preview = lastMsg == null
                  ? ''
                  : lastMsg.isDeletedForEveryone
                  ? AppStrings.psn01DeletedPreview
                  : lastMsg.text.isNotEmpty
                  ? lastMsg.text
                  : AppStrings.psn01PhotoPreview;
              final shortTime = ChatFormatters.formatShortTime(
                conv.updatedAt,
                now,
              );

              final targetRoute = conv.type == ConversationType.direct
                  ? '${AppPages.psn03.routePath}?conversationId=${conv.id}'
                  : '${AppPages.psn04.routePath}?conversationId=${conv.id}';
              final otherParticipant = conv.type == ConversationType.direct
                  ? (conv.participants
                            .where((p) => p.id != currentUid)
                            .firstOrNull ??
                        conv.participants.firstOrNull)
                  : null;
              final avatarName =
                  (otherParticipant != null &&
                      otherParticipant.displayName.isNotEmpty)
                  ? otherParticipant.displayName
                  : conv.title;
              final avatarSeed =
                  (otherParticipant != null &&
                      otherParticipant.avatarSeed.isNotEmpty)
                  ? otherParticipant.avatarSeed
                  : conv.id;

              return InkWell(
                onTap: () async {
                  await context.push(targetRoute);
                  await controller.loadInitial();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      conv.type == ConversationType.direct
                          ? InkWell(
                              borderRadius: AppRadius.pillRadius,
                              onTap: otherParticipant != null
                                  ? () => context.push(
                                      '${AppPages.sek04.routePath}?userId=${otherParticipant.id}',
                                    )
                                  : null,
                              child: AppAvatar(
                                name: avatarName,
                                seed: avatarSeed,
                                size: AppSizes.avatarLg,
                              ),
                            )
                          : Container(
                              width: AppSizes.avatarLg,
                              height: AppSizes.avatarLg,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.chipInactive,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                conv.type == ConversationType.sessionGroup
                                    ? Icons.sports_tennis_outlined
                                    : Icons.groups_outlined,
                                color: colors.primary,
                              ),
                            ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    conv.title,
                                    style: isUnread
                                        ? typo.bodyStrong
                                        : typo.bodyStrong.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMuted)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.xs,
                                    ),
                                    child: Tooltip(
                                      message: AppStrings.psn01MutedTooltip,
                                      child: Icon(
                                        Icons.volume_off_rounded,
                                        size: 14,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                  ),
                                if (conv.isReadOnly)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.xs,
                                    ),
                                    child: Text(
                                      AppStrings.psn01ReadOnlyBadge,
                                      style: typo.micro.copyWith(
                                        color: colors.textMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    preview.isNotEmpty
                                        ? '$preview · $shortTime'
                                        : shortTime,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typo.caption.copyWith(
                                      color: isUnread
                                          ? colors.text
                                          : colors.textMuted,
                                      fontWeight: isUnread
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isUnread) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                          ),
                        ),
                      ],
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
      appBar: AppBar(
        title: const Text(AppStrings.psn01Title),
        actions: <Widget>[
          if (flags.userGroups)
            IconButton(
              tooltip: AppStrings.psn01CreateGroupBtn,
              onPressed: () => _showCreateGroupDialog(context, ref),
              icon: const Icon(Icons.group_add_outlined),
            ),
          IconButton(
            tooltip: AppStrings.semanticsNotifications,
            onPressed: () => context.push(AppPages.sis01.routePath),
            icon: Badge(
              isLabelVisible: unreadCounts.unreadNotifications > 0,
              label: Text('${unreadCounts.unreadNotifications}'),
              child: Semantics(
                label: AppStrings.semanticsNotifications,
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Future<void> _showCreateGroupDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final titleController = TextEditingController();
    final colors = context.colors;
    final typo = context.typo;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.psn01CreateGroupTitle, style: typo.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(AppStrings.psn01GroupNameLabel, style: typo.captionStrong),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Contoh: Arisan Marga Simanjuntak',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.actionCancel, style: typo.body),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppStrings.psn01CreateGroupSubmit,
              style: typo.bodyStrong,
            ),
          ),
        ],
      ),
    );

    if (created != true || !context.mounted) return;
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final chatRepo = ref.read(chatRepositoryProvider);
    final res = await chatRepo.createCustomGroupChat(
      title: title,
      memberUserIds: const <String>['u-02', 'u-03'],
    );

    if (!context.mounted) return;
    if (res is Ok<Conversation>) {
      await ref.read(conversationsListProvider.notifier).loadInitial();
      if (!context.mounted) return;
      await context.push('${AppPages.psn04.routePath}?id=${res.value.id}');
    } else if (res is Err<Conversation>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
    }
  }
}
