import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/home/presentation/home_feed_controller.dart';
import 'package:horas/features/home/presentation/post_card.dart';
import 'package:material_ui/material_ui.dart';

/// BER-01 Feed Beranda (PRD 4, 5.1, 6.2, AC-15).
///
/// Story dan video adalah Fase 2 (`FeatureFlags.stories == false`) sehingga
/// baris story tidak ditampilkan dan tombol `+` langsung membuka Buat Postingan (`BER-04`).
class Ber01FeedPage extends ConsumerWidget {
  const Ber01FeedPage({super.key, this.tabIndex = 0});

  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(homeFeedControllerProvider);
    final controller = ref.read(homeFeedControllerProvider.notifier);
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ??
        ref.read(navigationBadgeRepositoryProvider).currentUnreadCounts();
    final scrollController = ref
        .read(shellNavigationProvider.notifier)
        .scrollControllerForTab(tabIndex);
    final now = ref.watch(authRepositoryProvider).currentTime;

    return Scaffold(
      appBar: AppBar(
        title: const HorasLogo(showRoof: false, wordmarkFontSize: 26),
        actions: <Widget>[
          _FeedTopBarIcon(
            icon: Icons.add_box_outlined,
            semanticsLabel: AppStrings.semanticsCreatePost,
            onTap: () => context.push(AppPages.ber04.routePath),
          ),
          _FeedTopBarIcon(
            icon: Icons.search_rounded,
            semanticsLabel: AppStrings.semanticsSearch,
            onTap: () => context.push(AppPages.ber09.routePath),
          ),
          _FeedTopBarIcon(
            icon: Icons.notifications_none_rounded,
            semanticsLabel: AppStrings.semanticsNotifications,
            badgeCount: unreadCounts.unreadNotifications,
            onTap: () => context.push(AppPages.sis01.routePath),
          ),
          _FeedTopBarIcon(
            icon: Icons.chat_bubble_outline_rounded,
            semanticsLabel: AppStrings.semanticsMessages,
            badgeCount: unreadCounts.unreadMessages,
            onTap: () => context.push(AppPages.psn01.routePath),
          ),
        ],
      ),
      body: _buildBody(
        context,
        ref,
        feedState: feedState,
        controller: controller,
        scrollController: scrollController,
        now: now,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required HomeFeedState feedState,
    required HomeFeedController controller,
    required ScrollController scrollController,
    required DateTime now,
  }) {
    if (feedState.isInitialLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    }

    // AC-15: Offline dengan data cache halaman pertama tampil bersama penanda dan tombol Coba lagi
    if (feedState.isOfflineWithCache && feedState.posts.isNotEmpty) {
      return StateView.offline(
        onRetry: controller.loadInitial,
        cachedChild: _buildPostList(
          context,
          ref,
          feedState: feedState,
          controller: controller,
          scrollController: scrollController,
          now: now,
        ),
      );
    }

    if (feedState.error != null && feedState.posts.isEmpty) {
      return StateView.fromError(
        feedState.error!,
        onRetry: controller.loadInitial,
        onBack: () => context.go(AppPages.sekitarPath),
      );
    }

    if (feedState.posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            const SizedBox(height: AppSpacing.xxl),
            StateView.empty(
              message: AppStrings.ber01EmptyMessage,
              actionLabel: AppStrings.ber01EmptyAction,
              onAction: () => context.go(AppPages.sekitarPath),
            ),
          ],
        ),
      );
    }

    return _buildPostList(
      context,
      ref,
      feedState: feedState,
      controller: controller,
      scrollController: scrollController,
      now: now,
    );
  }

  Widget _buildPostList(
    BuildContext context,
    WidgetRef ref, {
    required HomeFeedState feedState,
    required HomeFeedController controller,
    required ScrollController scrollController,
    required DateTime now,
  }) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
          vertical: AppSpacing.md,
        ),
        itemCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index >= feedState.posts.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: AppButton(
                label: AppStrings.ber01LoadMoreBtn,
                variant: AppButtonVariant.secondary,
                isLoading: feedState.isLoadingMore,
                isExpanded: true,
                onPressed: controller.loadMore,
              ),
            );
          }

          final post = feedState.posts[index];
          final isOwn = post.author.id == feedState.currentUserId;

          return PostCard(
            post: post,
            now: now,
            isOwnPost: isOwn,
            onTapCard: () =>
                context.push('${AppPages.ber06.routePath}?id=${post.id}'),
            onLikeTap: () => controller.toggleLike(post.id),
            onLikesCountTap: () =>
                context.push('${AppPages.ber08.routePath}?id=${post.id}'),
            onCommentTap: () =>
                context.push('${AppPages.ber07.routePath}?id=${post.id}'),
            onSaveTap: () => controller.toggleSave(post.id),
            onReportTap: () => context.push('/report'),
            onMuteTap: () => _confirmMute(context, controller, post),
            onBlockTap: () => _confirmBlock(context, controller, post),
            onEditTextTap: () => _openEditSheet(context, controller, post),
            onDeleteTap: () => _confirmDelete(context, controller, post),
          );
        },
      ),
    );
  }

  Future<void> _confirmMute(
    BuildContext context,
    HomeFeedController controller,
    Post post,
  ) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.ber01MuteConfirmTitle,
      message: AppStrings.ber01MuteConfirmMessage,
      confirmLabel: AppStrings.ber01MenuMute,
    );
    if (!ok || !context.mounted) return;
    final res = await controller.blockOrMuteUser(post.author.id);
    if (context.mounted) {
      if (res.isOk) {
        AppToast.show(
          context,
          message: AppStrings.ber01AccountMutedToast,
          variant: AppToastVariant.info,
        );
      }
    }
  }

  Future<void> _confirmBlock(
    BuildContext context,
    HomeFeedController controller,
    Post post,
  ) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.ber01BlockConfirmTitle,
      message: AppStrings.ber01BlockConfirmMessage,
      confirmLabel: AppStrings.ber01MenuBlock,
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    final res = await controller.blockOrMuteUser(post.author.id);
    if (context.mounted && res.isOk) {
      AppToast.show(
        context,
        message: AppStrings.ber01AccountBlockedToast,
        variant: AppToastVariant.info,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HomeFeedController controller,
    Post post,
  ) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.ber01DeleteConfirmTitle,
      message: AppStrings.ber01DeleteConfirmMessage,
      confirmLabel: AppStrings.actionDelete,
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    final res = await controller.deletePost(post.id);
    if (context.mounted && res.isOk) {
      AppToast.show(
        context,
        message: AppStrings.ber01PostDeletedToast,
        variant: AppToastVariant.success,
      );
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    HomeFeedController controller,
    Post post,
  ) async {
    final textController = TextEditingController(text: post.text);
    String? errMsg;

    await AppBottomSheet.show<void>(
      context,
      title: AppStrings.ber06EditTextTitle,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: textController,
                maxLines: 5,
                maxLength: 2000,
                errorText: errMsg,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: AppStrings.actionSave,
                isExpanded: true,
                onPressed: () async {
                  final res = await controller.editPostText(
                    postId: post.id,
                    newText: textController.text,
                  );
                  if (!sheetContext.mounted) return;
                  res.fold(
                    onOk: (_) => Navigator.of(sheetContext).pop(),
                    onErr: (err) {
                      setSheetState(() => errMsg = err.message);
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
    textController.dispose();
  }
}

class _FeedTopBarIcon extends StatelessWidget {
  const _FeedTopBarIcon({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final effectiveLabel = badgeCount > 0
        ? '$semanticsLabel, ${AppStrings.semanticsUnreadBadge(badgeCount)}'
        : semanticsLabel;

    return Semantics(
      button: true,
      label: effectiveLabel,
      child: IconButton(
        constraints: const BoxConstraints(
          minWidth: AppSizes.minTouchTarget,
          minHeight: AppSizes.minTouchTarget,
        ),
        tooltip: semanticsLabel,
        onPressed: onTap,
        icon: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Icon(icon, size: AppSizes.iconMd, color: colors.text),
            if (badgeCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.buttonPrimary,
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: typo.micro.copyWith(
                      color: colors.onPrimary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
