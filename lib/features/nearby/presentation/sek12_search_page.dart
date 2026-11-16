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
import 'package:horas/features/nearby/presentation/nearby_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-12 Pencarian Sekitar: mencari Orang dan Komunitas (Gereja = Fase 2 off, `AC-13`).
class Sek12SearchPage extends ConsumerStatefulWidget {
  const Sek12SearchPage({super.key});

  @override
  ConsumerState<Sek12SearchPage> createState() => _Sek12SearchPageState();
}

class _Sek12SearchPageState extends ConsumerState<Sek12SearchPage> {
  final TextEditingController _queryCtrl = TextEditingController();
  bool _hasSearched = false;
  bool _isLoading = false;
  AppError? _error;
  List<PersonSummary> _people = const <PersonSummary>[];
  List<Community> _communities = const <Community>[];
  List<String> _history = const <String>[];

  @override
  void initState() {
    super.initState();
    _history = ref.read(searchRepositoryProvider).getSearchHistory();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _hasSearched = true;
      _isLoading = true;
      _error = null;
    });

    final repo = ref.read(searchRepositoryProvider);
    await repo.addSearchHistory(clean);
    final peopleFuture = repo.searchPeople(query: clean);
    final commFuture = repo.searchCommunities(query: clean);

    final peopleRes = await peopleFuture;
    final commRes = await commFuture;

    if (!mounted) return;
    if (peopleRes is Err<List<PersonSummary>>) {
      setState(() {
        _isLoading = false;
        _error = peopleRes.failure;
        _history = repo.getSearchHistory();
      });
      return;
    }
    if (commRes is Err<List<Community>>) {
      setState(() {
        _isLoading = false;
        _error = commRes.failure;
        _history = repo.getSearchHistory();
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _people = (peopleRes as Ok<List<PersonSummary>>).value;
      _communities = (commRes as Ok<List<Community>>).value
          .where((c) => c.type != CommunityType.church)
          .toList(growable: false);
      _history = repo.getSearchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: AppTextField(
            controller: _queryCtrl,
            hintText: AppStrings.sek12SearchHint,
            textInputAction: TextInputAction.search,
            onSubmitted: _executeSearch,
            suffixIcon: Icons.search_rounded,
            suffixSemanticsLabel: AppStrings.semanticsSearch,
            onSuffixTap: () => _executeSearch(_queryCtrl.text),
          ),
          bottom: _hasSearched
              ? const TabBar(
                  tabs: <Widget>[
                    Tab(text: AppStrings.ber10TabPeople),
                    Tab(text: AppStrings.ber10TabCommunities),
                  ],
                )
              : null,
        ),
        body: !_hasSearched
            ? ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: <Widget>[
                  Text(AppStrings.sek12SearchPrompt, style: typo.caption),
                  if (_history.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(
                      title: AppStrings.ber09HistoryHeader,
                      actionLabel: AppStrings.ber09ClearAllHistory,
                      onActionTap: () async {
                        await ref
                            .read(searchRepositoryProvider)
                            .clearSearchHistory();
                        setState(() => _history = const <String>[]);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final item in _history)
                          AppChip(
                            label: item,
                            onTap: () {
                              _queryCtrl.text = item;
                              _executeSearch(item);
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              )
            : _buildResultsBody(),
      ),
    );
  }

  Widget _buildResultsBody() {
    if (_isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    }

    if (_error != null) {
      return StateView.fromError(
        _error!,
        onRetry: () => _executeSearch(_queryCtrl.text),
      );
    }

    return TabBarView(
      children: <Widget>[
        _people.isEmpty
            ? StateView.empty(
                message: AppStrings.ber10EmptyPeople,
                actionLabel: AppStrings.actionRetry,
                onAction: () => _executeSearch(_queryCtrl.text),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                itemCount: _people.length,
                itemBuilder: (context, index) {
                  final p = _people[index];
                  return PersonNearbyCard(
                    person: p,
                    onTap: () =>
                        context.push('${AppPages.sek04.routePath}?id=${p.id}'),
                  );
                },
              ),
        _communities.isEmpty
            ? StateView.empty(
                message: AppStrings.ber10EmptyCommunities,
                actionLabel: AppStrings.actionRetry,
                onAction: () => _executeSearch(_queryCtrl.text),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                itemCount: _communities.length,
                itemBuilder: (context, index) {
                  final c = _communities[index];
                  return CommunityCard(
                    community: c,
                    onTap: () =>
                        context.push('${AppPages.sek06.routePath}?id=${c.id}'),
                  );
                },
              ),
      ],
    );
  }
}
