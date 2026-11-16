import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/play/presentation/play_models.dart';

/// State utama modul Main Bareng (`MAN-01`, `MAN-02`, `MAN-07`).
final class PlayState {
  const PlayState({
    this.selectedCity = 'Medan',
    this.availableCities = const <WilayahCity>[],
    this.filter = const PlaySessionFilter(),
    this.sessions = const <PlaySession>[],
    this.courts = const <Court>[],
    this.isLoading = false,
    this.locationPermissionDenied = false,
    this.error,
  });

  final String selectedCity;
  final List<WilayahCity> availableCities;
  final PlaySessionFilter filter;
  final List<PlaySession> sessions;
  final List<Court> courts;
  final bool isLoading;
  final bool locationPermissionDenied;
  final AppError? error;

  PlayState copyWith({
    String? selectedCity,
    List<WilayahCity>? availableCities,
    PlaySessionFilter? filter,
    List<PlaySession>? sessions,
    List<Court>? courts,
    bool? isLoading,
    bool? locationPermissionDenied,
    AppError? error,
    bool clearError = false,
  }) {
    return PlayState(
      selectedCity: selectedCity ?? this.selectedCity,
      availableCities: availableCities ?? this.availableCities,
      filter: filter ?? this.filter,
      sessions: sessions ?? this.sessions,
      courts: courts ?? this.courts,
      isLoading: isLoading ?? this.isLoading,
      locationPermissionDenied:
          locationPermissionDenied ?? this.locationPermissionDenied,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller Riverpod untuk modul Main (`MAN-01`, `MAN-02`, `MAN-07`).
class PlayController extends Notifier<PlayState> {
  @override
  PlayState build() {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    Future<void>.microtask(loadInitial);
    return PlayState(
      selectedCity: nearbyRepo.currentSelectedCity,
      locationPermissionDenied: nearbyRepo.locationPermissionDenied,
    );
  }

  Future<void> loadInitial() async {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final courtRepo = ref.read(courtRepositoryProvider);
    final now = ref.read(authRepositoryProvider).currentTime;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedCity: nearbyRepo.currentSelectedCity,
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

    final citiesFuture = nearbyRepo.getAvailableCities();
    final sessionsFuture = sessionRepo.getSessions(
      city: state.selectedCity.isEmpty ? null : state.selectedCity,
      sportType: state.filter.sportType,
      skillLevel: state.filter.skillLevel,
    );
    final courtsFuture = courtRepo.getCourts(
      city: state.selectedCity.isEmpty ? null : state.selectedCity,
      sportType: state.filter.sportType,
    );

    final citiesRes = await citiesFuture;
    final sessionsRes = await sessionsFuture;
    final courtsRes = await courtsFuture;

    if (sessionsRes is Err<List<PlaySession>>) {
      state = state.copyWith(
        isLoading: false,
        availableCities: citiesRes is Ok<List<WilayahCity>>
            ? citiesRes.value
            : state.availableCities,
        error: sessionsRes.failure,
      );
      return;
    }

    final rawSessions = (sessionsRes as Ok<List<PlaySession>>).value;
    final filtered = rawSessions
        .where((s) => _matchesClientFilters(s, state.filter, now))
        .toList(growable: false);

    state = state.copyWith(
      isLoading: false,
      availableCities: citiesRes is Ok<List<WilayahCity>>
          ? citiesRes.value
          : state.availableCities,
      sessions: filtered,
      courts: courtsRes is Ok<List<Court>> ? courtsRes.value : const <Court>[],
      clearError: true,
    );
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
    state = state.copyWith(selectedCity: city, locationPermissionDenied: false);
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
