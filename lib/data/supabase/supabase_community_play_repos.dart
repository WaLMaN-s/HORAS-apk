import 'package:clock/clock.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/data/supabase/supabase_error_mapper.dart';
import 'package:horas/data/supabase/supabase_gateway.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/repositories/repositories.dart';

/// 11. Implementasi Supabase untuk [CommunityRepository].
final class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._gw);

  final SupabaseGateway _gw;

  Future<List<Community>> _hydrateCommunities(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const <Community>[];
    final commIds = rows.map((r) => r['id'] as String).toList();
    final mgrRows = await _gw.client
        .from('community_memberships')
        .select('community_id, user_id')
        .inFilter('community_id', commIds)
        .eq('role', 'manager');

    final managersByComm = <String, List<String>>{};
    for (final m in mgrRows) {
      managersByComm
          .putIfAbsent(m['community_id'] as String, () => <String>[])
          .add(m['user_id'] as String);
    }

    return rows
        .map(
          (r) => Community(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? '',
            type: SupabaseGateway.parseCommunityType(r['type'] as String?),
            accessType: SupabaseGateway.parseCommunityAccess(
              r['access_type'] as String?,
            ),
            city: (r['city'] as String?) ?? '',
            description: (r['description'] as String?) ?? '',
            avatarSeed: (r['avatar_seed'] as String?) ?? '',
            ownerId: (r['owner_id'] as String?) ?? '',
            margaName: r['marga_name'] as String?,
            managerIds: managersByComm[r['id'] as String] ?? const <String>[],
            memberCount: (r['member_count'] as int?) ?? 1,
            isVerified: (r['is_verified'] as bool?) ?? false,
            conversationId: r['conversation_id'] as String?,
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? clock.now(),
            lastManagerActiveAt:
                SupabaseGateway.parseDate(r['last_manager_active_at']) ??
                clock.now(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Result<List<Community>>> getCommunities({
    String? city,
    CommunityType? type,
  }) => _gw.guard(() async {
    var q = _gw.client.from('communities').select();
    if (city != null && city.trim().isNotEmpty) {
      q = q.ilike('city', city.trim());
    }
    if (type != null) {
      q = q.eq('type', SupabaseGateway.communityTypeToSql(type));
    }
    final rows = await q.order('member_count', ascending: false);
    return _hydrateCommunities(rows);
  });

  @override
  Future<Result<Community>> getCommunityById(String communityId) =>
      _gw.guard(() async {
        final row = await _gw.client
            .from('communities')
            .select()
            .eq('id', communityId)
            .single();
        final hydrated = await _hydrateCommunities(<Map<String, dynamic>>[row]);
        return hydrated.first;
      });

  @override
  Future<Result<Community>> createCommunity({
    required String name,
    required CommunityType type,
    required CommunityAccessType accessType,
    required String city,
    required String description,
    String? margaName,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'create_community',
      params: <String, Object?>{
        'p_name': name,
        'p_type': SupabaseGateway.communityTypeToSql(type),
        'p_access_type': SupabaseGateway.communityAccessToSql(accessType),
        'p_city': city,
        'p_marga_name': margaName,
        'p_description': description,
      },
    );
    final hydrated = await _hydrateCommunities(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });

  @override
  Future<Result<JoinRequest?>> joinCommunity(String communityId) =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) {
          throw const PermissionDeniedError(
            message: 'Login diperlukan.',
            permissionName: 'auth',
          );
        }
        final res = await _gw.client.rpc<Map<String, dynamic>>(
          'join_community',
          params: <String, Object?>{'p_community_id': communityId},
        );
        final status = res['status'] as String?;
        if (status == 'pending' && res['requestId'] is String) {
          final me = await _gw.getBatchPersonSummaries(<String>[uid]);
          return JoinRequest(
            id: res['requestId'] as String,
            communityId: communityId,
            applicant: me[uid]!,
            status: JoinRequestStatus.pending,
            createdAt: _gw.currentTime,
            expiresAt: _gw.currentTime.add(const Duration(days: 14)),
          );
        }
        return null;
      });

  @override
  Future<Result<void>> leaveCommunity(String communityId) =>
      _gw.guard(() async {
        await _gw.client.rpc<Object?>(
          'leave_community',
          params: <String, Object?>{'p_community_id': communityId},
        );
      });

  @override
  Future<Result<List<Membership>>> getMembers(String communityId) => _gw.guard(
    () async {
      final rows = await _gw.client
          .from('community_memberships')
          .select()
          .eq('community_id', communityId)
          .order('joined_at', ascending: true);
      final people = await _gw.getBatchPersonSummaries(
        rows.map((r) => r['user_id'] as String),
      );
      return rows
          .map(
            (r) => Membership(
              id: r['id'] as String,
              communityId: communityId,
              user: people[r['user_id'] as String]!,
              role: SupabaseGateway.parseCommunityRole(r['role'] as String?),
              joinedAt:
                  SupabaseGateway.parseDate(r['joined_at']) ?? _gw.currentTime,
            ),
          )
          .toList(growable: false);
    },
  );

  @override
  Future<Result<void>> removeMember({
    required String communityId,
    required String targetUserId,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'remove_community_member',
      params: <String, Object?>{
        'p_community_id': communityId,
        'p_target_user_id': targetUserId,
      },
    );
  });

  @override
  Future<Result<List<JoinRequest>>> getMyJoinRequests() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return const <JoinRequest>[];
    final rows = await _gw.client
        .from('community_join_requests')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    final people = await _gw.getBatchPersonSummaries(<String>[uid]);
    return rows
        .map(
          (r) => JoinRequest(
            id: r['id'] as String,
            communityId: r['community_id'] as String,
            applicant: people[uid]!,
            status: SupabaseGateway.parseJoinStatus(r['status'] as String?),
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            expiresAt:
                SupabaseGateway.parseDate(r['expires_at']) ?? _gw.currentTime,
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<List<JoinRequest>>> getPendingJoinRequests(
    String communityId,
  ) => _gw.guard(() async {
    final rows = await _gw.client
        .from('community_join_requests')
        .select()
        .eq('community_id', communityId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    final people = await _gw.getBatchPersonSummaries(
      rows.map((r) => r['user_id'] as String),
    );
    return rows
        .map(
          (r) => JoinRequest(
            id: r['id'] as String,
            communityId: communityId,
            applicant: people[r['user_id'] as String]!,
            status: JoinRequestStatus.pending,
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            expiresAt:
                SupabaseGateway.parseDate(r['expires_at']) ?? _gw.currentTime,
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<void>> respondJoinRequest({
    required String joinRequestId,
    required bool approve,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'respond_community_join_request',
      params: <String, Object?>{
        'p_request_id': joinRequestId,
        'p_approve': approve,
      },
    );
  });

  @override
  Future<Result<void>> setMemberRole({
    required String communityId,
    required String targetUserId,
    required CommunityRole role,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'set_community_member_role',
      params: <String, Object?>{
        'p_community_id': communityId,
        'p_target_user_id': targetUserId,
        'p_role': SupabaseGateway.communityRoleToSql(role),
      },
    );
  });

  @override
  Future<Result<Announcement>> createAnnouncement({
    required String communityId,
    required String title,
    required String body,
    bool isPinned = false,
  }) => _gw.guard(() async {
    final r = await _gw.client.rpc<Map<String, dynamic>>(
      'create_community_announcement',
      params: <String, Object?>{
        'p_community_id': communityId,
        'p_title': title,
        'p_content': body,
        'p_is_pinned': isPinned,
      },
    );
    final authors = await _gw.getBatchPersonSummaries(<String>[
      r['author_id'] as String,
    ]);
    return Announcement(
      id: r['id'] as String,
      communityId: communityId,
      author: authors[r['author_id'] as String]!,
      title: (r['title'] as String?) ?? '',
      body: (r['content'] as String?) ?? '',
      isPinned: (r['is_pinned'] as bool?) ?? false,
      createdAt: SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
    );
  });

  @override
  Future<Result<Announcement>> togglePinAnnouncement({
    required String communityId,
    required String announcementId,
  }) => _gw.guard(() async {
    final r = await _gw.client.rpc<Map<String, dynamic>>(
      'toggle_pin_announcement',
      params: <String, Object?>{
        'p_community_id': communityId,
        'p_announcement_id': announcementId,
      },
    );
    final authors = await _gw.getBatchPersonSummaries(<String>[
      r['author_id'] as String,
    ]);
    return Announcement(
      id: r['id'] as String,
      communityId: communityId,
      author: authors[r['author_id'] as String]!,
      title: (r['title'] as String?) ?? '',
      body: (r['content'] as String?) ?? '',
      isPinned: (r['is_pinned'] as bool?) ?? false,
      createdAt: SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
    );
  });

  @override
  Future<Result<List<Announcement>>> getAnnouncements(String communityId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('community_announcements')
            .select()
            .eq('community_id', communityId)
            .order('is_pinned', ascending: false)
            .order('created_at', ascending: false);
        final authors = await _gw.getBatchPersonSummaries(
          rows.map((r) => r['author_id'] as String),
        );
        return rows
            .map(
              (r) => Announcement(
                id: r['id'] as String,
                communityId: communityId,
                author: authors[r['author_id'] as String]!,
                title: (r['title'] as String?) ?? '',
                body: (r['content'] as String?) ?? '',
                isPinned: (r['is_pinned'] as bool?) ?? false,
                createdAt:
                    SupabaseGateway.parseDate(r['created_at']) ??
                    _gw.currentTime,
              ),
            )
            .toList(growable: false);
      });

  @override
  Future<Result<Community>> transferOwnership({
    required String communityId,
    required String newOwnerUserId,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'transfer_community_ownership',
      params: <String, Object?>{
        'p_community_id': communityId,
        'p_new_owner_id': newOwnerUserId,
      },
    );
    final hydrated = await _hydrateCommunities(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });
}

/// 12. Implementasi Supabase untuk [SessionRepository] (Cache offline AC-15, AC-08, AC-09).
final class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._gw);

  final SupabaseGateway _gw;

  Future<List<PlaySession>> _hydrateSessions(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const <PlaySession>[];
    final uid = _gw.currentUserId;
    final sessionIds = rows.map((r) => r['id'] as String).toList();
    final hostIds = rows.map((r) => r['host_id'] as String).toSet();
    final courtIds = rows
        .map((r) => r['court_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final hosts = await _gw.getBatchPersonSummaries(hostIds);

    final courtNames = <String, String>{};
    if (courtIds.isNotEmpty) {
      final courts = await _gw.client
          .from('courts')
          .select('id, name')
          .inFilter('id', courtIds);
      for (final c in courts) {
        courtNames[c['id'] as String] = (c['name'] as String?) ?? '';
      }
    }

    final parts = await _gw.client
        .from('session_participants')
        .select('session_id, user_id, status')
        .inFilter('session_id', sessionIds);
    final waits = await _gw.client
        .from('session_waitlist')
        .select('session_id')
        .inFilter('session_id', sessionIds);

    final partCount = <String, int>{};
    final joinedByMe = <String>{};
    for (final p in parts) {
      final sid = p['session_id'] as String;
      if (p['status'] == 'joined') {
        partCount[sid] = (partCount[sid] ?? 0) + 1;
        if (p['user_id'] == uid) joinedByMe.add(sid);
      }
    }
    final waitCount = <String, int>{};
    for (final w in waits) {
      final sid = w['session_id'] as String;
      waitCount[sid] = (waitCount[sid] ?? 0) + 1;
    }

    return rows
        .map((r) {
          final sid = r['id'] as String;
          final cid = r['court_id'] as String?;
          final schedUpdated = SupabaseGateway.parseDate(
            r['schedule_updated_at'],
          );
          return PlaySession(
            id: sid,
            host: hosts[r['host_id'] as String]!,
            sportType: SupabaseGateway.parseSportType(r['sport'] as String?),
            title: (r['title'] as String?) ?? '',
            city: (r['city'] as String?) ?? '',
            startTime:
                SupabaseGateway.parseDate(r['start_time']) ?? _gw.currentTime,
            endTime:
                SupabaseGateway.parseDate(r['end_time']) ?? _gw.currentTime,
            maxSlots: (r['max_slots'] as int?) ?? 2,
            skillLevel: SupabaseGateway.parseSkillLevel(
              r['skill_level'] as String?,
            ),
            feePerPersonRupiah: (r['fee_per_person_rupiah'] as int?) ?? 0,
            visibility: SupabaseGateway.parseSessionVisibility(
              r['visibility'] as String?,
            ),
            joinMode: SupabaseGateway.parseSessionJoinMode(
              r['join_mode'] as String?,
            ),
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            courtId: cid,
            courtName: cid != null ? courtNames[cid] : null,
            manualLocationSummary: r['manual_location_summary'] as String?,
            manualLocationFullDetail: joinedByMe.contains(sid)
                ? r['manual_location_full_detail'] as String?
                : null,
            notes: (r['notes'] as String?) ?? '',
            communityId: r['community_id'] as String?,
            status: SupabaseGateway.parseSessionStatus(r['status'] as String?),
            participantCount: partCount[sid] ?? 1,
            waitlistCount: waitCount[sid] ?? 0,
            isJoinedByMe: joinedByMe.contains(sid),
            isUpdated: schedUpdated != null,
            scheduleUpdatedAt: schedUpdated,
            conversationId: r['conversation_id'] as String?,
          );
        })
        .toList(growable: false);
  }

  PlaySession _sessionFromCacheJson(Map<String, Object?> j) {
    SportType parseSport(String? r) => SportType.values.firstWhere(
      (e) => e.name == r,
      orElse: () => SportType.badminton,
    );
    SkillLevel parseSkill(String? r) => SkillLevel.values.firstWhere(
      (e) => e.name == r,
      orElse: () => SkillLevel.all,
    );
    SessionVisibility parseVis(String? r) =>
        SessionVisibility.values.firstWhere(
          (e) => e.name == r,
          orElse: () => SessionVisibility.publicInArea,
        );
    SessionJoinMode parseJoin(String? r) => SessionJoinMode.values.firstWhere(
      (e) => e.name == r,
      orElse: () => SessionJoinMode.instant,
    );
    SessionStatus parseSt(String? r) => SessionStatus.values.firstWhere(
      (e) => e.name == r,
      orElse: () => SessionStatus.upcoming,
    );

    return PlaySession(
      id: (j['id'] as String?) ?? '',
      host: PersonSummary.fromJson(
        ((j['host'] as Map<Object?, Object?>?) ?? const <Object?, Object?>{})
            .map((k, v) => MapEntry(k.toString(), v)),
      ),
      sportType: parseSport(j['sportType'] as String?),
      title: (j['title'] as String?) ?? '',
      city: (j['city'] as String?) ?? '',
      startTime:
          DateTime.tryParse((j['startTime'] as String?) ?? '') ?? clock.now(),
      endTime:
          DateTime.tryParse((j['endTime'] as String?) ?? '') ?? clock.now(),
      maxSlots: (j['maxSlots'] as int?) ?? 2,
      skillLevel: parseSkill(j['skillLevel'] as String?),
      feePerPersonRupiah: (j['feePerPersonRupiah'] as int?) ?? 0,
      visibility: parseVis(j['visibility'] as String?),
      joinMode: parseJoin(j['joinMode'] as String?),
      createdAt:
          DateTime.tryParse((j['createdAt'] as String?) ?? '') ?? clock.now(),
      courtId: j['courtId'] as String?,
      courtName: j['courtName'] as String?,
      manualLocationSummary: j['manualLocationSummary'] as String?,
      notes: (j['notes'] as String?) ?? '',
      communityId: j['communityId'] as String?,
      status: parseSt(j['status'] as String?),
      participantCount: (j['participantCount'] as int?) ?? 1,
      waitlistCount: (j['waitlistCount'] as int?) ?? 0,
      isJoinedByMe: (j['isJoinedByMe'] as bool?) ?? false,
      isUpdated: (j['isUpdated'] as bool?) ?? false,
      conversationId: j['conversationId'] as String?,
    );
  }

  @override
  Future<Result<List<PlaySession>>> getSessions({
    String? city,
    SportType? sportType,
    SkillLevel? skillLevel,
  }) async {
    try {
      var q = _gw.client.from('play_sessions').select();
      if (city != null && city.trim().isNotEmpty) {
        q = q.ilike('city', city.trim());
      }
      if (sportType != null) {
        q = q.eq('sport', SupabaseGateway.sportTypeToSql(sportType));
      }
      if (skillLevel != null) {
        q = q.eq('skill_level', SupabaseGateway.skillLevelToSql(skillLevel));
      }
      final rows = await q.order('start_time', ascending: true);
      final sessions = await _hydrateSessions(rows);
      if (city == null && sportType == null && skillLevel == null) {
        await _gw.cache.saveSessions(
          sessions.map((s) => s.toJson()).toList(growable: false),
        );
      }
      _gw.cache.markLiveSync();
      return Ok<List<PlaySession>>(sessions);
    } on Object catch (e, st) {
      if (SupabaseErrorMapper.isOfflineFailure(e)) {
        final cached = _gw.cache.readSessions();
        if (cached.rows.isNotEmpty) {
          _gw.cache.markServingCache(cached.cachedAt);
          return Ok<List<PlaySession>>(
            cached.rows.map(_sessionFromCacheJson).toList(growable: false),
          );
        }
      }
      return Err<List<PlaySession>>(SupabaseErrorMapper.map(e, st));
    }
  }

  @override
  Future<Result<PlaySession>> getSessionById(String sessionId) =>
      _gw.guard(() async {
        final row = await _gw.client
            .from('play_sessions')
            .select()
            .eq('id', sessionId)
            .single();
        final hydrated = await _hydrateSessions(<Map<String, dynamic>>[row]);
        return hydrated.first;
      });

  @override
  Future<Result<PlaySession>> createSession({
    required SportType sportType,
    required String title,
    required String city,
    required DateTime startTime,
    required DateTime endTime,
    required int maxSlots,
    required SkillLevel skillLevel,
    required int feePerPersonRupiah,
    required SessionVisibility visibility,
    required SessionJoinMode joinMode,
    String? courtId,
    String? manualLocationSummary,
    String? manualLocationFullDetail,
    String notes = '',
    String? communityId,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'create_session',
      params: <String, Object?>{
        'p_title': title,
        'p_sport': SupabaseGateway.sportTypeToSql(sportType),
        'p_skill_level': SupabaseGateway.skillLevelToSql(skillLevel),
        'p_start_time': startTime.toUtc().toIso8601String(),
        'p_end_time': endTime.toUtc().toIso8601String(),
        'p_max_slots': maxSlots,
        'p_fee_per_person_rupiah': feePerPersonRupiah,
        'p_notes': notes,
        'p_visibility': SupabaseGateway.sessionVisibilityToSql(visibility),
        'p_join_mode': SupabaseGateway.sessionJoinModeToSql(joinMode),
        'p_court_id': courtId,
        'p_community_id': communityId,
        'p_city': city,
        'p_manual_location_summary': manualLocationSummary,
        'p_manual_location_full_detail': manualLocationFullDetail,
      },
    );
    final hydrated = await _hydrateSessions(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });

  @override
  Future<Result<PlaySession>> updateSessionSchedule({
    required String sessionId,
    DateTime? startTime,
    DateTime? endTime,
    String? courtId,
    String? manualLocationSummary,
    String? manualLocationFullDetail,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'update_session_schedule',
      params: <String, Object?>{
        'p_session_id': sessionId,
        'p_start_time': startTime?.toUtc().toIso8601String(),
        'p_end_time': endTime?.toUtc().toIso8601String(),
        'p_court_id': courtId,
        'p_manual_location_summary': manualLocationSummary,
        'p_manual_location_full_detail': manualLocationFullDetail,
      },
    );
    final hydrated = await _hydrateSessions(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });

  @override
  Future<Result<PlaySession>> cancelSession(String sessionId) =>
      _gw.guard(() async {
        final row = await _gw.client.rpc<Map<String, dynamic>>(
          'cancel_session',
          params: <String, Object?>{'p_session_id': sessionId},
        );
        final hydrated = await _hydrateSessions(<Map<String, dynamic>>[row]);
        return hydrated.first;
      });

  @override
  Future<Result<({Participant? participant, WaitlistEntry? waitlist})>>
  joinSession(String sessionId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final res = await _gw.client.rpc<Map<String, dynamic>>(
      'join_session',
      params: <String, Object?>{'p_session_id': sessionId},
    );
    final status = res['status'] as String?;
    final meMap = await _gw.getBatchPersonSummaries(<String>[uid]);
    final me = meMap[uid]!;
    if (status == 'waitlisted') {
      final list = await getWaitlist(sessionId);
      if (list is Ok<List<WaitlistEntry>>) {
        final mine = list.value.where((w) => w.user.id == uid).toList();
        if (mine.isNotEmpty) return (participant: null, waitlist: mine.first);
      }
      return (
        participant: null,
        waitlist: WaitlistEntry(
          id: 'wl-$sessionId-$uid',
          sessionId: sessionId,
          user: me,
          position: 1,
          enqueuedAt: _gw.currentTime,
        ),
      );
    }
    return (
      participant: Participant(
        id: 'part-$sessionId-$uid',
        sessionId: sessionId,
        user: me,
        status: SupabaseGateway.parseParticipantStatus(status),
        joinedAt: _gw.currentTime,
      ),
      waitlist: null,
    );
  });

  @override
  Future<Result<void>> leaveSession(String sessionId) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'leave_session',
      params: <String, Object?>{'p_session_id': sessionId},
    );
  });

  @override
  Future<Result<void>> respondToJoinRequest({
    required String sessionId,
    required String participantId,
    required bool approve,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'respond_session_join',
      params: <String, Object?>{
        'p_session_id': sessionId,
        'p_participant_id': participantId,
        'p_approve': approve,
      },
    );
  });

  @override
  Future<Result<void>> removeParticipant({
    required String sessionId,
    required String participantId,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'remove_session_participant',
      params: <String, Object?>{
        'p_session_id': sessionId,
        'p_participant_id': participantId,
      },
    );
  });

  @override
  Future<Result<Participant>> markAttendance({
    required String sessionId,
    required String participantId,
    required bool attended,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'mark_session_attendance',
      params: <String, Object?>{
        'p_session_id': sessionId,
        'p_participant_id': participantId,
        'p_attended': attended,
      },
    );
    final people = await _gw.getBatchPersonSummaries(<String>[
      row['user_id'] as String,
    ]);
    return Participant(
      id: row['id'] as String,
      sessionId: sessionId,
      user: people[row['user_id'] as String]!,
      status: SupabaseGateway.parseParticipantStatus(row['status'] as String?),
      attended: attended,
      joinedAt: SupabaseGateway.parseDate(row['joined_at']) ?? _gw.currentTime,
      promotedFromWaitlistAt: SupabaseGateway.parseDate(
        row['promoted_from_waitlist_at'],
      ),
    );
  });

  @override
  Future<Result<List<Participant>>> getParticipants(
    String sessionId,
  ) => _gw.guard(() async {
    final rows = await _gw.client
        .from('session_participants')
        .select()
        .eq('session_id', sessionId)
        .inFilter('status', <String>['joined', 'pending_approval', 'no_show'])
        .order('joined_at', ascending: true);
    final people = await _gw.getBatchPersonSummaries(
      rows.map((r) => r['user_id'] as String),
    );
    return rows
        .map(
          (r) => Participant(
            id: r['id'] as String,
            sessionId: sessionId,
            user: people[r['user_id'] as String]!,
            status: SupabaseGateway.parseParticipantStatus(
              r['status'] as String?,
            ),
            attended: r['status'] == 'no_show' ? false : null,
            joinedAt:
                SupabaseGateway.parseDate(r['joined_at']) ?? _gw.currentTime,
            promotedFromWaitlistAt: SupabaseGateway.parseDate(
              r['promoted_from_waitlist_at'],
            ),
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<List<WaitlistEntry>>> getWaitlist(String sessionId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('session_waitlist')
            .select()
            .eq('session_id', sessionId)
            .order('queued_at', ascending: true);
        final people = await _gw.getBatchPersonSummaries(
          rows.map((r) => r['user_id'] as String),
        );
        var pos = 1;
        return rows
            .map(
              (r) => WaitlistEntry(
                id: r['id'] as String,
                sessionId: sessionId,
                user: people[r['user_id'] as String]!,
                position: pos++,
                enqueuedAt:
                    SupabaseGateway.parseDate(r['queued_at']) ??
                    _gw.currentTime,
              ),
            )
            .toList(growable: false);
      });

  Future<List<PaymentShare>> _mapShares(
    String sessionId,
    List<Map<String, dynamic>> rows,
  ) async {
    final people = await _gw.getBatchPersonSummaries(
      rows.map((r) => r['user_id'] as String),
    );
    return rows
        .map(
          (r) => PaymentShare(
            id: r['id'] as String,
            sessionId: sessionId,
            participant: people[r['user_id'] as String]!,
            amountRupiah: (r['amount_rupiah'] as int?) ?? 0,
            participantMarkedPaid: (r['is_paid'] as bool?) ?? false,
            hostConfirmedPaid: (r['is_confirmed_by_host'] as bool?) ?? false,
            updatedAt:
                SupabaseGateway.parseDate(
                  r['confirmed_at'] ?? r['marked_paid_at'],
                ) ??
                _gw.currentTime,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Result<List<PaymentShare>>> getPaymentShares(String sessionId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('session_payment_shares')
            .select()
            .eq('session_id', sessionId);
        return _mapShares(sessionId, rows);
      });

  @override
  Future<Result<List<PaymentShare>>> updatePatungan({
    required String sessionId,
    required int amountRupiah,
    required bool isTotalAmount,
  }) => _gw.guard(() async {
    final res = await _gw.client.rpc<List<Object?>>(
      'update_session_patungan',
      params: <String, Object?>{
        'p_session_id': sessionId,
        'p_amount_rupiah': amountRupiah,
        'p_is_total': isTotalAmount,
      },
    );
    return _mapShares(
      sessionId,
      res
          .whereType<Map<Object?, Object?>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
    );
  });

  @override
  Future<Result<PaymentShare>> markPaymentPaid(String paymentShareId) =>
      _gw.guard(() async {
        final r = await _gw.client.rpc<Map<String, dynamic>>(
          'mark_payment_paid',
          params: <String, Object?>{'p_share_id': paymentShareId},
        );
        final list = await _mapShares(
          r['session_id'] as String,
          <Map<String, dynamic>>[r],
        );
        return list.first;
      });

  @override
  Future<Result<PaymentShare>> confirmPaymentReceived(String paymentShareId) =>
      _gw.guard(() async {
        final r = await _gw.client.rpc<Map<String, dynamic>>(
          'confirm_payment_received',
          params: <String, Object?>{'p_share_id': paymentShareId},
        );
        final list = await _mapShares(
          r['session_id'] as String,
          <Map<String, dynamic>>[r],
        );
        return list.first;
      });

  @override
  Future<Result<List<PlaySession>>> getMySessionHistory() => _gw.guard(
    () async {
      final uid = _gw.currentUserId;
      if (uid == null) return const <PlaySession>[];
      final parts = await _gw.client
          .from('session_participants')
          .select('session_id')
          .eq('user_id', uid);
      final ids = parts.map((p) => p['session_id'] as String).toSet().toList();
      if (ids.isEmpty) return const <PlaySession>[];
      final rows = await _gw.client
          .from('play_sessions')
          .select()
          .inFilter('id', ids)
          .order('start_time', ascending: false);
      return _hydrateSessions(rows);
    },
  );

  @override
  Future<Result<List<ReliabilityMark>>> getReliabilityMarksForHost(
    String targetUserId,
  ) => _gw.guard(() async {
    final rows = await _gw.client
        .from('reliability_marks')
        .select()
        .eq('user_id', targetUserId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (r) => ReliabilityMark(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            sessionId: r['session_id'] as String,
            reason: r['reason'] == 'no_show'
                ? ReliabilityMarkReason.noShowMarkedByHost
                : ReliabilityMarkReason.lateLeaveUnder3Hours,
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
          ),
        )
        .toList(growable: false);
  });
}

/// 13. Implementasi Supabase untuk [CourtRepository].
final class SupabaseCourtRepository implements CourtRepository {
  SupabaseCourtRepository(this._gw);

  final SupabaseGateway _gw;

  Court _courtFromRow(Map<String, dynamic> r) {
    final sports =
        ((r['supported_sports'] as List<Object?>?) ?? const <Object?>[])
            .whereType<String>()
            .map(SupabaseGateway.parseSportType)
            .toList(growable: false);
    final status = switch (r['moderation_status']) {
      'pending_review' => CourtModerationStatus.pendingModeration,
      'rejected' => CourtModerationStatus.flaggedForReview,
      _ => CourtModerationStatus.approved,
    };
    return Court(
      id: r['id'] as String,
      name: (r['name'] as String?) ?? '',
      address: (r['address'] as String?) ?? '',
      city: (r['city'] as String?) ?? '',
      supportedSports: sports,
      estimatedPriceText: (r['estimated_price_text'] as String?) ?? '',
      openingHours: (r['opening_hours'] as String?) ?? '',
      imageSeed: (r['image_seed'] as String?) ?? 'court-default',
      status: status,
    );
  }

  @override
  Future<Result<List<Court>>> getCourts({String? city, SportType? sportType}) =>
      _gw.guard(() async {
        var q = _gw.client.from('courts').select();
        if (city != null && city.trim().isNotEmpty) {
          q = q.ilike('city', city.trim());
        }
        if (sportType != null) {
          q = q.contains('supported_sports', <String>[
            SupabaseGateway.sportTypeToSql(sportType),
          ]);
        }
        final rows = await q.order('name', ascending: true);
        return rows.map(_courtFromRow).toList(growable: false);
      });

  @override
  Future<Result<Court>> getCourtById(String courtId) => _gw.guard(() async {
    final row = await _gw.client
        .from('courts')
        .select()
        .eq('id', courtId)
        .single();
    return _courtFromRow(row);
  });

  @override
  Future<Result<Court>> proposeCourt({
    required String name,
    required String address,
    required String city,
    required List<SportType> supportedSports,
    required String estimatedPriceText,
    required String openingHours,
  }) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final row = await _gw.client
        .from('courts')
        .insert(<String, Object?>{
          'name': name.trim(),
          'address': address.trim(),
          'city': city.trim(),
          'supported_sports': supportedSports
              .map(SupabaseGateway.sportTypeToSql)
              .toList(growable: false),
          'estimated_price_text': estimatedPriceText.trim(),
          'opening_hours': openingHours.trim(),
          'moderation_status': 'pending_review',
          'suggested_by': uid,
        })
        .select()
        .single();
    return _courtFromRow(row);
  });
}
