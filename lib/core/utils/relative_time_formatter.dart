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
