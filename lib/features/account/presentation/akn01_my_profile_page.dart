import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/home/presentation/ber07_comments_page.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-01 Profil Saya bergaya Instagram & Threads (`AKN-R1`, PRD 5.1).
class Akn01MyProfilePage extends ConsumerStatefulWidget {
  const Akn01MyProfilePage({super.key, this.tabIndex = 4});

  final int tabIndex;

  @override
  ConsumerState<Akn01MyProfilePage> createState() => _Akn01MyProfilePageState();
}

class _Akn01MyProfilePageState extends ConsumerState<Akn01MyProfilePage> {
  Profil? _profile;
  List<Post> _myPosts = const <Post>[];
  List<SavedPost> _savedPosts = const <SavedPost>[];
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final profileRes = await ref.read(profileRepositoryProvider).getMyProfile();
    if (!mounted) return;
    if (profileRes is Err<Profil>) {
      setState(() {
        _isLoading = false;
        _error = profileRes.failure;
      });
      return;
    }

    final profile = (profileRes as Ok<Profil>).value;
    final postRepo = ref.read(postRepositoryProvider);
    final postsRes = await postRepo.getUserPosts(profile.id);
    final savedRes = await postRepo.getSavedPosts();
    if (!mounted) return;

    setState(() {
      _profile = profile;
      _myPosts = postsRes is Ok<List<Post>> ? postsRes.value : const <Post>[];
      _savedPosts = savedRes is Ok<List<SavedPost>>
          ? savedRes.value
          : const <SavedPost>[];
      _isLoading = false;
    });
  }

  Future<void> _toggleLike(String postId) async {
    final res = await ref.read(postRepositoryProvider).toggleLike(postId);
    if (!mounted) return;
    res.fold(
      onOk: (updated) {
        setState(() {
          _myPosts = _myPosts
              .map((p) => p.id == updated.id ? updated : p)
              .toList(growable: false);
          _savedPosts = _savedPosts
              .map(
                (s) => s.post.id == updated.id
                    ? SavedPost(
                        id: s.id,
                        userId: s.userId,
                        post: updated,
                        savedAt: s.savedAt,
                      )
                    : s,
              )
              .toList(growable: false);
        });
      },
      onErr: (_) {},
    );
  }

  Future<void> _toggleSave(String postId) async {
    final res = await ref.read(postRepositoryProvider).toggleSavePost(postId);
    if (!mounted) return;
    res.fold(
      onOk: (updated) {
        setState(() {
          _myPosts = _myPosts
              .map((p) => p.id == updated.id ? updated : p)
              .toList(growable: false);
          if (!updated.isSavedByMe) {
            _savedPosts = _savedPosts
                .where((s) => s.post.id != updated.id)
                .toList(growable: false);
          }
        });
      },
      onErr: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ??
        ref.read(navigationBadgeRepositoryProvider).currentUnreadCounts();
    final scrollController = ref
        .read(shellNavigationProvider.notifier)
        .scrollControllerForTab(widget.tabIndex);
    final now = ref.read(authRepositoryProvider).currentTime;
    final colors = context.colors;
    final typo = context.typo;

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _load);
    } else if (_profile == null) {
      body = StateView.empty(
        message: AppStrings.stateEmptyDefaultTitle,
        actionLabel: AppStrings.actionRetry,
        onAction: _load,
      );
    } else {
      final me = _profile!;
      final photoPosts = _myPosts
          .where((p) => p.media.isNotEmpty)
          .toList(growable: false);

      body = DefaultTabController(
        length: 3,
        child: NestedScrollView(
          controller: scrollController,
          headerSliverBuilder: (ctx, innerScrolled) => <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.md,
                  AppSpacing.screenMargin,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Baris Header IG: Avatar besar di kiri + 3 kolom statistik di kanan
                    Row(
                      children: <Widget>[
                        AppAvatar(
                          name: me.displayName,
                          seed: me.avatarSeed,
                          size: 80,
                          showBorder: true,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            PhotoLightboxPage.show(
                              context,
                              seeds: <String>[me.avatarSeed],
                              title: me.displayName,
                              isCircular: true,
                            );
                          },
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: <Widget>[
                              _CounterTile(
                                count: _myPosts.length,
                                label: AppStrings.akn01PostsCountLabel,
                                onTap: () => context
                                    .push(AppPages.akn03.routePath)
                                    .ignore(),
                              ),
                              _CounterTile(
                                count: me.followersCount,
                                label: AppStrings.akn01FollowersCountLabel,
                                onTap: () async {
                                  await context.push(AppPages.akn05.routePath);
                                  await _load();
                                },
                              ),
                              _CounterTile(
                                count: me.followingCount,
                                label: AppStrings.akn01FollowingCountLabel,
                                onTap: () async {
                                  await context.push(AppPages.akn06.routePath);
                                  await _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Identitas Nama, Marga, Kota & Bio
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            me.displayName,
                            style: typo.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        VerifiedBadge(isVerified: me.isMargaVerified),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 2,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.pillRadius,
                          ),
                          child: Text(
                            '${me.marga} · ${me.subEthnic.displayName}',
                            style: typo.micro.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.location_on_outlined,
                              size: AppSizes.iconXs,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 2),
                            Text(me.city, style: typo.caption),
                          ],
                        ),
                      ],
                    ),
                    if (me.bio.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(me.bio, style: typo.body),
                    ],
                    const SizedBox(height: AppSpacing.md),

                    // Baris Tombol Seragam ala Instagram
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppButton(
                            label: AppStrings.akn02Title,
                            variant: AppButtonVariant.tonal,
                            compact: true,
                            onPressed: () async {
                              await context.push(AppPages.akn02.routePath);
                              await _load();
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: me.connectionsCount > 0
                                ? '${AppStrings.akn01ConnectionsShortcut} (${me.connectionsCount})'
                                : AppStrings.akn01ConnectionsShortcut,
                            variant: AppButtonVariant.tonal,
                            compact: true,
                            onPressed: () async {
                              await context.push(AppPages.akn12.routePath);
                              await _load();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.border.withValues(alpha: 0.45),
                      width: AppSizes.strokeThin,
                    ),
                    bottom: BorderSide(
                      color: colors.border.withValues(alpha: 0.45),
                      width: AppSizes.strokeThin,
                    ),
                  ),
                ),
                child: TabBar(
                  indicatorColor: colors.text,
                  indicatorWeight: 2,
                  labelColor: colors.text,
                  unselectedLabelColor: colors.textMuted,
                  dividerColor: Colors.transparent,
                  tabs: const <Tab>[
                    Tab(
                      icon: Icon(Icons.grid_on_rounded, size: 20),
                      text: AppStrings.akn01TabGrid,
                    ),
                    Tab(
                      icon: Icon(Icons.view_agenda_outlined, size: 20),
                      text: AppStrings.akn01TabPosts,
                    ),
                    Tab(
                      icon: Icon(Icons.bookmark_border_rounded, size: 20),
                      text: AppStrings.akn01TabSaved,
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: <Widget>[
              _ProfilePhotoGrid(
                posts: photoPosts,
                emptyMessage: AppStrings.akn01EmptyGrid,
                onRefresh: _load,
                onTapPost: (post) =>
                    context.push('${AppPages.ber06.routePath}?id=${post.id}'),
              ),
              _PostsTabList(
                posts: _myPosts,
                now: now,
                isOwnList: true,
                emptyMessage: AppStrings.akn01EmptyPosts,
                seeAllLabel: AppStrings.akn03Title,
                onSeeAll: () => context.push(AppPages.akn03.routePath).ignore(),
                onRefresh: _load,
                onLikeTap: _toggleLike,
                onSaveTap: _toggleSave,
              ),
              _PostsTabList(
                posts: _savedPosts.map((s) => s.post).toList(growable: false),
                now: now,
                isOwnList: false,
                emptyMessage: AppStrings.akn01EmptySaved,
                seeAllLabel: AppStrings.akn04Title,
                onSeeAll: () => context.push(AppPages.akn04.routePath).ignore(),
                onRefresh: _load,
                onLikeTap: _toggleLike,
                onSaveTap: _toggleSave,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(_profile?.displayName ?? AppStrings.akn01Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.semanticsCreatePost,
            onPressed: () => context.push(AppPages.ber04.routePath),
            icon: const Icon(Icons.add_box_outlined),
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
          IconButton(
            tooltip: AppStrings.semanticsSettings,
            onPressed: () => context.push(AppPages.akn07.routePath).ignore(),
            icon: Semantics(
              label: AppStrings.semanticsSettings,
              child: const Icon(Icons.settings_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.buttonRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('$count', style: context.typo.h3),
            const SizedBox(height: 1),
            Text(
              label,
              style: context.typo.micro.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoGrid extends StatelessWidget {
  const _ProfilePhotoGrid({
    required this.posts,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onTapPost,
  });

  final List<Post> posts;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final ValueChanged<Post> onTapPost;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            const SizedBox(height: AppSpacing.xxl),
            StateView.empty(
              message: emptyMessage,
              actionLabel: AppStrings.ber04Title,
              onAction: () => context.push(AppPages.ber04.routePath),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final firstMedia = post.media.first;
          final isMulti = post.media.length > 1;
          return GestureDetector(
            onTap: () => onTapPost(post),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                PlaceholderImage(
                  seed: firstMedia.seed,
                  borderRadius: BorderRadius.zero,
                ),
                if (firstMedia.isVideo)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                else if (isMulti)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.collections_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostsTabList extends StatelessWidget {
  const _PostsTabList({
    required this.posts,
    required this.now,
    required this.isOwnList,
    required this.emptyMessage,
    required this.seeAllLabel,
    required this.onSeeAll,
    required this.onRefresh,
    required this.onLikeTap,
    required this.onSaveTap,
  });

  final List<Post> posts;
  final DateTime now;
  final bool isOwnList;
  final String emptyMessage;
  final String seeAllLabel;
  final VoidCallback onSeeAll;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onLikeTap;
  final ValueChanged<String> onSaveTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (posts.isEmpty) {
      return StateView.empty(
        message: emptyMessage,
        actionLabel: seeAllLabel,
        onAction: onSeeAll,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: posts.length + 1,
        separatorBuilder: (_, _) => Divider(
          height: AppSizes.strokeThin,
          color: colors.border.withValues(alpha: 0.45),
        ),
        itemBuilder: (ctx, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
                vertical: AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSeeAll,
                  child: Text(seeAllLabel),
                ),
              ),
            );
          }
          final post = posts[index - 1];
          return PostCard(
            post: post,
            now: now,
            isOwnPost: isOwnList,
            onTapCard: () => context
                .push('${AppPages.ber06.routePath}?id=${post.id}')
                .ignore(),
            onLikeTap: () => onLikeTap(post.id),
            onSaveTap: () => onSaveTap(post.id),
            onLikesCountTap: () =>
                context.push('${AppPages.ber08.routePath}?id=${post.id}'),
            onCommentTap: () =>
                Ber07CommentsPage.showSheet(context, postId: post.id),
          );
        },
      ),
    );
  }
}
