import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/place_geo_helper.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/nearby/presentation/nearby_widgets.dart';
import 'package:horas/features/play/presentation/play_controller.dart';
import 'package:horas/features/play/presentation/play_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

enum _PlaySectionFilter { all, sessions, courts, churches }

/// MAN-01 Main (Utama): daftar sesi di sekitar, pelacakan area tujuan
/// (mis. Cilandak), serta lapangan & gereja terdekat dengan filter tab modern (`MAN-R1` .. `MAN-R10`).
class Man01PlayPage extends ConsumerStatefulWidget {
  const Man01PlayPage({super.key, this.tabIndex = 3});

  final int tabIndex;

  @override
  ConsumerState<Man01PlayPage> createState() => _Man01PlayPageState();
}

class _Man01PlayPageState extends ConsumerState<Man01PlayPage> {
  final TextEditingController _destController = TextEditingController();
  _PlaySectionFilter _activeTab = _PlaySectionFilter.all;

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  Future<void> _openExternalDirections({
    required String name,
    required String address,
    required String city,
    double? latitude,
    double? longitude,
  }) async {
    HapticFeedback.lightImpact().ignore();
    final uri = PlaceGeoHelper.googleMapsDirectionsUri(
      name: name,
      address: address,
      city: city,
      latitude: latitude,
      longitude: longitude,
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppToast.show(
        context,
        message: AppStrings.man08MapLaunchError,
        variant: AppToastVariant.error,
      );
    }
  }

  void _showDiscoveredCourtSheet(Court court, String? distanceRange) {
    final colors = context.colors;
    final typo = context.typo;
    AppBottomSheet.show<void>(
      context,
      title: court.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            distanceRange != null
                ? '${court.address} · $distanceRange'
                : court.address,
            style: typo.body,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            court.supportedSports.map((s) => s.label).join(', '),
            style: typo.captionStrong.copyWith(color: colors.accent),
          ),
          if (court.openingHours.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${AppStrings.man08OpeningHoursLabel}: ${court.openingHours}',
              style: typo.caption.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: AppStrings.man01DirectionsBtn,
            leadingIcon: Icons.directions_outlined,
            isExpanded: true,
            onPressed: () {
              Navigator.of(context).pop();
              _openExternalDirections(
                name: court.name,
                address: court.address,
                city: court.city,
                latitude: court.latitude,
                longitude: court.longitude,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: AppStrings.man01CreateSessionHereBtn,
            variant: AppButtonVariant.tonal,
            leadingIcon: Icons.add_box_outlined,
            isExpanded: true,
            onPressed: () {
              Navigator.of(context).pop();
              context.push(AppPages.man03.routePath);
            },
          ),
        ],
      ),
    );
  }

  void _showDiscoveredChurchSheet(Church church, String? distanceRange) {
    final colors = context.colors;
    final typo = context.typo;
    AppBottomSheet.show<void>(
      context,
      title: church.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${church.denomination.label} · ${church.city}',
            style: typo.captionStrong.copyWith(color: colors.accent),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            distanceRange != null
                ? '${church.address} · $distanceRange'
                : church.address,
            style: typo.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: AppStrings.man01DirectionsBtn,
            leadingIcon: Icons.directions_outlined,
            isExpanded: true,
            onPressed: () {
              Navigator.of(context).pop();
              _openExternalDirections(
                name: church.name,
                address: church.address,
                city: church.city,
                latitude: church.latitude,
                longitude: church.longitude,
              );
            },
          ),
        ],
      ),
    );
  }

  String? _distanceLabelFor(
    ({double latitude, double longitude})? refCoords,
    double? lat,
    double? lng,
    String city,
  ) {
    if (refCoords == null) return null;
    final target = (lat != null && lng != null)
        ? (latitude: lat, longitude: lng)
        : PlaceGeoHelper.cityCenterFor(city);
    final km = PlaceGeoHelper.haversineDistanceKm(
      lat1: refCoords.latitude,
      lng1: refCoords.longitude,
      lat2: target.latitude,
      lng2: target.longitude,
    );
    return PlaceGeoHelper.distanceRangeLabel(km);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playControllerProvider);
    final controller = ref.read(playControllerProvider.notifier);
    final flags = ref.watch(featureFlagsProvider);
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ??
        ref.read(navigationBadgeRepositoryProvider).currentUnreadCounts();
    final scrollController = ref
        .read(shellNavigationProvider.notifier)
        .scrollControllerForTab(widget.tabIndex);
    final colors = context.colors;
    final typo = context.typo;

    final effectiveTab =
        (!flags.church && _activeTab == _PlaySectionFilter.churches)
        ? _PlaySectionFilter.all
        : _activeTab;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text(AppStrings.man01Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.man01CreateSessionBtn,
            onPressed: () async {
              await context.push(AppPages.man03.routePath);
              await controller.loadInitial();
            },
            icon: Semantics(
              label: AppStrings.man01CreateSessionBtn,
              child: const Icon(Icons.add_box_outlined),
            ),
          ),
          IconButton(
            tooltip: AppStrings.man01FilterTooltip,
            onPressed: () => context.push(AppPages.man02.routePath),
            icon: Badge(
              isLabelVisible: state.filter.hasActiveFilters,
              label: Text('${state.filter.activeFilterCount}'),
              child: Semantics(
                label: AppStrings.man01FilterTooltip,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.man01HistoryTooltip,
            onPressed: () => context.push(AppPages.man09.routePath),
            icon: Semantics(
              label: AppStrings.man01HistoryTooltip,
              child: const Icon(Icons.history_rounded),
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
          // Kartu Lokasi & Lacak Tujuan Terpadu yang Ringkas
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: colors.chipInactive.withValues(alpha: 0.55),
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              state.usingDeviceLocation
                                  ? Icons.my_location_rounded
                                  : Icons.location_on_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  state.usingDeviceLocation
                                      ? AppStrings.man01DeviceLocationLabel
                                      : state.targetQuery.isNotEmpty
                                      ? AppStrings.man01TargetLocationLabel
                                      : AppStrings.sek01AreaLabel,
                                  style: typo.micro,
                                ),
                                Text(
                                  state.areaLabel.isNotEmpty
                                      ? state.areaLabel
                                      : state.selectedCity,
                                  style: typo.captionStrong,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: AppSizes.minTouchTarget,
                              minHeight: AppSizes.minTouchTarget,
                            ),
                            tooltip: AppStrings.man01UseMyLocationBtn,
                            icon: Icon(
                              Icons.gps_fixed_rounded,
                              color: colors.accent,
                              size: AppSizes.iconMd - 2,
                            ),
                            onPressed: () async {
                              HapticFeedback.lightImpact().ignore();
                              _destController.clear();
                              await controller.useMyDeviceLocation(context);
                            },
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showManualAreaPickerSheet(
                                context: context,
                                cities: state.availableCities,
                                selectedCity: state.selectedCity,
                              );
                              if (picked != null && picked.isNotEmpty) {
                                _destController.clear();
                                await controller.setSelectedCity(picked);
                              }
                            },
                            child: const Text(AppStrings.sek02ChangeAreaBtn),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: AppRadius.buttonRadius,
                                border: Border.all(
                                  color: colors.border.withValues(alpha: 0.6),
                                ),
                              ),
                              child: AppTextField(
                                controller: _destController,
                                hintText: AppStrings.man01DestinationHint,
                                leadingIcon: Icons.search_rounded,
                                borderless: true,
                                onSubmitted: (val) =>
                                    controller.trackDestinationLocation(val),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          AppButton(
                            label: AppStrings.man01TrackLocationBtn,
                            compact: true,
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              controller.trackDestinationLocation(
                                _destController.text,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Sub-tab pil: Semua | Sesi | Lapangan | Gereja
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _PlayFilterPill(
                        label: AppStrings.man01TabAll,
                        selected: effectiveTab == _PlaySectionFilter.all,
                        onTap: () =>
                            setState(() => _activeTab = _PlaySectionFilter.all),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _PlayFilterPill(
                        label:
                            '${AppStrings.man01TabSessions} (${state.sessions.length})',
                        selected: effectiveTab == _PlaySectionFilter.sessions,
                        onTap: () => setState(
                          () => _activeTab = _PlaySectionFilter.sessions,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _PlayFilterPill(
                        label:
                            '${AppStrings.man01TabCourts} (${state.courts.length})',
                        selected: effectiveTab == _PlaySectionFilter.courts,
                        onTap: () => setState(
                          () => _activeTab = _PlaySectionFilter.courts,
                        ),
                      ),
                      if (flags.church) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        _PlayFilterPill(
                          label:
                              '${AppStrings.man01TabChurches} (${state.churches.length})',
                          selected: effectiveTab == _PlaySectionFilter.churches,
                          onTap: () => setState(
                            () => _activeTab = _PlaySectionFilter.churches,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
              state,
              controller,
              scrollController,
              flags,
              effectiveTab,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PlayState state,
    PlayController controller,
    ScrollController scrollController,
    FeatureFlags flags,
    _PlaySectionFilter activeTab,
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

    if (state.error != null) {
      return StateView.fromError(state.error!, onRetry: controller.loadInitial);
    }

    final colors = context.colors;
    final typo = context.typo;
    final displayArea = state.areaLabel.isNotEmpty
        ? state.areaLabel
        : state.selectedCity;

    final showSessions =
        activeTab == _PlaySectionFilter.all ||
        activeTab == _PlaySectionFilter.sessions;
    final showCourts =
        activeTab == _PlaySectionFilter.all ||
        activeTab == _PlaySectionFilter.courts;
    final showChurches =
        flags.church &&
        (activeTab == _PlaySectionFilter.all ||
            activeTab == _PlaySectionFilter.churches);

    return RefreshIndicator(
      onRefresh: controller.loadInitial,
      child: ListView(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.md,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          if (state.isDiscoveringPlaces)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.chipInactive,
                  borderRadius: AppRadius.buttonRadius,
                ),
                child: Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppStrings.man01DiscoveringPlaces,
                      style: typo.caption,
                    ),
                  ],
                ),
              ),
            ),

          if (showSessions) ...<Widget>[
            if (state.sessions.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.chipInactive.withValues(alpha: 0.45),
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppStrings.man01EmptyMessage, style: typo.bodyStrong),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: AppStrings.man01CreateSessionBtn,
                      compact: true,
                      leadingIcon: Icons.add_box_outlined,
                      onPressed: () => context.push(AppPages.man03.routePath),
                    ),
                  ],
                ),
              )
            else
              for (final session in state.sessions)
                SessionSummaryCard(
                  session: session,
                  onTap: () async {
                    await context.push(
                      '${AppPages.man04.routePath}?id=${session.id}',
                    );
                    await controller.loadInitial();
                  },
                ),
          ],

          // Daftar Lapangan di Sekitar / Lokasi Tujuan
          if (showCourts) ...<Widget>[
            if (showSessions) const SizedBox(height: AppSpacing.sm),
            SectionHeader(
              title: '${AppStrings.man01PopularCourtsSection} ($displayArea)',
              actionLabel: AppStrings.man01AllCourtsAction,
              onActionTap: () => context.push(AppPages.man07.routePath),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.courts.isEmpty)
              Text(
                AppStrings.man01EmptyCourtsInArea,
                style: typo.caption.copyWith(color: colors.textMuted),
              )
            else
              for (final court in state.courts.take(8))
                Builder(
                  builder: (ctx) {
                    final distRange = _distanceLabelFor(
                      state.refCoords,
                      court.latitude,
                      court.longitude,
                      court.city,
                    );
                    final isOsm = court.id.startsWith('osm-');
                    return _PlaceDiscoveryCard(
                      icon: Icons.sports_tennis_rounded,
                      iconBg: colors.primary.withValues(alpha: 0.12),
                      iconColor: colors.accent,
                      title: court.name,
                      address: court.address,
                      distanceRange: distRange,
                      badgeText: isOsm
                          ? AppStrings.man01SourceMapBadge
                          : '${AppStrings.man08EstimatedPricePrefix}: ${court.estimatedPriceText}',
                      onDirectionsTap: () => _openExternalDirections(
                        name: court.name,
                        address: court.address,
                        city: court.city,
                        latitude: court.latitude,
                        longitude: court.longitude,
                      ),
                      onTap: () {
                        if (isOsm) {
                          _showDiscoveredCourtSheet(court, distRange);
                        } else {
                          context.push(
                            '${AppPages.man08.routePath}?courtId=${court.id}',
                          );
                        }
                      },
                    );
                  },
                ),
          ],

          // Daftar Gereja di Sekitar / Lokasi Tujuan (Fase 2 flag guard)
          if (showChurches) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SectionHeader(
              title: '${AppStrings.man01ChurchesSection} ($displayArea)',
              actionLabel: AppStrings.man01AllChurchesAction,
              onActionTap: () => context.push(AppPages.sek10.routePath),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.churches.isEmpty)
              Text(
                AppStrings.man01EmptyChurchesInArea,
                style: typo.caption.copyWith(color: colors.textMuted),
              )
            else
              for (final church in state.churches.take(8))
                Builder(
                  builder: (ctx) {
                    final distRange = _distanceLabelFor(
                      state.refCoords,
                      church.latitude,
                      church.longitude,
                      church.city,
                    );
                    final isOsm = church.id.startsWith('osm-');
                    return _PlaceDiscoveryCard(
                      icon: Icons.church_outlined,
                      iconBg: colors.ratingGold.withValues(alpha: 0.16),
                      iconColor: colors.ratingGold,
                      title: church.name,
                      address: church.address,
                      distanceRange: distRange,
                      badgeText: isOsm
                          ? '${church.denomination.label} · ${AppStrings.man01SourceMapBadge}'
                          : '${church.denomination.label} · ${church.city}',
                      onDirectionsTap: () => _openExternalDirections(
                        name: church.name,
                        address: church.address,
                        city: church.city,
                        latitude: church.latitude,
                        longitude: church.longitude,
                      ),
                      onTap: () {
                        if (isOsm) {
                          _showDiscoveredChurchSheet(church, distRange);
                        } else {
                          context.push(
                            '${AppPages.sek11.routePath}?id=${church.id}',
                          );
                        }
                      },
                    );
                  },
                ),
          ],
        ],
      ),
    );
  }
}

class _PlayFilterPill extends StatelessWidget {
  const _PlayFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.text : colors.chipInactive,
            borderRadius: AppRadius.pillRadius,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: typo.micro.copyWith(
              color: selected ? colors.surface : colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceDiscoveryCard extends StatelessWidget {
  const _PlaceDiscoveryCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.address,
    required this.badgeText,
    required this.onDirectionsTap,
    required this.onTap,
    this.distanceRange,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String address;
  final String? distanceRange;
  final String badgeText;
  final VoidCallback onDirectionsTap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: AppRadius.buttonRadius,
                  ),
                  child: Icon(icon, color: iconColor, size: AppSizes.iconMd),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              style: typo.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (distanceRange != null) ...<Widget>[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.chipInactive,
                                borderRadius: AppRadius.pillRadius,
                              ),
                              child: Text(
                                distanceRange!,
                                style: typo.micro.copyWith(color: colors.text),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: typo.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        badgeText,
                        style: typo.micro.copyWith(color: colors.accent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.minTouchTarget,
                    minHeight: AppSizes.minTouchTarget,
                  ),
                  tooltip: AppStrings.man01DirectionsBtn,
                  onPressed: onDirectionsTap,
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_rounded,
                      color: colors.accent,
                      size: AppSizes.iconSm + 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu ringkas Sesi Main bergaya modern dengan progress bar kuota untuk `MAN-01` dan `MAN-09`.
class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({
    required this.session,
    required this.onTap,
    super.key,
  });

  final PlaySession session;
  final VoidCallback onTap;

  IconData _sportIcon(SportType sport) {
    return switch (sport) {
      SportType.badminton => Icons.sports_tennis_rounded,
      SportType.futsal => Icons.sports_soccer_rounded,
      SportType.basketball => Icons.sports_basketball_rounded,
      SportType.volleyball => Icons.sports_volleyball_rounded,
      SportType.tableTennis => Icons.sports_tennis_outlined,
      SportType.jogging => Icons.directions_run_rounded,
      SportType.other => Icons.sports_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final feeText = PlayFormatters.formatRupiah(
      session.feePerPersonRupiah,
      freeLabel: AppStrings.man01FreeFeeLabel,
    );
    final isFree = session.feePerPersonRupiah <= 0;
    final ratio = session.maxSlots > 0
        ? (session.participantCount / session.maxSlots).clamp(0.0, 1.0)
        : 0.0;
    final slotsLeft = session.maxSlots - session.participantCount;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadius.pillRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _sportIcon(session.sportType),
                            size: 14,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            session.sportType.label,
                            style: typo.micro.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.chipInactive,
                        borderRadius: AppRadius.pillRadius,
                      ),
                      child: Text(
                        session.skillLevel.label,
                        style: typo.micro.copyWith(color: colors.text),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isFree
                            ? colors.success.withValues(alpha: 0.14)
                            : colors.chipInactive,
                        borderRadius: AppRadius.pillRadius,
                      ),
                      child: Text(
                        feeText,
                        style: typo.captionStrong.copyWith(
                          color: isFree ? colors.success : colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                Text(session.title, style: typo.h3),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${PlayFormatters.formatTimeWindow(session.startTime, session.endTime)} · ${session.visibleVenueText}',
                        style: typo.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.pillRadius,
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: colors.chipInactive,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      slotsLeft <= 0 ? colors.danger : colors.buttonPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${AppStrings.man01ParticipantsRatio(session.participantCount, session.maxSlots)} · ${AppStrings.man01SlotsRemaining(slotsLeft)}',
                        style: typo.micro.copyWith(color: colors.textMuted),
                      ),
                    ),
                    if (session.status == SessionStatus.cancelled)
                      Text(
                        AppStrings.man04StatusCancelledBadge,
                        style: typo.micro.copyWith(color: colors.danger),
                      )
                    else if (session.status == SessionStatus.completed)
                      Text(
                        AppStrings.man04StatusCompletedBadge,
                        style: typo.micro,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: session.isJoinedByMe
                              ? colors.chipInactive
                              : colors.buttonPrimary,
                          borderRadius: AppRadius.pillRadius,
                        ),
                        child: Text(
                          session.isJoinedByMe
                              ? AppStrings.man09TabJoined
                              : AppStrings.man04JoinBtn,
                          style: typo.micro.copyWith(
                            color: session.isJoinedByMe
                                ? colors.text
                                : colors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
