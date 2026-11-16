import 'dart:typed_data';

export 'package:horas/core/utils/relative_time_formatter.dart';

/// Item media foto terpilih di `BER-04` / `BER-05` sebelum diunggah ke repository.
final class SelectedMediaItem {
  const SelectedMediaItem({
    required this.id,
    required this.seed,
    required this.originalBytesCount,
    this.compressedBytes,
    this.aspectRatio = 1.0,
    this.rawExifMetadata = const <String, String>{},
  });

  final String id;
  final String seed;
  final int originalBytesCount;
  final Uint8List? compressedBytes;
  final double aspectRatio;
  final Map<String, String> rawExifMetadata;

  SelectedMediaItem copyWith({
    double? aspectRatio,
    Uint8List? compressedBytes,
  }) {
    return SelectedMediaItem(
      id: id,
      seed: seed,
      originalBytesCount: originalBytesCount,
      compressedBytes: compressedBytes ?? this.compressedBytes,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      rawExifMetadata: rawExifMetadata,
    );
  }
}
