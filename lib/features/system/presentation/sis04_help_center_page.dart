import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// SIS-04 Pusat Bantuan: artikel dan FAQ dari aset (`assets/data/bantuan.json`, `SIS-R5`).
class Sis04HelpCenterPage extends ConsumerStatefulWidget {
  const Sis04HelpCenterPage({super.key});

  @override
  ConsumerState<Sis04HelpCenterPage> createState() =>
      _Sis04HelpCenterPageState();
}

class _Sis04HelpCenterPageState extends ConsumerState<Sis04HelpCenterPage> {
  final _searchController = TextEditingController();
  List<HelpArticle> _allArticles = const <HelpArticle>[];
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadFromAssets);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFromAssets() async {
    try {
      final rawJson = await rootBundle.loadString('assets/data/bantuan.json');
      final list = jsonDecode(rawJson) as List<Object?>;
      final parsed = list
          .whereType<Map<String, Object?>>()
          .map(
            (m) => HelpArticle(
              id: (m['id'] as String?) ?? '',
              category: (m['category'] as String?) ?? '',
              question: (m['question'] as String?) ?? '',
              answer: (m['answer'] as String?) ?? '',
            ),
          )
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _allArticles = parsed;
          _isLoading = false;
        });
      }
    } on Object {
      final res = await ref.read(supportRepositoryProvider).getHelpArticles();
      if (!mounted) return;
      setState(() {
        _allArticles = res is Ok<List<HelpArticle>>
            ? res.value
            : const <HelpArticle>[];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _allArticles
        : _allArticles
              .where(
                (a) =>
                    a.question.toLowerCase().contains(q) ||
                    a.answer.toLowerCase().contains(q) ||
                    a.category.toLowerCase().contains(q),
              )
              .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sis04Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  AppTextField(
                    controller: _searchController,
                    hintText: AppStrings.sis04SearchHint,
                    leadingIcon: Icons.search_rounded,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (filtered.isEmpty)
                    StateView.empty(
                      message: AppStrings.sis04EmptyArticles,
                      actionLabel: AppStrings.sis05Title,
                      onAction: () => context.push(AppPages.sis05.routePath),
                    )
                  else
                    ...filtered.map(
                      (a) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ExpansionTile(
                          title: Text(
                            a.question,
                            style: context.typo.bodyStrong,
                          ),
                          subtitle: Text(
                            a.category,
                            style: context.typo.caption.copyWith(
                              color: context.colors.textMuted,
                            ),
                          ),
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.lg,
                              ),
                              child: Text(a.answer, style: context.typo.body),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: AppStrings.sis05Title,
                    variant: AppButtonVariant.secondary,
                    isExpanded: true,
                    onPressed: () =>
                        context.push(AppPages.sis05.routePath).ignore(),
                  ),
                ],
              ),
      ),
    );
  }
}
