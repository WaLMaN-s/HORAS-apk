import 'dart:typed_data';

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

/// Pemformat waktu relatif ringkas Bahasa Indonesia untuk kartu feed & komentar.
abstract final class RelativeTimeFormatter {
  static String format(DateTime timestamp, DateTime now) {
    final diff = now.difference(timestamp);
    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Baru saja';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt yang lalu';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} jam yang lalu';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} hari yang lalu';
    }
    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) {
      return '$weeks minggu yang lalu';
    }
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    return '$day/$month/${timestamp.year}';
  }
}
