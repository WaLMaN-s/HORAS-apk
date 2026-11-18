import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Hasil pemilihan dan kompresi satu gambar bebas metadata EXIF (`AC-10`).
final class EncodedImageResult {
  const EncodedImageResult({
    required this.name,
    required this.originalBytesCount,
    required this.compressedBytes,
    required this.dataUri,
  });

  final String name;
  final int originalBytesCount;
  final Uint8List compressedBytes;
  final String dataUri;
}

/// Helper untuk memilih foto dari Galeri/Kamera, menghapus EXIF/GPS di klien (`AC-10`),
/// dan mengubahnya menjadi Data URI (`data:image/jpeg;base64,...`) agar langsung tampil
/// di seluruh perangkat baik pada mode Mock maupun Supabase Cloud.
abstract final class ImageDataUriHelper {
  /// Memilih satu gambar dari [source] (`ImageSource.gallery` atau `ImageSource.camera`).
  static Future<EncodedImageResult?> pickAndEncodeImage(
    ImageSource source, {
    int maxDimension = 640,
    int quality = 75,
    int? maxRawBytes,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: maxDimension.toDouble(),
      maxHeight: maxDimension.toDouble(),
      imageQuality: quality,
    );
    if (picked == null) return null;
    return _encodeXFile(
      picked,
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
      final encoded = await _encodeXFile(
        file,
        maxDimension: maxDimension,
        quality: quality,
        maxRawBytes: maxRawBytes,
      );
      if (encoded != null) {
        results.add(encoded);
      }
    }
    return results;
  }

  static Future<EncodedImageResult?> _encodeXFile(
    XFile file, {
    required int maxDimension,
    required int quality,
    int? maxRawBytes,
  }) async {
    final rawBytes = await file.readAsBytes();
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
      // Gunakan rawBytes yang sudah di-resize oleh ImagePicker bila kompresor native tidak tersedia.
    }
    if (maxRawBytes != null && compressed.length > maxRawBytes) {
      throw FormatException('FILE_TOO_LARGE:${compressed.length}');
    }

    final base64Str = base64Encode(compressed);
    return EncodedImageResult(
      name: file.name,
      originalBytesCount: rawBytes.length,
      compressedBytes: compressed,
      dataUri: 'data:image/jpeg;base64,$base64Str',
    );
  }
}
