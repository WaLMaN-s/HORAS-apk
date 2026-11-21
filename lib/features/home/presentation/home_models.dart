import 'dart:typed_data';

export 'package:horas/core/utils/relative_time_formatter.dart';

/// Item media foto atau video terpilih di `BER-04` / `BER-05` sebelum diunggah ke repository.
final class SelectedMediaItem {
  const SelectedMediaItem({
    required this.id,
    required this.seed,
    required this.originalBytesCount,
    this.compressedBytes,
    this.aspectRatio = 1.0,
    this.rawExifMetadata = const <String, String>{},
    this.isVideo = false,
    this.durationSeconds,
  });

  final String id;
  final String seed;
  final int originalBytesCount;
  final Uint8List? compressedBytes;
  final double aspectRatio;
  final Map<String, String> rawExifMetadata;
  final bool isVideo;
  final int? durationSeconds;

  SelectedMediaItem copyWith({
    String? seed,
    int? originalBytesCount,
    double? aspectRatio,
    Uint8List? compressedBytes,
    bool? isVideo,
    int? durationSeconds,
  }) {
    return SelectedMediaItem(
      id: id,
      seed: seed ?? this.seed,
      originalBytesCount: originalBytesCount ?? this.originalBytesCount,
      compressedBytes: compressedBytes ?? this.compressedBytes,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      rawExifMetadata: rawExifMetadata,
      isVideo: isVideo ?? this.isVideo,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
