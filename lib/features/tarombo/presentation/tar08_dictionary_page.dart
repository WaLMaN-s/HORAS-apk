import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/theme/horas_colors.dart';
import 'package:horas/core/theme/horas_typography.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// TAR-08 Kamus Partuturan.
///
/// - Cari istilah, makna, contoh.
/// - Pilihan sub-suku dengan keterangan "Aturan aktif" (Toba) atau "Mode netral".
/// - Isi kamus hanya dari aturan yang sudah divalidasi atau bertanda draf (TAR-R5, TAR-R6).
/// - Status: memuat, kosong, offline, error.
class Tar08DictionaryPage extends ConsumerStatefulWidget {
  const Tar08DictionaryPage({super.key});

  @override
  ConsumerState<Tar08DictionaryPage> createState() =>
      _Tar08DictionaryPageState();
}

class _Tar08DictionaryPageState extends ConsumerState<Tar08DictionaryPage> {
  final _searchController = TextEditingController();
  String _selectedSubEthnic = 'Toba';
  bool _isLoading = true;
  AppError? _error;
  List<PartuturanDictionaryEntry> _entries =
      const <PartuturanDictionaryEntry>[];

  static const List<String> _subEthnics = <String>[
    'Toba',
    'Karo',
    'Simalungun',
    'Pakpak',
    'Mandailing',
    'Angkola',
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repo = ref.read(partuturanDictionaryRepositoryProvider);
    final subEthnic = SubEthnic.values.firstWhere(
      (e) => e.displayName.toLowerCase() == _selectedSubEthnic.toLowerCase(),
      orElse: () => SubEthnic.toba,
    );
    final res = await repo.searchEntries(
      subEthnic: subEthnic,
      query: _searchController.text.trim(),
    );

    if (!mounted) return;
    if (res is Ok<List<PartuturanDictionaryEntry>>) {
      setState(() {
        _entries = res.value;
        _isLoading = false;
      });
    } else if (res is Err<List<PartuturanDictionaryEntry>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final isActiveRule = _selectedSubEthnic == 'Toba';

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tar08Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.actionRetry,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Search box
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            color: colors.surface,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.tar08SearchHint,
                prefixIcon: const Icon(Icons.search, size: AppSizes.iconMd),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: AppSizes.iconSm),
                        tooltip: AppStrings.actionCancel,
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.chipInactive,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
            ),
          ),

          // Sub-ethnic selector chips + status badge
          Container(
            color: colors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      AppStrings.tar08SubEthnicLabel,
                      style: typo.captionStrong,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isActiveRule
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.chipInactive,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        isActiveRule
                            ? AppStrings.tar08ActiveRule
                            : AppStrings.tar08NeutralMode,
                        style: typo.micro.copyWith(
                          color: isActiveRule
                              ? colors.primary
                              : colors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _subEthnics.map((sub) {
                      final isSelected = _selectedSubEthnic == sub;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(sub),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedSubEthnic = sub);
                              _load();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content list
          Expanded(child: _buildBody(colors, typo)),
        ],
      ),
    );
  }

  Widget _buildBody(HorasColors colors, HorasTypography typo) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final isOffline = _error is OfflineError;
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                isOffline ? Icons.wifi_off_outlined : Icons.error_outline,
                color: colors.danger,
                size: AppSizes.iconLg,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!.message,
                style: typo.bodyStrong,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: AppSizes.iconSm),
                label: const Text(AppStrings.actionRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.menu_book_outlined,
                size: AppSizes.iconLg,
                color: colors.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.tar08EmptyDictionary,
                style: typo.body.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, idx) {
          final entry = _entries[idx];
          final isDraft = !entry.isValidated;

          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
              boxShadow: AppShadows.softCard(colors.shadow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.term,
                        style: typo.h3.copyWith(color: colors.primary),
                      ),
                    ),
                    if (isDraft)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.chipInactive,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'Draf',
                          style: typo.micro.copyWith(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${entry.subEthnic.label} · ${entry.category}',
                  style: typo.caption.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(entry.meaning, style: typo.body),
                if (entry.example.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppStrings.tar08ExampleLabel,
                          style: typo.micro.copyWith(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.example,
                          style: typo.caption.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
