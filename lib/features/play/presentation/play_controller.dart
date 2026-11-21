import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/utils/place_discovery_service.dart';
import 'package:horas/core/utils/place_geo_helper.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/play/presentation/play_models.dart';
import 'package:material_ui/material_ui.dart';

/// State utama modul Main Bareng (`MAN-01`, `MAN-02`, `MAN-07`, `SEK-10`).
final class PlayState {
  const PlayState({
    this.selectedCity = 'Medan',
    this.areaLabel = 'Medan',
    this.targetQuery = '',
    this.refCoords,
    this.usingDeviceLocation = false,
    this.hasExplicitTarget = false,
    this.availableCities = const <WilayahCity>[],
    this.filter = const PlaySessionFilter(),
    this.sessions = const <PlaySession>[],
    this.courts = const <Court>[],
    this.churches = const <Church>[],
    this.isLoading = false,
    this.isDiscoveringPlaces = false,
    this.locationPermissionDenied = false,
    this.error,
  });

  final String selectedCity;
  final String areaLabel;
  final String targetQuery;
  final ({double latitude, double longitude})? refCoords;
  final bool usingDeviceLocation;
  final bool hasExplicitTarget;
  final List<WilayahCity> availableCities;
  final PlaySessionFilter filter;
  final List<PlaySession> sessions;
  final List<Court> courts;
  final List<Church> churches;
  final bool isLoading;
  final bool isDiscoveringPlaces;
  final bool locationPermissionDenied;
  final AppError? error;

  PlayState copyWith({
    String? selectedCity,
    String? areaLabel,
    String? targetQuery,
    ({double latitude, double longitude})? refCoords,
    bool clearRefCoords = false,
    bool? usingDeviceLocation,
    bool? hasExplicitTarget,
    List<WilayahCity>? availableCities,
    PlaySessionFilter? filter,
    List<PlaySession>? sessions,
    List<Court>? courts,
    List<Church>? churches,
    bool? isLoading,
    bool? isDiscoveringPlaces,
    bool? locationPermissionDenied,
    AppError? error,
    bool clearError = false,
  }) {
    return PlayState(
      selectedCity: selectedCity ?? this.selectedCity,
      areaLabel: areaLabel ?? this.areaLabel,
      targetQuery: targetQuery ?? this.targetQuery,
      refCoords: clearRefCoords ? null : (refCoords ?? this.refCoords),
      usingDeviceLocation: usingDeviceLocation ?? this.usingDeviceLocation,
      hasExplicitTarget: hasExplicitTarget ?? this.hasExplicitTarget,
      availableCities: availableCities ?? this.availableCities,
      filter: filter ?? this.filter,
      sessions: sessions ?? this.sessions,
      courts: courts ?? this.courts,
      churches: churches ?? this.churches,
      isLoading: isLoading ?? this.isLoading,
      isDiscoveringPlaces: isDiscoveringPlaces ?? this.isDiscoveringPlaces,
      locationPermissionDenied:
          locationPermissionDenied ?? this.locationPermissionDenied,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller Riverpod untuk modul Main (`MAN-01`, `MAN-02`, `MAN-07`).
class PlayController extends Notifier<PlayState> {
  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  bool _triedAutoDeviceLocation = false;

  @override
  PlayState build() {
    ref.watch(authSessionEpochProvider);
    _triedAutoDeviceLocation = false;
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    final initialCity = nearbyRepo.currentSelectedCity;
    Future<void>.microtask(loadInitial);
    return PlayState(
      selectedCity: initialCity,
      areaLabel: initialCity,
      locationPermissionDenied: nearbyRepo.locationPermissionDenied,
    );
  }

  Future<void> loadInitial() async {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final courtRepo = ref.read(courtRepositoryProvider);
    final churchRepo = ref.read(churchRepositoryProvider);
    final now = ref.read(authRepositoryProvider).currentTime;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedCity: state.hasExplicitTarget
          ? state.selectedCity
          : nearbyRepo.currentSelectedCity,
      locationPermissionDenied: nearbyRepo.locationPermissionDenied,
    );

    if (nearbyRepo.locationPermissionDenied) {
      final citiesRes = await nearbyRepo.getAvailableCities();
      state = state.copyWith(
        isLoading: false,
        availableCities: citiesRes is Ok<List<WilayahCity>>
            ? citiesRes.value
            : state.availableCities,
        locationPermissionDenied: true,
      );
      return;
    }

    final citiesRes = await nearbyRepo.getAvailableCities();
    final cities = citiesRes is Ok<List<WilayahCity>>
        ? citiesRes.value
        : state.availableCities;

    // Pada aplikasi nyata (bukan unit test), otomatis pakai lokasi perkiraan perangkat bila izin sudah aktif
    var effectiveCity = state.selectedCity;
    var effectiveAreaLabel = state.areaLabel.isEmpty
        ? effectiveCity
        : state.areaLabel;
    var effectiveCoords = state.refCoords;
    var usingDevice = state.usingDeviceLocation;

    if (!_isFlutterTest &&
        !_triedAutoDeviceLocation &&
        !state.hasExplicitTarget) {
      _triedAutoDeviceLocation = true;
      final deviceLoc = await PlaceGeoHelper.tryReadGrantedDeviceLocation();
      if (deviceLoc != null) {
        final rev = await PlaceDiscoveryService.reverseGeocodeArea(
          latitude: deviceLoc.latitude,
          longitude: deviceLoc.longitude,
          availableCities: cities,
        );
        effectiveCity = rev.matchedCity;
        effectiveAreaLabel = rev.areaLabel;
        effectiveCoords = (
          latitude: deviceLoc.latitude,
          longitude: deviceLoc.longitude,
        );
        usingDevice = true;
        nearbyRepo.setCurrentSelectedCity(effectiveCity);
      }
    }

    if (effectiveCoords == null) {
      final fallback = PlaceGeoHelper.cityCenterFor(effectiveCity);
      effectiveCoords = (
        latitude: fallback.latitude,
        longitude: fallback.longitude,
      );
    }

    final sessionsFuture = sessionRepo.getSessions(
      city: effectiveCity.isEmpty ? null : effectiveCity,
      sportType: state.filter.sportType,
      skillLevel: state.filter.skillLevel,
    );
    // Ambil semua lapangan & gereja dari DB agar yang berdekatan lintas kecamatan/kota juga terjaring,
    // lalu gabungkan dan urutkan dari terdekat ke `effectiveCoords`.
    final allCourtsFuture = courtRepo.getCourts(
      sportType: state.filter.sportType,
    );
    final allChurchesFuture = churchRepo.getChurches();

    final sessionsRes = await sessionsFuture;
    final allCourtsRes = await allCourtsFuture;
    final allChurchesRes = await allChurchesFuture;

    if (sessionsRes is Err<List<PlaySession>>) {
      state = state.copyWith(
        isLoading: false,
        availableCities: cities,
        selectedCity: effectiveCity,
        areaLabel: effectiveAreaLabel,
        refCoords: effectiveCoords,
        usingDeviceLocation: usingDevice,
        error: sessionsRes.failure,
      );
      return;
    }

    final rawSessions = (sessionsRes as Ok<List<PlaySession>>).value;
    final filteredSessions = rawSessions
        .where((s) => _matchesClientFilters(s, state.filter, now))
        .toList(growable: false);

    final dbCourts = allCourtsRes is Ok<List<Court>>
        ? allCourtsRes.value
        : const <Court>[];
    final dbChurches = allChurchesRes is Ok<List<Church>>
        ? allChurchesRes.value
        : const <Church>[];

    final initialCourts = _mergeAndFilterCourts(
      dbCourts: dbCourts,
      osmCourts: const <Court>[],
      city: effectiveCity,
      coords: effectiveCoords,
      sportFilter: state.filter.sportType,
    );
    final initialChurches = _mergeAndFilterChurches(
      dbChurches: dbChurches,
      osmChurches: const <Church>[],
      city: effectiveCity,
      coords: effectiveCoords,
    );

    state = state.copyWith(
      isLoading: false,
      isDiscoveringPlaces: !_isFlutterTest,
      availableCities: cities,
      selectedCity: effectiveCity,
      areaLabel: effectiveAreaLabel,
      refCoords: effectiveCoords,
      usingDeviceLocation: usingDevice,
      sessions: filteredSessions,
      courts: initialCourts,
      churches: initialChurches,
      clearError: true,
    );

    // Muat lapangan & gereja nyata dari OpenStreetMap Overpass API di sekitar titik acuan
    if (!_isFlutterTest) {
      await _discoverOsmVenuesFor(
        coords: effectiveCoords,
        city: effectiveCity,
        dbCourts: dbCourts,
        dbChurches: dbChurches,
      );
    }
  }

  Future<void> _discoverOsmVenuesFor({
    required ({double latitude, double longitude}) coords,
    required String city,
    required List<Court> dbCourts,
    required List<Church> dbChurches,
  }) async {
    final discovered = await PlaceDiscoveryService.discoverNearbyVenues(
      latitude: coords.latitude,
      longitude: coords.longitude,
      fallbackCity: city,
    );
    final mergedCourts = _mergeAndFilterCourts(
      dbCourts: dbCourts,
      osmCourts: discovered.courts,
      city: city,
      coords: coords,
      sportFilter: state.filter.sportType,
    );
    final mergedChurches = _mergeAndFilterChurches(
      dbChurches: dbChurches,
      osmChurches: discovered.churches,
      city: city,
      coords: coords,
    );
    state = state.copyWith(
      isDiscoveringPlaces: false,
      courts: mergedCourts,
      churches: mergedChurches,
    );
  }

  List<Court> _mergeAndFilterCourts({
    required List<Court> dbCourts,
    required List<Court> osmCourts,
    required String city,
    required ({double latitude, double longitude}) coords,
    SportType? sportFilter,
  }) {
    final targetKey = state.targetQuery.trim().toLowerCase();
    final cityKey = city.trim().toLowerCase();

    final localRelevant = dbCourts.where((c) {
      if (sportFilter != null && !c.supportedSports.contains(sportFilter)) {
        return false;
      }
      if (c.city.toLowerCase() == cityKey) return true;
      if (targetKey.isNotEmpty &&
          (c.address.toLowerCase().contains(targetKey) ||
              c.name.toLowerCase().contains(targetKey))) {
        return true;
      }
      if (c.latitude != null && c.longitude != null) {
        final dist = PlaceGeoHelper.haversineDistanceKm(
          lat1: coords.latitude,
          lng1: coords.longitude,
          lat2: c.latitude!,
          lng2: c.longitude!,
        );
        return dist <= 15.0;
      }
      return false;
    }).toList();

    final seenNames = localRelevant.map((c) => c.name.toLowerCase()).toSet();
    final combined = <Court>[
      ...localRelevant,
      ...osmCourts.where((c) {
        if (sportFilter != null && !c.supportedSports.contains(sportFilter)) {
          return false;
        }
        return seenNames.add(c.name.toLowerCase());
      }),
    ];

    return PlaceGeoHelper.sortByNearest<Court>(
      combined,
      refLat: coords.latitude,
      refLng: coords.longitude,
      getLatitude: (c) => c.latitude,
      getLongitude: (c) => c.longitude,
      getCity: (c) => c.city,
    );
  }

  List<Church> _mergeAndFilterChurches({
    required List<Church> dbChurches,
    required List<Church> osmChurches,
    required String city,
    required ({double latitude, double longitude}) coords,
  }) {
    final targetKey = state.targetQuery.trim().toLowerCase();
    final cityKey = city.trim().toLowerCase();

    final localRelevant = dbChurches.where((c) {
      if (c.city.toLowerCase() == cityKey) return true;
      if (targetKey.isNotEmpty &&
          (c.address.toLowerCase().contains(targetKey) ||
              c.name.toLowerCase().contains(targetKey))) {
        return true;
      }
      if (c.latitude != null && c.longitude != null) {
        final dist = PlaceGeoHelper.haversineDistanceKm(
          lat1: coords.latitude,
          lng1: coords.longitude,
          lat2: c.latitude!,
          lng2: c.longitude!,
        );
        return dist <= 15.0;
      }
      return false;
    }).toList();

    final seenNames = localRelevant.map((c) => c.name.toLowerCase()).toSet();
    final combined = <Church>[
      ...localRelevant,
      ...osmChurches.where((c) => seenNames.add(c.name.toLowerCase())),
    ];

    return PlaceGeoHelper.sortByNearest<Church>(
      combined,
      refLat: coords.latitude,
      refLng: coords.longitude,
      getLatitude: (c) => c.latitude,
      getLongitude: (c) => c.longitude,
      getCity: (c) => c.city,
    );
  }

  /// Melacak koordinat lokasi tujuan yang diketik (mis. "Cilandak")
  /// lalu memuat sesi, lapangan, dan gereja di area tersebut.
  Future<void> trackDestinationLocation(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      state = state.copyWith(targetQuery: '', hasExplicitTarget: false);
      await loadInitial();
      return;
    }

    state = state.copyWith(
      isDiscoveringPlaces: true,
      hasExplicitTarget: true,
      targetQuery: clean,
    );

    final resolved = await PlaceDiscoveryService.geocodeTargetArea(
      clean,
      availableCities: state.availableCities,
    );
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    nearbyRepo.setCurrentSelectedCity(resolved.matchedCity);
    nearbyRepo.setLocationPermissionDenied(false);

    state = state.copyWith(
      selectedCity: resolved.matchedCity,
      areaLabel: resolved.areaLabel,
      refCoords: (latitude: resolved.latitude, longitude: resolved.longitude),
      usingDeviceLocation: false,
      hasExplicitTarget: true,
      targetQuery: clean,
      locationPermissionDenied: false,
    );
    await loadInitial();
  }

  /// Mendeteksi lokasi perangkat pengguna saat ini dan melacak lapangan & gereja terdekat.
  Future<bool> useMyDeviceLocation(BuildContext context) async {
    final resolved = await PlaceGeoHelper.resolveDeviceOrCityCoordinates(
      context,
      fallbackCity: state.selectedCity,
    );
    final rev = await PlaceDiscoveryService.reverseGeocodeArea(
      latitude: resolved.latitude,
      longitude: resolved.longitude,
      availableCities: state.availableCities,
    );
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    nearbyRepo.setCurrentSelectedCity(rev.matchedCity);
    nearbyRepo.setLocationPermissionDenied(false);

    state = state.copyWith(
      selectedCity: rev.matchedCity,
      areaLabel: rev.areaLabel,
      targetQuery: '',
      refCoords: (latitude: resolved.latitude, longitude: resolved.longitude),
      usingDeviceLocation: resolved.usedDeviceLocation,
      hasExplicitTarget: true,
      locationPermissionDenied: false,
    );
    await loadInitial();
    return resolved.usedDeviceLocation;
  }

  bool _matchesClientFilters(PlaySession s, PlaySessionFilter f, DateTime now) {
    if (f.costFilter == PlayCostFilter.freeOnly && s.feePerPersonRupiah > 0) {
      return false;
    }
    if (f.costFilter == PlayCostFilter.paidOnly && s.feePerPersonRupiah <= 0) {
      return false;
    }
    if (f.rangeFilter != null && s.host.proximity != f.rangeFilter) {
      return false;
    }
    final start = s.startTime;
    final sameDayToday =
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final sameDayTomorrow =
        start.year == tomorrow.year &&
        start.month == tomorrow.month &&
        start.day == tomorrow.day;
    switch (f.dayFilter) {
      case PlayDayFilter.all:
        break;
      case PlayDayFilter.today:
        if (!sameDayToday) return false;
      case PlayDayFilter.tomorrow:
        if (!sameDayTomorrow) return false;
      case PlayDayFilter.weekend:
        if (start.weekday != DateTime.saturday &&
            start.weekday != DateTime.sunday) {
          return false;
        }
    }
    return true;
  }

  Future<void> setSelectedCity(String city) async {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    nearbyRepo.setCurrentSelectedCity(city);
    nearbyRepo.setLocationPermissionDenied(false);
    final center = PlaceGeoHelper.cityCenterFor(city);
    state = state.copyWith(
      selectedCity: city,
      areaLabel: city,
      targetQuery: '',
      refCoords: (latitude: center.latitude, longitude: center.longitude),
      usingDeviceLocation: false,
      hasExplicitTarget: true,
      locationPermissionDenied: false,
    );
    await loadInitial();
  }

  Future<void> continueWithManualArea() async {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    nearbyRepo.setLocationPermissionDenied(false);
    state = state.copyWith(locationPermissionDenied: false);
    await loadInitial();
  }

  Future<void> applyFilter(PlaySessionFilter filter) async {
    state = state.copyWith(filter: filter);
    await loadInitial();
  }

  Future<void> resetFilter() async {
    state = state.copyWith(filter: const PlaySessionFilter());
    await loadInitial();
  }
}

/// Provider global untuk [PlayController].
final playControllerProvider = NotifierProvider<PlayController, PlayState>(
  PlayController.new,
);
