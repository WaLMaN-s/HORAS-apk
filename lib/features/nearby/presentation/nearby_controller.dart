import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/features/nearby/presentation/nearby_models.dart';

/// State untuk modul utama Sekitar (`SEK-01`, `SEK-02`, `SEK-03`, `SEK-05`).
final class NearbyState {
  const NearbyState({
    this.segment = NearbyMainSegment.orang,
    this.selectedCity = 'Medan',
    this.availableCities = const <WilayahCity>[],
    this.availableMargas = const <MargaEntry>[],
    this.filter = const NearbyPeopleFilter(),
    this.people = const <PersonSummary>[],
    this.communities = const <Community>[],
    this.myCommunityIds = const <String>{},
    this.currentPage = 1,
    this.hasMorePeople = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.locationPermissionDenied = false,
    this.error,
  });

  final NearbyMainSegment segment;
  final String selectedCity;
  final List<WilayahCity> availableCities;
  final List<MargaEntry> availableMargas;
  final NearbyPeopleFilter filter;
  final List<PersonSummary> people;
  final List<Community> communities;
  final Set<String> myCommunityIds;
  final int currentPage;
  final bool hasMorePeople;
  final bool isLoading;
  final bool isLoadingMore;
  final bool locationPermissionDenied;
  final AppError? error;

  NearbyState copyWith({
    NearbyMainSegment? segment,
    String? selectedCity,
    List<WilayahCity>? availableCities,
    List<MargaEntry>? availableMargas,
    NearbyPeopleFilter? filter,
    List<PersonSummary>? people,
    List<Community>? communities,
    Set<String>? myCommunityIds,
    int? currentPage,
    bool? hasMorePeople,
    bool? isLoading,
    bool? isLoadingMore,
    bool? locationPermissionDenied,
    AppError? error,
    bool clearError = false,
  }) {
    return NearbyState(
      segment: segment ?? this.segment,
      selectedCity: selectedCity ?? this.selectedCity,
      availableCities: availableCities ?? this.availableCities,
      availableMargas: availableMargas ?? this.availableMargas,
      filter: filter ?? this.filter,
      people: people ?? this.people,
      communities: communities ?? this.communities,
      myCommunityIds: myCommunityIds ?? this.myCommunityIds,
      currentPage: currentPage ?? this.currentPage,
      hasMorePeople: hasMorePeople ?? this.hasMorePeople,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      locationPermissionDenied:
          locationPermissionDenied ?? this.locationPermissionDenied,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller Riverpod untuk Sekitar (`SEK-01`, `SEK-02`, `SEK-03`, `SEK-05`).
class NearbyController extends Notifier<NearbyState> {
  @override
  NearbyState build() {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    Future<void>.microtask(loadInitial);
    return NearbyState(
      selectedCity: nearbyRepo.currentSelectedCity,
      locationPermissionDenied: nearbyRepo.locationPermissionDenied,
    );
  }

  Future<void> loadInitial() async {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    final commRepo = ref.read(communityRepositoryProvider);

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
    final margasFuture = profileRepo.getStandardMargaList();
    final activeCityFilter = state.filter.city ?? state.selectedCity;

    final peopleFuture = nearbyRepo.getNearbyPeople(
      city: activeCityFilter.isEmpty ? null : activeCityFilter,
      marga: state.filter.marga,
      hobby: state.filter.hobby,
      campusOrOffice: state.filter.campusOrOffice,
      page: 1,
    );
    final commFuture = commRepo.getCommunities();

    final citiesRes = await citiesFuture;
    final margasRes = await margasFuture;
    final peopleRes = await peopleFuture;
    final commRes = await commFuture;

    if (peopleRes is Err<List<PersonSummary>>) {
      state = state.copyWith(
        isLoading: false,
        availableCities: citiesRes is Ok<List<WilayahCity>>
            ? citiesRes.value
            : state.availableCities,
        availableMargas: margasRes is Ok<List<MargaEntry>>
            ? margasRes.value
            : state.availableMargas,
        error: peopleRes.failure,
      );
      return;
    }
    if (commRes is Err<List<Community>>) {
      state = state.copyWith(isLoading: false, error: commRes.failure);
      return;
    }

    final people = (peopleRes as Ok<List<PersonSummary>>).value;
    final communities = (commRes as Ok<List<Community>>).value
        .where((c) => c.type != CommunityType.church) // Fase 2 disembunyikan
        .toList(growable: false);

    state = state.copyWith(
      isLoading: false,
      availableCities: citiesRes is Ok<List<WilayahCity>>
          ? citiesRes.value
          : state.availableCities,
      availableMargas: margasRes is Ok<List<MargaEntry>>
          ? margasRes.value
          : state.availableMargas,
      people: people,
      communities: communities,
      currentPage: 1,
      hasMorePeople: people.length >= AppLimits.nearbyPageSize,
      clearError: true,
    );
  }

  void selectSegment(NearbyMainSegment segment) {
    if (state.segment == segment) return;
    state = state.copyWith(segment: segment);
  }

  Future<void> setSelectedCity(String city) async {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    nearbyRepo.setCurrentSelectedCity(city);
    nearbyRepo.setLocationPermissionDenied(false);
    state = state.copyWith(
      selectedCity: city,
      locationPermissionDenied: false,
      filter: state.filter.copyWith(clearCity: true),
    );
    await loadInitial();
  }

  Future<void> continueWithManualArea() async {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    nearbyRepo.setLocationPermissionDenied(false);
    state = state.copyWith(locationPermissionDenied: false);
    await loadInitial();
  }

  Future<void> applyFilter(NearbyPeopleFilter filter) async {
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    if (filter.city != null && filter.city!.trim().isNotEmpty) {
      nearbyRepo.setCurrentSelectedCity(filter.city!.trim());
      state = state.copyWith(selectedCity: filter.city!.trim(), filter: filter);
    } else {
      state = state.copyWith(filter: filter);
    }
    await loadInitial();
  }

  Future<void> resetFilter() async {
    state = state.copyWith(filter: const NearbyPeopleFilter());
    await loadInitial();
  }

  Future<void> loadMorePeople() async {
    if (state.isLoadingMore || !state.hasMorePeople) return;
    state = state.copyWith(isLoadingMore: true);

    final nextPage = state.currentPage + 1;
    final activeCityFilter = state.filter.city ?? state.selectedCity;
    final res = await ref
        .read(nearbyRepositoryProvider)
        .getNearbyPeople(
          city: activeCityFilter.isEmpty ? null : activeCityFilter,
          marga: state.filter.marga,
          hobby: state.filter.hobby,
          campusOrOffice: state.filter.campusOrOffice,
          page: nextPage,
        );

    if (res is Ok<List<PersonSummary>>) {
      final added = res.value;
      final existingIds = state.people.map((p) => p.id).toSet();
      final merged = <PersonSummary>[
        ...state.people,
        ...added.where((p) => !existingIds.contains(p.id)),
      ];
      state = state.copyWith(
        isLoadingMore: false,
        people: merged,
        currentPage: nextPage,
        hasMorePeople: added.length >= AppLimits.nearbyPageSize,
      );
      return;
    }

    state = state.copyWith(
      isLoadingMore: false,
      error: (res as Err<List<PersonSummary>>).failure,
    );
  }
}

/// Provider global untuk [NearbyController].
final nearbyControllerProvider =
    NotifierProvider<NearbyController, NearbyState>(NearbyController.new);
