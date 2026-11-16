import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sakelar fitur Fase 2 (PRD bagian 3 & 5.1).
///
/// Seluruh flag bernilai `false` pada Fase 1 (MVP) dan baru dibuka di Prompt 12.
/// Aturan wajib: UI Fase 2 tidak boleh tampil apabila flag terkait bernilai `false`.
final class FeatureFlags {
  const FeatureFlags({
    this.stories = false,
    this.video = false,
    this.hashtags = false,
    this.church = false,
    this.events = false,
    this.partuturanDictionary = false,
    this.voiceNote = false,
    this.stickers = false,
    this.userGroups = false,
    this.recurringSessions = false,
    this.courtMap = false,
  });

  /// BER-02, BER-03, BER-R12: baris story, penampil story, buat story.
  final bool stories;

  /// BER-05, BER-R2: unggah & putar video di postingan/story.
  final bool video;

  /// BER-01, BER-04: tagar (#hashtag) di postingan & pencarian.
  final bool hashtags;

  /// SEK-10, SEK-11, SEK-R13: direktori gereja & verifikasi gereja.
  final bool church;

  /// SEK-09, SEK-R12: detail kegiatan komunitas/gereja & RSVP.
  final bool events;

  /// TAR-08: kamus partuturan.
  final bool partuturanDictionary;

  /// PSN-R3: pesan suara (voice note) di chat.
  final bool voiceNote;

  /// PSN-R3: stiker di chat.
  final bool stickers;

  /// PSN-R5: grup chat buatan pengguna (di luar grup komunitas/sesi otomatis).
  final bool userGroups;

  /// MAN-03: sesi olahraga berulang.
  final bool recurringSessions;

  /// MAN-07: tampilan peta lapangan.
  final bool courtMap;

  FeatureFlags copyWith({
    bool? stories,
    bool? video,
    bool? hashtags,
    bool? church,
    bool? events,
    bool? partuturanDictionary,
    bool? voiceNote,
    bool? stickers,
    bool? userGroups,
    bool? recurringSessions,
    bool? courtMap,
  }) {
    return FeatureFlags(
      stories: stories ?? this.stories,
      video: video ?? this.video,
      hashtags: hashtags ?? this.hashtags,
      church: church ?? this.church,
      events: events ?? this.events,
      partuturanDictionary: partuturanDictionary ?? this.partuturanDictionary,
      voiceNote: voiceNote ?? this.voiceNote,
      stickers: stickers ?? this.stickers,
      userGroups: userGroups ?? this.userGroups,
      recurringSessions: recurringSessions ?? this.recurringSessions,
      courtMap: courtMap ?? this.courtMap,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlags &&
          other.stories == stories &&
          other.video == video &&
          other.hashtags == hashtags &&
          other.church == church &&
          other.events == events &&
          other.partuturanDictionary == partuturanDictionary &&
          other.voiceNote == voiceNote &&
          other.stickers == stickers &&
          other.userGroups == userGroups &&
          other.recurringSessions == recurringSessions &&
          other.courtMap == courtMap;

  @override
  int get hashCode => Object.hash(
    stories,
    video,
    hashtags,
    church,
    events,
    partuturanDictionary,
    voiceNote,
    stickers,
    userGroups,
    recurringSessions,
    courtMap,
  );
}

/// Provider global untuk [FeatureFlags].
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return const FeatureFlags();
});
