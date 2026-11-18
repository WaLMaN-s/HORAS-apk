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
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-10 Daftar Gereja (SEK-R13).
///
/// - Filter denominasi (HKBP, GKPI, HKI, GKPS, GBKP, lainnya) & urutan Terdekat.
/// - Sakelar Daftar / Peta gereja dengan penanda interaktif.
/// - Jadwal ibadah, kontak, kegiatan.
/// - Jumlah jemaat di HORAS hanya tampil bila minimal 5 orang (SEK-R13).
/// - Lencana Terverifikasi vs Belum diverifikasi.
/// - Formulir usulkan gereja dengan pemilih titik di peta.
/// - Memiliki status memuat, kosong, offline, error.
class Sek10ChurchListPage extends ConsumerStatefulWidget {
  const Sek10ChurchListPage({super.key});

  @override
  ConsumerState<Sek10ChurchListPage> createState() =>
      _Sek10ChurchListPageState();
}

class _Sek10ChurchListPageState extends ConsumerState<Sek10ChurchListPage> {
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();
  ChurchDenomination? _selectedDenomination;
  bool _isLoading = true;
  bool _showMap = false;
  bool _sortByNearest = false;
  ({double latitude, double longitude})? _refCoords;
  AppError? _error;
  List<Church> _churches = const <Church>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final churchRepo = ref.read(churchRepositoryProvider);
    final res = await churchRepo.getChurches(
      denomination: _selectedDenomination,
      query: _searchController.text.trim(),
    );

    if (!mounted) return;
    if (res is Err<List<Church>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }

    var list = (res as Ok<List<Church>>).value;
    if (_sortByNearest && _refCoords != null) {
      list = PlaceGeoHelper.sortByNearest<Church>(
        list,
        refLat: _refCoords!.latitude,
        refLng: _refCoords!.longitude,
        getLatitude: (c) => c.latitude,
        getLongitude: (c) => c.longitude,
        getCity: (c) => c.city,
      );
    }

    setState(() {
      _churches = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleSortByNearest() async {
    if (_sortByNearest) {
      setState(() => _sortByNearest = false);
      await _load();
      return;
    }
    final resolved = await PlaceGeoHelper.resolveDeviceOrCityCoordinates(
      context,
      fallbackCity: 'Medan',
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
      _churches = PlaceGeoHelper.sortByNearest<Church>(
        _churches,
        refLat: resolved.latitude,
        refLng: resolved.longitude,
        getLatitude: (c) => c.latitude,
        getLongitude: (c) => c.longitude,
        getCity: (c) => c.city,
      );
    });
  }

  Future<void> _centerOnMyLocation() async {
    final resolved = await PlaceGeoHelper.resolveDeviceOrCityCoordinates(
      context,
      fallbackCity: 'Medan',
    );
    if (!mounted) return;
    setState(() {
      _refCoords = (latitude: resolved.latitude, longitude: resolved.longitude);
    });
    _mapController.move(LatLng(resolved.latitude, resolved.longitude), 13.5);
  }

  LatLng _pointForChurch(Church church) {
    if (church.latitude != null && church.longitude != null) {
      return LatLng(church.latitude!, church.longitude!);
    }
    final fallback = PlaceGeoHelper.cityCenterFor(church.city);
    return LatLng(fallback.latitude, fallback.longitude);
  }

  void _showProposeChurchSheet() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Medan');
    final phoneCtrl = TextEditingController();
    ChurchDenomination denom = ChurchDenomination.hkbp;
    LatLng? selectedPoint;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final modalColors = sheetContext.colors;
            final modalTypo = sheetContext.typo;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom:
                      MediaQuery.of(sheetContext).viewInsets.bottom +
                      AppSpacing.lg,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppStrings.sek10ProposeChurchTitle,
                        style: modalTypo.h3,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: nameCtrl,
                        label: AppStrings.sek10ChurchNameLabel,
                        hintText: AppStrings.sek10ChurchNameHint,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<ChurchDenomination>(
                        initialValue: denom,
                        decoration: const InputDecoration(
                          labelText: AppStrings.sek10DenominationLabel,
                          border: OutlineInputBorder(),
                        ),
                        items: ChurchDenomination.values.map((d) {
                          return DropdownMenuItem<ChurchDenomination>(
                            value: d,
                            child: Text(d.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => denom = val);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: addrCtrl,
                        label: AppStrings.sek10ChurchAddressLabel,
                        hintText: AppStrings.sek10ChurchAddressHint,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: cityCtrl,
                        label: AppStrings.sek10ChurchCityLabel,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: selectedPoint == null
                            ? AppStrings.mapPickLocationBtn
                            : AppStrings.mapChangeLocationBtn,
                        variant: AppButtonVariant.secondary,
                        leadingIcon: Icons.add_location_alt_outlined,
                        isExpanded: true,
                        onPressed: () async {
                          final picked = await PlaceLocationPickerPage.show(
                            sheetContext,
                            initialLatitude: selectedPoint?.latitude,
                            initialLongitude: selectedPoint?.longitude,
                            fallbackCity: cityCtrl.text.trim(),
                          );
                          if (picked != null && sheetContext.mounted) {
                            setModalState(() => selectedPoint = picked);
                          }
                        },
                      ),
                      if (selectedPoint != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${AppStrings.mapSelectedCoordinatesPrefix}: '
                          '${selectedPoint!.latitude.toStringAsFixed(5)}, '
                          '${selectedPoint!.longitude.toStringAsFixed(5)}',
                          style: modalTypo.caption.copyWith(
                            color: modalColors.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: phoneCtrl,
                        label: AppStrings.sek10ChurchPhoneLabel,
                        hintText: AppStrings.sek10ChurchPhoneHint,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: AppStrings.sek10SubmitProposeBtn,
                        variant: AppButtonVariant.primary,
                        isExpanded: true,
                        isLoading: isSubmitting,
                        onPressed: () async {
                          final cleanName = nameCtrl.text.trim();
                          final cleanAddr = addrCtrl.text.trim();
                          final cleanCity = cityCtrl.text.trim();
                          if (cleanName.isEmpty ||
                              cleanAddr.isEmpty ||
                              cleanCity.isEmpty) {
                            AppToast.show(
                              sheetContext,
                              message: AppStrings.sek10ProposeValidationError,
                              variant: AppToastVariant.error,
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          final res = await ref
                              .read(churchRepositoryProvider)
                              .proposeChurch(
                                name: cleanName,
                                denomination: denom,
                                address: cleanAddr,
                                city: cleanCity,
                                contactPhone: phoneCtrl.text.trim(),
                                latitude: selectedPoint?.latitude,
                                longitude: selectedPoint?.longitude,
                                serviceSchedules: const <ChurchServiceSchedule>[
                                  ChurchServiceSchedule(
                                    dayOfWeek: 'Minggu',
                                    time: '09.00 WIB',
                                    language: 'Bahasa Indonesia',
                                  ),
                                ],
                              );

                          if (!sheetContext.mounted) return;
                          setModalState(() => isSubmitting = false);

                          if (res is Ok<Church>) {
                            sheetContext.pop();
                            if (mounted) {
                              AppToast.show(
                                context,
                                message: AppStrings.sek10ProposedToast,
                                variant: AppToastVariant.success,
                              );
                              await _load();
                            }
                          } else if (res is Err<Church>) {
                            AppToast.show(
                              sheetContext,
                              message: res.failure.message,
                              variant: AppToastVariant.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    if (!flags.church) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sek10Title)),
        body: StateView.contentUnavailable(
          onBack: () => context.go(AppPages.sekitarPath),
        ),
      );
    }

    Widget content;
    if (_isLoading) {
      content = const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    } else if (_error != null) {
      content = StateView.fromError(_error!, onRetry: _load);
    } else if (_churches.isEmpty) {
      content = StateView.empty(
        message: AppStrings.sek10EmptyChurches,
        actionLabel: AppStrings.sek10ProposeChurchBtn,
        onAction: _showProposeChurchSheet,
      );
    } else if (_showMap) {
      final firstPoint = _pointForChurch(_churches.first);

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
                    initialZoom: 12.5,
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'id.horas.app',
                    ),
                    MarkerLayer(
                      markers: _churches.map((c) {
                        final point = _pointForChurch(c);
                        return Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          child: Semantics(
                            label: c.name,
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                context.push(
                                  '${AppPages.sek11.routePath}?id=${c.id}',
                                );
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
                                  Icons.church_outlined,
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
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _churches.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, idx) {
            final church = _churches[idx];
            String? distanceRange;
            if (_refCoords != null) {
              final pt = _pointForChurch(church);
              final distKm = PlaceGeoHelper.haversineDistanceKm(
                lat1: _refCoords!.latitude,
                lng1: _refCoords!.longitude,
                lat2: pt.latitude,
                lng2: pt.longitude,
              );
              distanceRange = PlaceGeoHelper.distanceRangeLabel(distKm);
            }

            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () =>
                  context.push('${AppPages.sek11.routePath}?id=${church.id}'),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                  boxShadow: AppShadows.softCard(colors.shadow),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.chipInactive,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.church_outlined,
                        color: colors.primary,
                        size: AppSizes.iconMd,
                      ),
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
                                  church.name,
                                  style: typo.bodyStrong,
                                ),
                              ),
                              if (church.isVerified)
                                Icon(
                                  Icons.verified,
                                  color: colors.primary,
                                  size: AppSizes.iconSm,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            distanceRange != null
                                ? '${church.denomination.label} · ${church.city} · $distanceRange'
                                : '${church.denomination.label} · ${church.city}',
                            style: typo.caption.copyWith(color: colors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            church.address,
                            style: typo.micro.copyWith(color: colors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // SEK-R13: Jumlah jemaat hanya tampil bila minimal 5 orang
                          if (church.canDisplayMemberCount)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.chipInactive,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                AppStrings.sek10MemberCountFormat(
                                  church.memberCount,
                                ),
                                style: typo.micro.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sek10Title),
        actions: <Widget>[
          IconButton(
            tooltip: _showMap
                ? AppStrings.sek10ViewList
                : AppStrings.sek10ViewMap,
            icon: Icon(_showMap ? Icons.view_list_rounded : Icons.map_outlined),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            tooltip: AppStrings.sek10ProposeChurchBtn,
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: _showProposeChurchSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Bilah Pencarian
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: AppTextField(
                controller: _searchController,
                hintText: AppStrings.sek10SearchHint,
                leadingIcon: Icons.search,
                onSubmitted: (_) => _load(),
              ),
            ),
            // Chip Filter Denominasi & Urutan Terdekat
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  FilterChip(
                    label: const Text(AppStrings.mapSortNearest),
                    selected: _sortByNearest,
                    onSelected: (_) => _toggleSortByNearest(),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilterChip(
                    label: const Text(AppStrings.sek10DenominationAll),
                    selected: _selectedDenomination == null,
                    onSelected: (selected) {
                      setState(() => _selectedDenomination = null);
                      _load();
                    },
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ...ChurchDenomination.values.map((d) {
                    final isSel = _selectedDenomination == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChip(
                        label: Text(d.label),
                        selected: isSel,
                        onSelected: (selected) {
                          setState(() {
                            _selectedDenomination = selected ? d : null;
                          });
                          _load();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
