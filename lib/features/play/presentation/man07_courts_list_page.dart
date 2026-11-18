import 'package:flutter_map/flutter_map.dart';
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
import 'package:horas/core/utils/place_geo_helper.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/play/presentation/play_controller.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// MAN-07 Daftar Lapangan (`MAN-R10`).
///
/// Tampilan peta lapangan menggunakan flutter_map (OpenStreetMap) saat `FeatureFlags.courtMap == true`.
class Man07CourtsListPage extends ConsumerStatefulWidget {
  const Man07CourtsListPage({super.key});

  @override
  ConsumerState<Man07CourtsListPage> createState() =>
      _Man07CourtsListPageState();
}

class _Man07CourtsListPageState extends ConsumerState<Man07CourtsListPage> {
  final MapController _mapController = MapController();
  SportType? _selectedSport;
  List<Court> _courts = const <Court>[];
  bool _isLoading = true;
  bool _showMap = false;
  bool _sortByNearest = false;
  ({double latitude, double longitude})? _refCoords;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
    var list = (res as Ok<List<Court>>).value;
    if (_sortByNearest && _refCoords != null) {
      list = PlaceGeoHelper.sortByNearest<Court>(
        list,
        refLat: _refCoords!.latitude,
        refLng: _refCoords!.longitude,
        getLatitude: (c) => c.latitude,
        getLongitude: (c) => c.longitude,
        getCity: (c) => c.city,
      );
    }
    setState(() {
      _courts = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleSortByNearest() async {
    if (_sortByNearest) {
      setState(() => _sortByNearest = false);
      await _load();
      return;
    }
    final city = ref.read(playControllerProvider).selectedCity;
    final resolved = await PlaceGeoHelper.resolveDeviceOrCityCoordinates(
      context,
      fallbackCity: city,
    );
    if (!mounted) return;
    if (!resolved.usedDeviceLocation) {
      AppToast.show(
        context,
        message: AppStrings.mapLocationUseCityFallbackToast,
      );
    }
    setState(() {
      _refCoords = (latitude: resolved.latitude, longitude: resolved.longitude);
      _sortByNearest = true;
      _courts = PlaceGeoHelper.sortByNearest<Court>(
        _courts,
        refLat: resolved.latitude,
        refLng: resolved.longitude,
        getLatitude: (c) => c.latitude,
        getLongitude: (c) => c.longitude,
        getCity: (c) => c.city,
      );
    });
  }

  Future<void> _centerOnMyLocation() async {
    final city = ref.read(playControllerProvider).selectedCity;
    final resolved = await PlaceGeoHelper.resolveDeviceOrCityCoordinates(
      context,
      fallbackCity: city,
    );
    if (!mounted) return;
    setState(() {
      _refCoords = (latitude: resolved.latitude, longitude: resolved.longitude);
    });
    _mapController.move(LatLng(resolved.latitude, resolved.longitude), 13.5);
  }

  LatLng _pointForCourt(Court court) {
    if (court.latitude != null && court.longitude != null) {
      return LatLng(court.latitude!, court.longitude!);
    }
    final fallback = PlaceGeoHelper.cityCenterFor(court.city);
    return LatLng(fallback.latitude, fallback.longitude);
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
    } else if (flags.courtMap && _showMap) {
      final firstPoint = _pointForCourt(_courts.first);

      content = Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            color: colors.confidenceAmberSurface,
            child: Text(
              AppStrings.man07MapDisclaimer,
              style: typo.micro.copyWith(color: colors.confidenceAmber),
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: firstPoint,
                    initialZoom: 13.0,
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'id.horas.app',
                    ),
                    MarkerLayer(
                      markers: _courts.map((c) {
                        final point = _pointForCourt(c);
                        return Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          child: Semantics(
                            label: c.name,
                            button: true,
                            child: GestureDetector(
                              onTap: () async {
                                await context.push(
                                  '${AppPages.man08.routePath}?courtId=${c.id}',
                                );
                                await _load();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.onPrimary,
                                    width: 2,
                                  ),
                                  boxShadow: AppShadows.softCard(colors.shadow),
                                ),
                                child: Icon(
                                  Icons.sports_tennis,
                                  color: colors.onPrimary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const Positioned(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: OsmAttributionBadge(),
                ),
                Positioned(
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Material(
                    color: colors.surface,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      tooltip: AppStrings.mapMyLocationTooltip,
                      icon: Icon(
                        Icons.my_location_outlined,
                        color: colors.primary,
                      ),
                      onPressed: _centerOnMyLocation,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  AppChip(
                    label: AppStrings.mapSortNearest,
                    isSelected: _sortByNearest,
                    onTap: _toggleSortByNearest,
                  ),
                  const SizedBox(width: AppSpacing.sm),
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

            ..._courts.map((court) {
              String? distanceRange;
              if (_refCoords != null) {
                final pt = _pointForCourt(court);
                final distKm = PlaceGeoHelper.haversineDistanceKm(
                  lat1: _refCoords!.latitude,
                  lng1: _refCoords!.longitude,
                  lat2: pt.latitude,
                  lng2: pt.longitude,
                );
                distanceRange = PlaceGeoHelper.distanceRangeLabel(distKm);
              }

              return Padding(
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
                                  distanceRange != null
                                      ? '${court.address} · $distanceRange'
                                      : court.address,
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
              );
            }),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.man07Title),
        actions: <Widget>[
          if (flags.courtMap)
            IconButton(
              tooltip: _showMap
                  ? AppStrings.man07ViewList
                  : AppStrings.man07ViewMap,
              icon: Icon(
                _showMap ? Icons.view_list_rounded : Icons.map_outlined,
              ),
              onPressed: () => setState(() => _showMap = !_showMap),
            ),
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
