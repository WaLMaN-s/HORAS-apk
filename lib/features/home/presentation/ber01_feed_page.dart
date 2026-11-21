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
import 'package:horas/features/home/presentation/ber07_comments_page.dart';
import 'package:horas/features/home/presentation/home_feed_controller.dart';
import 'package:material_ui/material_ui.dart';

/// BER-01 Feed Beranda bergaya Threads + Instagram (PRD 4, 5.1, 6.2, AC-15).
///
/// Story dan video adalah Fase 2 (`FeatureFlags.stories == false`) sehingga
/// baris story tidak ditampilkan dan tombol `+` langsung membuka Buat Postingan (`BER-04`).
class Ber01FeedPage extends ConsumerWidget {
  const Ber01FeedPage({super.key, this.tabIndex = 0});

  final int tabIndex;

  void _showCreateChoiceModal(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    AppBottomSheet.show<void>(
      context,
      title: AppStrings.ber01ChooseCreateType,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_note_rounded, color: colors.accent),
            ),
            title: Text(
              AppStrings.ber01CreatePostOption,
              style: typo.bodyStrong,
            ),
            subtitle: Text(AppStrings.ber01ComposerPrompt, style: typo.caption),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
            ),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppPages.ber04.routePath);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.ratingGold.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                color: colors.ratingGold,
              ),
            ),
            title: Text(
              AppStrings.ber01CreateStoryOption,
              style: typo.bodyStrong,
            ),
            subtitle: Text(AppStrings.ber03DurationNotice, style: typo.caption),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
            ),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppPages.ber03.routePath);
            },
          ),
        ],
      ),
    );
  }

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

    final authRepo = ref.watch(authRepositoryProvider);
    final inner = _buildBody(
      context,
      ref,
      feedState: feedState,
      controller: controller,
      scrollController: scrollController,
      now: now,
    );

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: const HorasLogo(showRoof: false, wordmarkFontSize: 26),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSizes.strokeThin),
          child: Divider(
            height: AppSizes.strokeThin,
            thickness: AppSizes.strokeThin,
            color: context.colors.border.withValues(alpha: 0.55),
          ),
        ),
        actions: <Widget>[
          _FeedTopBarIcon(
            icon: Icons.add_box_outlined,
            semanticsLabel: AppStrings.semanticsCreatePost,
            onTap: () {
              HapticFeedback.lightImpact();
              final flags = ref.read(featureFlagsProvider);
              if (flags.stories) {
                _showCreateChoiceModal(context);
              } else {
                context.push(AppPages.ber04.routePath);
              }
            },
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
        ],
      ),
      body: authRepo.hadDeletionRecentlyCancelled
          ? Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: context.colors.primary.withValues(alpha: 0.12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${AppStrings.akn14CancelledScreenTitle}: ${AppStrings.akn14CancelledScreenBody}',
                          style: context.typo.caption,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          authRepo.clearDeletionCancelledNotice();
                          ref.invalidate(authRepositoryProvider);
                        },
                        child: const Text(AppStrings.actionClose),
                      ),
                    ],
                  ),
                ),
                Expanded(child: inner),
              ],
            )
          : inner,
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
    final colors = context.colors;
    final totalItems = 1 + feedState.posts.length + (feedState.hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        scrollCacheExtent: const ScrollCacheExtent.viewport(1.0),
        itemCount: totalItems,
        separatorBuilder: (context, index) => Divider(
          height: AppSizes.strokeThin,
          thickness: AppSizes.strokeThin,
          color: colors.border.withValues(alpha: 0.45),
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            final flags = ref.watch(featureFlagsProvider);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (flags.stories) const _StoriesTray(),
                _ThreadsQuickComposer(
                  profile: feedState.myProfile,
                  onAvatarTap: () => context.go(AppPages.akunPath),
                  onComposeTap: () => context.push(AppPages.ber04.routePath),
                ),
              ],
            );
          }

          final postIndex = index - 1;
          if (postIndex >= feedState.posts.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
                vertical: AppSpacing.md,
              ),
              child: AppButton(
                label: AppStrings.ber01LoadMoreBtn,
                variant: AppButtonVariant.tonal,
                isLoading: feedState.isLoadingMore,
                isExpanded: true,
                onPressed: controller.loadMore,
              ),
            );
          }

          final post = feedState.posts[postIndex];
          final isOwn = post.author.id == feedState.currentUserId;

          return RepaintBoundary(
            key: ValueKey<String>('post-${post.id}'),
            child: PostCard(
              post: post,
              now: now,
              isOwnPost: isOwn,
              onAuthorTap: () {
                if (isOwn) {
                  context.go(AppPages.akunPath);
                } else {
                  context.push(
                    '${AppPages.sek04.routePath}?id=${post.author.id}',
                  );
                }
              },
              onTapCard: () =>
                  context.push('${AppPages.ber06.routePath}?id=${post.id}'),
              onLikeTap: () => controller.toggleLike(post.id),
              onLikesCountTap: () =>
                  context.push('${AppPages.ber08.routePath}?id=${post.id}'),
              onCommentTap: () =>
                  Ber07CommentsPage.showSheet(context, postId: post.id),
              onSaveTap: () => controller.toggleSave(post.id),
              onReportTap: () => context.push('/report'),
              onMuteTap: () => _confirmMute(context, controller, post),
              onBlockTap: () => _confirmBlock(context, controller, post),
              onEditTextTap: () => _openEditSheet(context, controller, post),
              onDeleteTap: () => _confirmDelete(context, controller, post),
            ),
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
            Icon(icon, size: AppSizes.iconMd + 1, color: colors.text),
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

class _ThreadsQuickComposer extends StatelessWidget {
  const _ThreadsQuickComposer({
    required this.onAvatarTap,
    required this.onComposeTap,
    this.profile,
  });

  final Profil? profile;
  final VoidCallback onAvatarTap;
  final VoidCallback onComposeTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final displayName = profile?.displayName ?? AppStrings.appName;
    final avatarSeed = profile?.avatarSeed ?? 'horas-me';

    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onComposeTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Semantics(
                button: true,
                label: AppStrings.ber01AuthorProfileSemantics(displayName),
                child: InkWell(
                  onTap: onAvatarTap,
                  borderRadius: AppRadius.pillRadius,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: AppSizes.minTouchTarget,
                      minHeight: AppSizes.minTouchTarget,
                    ),
                    child: Center(
                      child: AppAvatar(
                        name: displayName,
                        seed: avatarSeed,
                        size: AppSizes.avatarMd,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  button: true,
                  label: AppStrings.ber01ComposerSemantics,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.chipInactive.withValues(alpha: 0.65),
                      borderRadius: AppRadius.pillRadius,
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      AppStrings.ber01ComposerPrompt,
                      style: typo.body.copyWith(color: colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Semantics(
                button: true,
                label: AppStrings.ber01ComposerPhotoTooltip,
                child: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.minTouchTarget,
                    minHeight: AppSizes.minTouchTarget,
                  ),
                  tooltip: AppStrings.ber01ComposerPhotoTooltip,
                  onPressed: onComposeTap,
                  icon: Icon(
                    Icons.photo_library_outlined,
                    size: AppSizes.iconMd,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoriesTray extends ConsumerStatefulWidget {
  const _StoriesTray();

  @override
  ConsumerState<_StoriesTray> createState() => _StoriesTrayState();
}

class _StoriesTrayState extends ConsumerState<_StoriesTray>
    with AutomaticKeepAliveClientMixin {
  List<Story> _stories = const <Story>[];
  final Set<String> _viewedLocally = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadStories);
  }

  Future<void> _loadStories() async {
    final res = await ref.read(storyRepositoryProvider).getStories();
    if (!mounted) return;
    if (res is Ok<List<Story>>) {
      setState(() => _stories = res.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<int>(storiesRefreshTickProvider, (_, _) {
      _loadStories();
    });
    final myProfile = ref.watch(
      homeFeedControllerProvider.select((s) => s.myProfile),
    );
    final colors = context.colors;
    final typo = context.typo;

    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.4),
            width: AppSizes.strokeThin,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
        ),
        itemCount: 1 + _stories.length,
        itemBuilder: (context, idx) {
          if (idx == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md + 2),
              child: InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact().ignore();
                  await context.push(AppPages.ber03.routePath);
                  await _loadStories();
                },
                borderRadius: AppRadius.cardRadius,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Stack(
                      children: <Widget>[
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.border,
                              width: 1.5,
                            ),
                            color: colors.chipInactive,
                          ),
                          alignment: Alignment.center,
                          child:
                              myProfile != null &&
                                  PlaceholderImage.isRealImageSeed(
                                    myProfile.avatarSeed,
                                  )
                              ? AppAvatar(
                                  name: myProfile.displayName,
                                  seed: myProfile.avatarSeed,
                                  size: 58,
                                )
                              : Icon(
                                  Icons.person_outline_rounded,
                                  color: colors.textMuted,
                                  size: AppSizes.iconMd + 4,
                                ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colors.buttonPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add_rounded,
                              color: colors.onPrimary,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 68,
                      child: Text(
                        AppStrings.ber01YourStory,
                        style: typo.micro.copyWith(color: colors.textMuted),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final story = _stories[idx - 1];
          final isSeen =
              story.isViewedByMe || _viewedLocally.contains(story.id);

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md + 2),
            child: InkWell(
              onTap: () async {
                HapticFeedback.lightImpact().ignore();
                await context.push(
                  '${AppPages.ber02.routePath}?id=${story.id}',
                );
                if (mounted) {
                  setState(() => _viewedLocally.add(story.id));
                }
              },
              borderRadius: AppRadius.cardRadius,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(2.6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSeen
                          ? null
                          : LinearGradient(
                              colors: <Color>[
                                colors.primary,
                                colors.accent,
                                colors.ratingGold,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      border: isSeen
                          ? Border.all(color: colors.border, width: 1.6)
                          : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surface,
                      ),
                      padding: const EdgeInsets.all(2.2),
                      child: ClipOval(
                        child: PlaceholderImage(
                          seed:
                              PlaceholderImage.isRealImageSeed(story.mediaSeed)
                              ? story.mediaSeed
                              : story.author.avatarSeed,
                          width: 54,
                          height: 54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 68,
                    child: Text(
                      story.author.displayName.split(' ').first,
                      style: typo.micro.copyWith(
                        color: isSeen ? colors.textMuted : colors.text,
                        fontWeight: isSeen ? FontWeight.w500 : FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
