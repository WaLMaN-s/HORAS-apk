import 'package:clock/clock.dart';

/// Pembuat kode referensi singkat untuk status error server (PRD 5.2).
abstract final class ReferenceCode {
  static String generate({String prefix = 'HRS', int? seed}) {
    final now = clock.now().toUtc();
    final raw = seed ?? now.millisecondsSinceEpoch;
    final token = (raw.abs() % 0xFFFFFF)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(6, '0');
    return '$prefix-$token';
  }
}
