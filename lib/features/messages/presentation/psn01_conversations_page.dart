import 'package:flutter/services.dart' show HapticFeedback;
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

enum _ConversationsFilter { all, unread, groups }

/// PSN-01 Daftar Pesan ala Instagram DM dengan pencarian instan & filter cepat (`PSN-R1`..`PSN-R6`, `PSN-R9`).
///
/// Grup buatan pengguna adalah Fase 2 (`FeatureFlags.userGroups == false`) dan
/// disembunyikan dari layar ini pada MVP.
class Psn01ConversationsPage extends ConsumerStatefulWidget {
  const Psn01ConversationsPage({super.key, this.tabIndex});

  final int? tabIndex;

  @override
  ConsumerState<Psn01ConversationsPage> createState() =>
      _Psn01ConversationsPageState();
}

class _Psn01ConversationsPageState
    extends ConsumerState<Psn01ConversationsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ConversationsFilter _filter = _ConversationsFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsListProvider);
    final controller = ref.read(conversationsListProvider.notifier);
    final flags = ref.watch(featureFlagsProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final currentUid = authRepo.currentUserId;
    final now = authRepo.currentTime;
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ??
        ref.read(navigationBadgeRepositoryProvider).currentUnreadCounts();
    final scrollController = widget.tabIndex != null
        ? ref
              .read(shellNavigationProvider.notifier)
              .scrollControllerForTab(widget.tabIndex!)
        : null;
    final colors = context.colors;
    final typo = context.typo;

    final query = _searchQuery.trim().toLowerCase();
    final filteredConversations = state.conversations
        .where((conv) {
          if (_filter == _ConversationsFilter.unread && conv.unreadCount <= 0) {
            return false;
          }
          if (_filter == _ConversationsFilter.groups &&
              conv.type == ConversationType.direct) {
            return false;
          }
          if (query.isEmpty) return true;
          final lastText = conv.lastMessage?.text.toLowerCase() ?? '';
          return conv.title.toLowerCase().contains(query) ||
              lastText.contains(query);
        })
        .toList(growable: false);

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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.0),
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: <Widget>[
            // Pencarian instan gaya Instagram DM
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.xs,
                AppSpacing.screenMargin,
                AppSpacing.sm,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.chipInactive,
                  borderRadius: AppRadius.pillRadius,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.search_rounded,
                      size: AppSizes.iconMd - 2,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: typo.body,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: AppStrings.psn01SearchHint,
                          hintStyle: typo.body.copyWith(
                            color: colors.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm + 2,
                          ),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSizes.minTouchTarget,
                          minHeight: AppSizes.minTouchTarget,
                        ),
                        tooltip: AppStrings.semanticsClearInput,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: AppSizes.iconSm,
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Baris Filter Cepat + Permintaan Pesan ala Instagram DM
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                0,
                AppSpacing.screenMargin,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          _FilterPill(
                            label: AppStrings.psn01FilterAll,
                            selected: _filter == _ConversationsFilter.all,
                            onTap: () => setState(
                              () => _filter = _ConversationsFilter.all,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _FilterPill(
                            label: AppStrings.psn01FilterUnread,
                            selected: _filter == _ConversationsFilter.unread,
                            onTap: () => setState(
                              () => _filter = _ConversationsFilter.unread,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _FilterPill(
                            label: AppStrings.psn01FilterGroups,
                            selected: _filter == _ConversationsFilter.groups,
                            onTap: () => setState(
                              () => _filter = _ConversationsFilter.groups,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  InkWell(
                    borderRadius: AppRadius.pillRadius,
                    onTap: () async {
                      HapticFeedback.lightImpact().ignore();
                      await context.push(AppPages.psn02.routePath);
                      await controller.loadInitial();
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSizes.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              AppStrings.psn01RequestsBannerTitle,
                              style: typo.captionStrong.copyWith(
                                color: state.pendingRequestsCount > 0
                                    ? colors.accent
                                    : colors.textMuted,
                              ),
                            ),
                            if (state.pendingRequestsCount > 0) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.buttonPrimary,
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

            if (filteredConversations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                  vertical: AppSpacing.xxl,
                ),
                child: Center(
                  child: Text(
                    AppStrings.psn01EmptyFilterMessage,
                    style: typo.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...filteredConversations.map((conv) {
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
                      horizontal: AppSpacing.screenMargin,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: <Widget>[
                        conv.type == ConversationType.direct
                            ? InkWell(
                                borderRadius: AppRadius.pillRadius,
                                onTap: otherParticipant != null
                                    ? () => context.push(
                                        '${AppPages.sek04.routePath}?id=${otherParticipant.id}',
                                      )
                                    : null,
                                child: AppAvatar(
                                  name: avatarName,
                                  seed: avatarSeed,
                                  size: 56,
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.primary.withValues(alpha: 0.12),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  conv.type == ConversationType.sessionGroup
                                      ? Icons.sports_tennis_outlined
                                      : Icons.groups_outlined,
                                  color: colors.accent,
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
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    shortTime,
                                    style: typo.micro.copyWith(
                                      color: isUnread
                                          ? colors.accent
                                          : colors.textMuted,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      preview.isNotEmpty
                                          ? preview
                                          : AppStrings.psn01PhotoPreview,
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
                                  if (conv.isReadOnly)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: AppSpacing.xs,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.chipInactive,
                                          borderRadius: AppRadius.pillRadius,
                                        ),
                                        child: Text(
                                          AppStrings.psn01ReadOnlyBadge,
                                          style: typo.micro,
                                        ),
                                      ),
                                    ),
                                  if (isUnread) ...<Widget>[
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.buttonPrimary,
                                        borderRadius: AppRadius.pillRadius,
                                      ),
                                      child: Text(
                                        conv.unreadCount > 99
                                            ? '99+'
                                            : '${conv.unreadCount}',
                                        style: typo.micro.copyWith(
                                          color: colors.onPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
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
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
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
            AppTextField(
              controller: titleController,
              hintText: 'Contoh: Arisan Marga Simanjuntak',
            ),
          ],
        ),
        actions: <Widget>[
          AppButton(
            label: AppStrings.actionCancel,
            variant: AppButtonVariant.text,
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: AppStrings.psn01CreateGroupSubmit,
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (created != true || !context.mounted) return;
    final title = titleController.text.trim();
    titleController.dispose();
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.pillRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.text : colors.chipInactive,
            borderRadius: AppRadius.pillRadius,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: typo.micro.copyWith(
              color: selected ? colors.surface : colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
