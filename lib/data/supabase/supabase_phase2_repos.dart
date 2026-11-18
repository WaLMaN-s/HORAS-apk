import 'dart:async';

import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/data/supabase/supabase_gateway.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/repositories/repositories.dart';

/// Implementasi Supabase untuk [StoryRepository] (BER-02, BER-03, BER-R12).
final class SupabaseStoryRepository implements StoryRepository {
  const SupabaseStoryRepository(this._gw);

  final SupabaseGateway _gw;

  Future<List<Story>> _hydrateStories(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const <Story>[];
    final authorIds = rows
        .map((r) => (r['author_id'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final authors = await _gw.getBatchPersonSummaries(authorIds);
    final me = _gw.currentSessionProfile;

    final result = <Story>[];
    for (final r in rows) {
      final raw = Story.fromJson(r);
      final authorId = (r['author_id'] as String?) ?? raw.author.id;
      var author =
          authors[authorId] ?? SupabaseGateway.deletedPersonFallback(authorId);
      if (me != null && authorId == me.id) {
        author = author.copyWith(
          displayName: me.displayName,
          avatarSeed: me.avatarSeed,
          city: me.city,
        );
      }
      result.add(
        Story(
          id: raw.id,
          author: author,
          mediaSeed: raw.mediaSeed,
          caption: raw.caption,
          isVideo: raw.isVideo,
          durationSeconds: raw.durationSeconds,
          createdAt: raw.createdAt,
          expiresAt: raw.expiresAt,
          viewerCount: raw.viewerCount,
          isViewedByMe: raw.isViewedByMe,
        ),
      );
    }
    return result;
  }

  @override
  Future<Result<List<Story>>> getStories() => _gw.guard(() async {
    final rows = await _gw.client
        .from('stories')
        .select()
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false);

    return _hydrateStories(rows);
  });

  @override
  Future<Result<Story>> createStory({
    required String mediaSeed,
    required bool isVideo,
    required int durationSeconds,
    String caption = '',
  }) => _gw.guard(() async {
    final me = _gw.currentSessionProfile;
    if (me == null) {
      throw const PermissionDeniedError(
        message: 'Sesi berakhir.',
        permissionName: 'auth',
      );
    }
    if (durationSeconds > 15) {
      throw const ValidationError(
        message: 'Durasi video story maksimal 15 detik (BER-R12).',
        field: 'durationSeconds',
      );
    }

    final uploaded = await _gw.mediaUploader.uploadWithRetryAndResume(
      bucket: 'posts',
      sourcePathOrSeed: mediaSeed,
    );
    final storedSeed = uploaded.publicUrl ?? uploaded.storagePath;

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));
    final row = await _gw.client
        .from('stories')
        .insert(<String, Object?>{
          'author_id': me.id,
          'media_seed': storedSeed,
          'caption': caption,
          'is_video': isVideo,
          'duration_seconds': durationSeconds,
          'expires_at': expiresAt.toIso8601String(),
        })
        .select()
        .single();

    final hydrated = await _hydrateStories(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });

  @override
  Future<Result<List<StoryViewer>>> getStoryViewers(String storyId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('story_views')
            .select()
            .eq('story_id', storyId)
            .order('viewed_at', ascending: false);
        if (rows.isEmpty) return const <StoryViewer>[];
        final viewerIds = rows
            .map((r) => (r['viewer_id'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        final viewers = await _gw.getBatchPersonSummaries(viewerIds);

        return rows
            .map((r) {
              final raw = StoryViewer.fromJson(r);
              final vid = (r['viewer_id'] as String?) ?? raw.viewer.id;
              return StoryViewer(
                id: raw.id,
                storyId: raw.storyId,
                viewer:
                    viewers[vid] ?? SupabaseGateway.deletedPersonFallback(vid),
                viewedAt: raw.viewedAt,
              );
            })
            .toList(growable: false);
      });

  @override
  Future<Result<void>> markStoryViewed(String storyId) => _gw.guard(() async {
    final me = _gw.currentSessionProfile;
    if (me == null) return;
    await _gw.client.from('story_views').upsert(<String, Object?>{
      'story_id': storyId,
      'viewer_id': me.id,
      'viewed_at': DateTime.now().toIso8601String(),
    });
  });

  @override
  Future<Result<void>> deleteStory(String storyId) => _gw.guard(() async {
    await _gw.client.from('stories').delete().eq('id', storyId);
  });
}

/// Implementasi Supabase untuk [EventRepository] (SEK-09, SEK-R12).
final class SupabaseEventRepository implements EventRepository {
  const SupabaseEventRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<List<CommunityEvent>>> getEvents(String communityId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('community_events')
            .select()
            .eq('community_id', communityId)
            .order('start_time');

        return rows
            .map((r) => CommunityEvent.fromJson(r))
            .toList(growable: false);
      });

  @override
  Future<Result<CommunityEvent>> getEventById(String eventId) =>
      _gw.guard(() async {
        final row = await _gw.client
            .from('community_events')
            .select()
            .eq('id', eventId)
            .single();

        return CommunityEvent.fromJson(row);
      });

  @override
  Future<Result<CommunityEvent>> createEvent({
    required String communityId,
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String locationName,
    String? mapLink,
    int? capacity,
  }) => _gw.guard(() async {
    if (startTime.isBefore(DateTime.now())) {
      throw const ValidationError(
        message:
            'Waktu mulai kegiatan tidak dapat dibuat di masa lampau (SEK-R12).',
        field: 'startTime',
      );
    }

    final row = await _gw.client
        .from('community_events')
        .insert(<String, Object?>{
          'community_id': communityId,
          'title': title,
          'description': description,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'location_name': locationName,
          'map_link': mapLink,
          'capacity': capacity,
          'is_cancelled': false,
        })
        .select()
        .single();

    return CommunityEvent.fromJson(row);
  });

  @override
  Future<Result<CommunityEvent>> cancelEvent(String eventId) =>
      _gw.guard(() async {
        final row = await _gw.client
            .from('community_events')
            .update(<String, Object?>{'is_cancelled': true})
            .eq('id', eventId)
            .select()
            .single();

        return CommunityEvent.fromJson(row);
      });

  @override
  Future<Result<CommunityEvent>> rsvpEvent({
    required String eventId,
    required EventRsvpStatus status,
  }) => _gw.guard(() async {
    final me = _gw.currentSessionProfile;
    if (me == null) {
      throw const PermissionDeniedError(
        message: 'Sesi berakhir.',
        permissionName: 'auth',
      );
    }

    await _gw.client.from('event_rsvps').upsert(<String, Object?>{
      'event_id': eventId,
      'user_id': me.id,
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    });

    final row = await _gw.client
        .from('community_events')
        .select()
        .eq('id', eventId)
        .single();

    return CommunityEvent.fromJson(row).copyWith(myRsvp: status);
  });

  @override
  Future<Result<List<EventAttendee>>> getEventAttendees(String eventId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('event_rsvps')
            .select()
            .eq('event_id', eventId);

        return rows
            .map(
              (r) => EventAttendee(
                id: (r['id'] as String?) ?? '',
                eventId: eventId,
                user: PersonSummary.fromJson(
                  r['user'] is Map<String, Object?>
                      ? r['user'] as Map<String, Object?>
                      : const <String, Object?>{},
                ),
                status: EventRsvpStatus.values.firstWhere(
                  (s) => s.name == r['status'],
                  orElse: () => EventRsvpStatus.none,
                ),
                updatedAt:
                    DateTime.tryParse((r['updated_at'] as String?) ?? '') ??
                    DateTime.now(),
              ),
            )
            .toList(growable: false);
      });
}

/// Implementasi Supabase untuk [ChurchRepository] (SEK-10, SEK-11, SEK-R13).
final class SupabaseChurchRepository implements ChurchRepository {
  const SupabaseChurchRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<List<Church>>> getChurches({
    String? city,
    ChurchDenomination? denomination,
    String? query,
  }) => _gw.guard(() async {
    var q = _gw.client.from('churches').select();
    if (city != null && city.trim().isNotEmpty) {
      q = q.ilike('city', city.trim());
    }
    if (denomination != null) {
      q = q.eq('denomination', denomination.name);
    }
    if (query != null && query.trim().isNotEmpty) {
      final clean = query.trim();
      q = q.or('name.ilike.%$clean%,city.ilike.%$clean%');
    }
    final rows = await q.order('name');
    return rows.map((r) => Church.fromJson(r)).toList(growable: false);
  });

  @override
  Future<Result<Church>> getChurchById(String churchId) => _gw.guard(() async {
    final row = await _gw.client
        .from('churches')
        .select()
        .eq('id', churchId)
        .single();

    return Church.fromJson(row);
  });

  @override
  Future<Result<Church>> proposeChurch({
    required String name,
    required ChurchDenomination denomination,
    required String address,
    required String city,
    required List<ChurchServiceSchedule> serviceSchedules,
    String contactPhone = '',
    String contactEmail = '',
    double? latitude,
    double? longitude,
  }) => _gw.guard(() async {
    final payload = <String, Object?>{
      'name': name,
      'denomination': denomination.name,
      'address': address,
      'city': city,
      'service_schedules': serviceSchedules.map((s) => s.toJson()).toList(),
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'is_verified': false,
      'member_count': 1,
    };
    if (latitude != null && longitude != null) {
      payload['latitude'] = latitude;
      payload['longitude'] = longitude;
    }
    final row = await _gw.client
        .from('churches')
        .insert(payload)
        .select()
        .single();

    return Church.fromJson(row);
  });

  @override
  Future<Result<Church>> setMyHomeChurch(
    String churchId, {
    bool isVisible = false,
  }) => _gw.guard(() async {
    final me = _gw.currentSessionProfile;
    if (me != null) {
      await _gw.client
          .from('profiles')
          .update(<String, Object?>{
            'home_church_id': churchId,
            'is_home_church_visible': isVisible,
          })
          .eq('id', me.id);
    }
    final row = await _gw.client
        .from('churches')
        .select()
        .eq('id', churchId)
        .single();
    return Church.fromJson(row)
        .copyWith(isUserHomeChurch: true, isHomeChurchVisible: isVisible);
  });

  @override
  Future<Result<List<CommunityEvent>>> getChurchEvents(String churchId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('community_events')
            .select()
            .eq('community_id', churchId)
            .order('start_time');
        return rows
            .map((r) => CommunityEvent.fromJson(r))
            .toList(growable: false);
      });
}

/// Implementasi Supabase untuk [PartuturanDictionaryRepository] (TAR-08, TAR-R6).
final class SupabasePartuturanDictionaryRepository
    implements PartuturanDictionaryRepository {
  const SupabasePartuturanDictionaryRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<List<PartuturanDictionaryEntry>>> searchEntries({
    String query = '',
    SubEthnic? subEthnic,
  }) => _gw.guard(() async {
    var q = _gw.client.from('partuturan_dictionary').select();
    if (subEthnic != null) {
      q = q.eq('sub_ethnic', subEthnic.name);
    }
    if (query.trim().isNotEmpty) {
      final clean = query.trim();
      q = q.or('term.ilike.%$clean%,meaning.ilike.%$clean%');
    }
    final rows = await q.order('term');
    return rows
        .map((r) => PartuturanDictionaryEntry.fromJson(r))
        .toList(growable: false);
  });

  @override
  PartuturanRuleStatus getSubEthnicStatus(SubEthnic subEthnic) {
    return subEthnic == SubEthnic.toba
        ? PartuturanRuleStatus.active
        : PartuturanRuleStatus.neutral;
  }
}
