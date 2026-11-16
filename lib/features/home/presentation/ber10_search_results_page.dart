import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// BER-10 Hasil Pencarian (BER-R13, AC-11, AC-13):
/// Menampilkan HANYA tab **Orang** (nama, marga) dan **Komunitas** (nama, kota).
/// Tab Gereja dan Postingan publik adalah Fase 2 dan tidak ditampilkan di Fase 1.
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
  AppError? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    if (!mounted) return;

    peopleRes.fold(
      onOk: (people) {
        commRes.fold(
          onOk: (comms) => setState(() {
            _people = people;
            _communities = comms;
            _isLoading = false;
          }),
          onErr: (err) => setState(() {
            _error = err;
            _isLoading = false;
          }),
        );
      },
      onErr: (err) => setState(() {
        _error = err;
        _isLoading = false;
      }),
    );
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
          tabs: const <Tab>[
            Tab(text: AppStrings.ber10TabPeople),
            Tab(text: AppStrings.ber10TabCommunities),
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
            onTap: () => context.push(AppPages.sek06.routePath),
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
}
