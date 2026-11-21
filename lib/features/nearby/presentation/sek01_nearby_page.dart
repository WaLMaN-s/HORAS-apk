import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/nearby/presentation/nearby_controller.dart';
import 'package:horas/features/nearby/presentation/nearby_models.dart';
import 'package:horas/features/nearby/presentation/nearby_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-01 Sekitar Utama bergaya modern ringkas (PRD 5.1, 6.3, 8 A2/A5).
///
/// Menampilkan segmen Orang dan Komunitas saja pada MVP; Gereja adalah Fase 2
/// (`FeatureFlags.church == false`) dan disembunyikan saat flag nonaktif.
class Sek01NearbyPage extends ConsumerStatefulWidget {
  const Sek01NearbyPage({super.key, this.tabIndex = 1});

  final int tabIndex;

  @override
  ConsumerState<Sek01NearbyPage> createState() => _Sek01NearbyPageState();
}

class _Sek01NearbyPageState extends ConsumerState<Sek01NearbyPage> {
  final Set<String> _busyFollowUserIds = <String>{};
  final Map<String, bool> _localFollowOverride = <String, bool>{};

  Future<void> _toggleQuickFollow(PersonSummary person) async {
    if (_busyFollowUserIds.contains(person.id)) return;
    HapticFeedback.lightImpact().ignore();
    final currentlyFollowing =
        _localFollowOverride[person.id] ?? person.isFollowing;
    setState(() {
      _busyFollowUserIds.add(person.id);
      _localFollowOverride[person.id] = !currentlyFollowing;
    });

    final followRepo = ref.read(followRepositoryProvider);
    final bool ok;
    String? errMsg;
    if (currentlyFollowing) {
      final res = await followRepo.unfollowUser(person.id);
      ok = res.isOk;
      if (res is Err<void>) errMsg = res.failure.message;
    } else {
      final res = await followRepo.followUser(person.id);
      ok = res.isOk;
      if (res is Err<Follow>) errMsg = res.failure.message;
    }

    if (!mounted) return;
    setState(() {
      _busyFollowUserIds.remove(person.id);
      if (!ok) {
        _localFollowOverride[person.id] = currentlyFollowing;
      }
    });
    if (!ok && errMsg != null) {
      AppToast.show(context, message: errMsg, variant: AppToastVariant.error);
    }
  }

  Future<void> _openAreaPicker(
    NearbyState state,
    NearbyController controller,
  ) async {
    final picked = await showManualAreaPickerSheet(
      context: context,
      cities: state.availableCities,
      selectedCity: state.selectedCity,
    );
    if (picked != null && picked.isNotEmpty) {
      await controller.setSelectedCity(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyControllerProvider);
    final controller = ref.read(nearbyControllerProvider.notifier);
    final flags = ref.watch(featureFlagsProvider);
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ??
        ref.read(navigationBadgeRepositoryProvider).currentUnreadCounts();
    final scrollController = ref
        .read(shellNavigationProvider.notifier)
        .scrollControllerForTab(widget.tabIndex);
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Row(
          children: <Widget>[
            const Text(AppStrings.sek01Title),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: InkWell(
                onTap: () => _openAreaPicker(state, controller),
                borderRadius: AppRadius.pillRadius,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.chipInactive,
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          state.selectedCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.micro.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
          // Baris Segmen Pill Ringkas (Orang | Komunitas | Gereja jika Fase 2 aktif)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.xs,
              AppSpacing.screenMargin,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _SegmentPill(
                        label: AppStrings.sek01SegmentOrang,
                        icon: Icons.people_outline_rounded,
                        selected: state.segment == NearbyMainSegment.orang,
                        onTap: () =>
                            controller.selectSegment(NearbyMainSegment.orang),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _SegmentPill(
                        label: AppStrings.sek01SegmentKomunitas,
                        icon: Icons.groups_outlined,
                        selected: state.segment == NearbyMainSegment.komunitas,
                        onTap: () => controller.selectSegment(
                          NearbyMainSegment.komunitas,
                        ),
                      ),
                      if (flags.church) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        _SegmentPill(
                          label: AppStrings.sek10Title,
                          icon: Icons.church_outlined,
                          selected: false,
                          onTap: () => context.push(AppPages.sek10.routePath),
                        ),
                      ],
                    ],
                  ),
                ),
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
          Divider(
            height: AppSizes.strokeThin,
            color: colors.border.withValues(alpha: 0.45),
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
        onOpenSettings: () => _openAreaPicker(state, controller),
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
              await _openAreaPicker(state, controller);
            }
          },
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          _localFollowOverride.clear();
          await controller.loadInitial();
        },
        child: ListView(
          controller: scrollController,
          scrollCacheExtent: const ScrollCacheExtent.viewport(1.0),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.md,
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
              Builder(
                builder: (ctx) {
                  final isFollowing =
                      _localFollowOverride[person.id] ?? person.isFollowing;
                  final isBusy = _busyFollowUserIds.contains(person.id);
                  final actionLabel = isFollowing
                      ? AppStrings.termMengikuti
                      : (person.isFollowedBy
                            ? AppStrings.termFollback
                            : AppStrings.termIkuti);
                  return PersonNearbyCard(
                    person: person,
                    onTap: () => context.push(
                      '${AppPages.sek04.routePath}?id=${person.id}',
                    ),
                    trailing: AppButton(
                      label: actionLabel,
                      variant: isFollowing
                          ? AppButtonVariant.tonal
                          : AppButtonVariant.primary,
                      compact: true,
                      isDisabled: isBusy,
                      onPressed: () => _toggleQuickFollow(person),
                    ),
                  );
                },
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
          AppSpacing.md,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: AppStrings.sek01ViewAllCommunities,
                  variant: AppButtonVariant.tonal,
                  compact: true,
                  leadingIcon: Icons.explore_outlined,
                  onPressed: () => context.push(AppPages.sek05.routePath),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: AppStrings.sek01CreateCommunityBtn,
                  compact: true,
                  leadingIcon: Icons.add_rounded,
                  onPressed: () => context.push(AppPages.sek07.routePath),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
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

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.pillRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.text : colors.chipInactive,
            borderRadius: AppRadius.pillRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: selected ? colors.surface : colors.text,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                label,
                style: typo.captionStrong.copyWith(
                  color: selected ? colors.surface : colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
