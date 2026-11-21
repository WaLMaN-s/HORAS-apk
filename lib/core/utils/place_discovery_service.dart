import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:horas/core/utils/place_geo_helper.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/coarse_location_matcher.dart';

/// Hasil resolusi area tujuan atau posisi perangkat berbasis area kasar/peta.
typedef ResolvedAreaResult = ({
  double latitude,
  double longitude,
  String areaLabel,
  String matchedCity,
  bool fromGeocoder,
});

/// Layanan penemuan tempat umum (Lapangan Olahraga & Gereja) berbasis
/// koordinat area / tujuan menggunakan OpenStreetMap Nominatim & Overpass API.
///
/// Privasi (`SEK-R2`, `AUT-R10`, `AC-07`):
/// - Hanya digunakan untuk menemukan tempat umum publik (lapangan & gereja).
/// - Koordinat perangkat tidak pernah dikirim ke server HORAS.
abstract final class PlaceDiscoveryService {
  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Jangkar kecamatan / kawasan populer untuk resolusi instan bahkan saat offline.
  static const Map<
    String,
    ({double lat, double lng, String city, String label})
  >
  _knownSubdistricts =
      <String, ({double lat, double lng, String city, String label})>{
        'cilandak': (
          lat: -6.2921,
          lng: 106.7975,
          city: 'Jakarta Selatan',
          label: 'Cilandak, Jakarta Selatan',
        ),
        'kemang': (
          lat: -6.2607,
          lng: 106.8152,
          city: 'Jakarta Selatan',
          label: 'Kemang, Jakarta Selatan',
        ),
        'tebet': (
          lat: -6.2297,
          lng: 106.8543,
          city: 'Jakarta Selatan',
          label: 'Tebet, Jakarta Selatan',
        ),
        'pasar minggu': (
          lat: -6.2889,
          lng: 106.8439,
          city: 'Jakarta Selatan',
          label: 'Pasar Minggu, Jakarta Selatan',
        ),
        'kebayoran baru': (
          lat: -6.2442,
          lng: 106.7997,
          city: 'Jakarta Selatan',
          label: 'Kebayoran Baru, Jakarta Selatan',
        ),
        'jagakarsa': (
          lat: -6.3340,
          lng: 106.8229,
          city: 'Jakarta Selatan',
          label: 'Jagakarsa, Jakarta Selatan',
        ),
        'setiabudi': (
          lat: -6.2156,
          lng: 106.8295,
          city: 'Jakarta Selatan',
          label: 'Setiabudi, Jakarta Selatan',
        ),
        'menteng': (
          lat: -6.1944,
          lng: 106.8350,
          city: 'Jakarta Pusat',
          label: 'Menteng, Jakarta Pusat',
        ),
        'rawamangun': (
          lat: -6.1972,
          lng: 106.8895,
          city: 'Jakarta Timur',
          label: 'Rawamangun, Jakarta Timur',
        ),
        'cawang': (
          lat: -6.2464,
          lng: 106.8726,
          city: 'Jakarta Timur',
          label: 'Cawang, Jakarta Timur',
        ),
        'kelapa gading': (
          lat: -6.1574,
          lng: 106.9056,
          city: 'Jakarta Utara',
          label: 'Kelapa Gading, Jakarta Utara',
        ),
        'medan baru': (
          lat: 3.5707,
          lng: 98.6606,
          city: 'Medan',
          label: 'Medan Baru, Medan',
        ),
        'medan selayang': (
          lat: 3.5621,
          lng: 98.6368,
          city: 'Medan',
          label: 'Medan Selayang, Medan',
        ),
        'medan helvetia': (
          lat: 3.6095,
          lng: 98.6443,
          city: 'Medan',
          label: 'Medan Helvetia, Medan',
        ),
        'coblong': (
          lat: -6.8895,
          lng: 107.6143,
          city: 'Bandung',
          label: 'Coblong, Bandung',
        ),
        'serpong': (
          lat: -6.3006,
          lng: 106.6656,
          city: 'Tangerang Selatan',
          label: 'Serpong, Tangerang Selatan',
        ),
        'bintaro': (
          lat: -6.2725,
          lng: 106.7377,
          city: 'Tangerang Selatan',
          label: 'Bintaro, Tangerang Selatan',
        ),
        'batam kota': (
          lat: 1.1301,
          lng: 104.0529,
          city: 'Batam',
          label: 'Batam Kota, Batam',
        ),
      };

  static Future<String?> _getText(
    Uri uri, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_isFlutterTest) return null;
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final req = await client.getUrl(uri).timeout(timeout);
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'HORAS-App/1.0 (id.horas.app)',
      );
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      return await resp.transform(utf8.decoder).join().timeout(timeout);
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String?> _postForm(
    Uri uri,
    String body, {
    Duration timeout = const Duration(seconds: 7),
  }) async {
    if (_isFlutterTest) return null;
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final req = await client.postUrl(uri).timeout(timeout);
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'HORAS-App/1.0 (id.horas.app)',
      );
      req.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      req.write(body);
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      return await resp.transform(utf8.decoder).join().timeout(timeout);
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Melacak koordinat dan nama kota/kecamatan dari kata kunci area tujuan (mis. "Cilandak").
  static Future<ResolvedAreaResult> geocodeTargetArea(
    String rawQuery, {
    List<WilayahCity> availableCities = const <WilayahCity>[],
  }) async {
    final clean = rawQuery.trim();
    final lower = clean.toLowerCase();

    final known = _knownSubdistricts[lower];
    if (known != null) {
      return (
        latitude: known.lat,
        longitude: known.lng,
        areaLabel: known.label,
        matchedCity: known.city,
        fromGeocoder: false,
      );
    }

    // Cocokkan terhadap daftar kota & kecamatan di `wilayah.json`
    for (final c in availableCities) {
      if (c.name.toLowerCase() == lower) {
        final pt = PlaceGeoHelper.cityCenterFor(c.name);
        return (
          latitude: pt.latitude,
          longitude: pt.longitude,
          areaLabel: c.name,
          matchedCity: c.name,
          fromGeocoder: false,
        );
      }
      for (final sub in c.subdistricts) {
        if (sub.toLowerCase() == lower) {
          final pt = PlaceGeoHelper.cityCenterFor(c.name);
          // Tetap coba Nominatim agar titik pusat kecamatannya lebih tepat.
          final live = await _nominatimSearch(
            '$sub, ${c.name}, Indonesia',
            availableCities,
          );
          if (live != null) return live;
          return (
            latitude: pt.latitude,
            longitude: pt.longitude,
            areaLabel: '$sub, ${c.name}',
            matchedCity: c.name,
            fromGeocoder: false,
          );
        }
      }
    }

    final live = await _nominatimSearch('$clean, Indonesia', availableCities);
    if (live != null) return live;

    final fallback = PlaceGeoHelper.cityCenterFor(clean);
    return (
      latitude: fallback.latitude,
      longitude: fallback.longitude,
      areaLabel: clean.isEmpty ? 'Medan' : clean,
      matchedCity: clean.isEmpty ? 'Medan' : clean,
      fromGeocoder: false,
    );
  }

  static Future<ResolvedAreaResult?> _nominatimSearch(
    String q,
    List<WilayahCity> availableCities,
  ) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': q,
        'countrycodes': 'id',
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '1',
      },
    );
    final raw = await _getText(uri);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return null;
      final first = decoded.first;
      if (first is! Map) return null;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lng = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lng == null) return null;

      final addr = first['address'] is Map
          ? (first['address'] as Map).map(
              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
            )
          : const <String, String>{};
      final city = _extractIndonesianCity(addr, lat, lng, availableCities);
      final sub =
          addr['suburb'] ??
          addr['city_district'] ??
          addr['village'] ??
          addr['town'] ??
          first['name']?.toString() ??
          '';
      final areaLabel =
          sub.isNotEmpty && !city.toLowerCase().contains(sub.toLowerCase())
          ? '$sub, $city'
          : city;
      return (
        latitude: lat,
        longitude: lng,
        areaLabel: areaLabel,
        matchedCity: city,
        fromGeocoder: true,
      );
    } on Object {
      return null;
    }
  }

  /// Mengubah koordinat kasar perangkat menjadi label area (mis. "Cilandak, Jakarta Selatan").
  static Future<({String areaLabel, String matchedCity, String? subdistrict})>
  reverseGeocodeArea({
    required double latitude,
    required double longitude,
    List<WilayahCity> availableCities = const <WilayahCity>[],
  }) async {
    final fallbackCity = CoarseLocationCityMatcher.matchNearestCityName(
      coarseLat: latitude,
      coarseLon: longitude,
      availableCityNames: availableCities.map((c) => c.name).toList(),
    );

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      <String, String>{
        'lat': latitude.toStringAsFixed(4),
        'lon': longitude.toStringAsFixed(4),
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '14',
      },
    );
    final raw = await _getText(uri);
    if (raw == null || raw.isEmpty) {
      return (
        areaLabel: fallbackCity,
        matchedCity: fallbackCity,
        subdistrict: null,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return (
          areaLabel: fallbackCity,
          matchedCity: fallbackCity,
          subdistrict: null,
        );
      }
      final addr = decoded['address'] is Map
          ? (decoded['address'] as Map).map(
              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
            )
          : const <String, String>{};
      final city = _extractIndonesianCity(
        addr,
        latitude,
        longitude,
        availableCities,
      );
      final sub =
          addr['city_district'] ??
          addr['suburb'] ??
          addr['village'] ??
          addr['municipality'] ??
          '';
      final cleanSub = sub
          .replaceFirst(RegExp(r'^Kecamatan\s+', caseSensitive: false), '')
          .trim();
      final label =
          cleanSub.isNotEmpty &&
              !city.toLowerCase().contains(cleanSub.toLowerCase())
          ? '$cleanSub, $city'
          : city;
      return (
        areaLabel: label,
        matchedCity: city,
        subdistrict: cleanSub.isEmpty ? null : cleanSub,
      );
    } on Object {
      return (
        areaLabel: fallbackCity,
        matchedCity: fallbackCity,
        subdistrict: null,
      );
    }
  }

  static String _extractIndonesianCity(
    Map<String, String> addr,
    double lat,
    double lng,
    List<WilayahCity> availableCities,
  ) {
    final candidates = <String>[
      addr['city'] ?? '',
      addr['city_district'] ?? '',
      addr['county'] ?? '',
      addr['state_district'] ?? '',
      addr['town'] ?? '',
      addr['state'] ?? '',
    ].where((e) => e.trim().isNotEmpty).toList();

    for (final raw in candidates) {
      final norm = raw
          .replaceFirst(
            RegExp(r'^(Kota|Kabupaten)\s+', caseSensitive: false),
            '',
          )
          .trim()
          .toLowerCase();
      for (final c in availableCities) {
        if (c.name.toLowerCase() == norm ||
            norm.contains(c.name.toLowerCase())) {
          return c.name;
        }
      }
      if (norm.contains('jakarta selatan') || norm.contains('south jakarta')) {
        return 'Jakarta Selatan';
      }
      if (norm.contains('jakarta timur') || norm.contains('east jakarta')) {
        return 'Jakarta Timur';
      }
      if (norm.contains('jakarta pusat') || norm.contains('central jakarta')) {
        return 'Jakarta Pusat';
      }
      if (norm.contains('jakarta barat') || norm.contains('west jakarta')) {
        return 'Jakarta Barat';
      }
      if (norm.contains('jakarta utara') || norm.contains('north jakarta')) {
        return 'Jakarta Utara';
      }
    }
    return CoarseLocationCityMatcher.matchNearestCityName(
      coarseLat: lat,
      coarseLon: lng,
      availableCityNames: availableCities.map((c) => c.name).toList(),
    );
  }

  /// Menemukan lapangan olahraga dan gereja publik di sekitar titik `(latitude, longitude)`
  /// melalui Overpass API OpenStreetMap (radius 3,5 km).
  static Future<({List<Court> courts, List<Church> churches})>
  discoverNearbyVenues({
    required double latitude,
    required double longitude,
    required String fallbackCity,
    int radiusMeters = 3500,
  }) async {
    if (_isFlutterTest) {
      return (courts: const <Court>[], churches: const <Church>[]);
    }
    final latStr = latitude.toStringAsFixed(5);
    final lngStr = longitude.toStringAsFixed(5);
    final query =
        '''
[out:json][timeout:6];
(
  nwr["leisure"~"^(sports_centre|pitch|stadium|fitness_centre)\$"]["name"](around:$radiusMeters,$latStr,$lngStr);
  nwr["sport"]["name"](around:$radiusMeters,$latStr,$lngStr);
  nwr["amenity"="place_of_worship"]["religion"="christian"]["name"](around:$radiusMeters,$latStr,$lngStr);
  nwr["amenity"="place_of_worship"]["name"~"(Gereja|HKBP|GKPI|HKI|GKPS|GBKP|GPIB|GKI|Gereja Batak)",i](around:$radiusMeters,$latStr,$lngStr);
);
out center 40;
''';

    final body = 'data=${Uri.encodeQueryComponent(query)}';
    final raw = await _postForm(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body,
    );
    if (raw == null || raw.isEmpty) {
      return (courts: const <Court>[], churches: const <Church>[]);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['elements'] is! List) {
        return (courts: const <Court>[], churches: const <Church>[]);
      }

      final seenCourts = <String>{};
      final seenChurches = <String>{};
      final courts = <Court>[];
      final churches = <Church>[];

      for (final elem in decoded['elements'] as List) {
        if (elem is! Map) continue;
        final tagsRaw = elem['tags'];
        if (tagsRaw is! Map) continue;
        final tags = tagsRaw.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
        final name = (tags['name'] ?? '').trim();
        if (name.isEmpty) continue;

        double? elLat = (elem['lat'] as num?)?.toDouble();
        double? elLng = (elem['lon'] as num?)?.toDouble();
        if ((elLat == null || elLng == null) && elem['center'] is Map) {
          final center = elem['center'] as Map;
          elLat = (center['lat'] as num?)?.toDouble();
          elLng = (center['lon'] as num?)?.toDouble();
        }
        if (elLat == null || elLng == null) continue;

        final idNum = elem['id']?.toString() ?? '${name.hashCode}';
        final street = tags['addr:street'] ?? '';
        final suburb = tags['addr:suburb'] ?? tags['addr:district'] ?? '';
        final cityTag = (tags['addr:city'] ?? '').trim().isNotEmpty
            ? tags['addr:city']!.trim()
            : fallbackCity;
        final addrParts = <String>[
          if (street.isNotEmpty) street,
          if (suburb.isNotEmpty) suburb,
          cityTag,
        ];
        final address = addrParts.isEmpty ? cityTag : addrParts.join(', ');

        final isChurch = tags['amenity'] == 'place_of_worship';
        if (isChurch) {
          final key = name.toLowerCase();
          if (seenChurches.add(key)) {
            churches.add(
              Church(
                id: 'osm-church-$idNum',
                name: name,
                denomination: _inferDenomination(name),
                address: address,
                city: cityTag,
                serviceSchedules: const <ChurchServiceSchedule>[
                  ChurchServiceSchedule(
                    dayOfWeek: 'Minggu',
                    time: 'Jadwal lihat info lokasi',
                    language: 'Bahasa Indonesia / Batak',
                  ),
                ],
                contactPhone: tags['phone'] ?? tags['contact:phone'] ?? '',
                contactEmail: tags['email'] ?? '',
                isVerified: false,
                memberCount: 0,
                latitude: elLat,
                longitude: elLng,
              ),
            );
          }
        } else {
          final key = name.toLowerCase();
          if (seenCourts.add(key)) {
            courts.add(
              Court(
                id: 'osm-court-$idNum',
                name: name,
                address: address,
                city: cityTag,
                supportedSports: _inferSports(tags['sport'] ?? '', name),
                estimatedPriceText: 'Tarif lihat lokasi / OpenStreetMap',
                openingHours: tags['opening_hours'] ?? 'Jam buka lihat lokasi',
                imageSeed: 'osm-court-$idNum',
                latitude: elLat,
                longitude: elLng,
              ),
            );
          }
        }
      }

      final sortedCourts = PlaceGeoHelper.sortByNearest<Court>(
        courts,
        refLat: latitude,
        refLng: longitude,
        getLatitude: (c) => c.latitude,
        getLongitude: (c) => c.longitude,
        getCity: (c) => c.city,
      ).take(15).toList(growable: false);

      final sortedChurches = PlaceGeoHelper.sortByNearest<Church>(
        churches,
        refLat: latitude,
        refLng: longitude,
        getLatitude: (c) => c.latitude,
        getLongitude: (c) => c.longitude,
        getCity: (c) => c.city,
      ).take(15).toList(growable: false);

      return (courts: sortedCourts, churches: sortedChurches);
    } on Object {
      return (courts: const <Court>[], churches: const <Church>[]);
    }
  }

  static ChurchDenomination _inferDenomination(String name) {
    final u = name.toUpperCase();
    if (u.contains('HKBP')) return ChurchDenomination.hkbp;
    if (u.contains('GKPI')) return ChurchDenomination.gkpi;
    if (u.contains('HKI')) return ChurchDenomination.hki;
    if (u.contains('GKPS')) return ChurchDenomination.gkps;
    if (u.contains('GBKP')) return ChurchDenomination.gbkp;
    return ChurchDenomination.lainnya;
  }

  static List<SportType> _inferSports(String rawSport, String name) {
    final lower = '$rawSport $name'.toLowerCase();
    final out = <SportType>[];
    if (lower.contains('badminton') || lower.contains('bulutangkis')) {
      out.add(SportType.badminton);
    }
    if (lower.contains('futsal') ||
        lower.contains('soccer') ||
        lower.contains('mini_soccer')) {
      out.add(SportType.futsal);
    }
    if (lower.contains('volleyball') || lower.contains('voli')) {
      out.add(SportType.volleyball);
    }
    if (lower.contains('basketball') || lower.contains('basket')) {
      out.add(SportType.basketball);
    }
    if (lower.contains('table_tennis') ||
        lower.contains('pingpong') ||
        lower.contains('tenis meja')) {
      out.add(SportType.tableTennis);
    }
    if (lower.contains('running') ||
        lower.contains('athletics') ||
        lower.contains('jogging')) {
      out.add(SportType.jogging);
    }
    return out.isEmpty ? const <SportType>[SportType.other] : out;
  }
}
