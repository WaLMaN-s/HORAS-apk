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
import 'package:material_ui/material_ui.dart';

/// AKN-01 Profil Saya (`AKN-R1`, PRD 5.1).
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
      body = DefaultTabController(
        length: 2,
        child: NestedScrollView(
          controller: scrollController,
          headerSliverBuilder: (ctx, innerScrolled) => <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        AppAvatar(
                          name: me.displayName,
                          seed: me.avatarSeed,
                          size: AppSizes.avatarLg,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(me.displayName, style: typo.h2),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: <Widget>[
                                  Text(
                                    '${me.marga} · ${me.subEthnic.displayName}',
                                    style: typo.bodyStrong.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  VerifiedBadge(isVerified: me.isMargaVerified),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                me.city,
                                style: typo.caption.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (me.bio.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(me.bio, style: typo.body),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _CounterTile(
                            count: me.followersCount,
                            label: AppStrings.akn01FollowersCountLabel,
                            onTap: () async {
                              await context.push(AppPages.akn05.routePath);
                              await _load();
                            },
                          ),
                        ),
                        Expanded(
                          child: _CounterTile(
                            count: me.followingCount,
                            label: AppStrings.akn01FollowingCountLabel,
                            onTap: () async {
                              await context.push(AppPages.akn06.routePath);
                              await _load();
                            },
                          ),
                        ),
                        Expanded(
                          child: _CounterTile(
                            count: me.connectionsCount,
                            label: AppStrings.akn01ConnectionsCountLabel,
                            onTap: () async {
                              await context.push(AppPages.akn12.routePath);
                              await _load();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppButton(
                            label: AppStrings.akn02Title,
                            variant: AppButtonVariant.secondary,
                            onPressed: () async {
                              await context.push(AppPages.akn02.routePath);
                              await _load();
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: AppStrings.akn01ConnectionsShortcut,
                            variant: AppButtonVariant.secondary,
                            onPressed: () =>
                                context.push(AppPages.akn12.routePath).ignore(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TabBar(
                tabs: <Tab>[
                  Tab(text: '${AppStrings.akn01TabPosts} (${_myPosts.length})'),
                  Tab(
                    text: '${AppStrings.akn01TabSaved} (${_savedPosts.length})',
                  ),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: <Widget>[
              _PostsTabList(
                posts: _myPosts,
                now: now,
                emptyMessage: AppStrings.akn01EmptyPosts,
                seeAllLabel: AppStrings.akn03Title,
                onSeeAll: () => context.push(AppPages.akn03.routePath).ignore(),
                onRefresh: _load,
              ),
              _PostsTabList(
                posts: _savedPosts.map((s) => s.post).toList(growable: false),
                now: now,
                emptyMessage: AppStrings.akn01EmptySaved,
                seeAllLabel: AppStrings.akn04Title,
                onSeeAll: () => context.push(AppPages.akn04.routePath).ignore(),
                onRefresh: _load,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.akn01Title),
        actions: <Widget>[
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
      borderRadius: AppRadius.cardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: <Widget>[
            Text('$count', style: context.typo.h3),
            Text(
              label,
              style: context.typo.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostsTabList extends StatelessWidget {
  const _PostsTabList({
    required this.posts,
    required this.now,
    required this.emptyMessage,
    required this.seeAllLabel,
    required this.onSeeAll,
    required this.onRefresh,
  });

  final List<Post> posts;
  final DateTime now;
  final String emptyMessage;
  final String seeAllLabel;
  final VoidCallback onSeeAll;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return StateView.empty(
        message: emptyMessage,
        actionLabel: seeAllLabel,
        onAction: onSeeAll,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: posts.length + 1,
        itemBuilder: (ctx, index) {
          if (index == 0) {
            return Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onSeeAll, child: Text(seeAllLabel)),
            );
          }
          final post = posts[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: PostCard(
              post: post,
              now: now,
              isOwnPost: true,
              onTapCard: () => context
                  .push('${AppPages.ber06.routePath}?postId=${post.id}')
                  .ignore(),
            ),
          );
        },
      ),
    );
  }
}
