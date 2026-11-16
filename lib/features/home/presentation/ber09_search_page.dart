import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// BER-09 Pencarian: kolom cari, riwayat pencarian (dapat dihapus), dan saran (BER-R13).
class Ber09SearchPage extends ConsumerStatefulWidget {
  const Ber09SearchPage({super.key});

  @override
  ConsumerState<Ber09SearchPage> createState() => _Ber09SearchPageState();
}

class _Ber09SearchPageState extends ConsumerState<Ber09SearchPage> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _executeSearch(String rawQuery) async {
    final clean = rawQuery.trim();
    if (clean.isEmpty) return;
    await ref.read(searchRepositoryProvider).addSearchHistory(clean);
    if (!mounted) return;
    final encoded = Uri.encodeQueryComponent(clean);
    await context.push('${AppPages.ber10.routePath}?q=$encoded');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final searchRepo = ref.watch(searchRepositoryProvider);
    final history = searchRepo.getSearchHistory();
    final suggestions = searchRepo.getSearchSuggestions();
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.ber09Title, style: typo.h2)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          children: <Widget>[
            AppTextField(
              hintText: AppStrings.ber09SearchHint,
              controller: _queryController,
              leadingIcon: Icons.search_rounded,
              suffixIcon: _queryController.text.isNotEmpty
                  ? Icons.clear_rounded
                  : null,
              suffixSemanticsLabel: AppStrings.semanticsClearInput,
              onSuffixTap: () {
                _queryController.clear();
                setState(() {});
              },
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: _executeSearch,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: AppStrings.ber09Title,
              isExpanded: true,
              onPressed: () => _executeSearch(_queryController.text),
            ),
            if (history.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                title: AppStrings.ber09HistoryHeader,
                actionLabel: AppStrings.ber09ClearAllHistory,
                onActionTap: () async {
                  await searchRepo.clearSearchHistory();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history_rounded, color: colors.textMuted),
                  title: Text(item, style: typo.body),
                  trailing: Semantics(
                    button: true,
                    label: AppStrings.ber09DeleteHistoryItemTooltip,
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: AppSizes.minTouchTarget,
                        minHeight: AppSizes.minTouchTarget,
                      ),
                      tooltip: AppStrings.ber09DeleteHistoryItemTooltip,
                      onPressed: () async {
                        await searchRepo.removeSearchHistory(item);
                        if (mounted) setState(() {});
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        size: AppSizes.iconSm,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  onTap: () => _executeSearch(item),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: AppStrings.ber09SuggestionsHeader),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final sug in suggestions)
                  AppChip(label: sug, onTap: () => _executeSearch(sug)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
