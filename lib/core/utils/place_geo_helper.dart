import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/widgets/confirm_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

/// Helper murni untuk perhitungan jarak tempat umum (lapangan & gereja),
/// pengurutan "Terdekat", dan pemetaan titik pusat kota.
///
/// Privasi (`SEK-R2`, `AUT-R10`, `AC-07`):
/// - Koordinat hanya digunakan untuk **tempat umum** (lapangan, gereja).
/// - Lokasi perangkat (coarse/perkiraan) hanya dihitung di perangkat untuk
///   mengurutkan daftar dan memusatkan peta, **tidak pernah** dikirim atau disimpan ke server.
/// - Jarak ke tempat umum ditampilkan dalam bentuk rentang (`< 1 km`, `1–5 km`, dst.),
///   bukan angka presisi.
abstract final class PlaceGeoHelper {
  static const MethodChannel _channel = MethodChannel(
    'id.horas.app/coarse_location',
  );

  /// Titik cadangan bawaan: Pusat Kota Medan.
  static const ({double latitude, double longitude}) defaultMedanCenter = (
    latitude: 3.5952,
    longitude: 98.6722,
  );

  /// Titik pusat perkiraan 43 kota di `assets/data/wilayah.json`.
  static const Map<String, ({double latitude, double longitude})> _cityCenters =
      <String, ({double latitude, double longitude})>{
        'medan': (latitude: 3.5952, longitude: 98.6722),
        'pematangsiantar': (latitude: 2.9595, longitude: 99.0682),
        'balige': (latitude: 2.3333, longitude: 99.0667),
        'tarutung': (latitude: 2.0167, longitude: 98.9667),
        'sidikalang': (latitude: 2.7500, longitude: 98.3167),
        'kabanjahe': (latitude: 3.1000, longitude: 98.4833),
        'doloksanggul': (latitude: 2.2530, longitude: 98.7480),
        'pangururan': (latitude: 2.6080, longitude: 98.6940),
        'rantauprapat': (latitude: 2.1000, longitude: 99.8333),
        'padangsidimpuan': (latitude: 1.3789, longitude: 99.2719),
        'sibolga': (latitude: 1.7427, longitude: 98.7792),
        'binjai': (latitude: 3.6001, longitude: 98.4854),
        'tebing tinggi': (latitude: 3.3285, longitude: 99.1625),
        'lubuk pakam': (latitude: 3.5558, longitude: 98.8753),
        'gunungtua': (latitude: 1.5333, longitude: 99.6333),
        'kisaran': (latitude: 2.9833, longitude: 99.6167),
        'jakarta pusat': (latitude: -6.1865, longitude: 106.8341),
        'jakarta selatan': (latitude: -6.2615, longitude: 106.8106),
        'jakarta timur': (latitude: -6.2250, longitude: 106.9004),
        'jakarta barat': (latitude: -6.1674, longitude: 106.7637),
        'jakarta utara': (latitude: -6.1384, longitude: 106.8640),
        'jakarta': (latitude: -6.2088, longitude: 106.8456),
        'bandung': (latitude: -6.9175, longitude: 107.6191),
        'bekasi': (latitude: -6.2383, longitude: 106.9756),
        'depok': (latitude: -6.4025, longitude: 106.7942),
        'bogor': (latitude: -6.5971, longitude: 106.8060),
        'tangerang': (latitude: -6.1783, longitude: 106.6319),
        'tangerang selatan': (latitude: -6.2886, longitude: 106.7179),
        'batam': (latitude: 1.1301, longitude: 104.0529),
        'tanjungpinang': (latitude: 0.9186, longitude: 104.4467),
        'pekanbaru': (latitude: 0.5071, longitude: 101.4478),
        'dumai': (latitude: 1.6667, longitude: 101.4500),
        'padang': (latitude: -0.9471, longitude: 100.4172),
        'palembang': (latitude: -2.9761, longitude: 104.7754),
        'jambi': (latitude: -1.6101, longitude: 103.6131),
        'bandar lampung': (latitude: -5.4292, longitude: 105.2619),
        'surabaya': (latitude: -7.2575, longitude: 112.7521),
        'malang': (latitude: -7.9666, longitude: 112.6326),
        'yogyakarta': (latitude: -7.7956, longitude: 110.3695),
        'semarang': (latitude: -6.9667, longitude: 110.4167),
        'denpasar': (latitude: -8.6705, longitude: 115.2126),
        'balikpapan': (latitude: -1.2379, longitude: 116.8529),
        'pontianak': (latitude: -0.0263, longitude: 109.3425),
        'makassar': (latitude: -5.1477, longitude: 119.4327),
      };

  /// Mengembalikan titik pusat kota berdasarkan nama kota (atau Medan bila tidak ditemukan).
  static ({double latitude, double longitude}) cityCenterFor(String? city) {
    final key = (city ?? '').trim().toLowerCase();
    if (key.isEmpty) return defaultMedanCenter;
    return _cityCenters[key] ?? defaultMedanCenter;
  }

  /// Menghitung jarak garis lurus (Haversine) dalam kilometer antara dua titik koordinat.
  static double haversineDistanceKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Label rentang jarak ke tempat umum (tanpa pernah menampilkan angka kilometer presisi).
  static String distanceRangeLabel(double distanceKm) {
    if (distanceKm < 1.0) return '< 1 km';
    if (distanceKm <= 5.0) return '1–5 km';
    if (distanceKm <= 10.0) return '5–10 km';
    return '> 10 km';
  }

  /// Mengurutkan daftar tempat umum dari yang terdekat ke titik acuan `(refLat, refLng)`.
  /// Bila tempat belum memiliki koordinat eksplisit, digunakan pusat kota tempat tersebut.
  static List<T> sortByNearest<T>(
    List<T> items, {
    required double refLat,
    required double refLng,
    required double? Function(T item) getLatitude,
    required double? Function(T item) getLongitude,
    String? Function(T item)? getCity,
  }) {
    final indexed = <({T item, double distanceKm, int index})>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final lat = getLatitude(item);
      final lng = getLongitude(item);
      final ({double latitude, double longitude}) target;
      if (lat != null && lng != null) {
        target = (latitude: lat, longitude: lng);
      } else {
        target = cityCenterFor(getCity?.call(item));
      }
      final dist = haversineDistanceKm(
        lat1: refLat,
        lng1: refLng,
        lat2: target.latitude,
        lng2: target.longitude,
      );
      indexed.add((item: item, distanceKm: dist, index: i));
    }

    indexed.sort((a, b) {
      final cmp = a.distanceKm.compareTo(b.distanceKm);
      if (cmp != 0) return cmp;
      return a.index.compareTo(b.index);
    });

    return indexed.map((e) => e.item).toList(growable: false);
  }

  /// Membuat tautan petunjuk arah Google Maps:
  /// - Bila tempat memiliki `latitude` & `longitude`, langsung mengarah ke koordinat (`maps/dir`).
  /// - Bila belum memiliki koordinat, kembali ke pencarian teks nama + alamat + kota (`maps/search`).
  static Uri googleMapsDirectionsUri({
    required String name,
    required String address,
    required String city,
    double? latitude,
    double? longitude,
  }) {
    if (latitude != null && longitude != null) {
      return Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    }
    final query = Uri.encodeComponent('$name, $address, $city');
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  }

  /// Membaca lokasi perkiraan perangkat secara diam-diam HANYA bila izin sudah diberikan.
  /// Mengembalikan `null` apabila izin belum diberikan atau layanan lokasi tidak aktif.
  static Future<({double latitude, double longitude})?>
  tryReadGrantedDeviceLocation() async {
    try {
      final status = await perm.Permission.location.status;
      if (!status.isGranted) return null;
      final raw = await _channel.invokeMapMethod<String, double>(
        'getCoarseLocation',
      );
      final lat = raw?['latitude'];
      final lng = raw?['longitude'];
      if (lat != null && lng != null) {
        return (latitude: lat, longitude: lng);
      }
    } on Object {
      // Abaikan pada lingkungan test / desktop / perangkat tanpa GPS.
    }
    return null;
  }

  /// Meminta/membaca lokasi perkiraan perangkat (AUT-R10) hanya di memori lokal.
  /// Bila izin ditolak atau layanan lokasi tidak tersedia, otomatis kembali ke pusat kota `fallbackCity`.
  static Future<({double latitude, double longitude, bool usedDeviceLocation})>
  resolveDeviceOrCityCoordinates(
    BuildContext context, {
    String? fallbackCity,
  }) async {
    final fallback = cityCenterFor(fallbackCity);
    try {
      var status = await perm.Permission.location.status;
      if (!status.isGranted) {
        if (!context.mounted) {
          return (
            latitude: fallback.latitude,
            longitude: fallback.longitude,
            usedDeviceLocation: false,
          );
        }
        final proceed = await ConfirmDialog.show(
          context,
          title: AppStrings.mapLocationRationaleTitle,
          message: AppStrings.mapLocationRationaleMessage,
          confirmLabel: AppStrings.mapLocationAllowBtn,
        );
        if (!proceed) {
          return (
            latitude: fallback.latitude,
            longitude: fallback.longitude,
            usedDeviceLocation: false,
          );
        }
        status = await perm.Permission.location.request();
      }

      if (status.isGranted) {
        final raw = await _channel.invokeMapMethod<String, double>(
          'getCoarseLocation',
        );
        final lat = raw?['latitude'];
        final lng = raw?['longitude'];
        if (lat != null && lng != null) {
          return (latitude: lat, longitude: lng, usedDeviceLocation: true);
        }
      }
    } on MissingPluginException {
      // Lingkungan test / desktop: gunakan pusat kota.
    } on PlatformException {
      // Gunakan pusat kota bila layanan lokasi gagal.
    }

    return (
      latitude: fallback.latitude,
      longitude: fallback.longitude,
      usedDeviceLocation: false,
    );
  }
}
