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
import 'package:horas/features/play/presentation/play_controller.dart';
import 'package:material_ui/material_ui.dart';

/// MAN-07 Daftar Lapangan (`MAN-R10`).
///
/// Tampilan peta lapangan adalah Fase 2 (`FeatureFlags.courtMap == false`),
/// sehingga Fase 1 hanya menampilkan daftar lapangan tanpa SDK peta.
class Man07CourtsListPage extends ConsumerStatefulWidget {
  const Man07CourtsListPage({super.key});

  @override
  ConsumerState<Man07CourtsListPage> createState() =>
      _Man07CourtsListPageState();
}

class _Man07CourtsListPageState extends ConsumerState<Man07CourtsListPage> {
  SportType? _selectedSport;
  List<Court> _courts = const <Court>[];
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final city = ref.read(playControllerProvider).selectedCity;
    final res = await ref
        .read(courtRepositoryProvider)
        .getCourts(city: city.isEmpty ? null : city, sportType: _selectedSport);
    if (!mounted) return;
    if (res is Err<List<Court>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }
    setState(() {
      _courts = (res as Ok<List<Court>>).value;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    Widget content;
    if (_isLoading) {
      content = const StateView.loading(itemCount: 3);
    } else if (_error != null) {
      content = StateView.fromError(_error!, onRetry: _load);
    } else if (_courts.isEmpty) {
      content = StateView.empty(
        message: AppStrings.man07EmptyCourtsMessage,
        actionLabel: AppStrings.man07ProposeCourtBtn,
        onAction: () async {
          await context.push('${AppPages.man08.routePath}?propose=true');
          await _load();
        },
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            // Fase 2 guard: peta lapangan disembunyikan saat flag off.
            if (flags.courtMap) const SizedBox.shrink(),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  AppChip(
                    label: AppStrings.man02AllSports,
                    isSelected: _selectedSport == null,
                    onTap: () {
                      setState(() => _selectedSport = null);
                      _load();
                    },
                  ),
                  ...SportType.values.map(
                    (sport) => Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: AppChip(
                        label: sport.label,
                        isSelected: _selectedSport == sport,
                        onTap: () {
                          setState(() => _selectedSport = sport);
                          _load();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            ..._courts.map(
              (court) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: AppRadius.cardRadius,
                    onTap: () async {
                      await context.push(
                        '${AppPages.man08.routePath}?courtId=${court.id}',
                      );
                      await _load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          PlaceholderImage(
                            seed: court.imageSeed,
                            width: 84,
                            height: 84,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(court.name, style: typo.bodyStrong),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  court.address,
                                  style: typo.caption.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${AppStrings.man08EstimatedPricePrefix}: ${court.estimatedPriceText}',
                                  style: typo.caption.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                                if (court.status ==
                                        CourtModerationStatus
                                            .flaggedForReview ||
                                    court.wrongInfoReportCount > 3) ...<Widget>[
                                  const SizedBox(height: AppSpacing.xs),
                                  AppChip(
                                    label:
                                        AppStrings.man08FlaggedForReviewBadge,
                                    customBackgroundColor:
                                        colors.confidenceAmberSurface,
                                    customForegroundColor:
                                        colors.confidenceAmber,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.man07Title),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await context.push('${AppPages.man08.routePath}?propose=true');
              await _load();
            },
            child: const Text(AppStrings.man07ProposeCourtBtn),
          ),
        ],
      ),
      body: SafeArea(child: content),
    );
  }
}
