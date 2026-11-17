import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:horas/features/nearby/presentation/nearby_models.dart';
import 'package:horas/features/nearby/presentation/nearby_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-01 Sekitar Utama (PRD 5.1, 6.3, 8 A2/A5).
///
/// Menampilkan segmen Orang dan Komunitas saja; Gereja dan Kegiatan adalah Fase 2
/// (`FeatureFlags.church == false`, `FeatureFlags.events == false`) dan disembunyikan.
class Sek01NearbyPage extends ConsumerWidget {
  const Sek01NearbyPage({super.key, this.tabIndex = 1});

  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyControllerProvider);
    final controller = ref.read(nearbyControllerProvider.notifier);
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ??
        ref.read(navigationBadgeRepositoryProvider).currentUnreadCounts();
    final scrollController = ref
        .read(shellNavigationProvider.notifier)
        .scrollControllerForTab(tabIndex);
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sek01Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.sek01OpenSearchTooltip,
            onPressed: () => context.push(AppPages.sek12.routePath),
            icon: Semantics(
              label: AppStrings.semanticsSearch,
              child: const Icon(Icons.search_rounded),
            ),
          ),
          IconButton(
            tooltip: AppStrings.sek01OpenFilterTooltip,
            onPressed: () => context.push(AppPages.sek03.routePath),
            icon: Badge(
              isLabelVisible: state.filter.hasActiveFilters,
              label: Text('${state.filter.activeFilterCount}'),
              child: Semantics(
                label: AppStrings.sek01OpenFilterTooltip,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
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
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.sm,
              AppSpacing.screenMargin,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Baris Area tanpa GPS (SEK-R1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.location_on_outlined,
                        color: colors.primary,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(AppStrings.sek01AreaLabel, style: typo.micro),
                            Text(
                              state.selectedCity,
                              style: typo.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showManualAreaPickerSheet(
                            context: context,
                            cities: state.availableCities,
                            selectedCity: state.selectedCity,
                          );
                          if (picked != null && picked.isNotEmpty) {
                            await controller.setSelectedCity(picked);
                          }
                        },
                        child: const Text(AppStrings.sek02ChangeAreaBtn),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Segmen Orang dan Komunitas (Gereja disembunyikan karena Fase 2 off)
                SegmentedButton<NearbyMainSegment>(
                  segments: const <ButtonSegment<NearbyMainSegment>>[
                    ButtonSegment<NearbyMainSegment>(
                      value: NearbyMainSegment.orang,
                      label: Text(AppStrings.sek01SegmentOrang),
                      icon: Icon(Icons.people_outline_rounded),
                    ),
                    ButtonSegment<NearbyMainSegment>(
                      value: NearbyMainSegment.komunitas,
                      label: Text(AppStrings.sek01SegmentKomunitas),
                      icon: Icon(Icons.groups_outlined),
                    ),
                  ],
                  selected: <NearbyMainSegment>{state.segment},
                  onSelectionChanged: (selected) {
                    if (selected.isNotEmpty) {
                      controller.selectSegment(selected.first);
                    }
                  },
                ),
                if (ref.watch(featureFlagsProvider).church) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: () => context.push(AppPages.sek10.routePath),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: colors.chipInactive,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.church_outlined,
                            color: colors.primary,
                            size: AppSizes.iconMd,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${AppStrings.sek10Title} · Temukan gereja & jadwal ibadah',
                              style: typo.captionStrong,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: AppSizes.iconSm,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (state.filter.hasActiveFilters &&
                    state.segment == NearbyMainSegment.orang) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final label in state.filter.activeLabels())
                        AppChip(label: label, isSelected: true),
                      ActionChip(
                        label: const Text(AppStrings.sek03ResetBtn),
                        onPressed: controller.resetFilter,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _buildBody(
              context,
              ref,
              state,
              controller,
              scrollController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NearbyState state,
    NearbyController controller,
    ScrollController scrollController,
  ) {
    if (state.isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    }

    if (state.locationPermissionDenied) {
      return StateView.permissionDenied(
        benefitMessage: AppStrings.sek01LocationPermissionBenefit,
        onOpenSettings: () async {
          final picked = await showManualAreaPickerSheet(
            context: context,
            cities: state.availableCities,
            selectedCity: state.selectedCity,
          );
          if (picked != null && picked.isNotEmpty) {
            await controller.setSelectedCity(picked);
          }
        },
        onContinueWithoutPermission: controller.continueWithManualArea,
      );
    }

    final error = state.error;
    if (error != null) {
      return StateView.fromError(error, onRetry: controller.loadInitial);
    }

    if (state.segment == NearbyMainSegment.orang) {
      if (state.people.isEmpty) {
        return StateView.empty(
          message: AppStrings.sek01EmptyPeopleMessage,
          actionLabel: state.filter.hasActiveFilters
              ? AppStrings.sek03ResetBtn
              : AppStrings.sek02ChangeAreaBtn,
          onAction: () async {
            if (state.filter.hasActiveFilters) {
              await controller.resetFilter();
            } else {
              final picked = await showManualAreaPickerSheet(
                context: context,
                cities: state.availableCities,
                selectedCity: state.selectedCity,
              );
              if (picked != null && picked.isNotEmpty) {
                await controller.setSelectedCity(picked);
              }
            }
          },
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadInitial,
        child: ListView(
          controller: scrollController,
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.0),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.sm,
            AppSpacing.screenMargin,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            SectionHeader(
              title: AppStrings.sek02Title,
              actionLabel: AppStrings.sek01ViewAllPeople,
              onActionTap: () => context.push(AppPages.sek02.routePath),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final person in state.people.take(8))
              PersonNearbyCard(
                person: person,
                onTap: () =>
                    context.push('${AppPages.sek04.routePath}?id=${person.id}'),
              ),
          ],
        ),
      );
    }

    // Segmen Komunitas
    if (state.communities.isEmpty) {
      return StateView.empty(
        message: AppStrings.sek01EmptyCommunitiesMessage,
        actionLabel: AppStrings.sek01CreateCommunityBtn,
        onAction: () => context.push(AppPages.sek07.routePath),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadInitial,
      child: ListView(
        controller: scrollController,
        scrollCacheExtent: const ScrollCacheExtent.viewport(1.0),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.sm,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: AppStrings.sek01ViewAllCommunities,
                  variant: AppButtonVariant.secondary,
                  leadingIcon: Icons.explore_outlined,
                  onPressed: () => context.push(AppPages.sek05.routePath),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: AppStrings.sek01CreateCommunityBtn,
                  leadingIcon: Icons.add_rounded,
                  onPressed: () => context.push(AppPages.sek07.routePath),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final comm in state.communities)
            CommunityCard(
              community: comm,
              onTap: () =>
                  context.push('${AppPages.sek06.routePath}?id=${comm.id}'),
            ),
        ],
      ),
    );
  }
}
