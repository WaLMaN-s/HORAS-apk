import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Hasil pemilihan dan kompresi satu gambar bebas metadata EXIF (`AC-10`).
final class EncodedImageResult {
  const EncodedImageResult({
    required this.name,
    required this.originalBytesCount,
    required this.compressedBytes,
    required this.dataUri,
    this.aspectRatio = 1.0,
  });

  final String name;
  final int originalBytesCount;
  final Uint8List compressedBytes;
  final String dataUri;
  final double aspectRatio;
}

/// Helper untuk memilih foto dari Galeri/Kamera, menghapus EXIF/GPS di klien (`AC-10`),
/// dan mengubahnya menjadi Data URI (`data:image/jpeg;base64,...`) agar langsung tampil
/// di seluruh perangkat baik pada mode Mock maupun Supabase Cloud.
abstract final class ImageDataUriHelper {
  /// Memilih satu gambar mentah dari [source] untuk dipotong (`crop`) atau dikompres.
  static Future<({String name, Uint8List bytes})?> pickRawImage(
    ImageSource source, {
    int maxDimension = 1440,
    int quality = 90,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: maxDimension.toDouble(),
      maxHeight: maxDimension.toDouble(),
      imageQuality: quality,
    );
    if (picked == null) return null;
    final raw = await picked.readAsBytes();
    if (raw.isEmpty) return null;
    return (name: picked.name, bytes: raw);
  }

  /// Mendekode string `data:image/...;base64,...` menjadi bytes bila valid.
  static Uint8List? decodeDataUri(String? seed) {
    if (seed == null || !seed.startsWith('data:image/')) return null;
    final comma = seed.indexOf(',');
    if (comma <= 0 || comma >= seed.length - 1) return null;
    try {
      return base64Decode(seed.substring(comma + 1));
    } on Object {
      return null;
    }
  }

  /// Membaca rasio asli (`width / height`) dari bytes gambar (JPEG/PNG/WebP).
  static Future<double> detectAspectRatio(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (w > 0 && h > 0) {
        return (w / h).clamp(0.4, 2.5);
      }
    } on Object {
      // Abaikan bila codec native tidak tersedia pada unit test headless.
    }
    return 1.0;
  }

  /// Mengompres [rawBytes] (menghapus EXIF/GPS) dan mengubahnya menjadi [EncodedImageResult].
  static Future<EncodedImageResult> encodeBytes(
    Uint8List rawBytes, {
    String name = 'photo.jpg',
    int maxDimension = 720,
    int quality = 78,
    int? maxRawBytes,
    double? aspectRatio,
  }) async {
    Uint8List compressed = rawBytes;
    try {
      final result = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        keepExif: false, // AC-10: Hapus seluruh metadata EXIF/GPS
      );
      if (result.isNotEmpty) {
        compressed = result;
      }
    } on Object {
      // Gunakan bytes asli yang sudah di-resize bila kompresor native tidak tersedia.
    }
    if (maxRawBytes != null && compressed.length > maxRawBytes) {
      throw FormatException('FILE_TOO_LARGE:${compressed.length}');
    }

    final resolvedRatio = aspectRatio ?? await detectAspectRatio(compressed);
    final base64Str = base64Encode(compressed);
    return EncodedImageResult(
      name: name,
      originalBytesCount: rawBytes.length,
      compressedBytes: compressed,
      dataUri: 'data:image/jpeg;base64,$base64Str',
      aspectRatio: resolvedRatio,
    );
  }

  /// Memilih satu gambar dari [source] (`ImageSource.gallery` atau `ImageSource.camera`).
  static Future<EncodedImageResult?> pickAndEncodeImage(
    ImageSource source, {
    int maxDimension = 640,
    int quality = 75,
    int? maxRawBytes,
  }) async {
    final raw = await pickRawImage(
      source,
      maxDimension: maxDimension,
      quality: quality,
    );
    if (raw == null) return null;
    return encodeBytes(
      raw.bytes,
      name: raw.name,
      maxDimension: maxDimension,
      quality: quality,
      maxRawBytes: maxRawBytes,
    );
  }

  /// Memilih banyak gambar sekaligus dari galeri.
  static Future<List<EncodedImageResult>> pickMultipleAndEncodeImages({
    required int limit,
    int maxDimension = 800,
    int quality = 75,
    int? maxRawBytes,
  }) async {
    if (limit <= 0) return const <EncodedImageResult>[];
    final picker = ImagePicker();
    List<XFile> pickedFiles = const <XFile>[];
    if (limit == 1) {
      final single = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxDimension.toDouble(),
        maxHeight: maxDimension.toDouble(),
        imageQuality: quality,
      );
      pickedFiles = single != null ? <XFile>[single] : const <XFile>[];
    } else {
      try {
        pickedFiles = await picker.pickMultiImage(
          limit: limit,
          maxWidth: maxDimension.toDouble(),
          maxHeight: maxDimension.toDouble(),
          imageQuality: quality,
        );
      } on Object {
        try {
          pickedFiles = await picker.pickMultiImage(
            maxWidth: maxDimension.toDouble(),
            maxHeight: maxDimension.toDouble(),
            imageQuality: quality,
          );
        } on Object {
          final single = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: maxDimension.toDouble(),
            maxHeight: maxDimension.toDouble(),
            imageQuality: quality,
          );
          pickedFiles = single != null ? <XFile>[single] : const <XFile>[];
        }
      }
    }

    final results = <EncodedImageResult>[];
    for (final file in pickedFiles.take(limit)) {
      final rawBytes = await file.readAsBytes();
      final encoded = await encodeBytes(
        rawBytes,
        name: file.name,
        maxDimension: maxDimension,
        quality: quality,
        maxRawBytes: maxRawBytes,
      );
      results.add(encoded);
    }
    return results;
  }
}
