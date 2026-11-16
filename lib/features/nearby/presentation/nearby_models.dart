/// Segmen utama pada halaman Sekitar (SEK-01; Gereja adalah Fase 2 dan disembunyikan).
enum NearbyMainSegment { orang, komunitas }

/// Kriteria filter pencarian & daftar orang di Sekitar (SEK-03).
final class NearbyPeopleFilter {
  const NearbyPeopleFilter({
    this.city,
    this.marga,
    this.hobby,
    this.campusOrOffice,
  });

  final String? city;
  final String? marga;
  final String? hobby;
  final String? campusOrOffice;

  bool get hasActiveFilters =>
      (city != null && city!.trim().isNotEmpty) ||
      (marga != null && marga!.trim().isNotEmpty) ||
      (hobby != null && hobby!.trim().isNotEmpty) ||
      (campusOrOffice != null && campusOrOffice!.trim().isNotEmpty);

  int get activeFilterCount {
    var count = 0;
    if (city != null && city!.trim().isNotEmpty) count++;
    if (marga != null && marga!.trim().isNotEmpty) count++;
    if (hobby != null && hobby!.trim().isNotEmpty) count++;
    if (campusOrOffice != null && campusOrOffice!.trim().isNotEmpty) count++;
    return count;
  }

  List<String> activeLabels() {
    final labels = <String>[];
    if (city != null && city!.trim().isNotEmpty) labels.add(city!.trim());
    if (marga != null && marga!.trim().isNotEmpty) labels.add(marga!.trim());
    if (campusOrOffice != null && campusOrOffice!.trim().isNotEmpty) {
      labels.add(campusOrOffice!.trim());
    }
    if (hobby != null && hobby!.trim().isNotEmpty) labels.add(hobby!.trim());
    return labels;
  }

  NearbyPeopleFilter copyWith({
    String? city,
    bool clearCity = false,
    String? marga,
    bool clearMarga = false,
    String? hobby,
    bool clearHobby = false,
    String? campusOrOffice,
    bool clearCampusOrOffice = false,
  }) {
    return NearbyPeopleFilter(
      city: clearCity ? null : (city ?? this.city),
      marga: clearMarga ? null : (marga ?? this.marga),
      hobby: clearHobby ? null : (hobby ?? this.hobby),
      campusOrOffice: clearCampusOrOffice
          ? null
          : (campusOrOffice ?? this.campusOrOffice),
    );
  }
}
