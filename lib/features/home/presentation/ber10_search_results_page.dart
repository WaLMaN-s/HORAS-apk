import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
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

/// BER-10 Hasil Pencarian (BER-R13, AC-11, AC-13):
///
/// Menampilkan tab **Orang** dan **Komunitas**.
/// Tab **Gereja** dan **Postingan** publik aktif saat FeatureFlags Fase 2 aktif.
class Ber10SearchResultsPage extends ConsumerStatefulWidget {
  const Ber10SearchResultsPage({required this.initialQuery, super.key});

  final String initialQuery;

  @override
  ConsumerState<Ber10SearchResultsPage> createState() =>
      _Ber10SearchResultsPageState();
}

class _Ber10SearchResultsPageState extends ConsumerState<Ber10SearchResultsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;

  List<PersonSummary> _people = const <PersonSummary>[];
  List<Community> _communities = const <Community>[];
  List<Church> _churches = const <Church>[];
  List<Post> _posts = const <Post>[];
  AppError? _error;
  bool _isLoading = true;
  bool _hasPhase2 = false;

  @override
  void initState() {
    super.initState();
    final flags = ref.read(featureFlagsProvider);
    _hasPhase2 = flags.church || flags.hashtags;
    _tabController = TabController(length: _hasPhase2 ? 4 : 2, vsync: this);
    _searchController = TextEditingController(text: widget.initialQuery);
    _runSearch(widget.initialQuery);
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final searchRepo = ref.read(searchRepositoryProvider);
    final peopleRes = await searchRepo.searchPeople(query: query);
    final commRes = await searchRepo.searchCommunities(query: query);

    Result<List<Church>>? churchRes;
    Result<List<Post>>? postsRes;

    if (_hasPhase2) {
      churchRes = await searchRepo.searchChurches(query: query);
      postsRes = await searchRepo.searchPublicPosts(query: query);
    }

    if (!mounted) return;

    if (peopleRes is Err<List<PersonSummary>>) {
      setState(() {
        _error = peopleRes.failure;
        _isLoading = false;
      });
      return;
    }

    if (commRes is Err<List<Community>>) {
      setState(() {
        _error = commRes.failure;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _people = (peopleRes as Ok<List<PersonSummary>>).value;
      _communities = (commRes as Ok<List<Community>>).value;
      if (churchRes is Ok<List<Church>>) {
        _churches = churchRes.value;
      }
      if (postsRes is Ok<List<Post>>) {
        _posts = postsRes.value;
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.ber10Title, style: typo.h2),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.accent,
          unselectedLabelColor: colors.textMuted,
          indicatorColor: colors.accent,
          isScrollable: _hasPhase2,
          tabs: <Tab>[
            const Tab(text: AppStrings.ber10TabPeople),
            const Tab(text: AppStrings.ber10TabCommunities),
            if (_hasPhase2) const Tab(text: AppStrings.ber10TabChurches),
            if (_hasPhase2) const Tab(text: AppStrings.ber10TabPosts),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.md,
                AppSpacing.screenMargin,
                AppSpacing.sm,
              ),
              child: AppTextField(
                hintText: AppStrings.ber09SearchHint,
                controller: _searchController,
                leadingIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const SingleChildScrollView(
                      child: StateView.loading(itemCount: 3),
                    )
                  : _error != null
                  ? StateView.fromError(
                      _error!,
                      onRetry: () => _runSearch(_searchController.text),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _buildPeopleTab(context),
                        _buildCommunitiesTab(context),
                        if (_hasPhase2) _buildChurchesTab(context),
                        if (_hasPhase2) _buildPostsTab(context),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeopleTab(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (_people.isEmpty) {
      return StateView.empty(
        message: AppStrings.ber10EmptyPeople,
        actionLabel: AppStrings.actionRetry,
        onAction: () => _runSearch(_searchController.text),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: _people.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final person = _people[index];
        final partuturan = person.partuturan;
        final showBadge = partuturan != null && !partuturan.modeNetral;

        return Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: () =>
                context.push('${AppPages.sek04.routePath}?id=${person.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  AppAvatar(
                    name: person.displayName,
                    seed: person.avatarSeed,
                    size: AppSizes.avatarMd,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(person.displayName, style: typo.bodyStrong),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${person.marga} · ${person.city} · ${person.proximity.displayLabel}',
                          style: typo.caption,
                        ),
                      ],
                    ),
                  ),
                  if (showBadge)
                    PartuturanBadge(
                      result: partuturan,
                      onTap: () => context.push(
                        '${AppPages.tar05.routePath}?userId=${person.id}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunitiesTab(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (_communities.isEmpty) {
      return StateView.empty(
        message: AppStrings.ber10EmptyCommunities,
        actionLabel: AppStrings.actionRetry,
        onAction: () => _runSearch(_searchController.text),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: _communities.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final comm = _communities[index];

        return Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: () =>
                context.push('${AppPages.sek06.routePath}?id=${comm.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  PlaceholderImage(
                    seed: comm.avatarSeed,
                    width: AppSizes.avatarMd,
                    height: AppSizes.avatarMd,
                    borderRadius: AppRadius.photoRadius,
                    showMountainSilhouette: false,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(comm.name, style: typo.bodyStrong),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            VerifiedBadge(
                              isVerified: comm.isVerified,
                              showUnverifiedLabel:
                                  comm.type == CommunityType.punguanMarga,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${comm.type.label} · ${comm.city} · ${comm.memberCount} anggota',
                          style: typo.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChurchesTab(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (_churches.isEmpty) {
      return StateView.empty(
        message: AppStrings.sek10EmptyChurches,
        actionLabel: AppStrings.actionRetry,
        onAction: () => _runSearch(_searchController.text),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: _churches.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final church = _churches[index];

        return Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: () =>
                context.push('${AppPages.sek11.routePath}?id=${church.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.church_outlined,
                      color: colors.primary,
                      size: AppSizes.iconMd,
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
                              child: Text(church.name, style: typo.bodyStrong),
                            ),
                            if (church.isVerified)
                              const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: AppSizes.iconSm,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${church.denomination.label} · ${church.city}',
                          style: typo.caption.copyWith(color: colors.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          church.address,
                          style: typo.micro.copyWith(color: colors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsTab(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (_posts.isEmpty) {
      return StateView.empty(
        message: 'Tidak ada postingan yang sesuai pencarian.',
        actionLabel: AppStrings.actionRetry,
        onAction: () => _runSearch(_searchController.text),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: _posts.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final post = _posts[index];

        return Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: () =>
                context.push('${AppPages.ber06.routePath}?id=${post.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      AppAvatar(
                        name: post.author.displayName,
                        seed: post.author.avatarSeed,
                        size: AppSizes.avatarSm,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          post.author.displayName,
                          style: typo.bodyStrong,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    post.text,
                    style: typo.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.favorite_border,
                        size: AppSizes.iconSm,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.likeCount}', style: typo.caption),
                      const SizedBox(width: AppSpacing.md),
                      Icon(
                        Icons.chat_bubble_outline,
                        size: AppSizes.iconSm,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.commentCount}', style: typo.caption),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
