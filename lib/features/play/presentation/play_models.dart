import 'package:horas/domain/models/models.dart';

/// Filter rentang hari pada daftar sesi Main (`MAN-02`).
enum PlayDayFilter { all, today, tomorrow, weekend }

/// Filter biaya sesi pada daftar sesi Main (`MAN-02`).
enum PlayCostFilter { all, freeOnly, paidOnly }

/// Filter gabungan untuk `MAN-01` dan `MAN-02`.
final class PlaySessionFilter {
  const PlaySessionFilter({
    this.sportType,
    this.skillLevel,
    this.dayFilter = PlayDayFilter.all,
    this.rangeFilter,
    this.costFilter = PlayCostFilter.all,
  });

  final SportType? sportType;
  final SkillLevel? skillLevel;
  final PlayDayFilter dayFilter;
  final AreaProximity? rangeFilter;
  final PlayCostFilter costFilter;

  bool get hasActiveFilters =>
      sportType != null ||
      skillLevel != null ||
      dayFilter != PlayDayFilter.all ||
      rangeFilter != null ||
      costFilter != PlayCostFilter.all;

  int get activeFilterCount {
    var count = 0;
    if (sportType != null) count++;
    if (skillLevel != null) count++;
    if (dayFilter != PlayDayFilter.all) count++;
    if (rangeFilter != null) count++;
    if (costFilter != PlayCostFilter.all) count++;
    return count;
  }

  PlaySessionFilter copyWith({
    SportType? sportType,
    bool clearSportType = false,
    SkillLevel? skillLevel,
    bool clearSkillLevel = false,
    PlayDayFilter? dayFilter,
    AreaProximity? rangeFilter,
    bool clearRangeFilter = false,
    PlayCostFilter? costFilter,
  }) {
    return PlaySessionFilter(
      sportType: clearSportType ? null : (sportType ?? this.sportType),
      skillLevel: clearSkillLevel ? null : (skillLevel ?? this.skillLevel),
      dayFilter: dayFilter ?? this.dayFilter,
      rangeFilter: clearRangeFilter ? null : (rangeFilter ?? this.rangeFilter),
      costFilter: costFilter ?? this.costFilter,
    );
  }
}

/// Formatter lokal ringkas untuk tampilan waktu dan biaya Rupiah pada modul Main.
abstract final class PlayFormatters {
  static String formatRupiah(int amount, {String freeLabel = 'Gratis'}) {
    if (amount <= 0) return freeLabel;
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      if (i > 0 && posFromEnd % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return 'Rp$buffer';
  }

  static String formatTimeWindow(DateTime start, DateTime end) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(start.day)}/${two(start.month)} · ${two(start.hour)}:${two(start.minute)}–${two(end.hour)}:${two(end.minute)}';
  }

  static String formatClockTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
