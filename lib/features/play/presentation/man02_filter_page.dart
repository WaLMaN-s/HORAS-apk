import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/play/presentation/play_controller.dart';
import 'package:horas/features/play/presentation/play_models.dart';
import 'package:material_ui/material_ui.dart';

/// MAN-02 Filter Sesi: olahraga, hari, level, rentang jarak area, dan biaya.
class Man02FilterPage extends ConsumerStatefulWidget {
  const Man02FilterPage({super.key});

  @override
  ConsumerState<Man02FilterPage> createState() => _Man02FilterPageState();
}

class _Man02FilterPageState extends ConsumerState<Man02FilterPage> {
  late SportType? _sport;
  late SkillLevel? _level;
  late PlayDayFilter _day;
  late AreaProximity? _range;
  late PlayCostFilter _cost;

  @override
  void initState() {
    super.initState();
    final current = ref.read(playControllerProvider).filter;
    _sport = current.sportType;
    _level = current.skillLevel;
    _day = current.dayFilter;
    _range = current.rangeFilter;
    _cost = current.costFilter;
  }

  Future<void> _apply() async {
    await ref
        .read(playControllerProvider.notifier)
        .applyFilter(
          PlaySessionFilter(
            sportType: _sport,
            skillLevel: _level,
            dayFilter: _day,
            rangeFilter: _range,
            costFilter: _cost,
          ),
        );
    if (mounted) context.pop();
  }

  Future<void> _reset() async {
    await ref.read(playControllerProvider.notifier).resetFilter();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.man02Title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: <Widget>[
          Text(AppStrings.man02SportLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppChip(
                label: AppStrings.man02AllSports,
                isSelected: _sport == null,
                onTap: () => setState(() => _sport = null),
              ),
              for (final s in SportType.values)
                AppChip(
                  label: s.label,
                  isSelected: _sport == s,
                  onTap: () => setState(() => _sport = s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.man02DayLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final d in PlayDayFilter.values)
                AppChip(
                  label: switch (d) {
                    PlayDayFilter.all => AppStrings.man02DayAll,
                    PlayDayFilter.today => AppStrings.man02DayToday,
                    PlayDayFilter.tomorrow => AppStrings.man02DayTomorrow,
                    PlayDayFilter.weekend => AppStrings.man02DayWeekend,
                  },
                  isSelected: _day == d,
                  onTap: () => setState(() => _day = d),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.man02LevelLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppChip(
                label: AppStrings.man02AllLevels,
                isSelected: _level == null,
                onTap: () => setState(() => _level = null),
              ),
              for (final lvl in SkillLevel.values)
                AppChip(
                  label: lvl.label,
                  isSelected: _level == lvl,
                  onTap: () => setState(() => _level = lvl),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.man02RangeLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppChip(
                label: AppStrings.man02RangeAll,
                isSelected: _range == null,
                onTap: () => setState(() => _range = null),
              ),
              AppChip(
                label: AppStrings.man02RangeSameSubdistrict,
                isSelected: _range == AreaProximity.diKecamatanmu,
                onTap: () =>
                    setState(() => _range = AreaProximity.diKecamatanmu),
              ),
              AppChip(
                label: AppStrings.man02RangeSameCity,
                isSelected: _range == AreaProximity.diKotamu,
                onTap: () => setState(() => _range = AreaProximity.diKotamu),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.man02CostLabel, style: typo.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppChip(
                label: AppStrings.man02CostAll,
                isSelected: _cost == PlayCostFilter.all,
                onTap: () => setState(() => _cost = PlayCostFilter.all),
              ),
              AppChip(
                label: AppStrings.man02CostFree,
                isSelected: _cost == PlayCostFilter.freeOnly,
                onTap: () => setState(() => _cost = PlayCostFilter.freeOnly),
              ),
              AppChip(
                label: AppStrings.man02CostPaid,
                isSelected: _cost == PlayCostFilter.paidOnly,
                onTap: () => setState(() => _cost = PlayCostFilter.paidOnly),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: AppStrings.sek03ResetBtn,
                  variant: AppButtonVariant.secondary,
                  onPressed: _reset,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: AppStrings.sek03ApplyBtn,
                  onPressed: _apply,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
