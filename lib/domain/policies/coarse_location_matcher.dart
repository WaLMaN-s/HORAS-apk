/// Pencocok lokasi perkiraan (`ACCESS_COARSE_LOCATION`) ke kota terdekat di perangkat,
/// lalu langsung membuang koordinatnya (AUT-R10, PRD 12).
///
/// Koordinat TIDAK PERNAH disimpan di model atau dikirim ke repository.
abstract final class CoarseLocationCityMatcher {
  static const List<(String city, double approxLat, double approxLon)>
  _cityAnchors = <(String, double, double)>[
    ('Medan', 3.5952, 98.6722),
    ('Pematangsiantar', 2.9595, 99.0682),
    ('Balige', 2.3333, 99.0667),
    ('Tarutung', 2.0167, 98.9667),
    ('Sidikalang', 2.7500, 98.3167),
    ('Kabanjahe', 3.1000, 98.4833),
    ('Doloksanggul', 2.2500, 98.7500),
    ('Pangururan', 2.6000, 98.7000),
    ('Jakarta Selatan', -6.2615, 106.8106),
    ('Jakarta Timur', -6.2250, 106.9004),
    ('Jakarta Pusat', -6.1805, 106.8284),
    ('Bandung', -6.9175, 107.6191),
    ('Batam', 1.1301, 104.0529),
    ('Pekanbaru', 0.5071, 101.4478),
    ('Surabaya', -7.2575, 112.7521),
    ('Yogyakarta', -7.7956, 110.3695),
  ];

  /// Mengembalikan hanya nama kota terdekat dan langsung membuang `coarseLat`/`coarseLon`.
  static String matchNearestCityName({
    required double coarseLat,
    required double coarseLon,
    List<String> availableCityNames = const <String>[],
  }) {
    String bestCity = 'Medan';
    var bestScore = double.infinity;

    for (final anchor in _cityAnchors) {
      if (availableCityNames.isNotEmpty &&
          !availableCityNames.any(
            (c) => c.toLowerCase() == anchor.$1.toLowerCase(),
          )) {
        continue;
      }
      final dLat = coarseLat - anchor.$2;
      final dLon = coarseLon - anchor.$3;
      final score = dLat * dLat + dLon * dLon;
      if (score < bestScore) {
        bestScore = score;
        bestCity = anchor.$1;
      }
    }
    return bestCity;
  }
}
