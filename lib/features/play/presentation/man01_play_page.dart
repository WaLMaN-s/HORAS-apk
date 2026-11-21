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

/// MAN-01 Main (Utama): daftar sesi di sekitar, pelacakan area tujuan
/// (mis. Cilandak), serta lapangan & gereja terdekat (`MAN-R1` .. `MAN-R10`).
class Man01PlayPage extends ConsumerStatefulWidget {
  const Man01PlayPage({super.key, this.tabIndex = 3});

  final int tabIndex;

  @override
  ConsumerState<Man01PlayPage> createState() => _Man01PlayPageState();
}

class _Man01PlayPageState extends ConsumerState<Man01PlayPage> {
  final TextEditingController _destController = TextEditingController();

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
            style: typo.caption.copyWith(color: colors.primary),
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
            variant: AppButtonVariant.secondary,
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
            style: typo.captionStrong.copyWith(color: colors.primary),
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

    return Scaffold(
      appBar: AppBar(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.sm,
              AppSpacing.screenMargin,
              AppSpacing.xs,
            ),
            child: Column(
              children: <Widget>[
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
                        state.usingDeviceLocation
                            ? Icons.my_location_rounded
                            : Icons.location_on_outlined,
                        color: colors.primary,
                        size: AppSizes.iconMd,
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
                              style: typo.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: AppStrings.man01UseMyLocationBtn,
                        icon: Icon(
                          Icons.gps_fixed_rounded,
                          color: colors.primary,
                          size: AppSizes.iconMd,
                        ),
                        onPressed: () async {
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
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _destController,
                        hintText: AppStrings.man01DestinationHint,
                        leadingIcon: Icons.search_rounded,
                        onSubmitted: (val) =>
                            controller.trackDestinationLocation(val),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        controller.trackDestinationLocation(
                          _destController.text,
                        );
                      },
                      child: const Text(AppStrings.man01TrackLocationBtn),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(
              context,
              state,
              controller,
              scrollController,
              flags,
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

    return RefreshIndicator(
      onRefresh: controller.loadInitial,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.sm,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          if (state.isDiscoveringPlaces)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(AppStrings.man01DiscoveringPlaces, style: typo.caption),
                ],
              ),
            ),

          if (state.sessions.isEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppStrings.man01EmptyMessage, style: typo.bodyStrong),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: AppStrings.man01CreateSessionBtn,
                      leadingIcon: Icons.add_box_outlined,
                      onPressed: () => context.push(AppPages.man03.routePath),
                    ),
                  ],
                ),
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

          // Daftar Lapangan di Sekitar / Lokasi Tujuan
          const SizedBox(height: AppSpacing.md),
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
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: Icon(
                        Icons.sports_tennis_outlined,
                        color: colors.primary,
                      ),
                      title: Text(court.name, style: typo.bodyStrong),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            distRange != null
                                ? '${court.address} · $distRange'
                                : court.address,
                            style: typo.caption,
                          ),
                          Text(
                            isOsm
                                ? AppStrings.man01SourceMapBadge
                                : '${AppStrings.man08EstimatedPricePrefix}: ${court.estimatedPriceText}',
                            style: typo.micro.copyWith(color: colors.primary),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        tooltip: AppStrings.man01DirectionsBtn,
                        icon: Icon(
                          Icons.directions_outlined,
                          color: colors.primary,
                        ),
                        onPressed: () => _openExternalDirections(
                          name: court.name,
                          address: court.address,
                          city: court.city,
                          latitude: court.latitude,
                          longitude: court.longitude,
                        ),
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
                    ),
                  );
                },
              ),

          // Daftar Gereja di Sekitar / Lokasi Tujuan (Fase 2 flag guard)
          if (flags.church) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Icon(
                          Icons.church_outlined,
                          color: colors.primary,
                        ),
                        title: Text(church.name, style: typo.bodyStrong),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              distRange != null
                                  ? '${church.address} · $distRange'
                                  : church.address,
                              style: typo.caption,
                            ),
                            Text(
                              isOsm
                                  ? '${church.denomination.label} · ${AppStrings.man01SourceMapBadge}'
                                  : '${church.denomination.label} · ${church.city}',
                              style: typo.micro.copyWith(color: colors.primary),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: AppStrings.man01DirectionsBtn,
                          icon: Icon(
                            Icons.directions_outlined,
                            color: colors.primary,
                          ),
                          onPressed: () => _openExternalDirections(
                            name: church.name,
                            address: church.address,
                            city: church.city,
                            latitude: church.latitude,
                            longitude: church.longitude,
                          ),
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
                      ),
                    );
                  },
                ),
          ],
        ],
      ),
    );
  }
}

/// Kartu ringkas Sesi Main untuk `MAN-01` dan `MAN-09`.
class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({
    required this.session,
    required this.onTap,
    super.key,
  });

  final PlaySession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final feeText = PlayFormatters.formatRupiah(
      session.feePerPersonRupiah,
      freeLabel: AppStrings.man01FreeFeeLabel,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppChip(
                    label: session.sportType.label,
                    isSelected: true,
                    customBackgroundColor: colors.primary.withValues(
                      alpha: 0.12,
                    ),
                    customForegroundColor: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(session.skillLevel.label, style: typo.captionStrong),
                  const Spacer(),
                  Text(
                    feeText,
                    style: typo.bodyStrong.copyWith(color: colors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(session.title, style: typo.h3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${PlayFormatters.formatTimeWindow(session.startTime, session.endTime)} · ${session.visibleVenueText}',
                style: typo.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppStrings.man01ParticipantsRatio(
                        session.participantCount,
                        session.maxSlots,
                      ),
                      style: typo.captionStrong,
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
                    Text(
                      session.isJoinedByMe
                          ? AppStrings.man09TabJoined
                          : AppStrings.man04JoinBtn,
                      style: typo.bodyStrong.copyWith(color: colors.primary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
