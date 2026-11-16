import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:horas/features/nearby/presentation/nearby_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-02 Daftar Orang Sekitar (`SEK-R1`, `SEK-R2`, `AC-07`).
///
/// Menampilkan 20 hasil per halaman sesuai urutan: kerabat (keyakinan tinggi/sedang),
/// komunitas sama, hobi sama, aktivitas terbaru. Area berdasar profil/pilihan manual, bukan GPS.
class Sek02PeopleListPage extends ConsumerWidget {
  const Sek02PeopleListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyControllerProvider);
    final controller = ref.read(nearbyControllerProvider.notifier);
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sek02Title),
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
            child: Container(
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
                    Icons.location_city_outlined,
                    size: AppSizes.iconMd,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${AppStrings.sek01AreaLabel}: ${state.selectedCity}',
                      style: typo.bodyStrong,
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
          ),
          Expanded(child: _buildListBody(context, state, controller)),
        ],
      ),
    );
  }

  Widget _buildListBody(
    BuildContext context,
    NearbyState state,
    NearbyController controller,
  ) {
    if (state.isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 5),
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
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.sm,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        itemCount: state.people.length + (state.hasMorePeople ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.people.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: AppButton(
                label: AppStrings.sek02LoadMoreBtn,
                variant: AppButtonVariant.secondary,
                isLoading: state.isLoadingMore,
                onPressed: controller.loadMorePeople,
              ),
            );
          }
          final person = state.people[index];
          return PersonNearbyCard(
            person: person,
            onTap: () =>
                context.push('${AppPages.sek04.routePath}?id=${person.id}'),
          );
        },
      ),
    );
  }
}
