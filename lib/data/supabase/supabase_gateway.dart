import 'dart:async';

import 'package:clock/clock.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/data/supabase/supabase_error_mapper.dart';
import 'package:horas/data/supabase/supabase_media_uploader.dart';
import 'package:horas/data/supabase/supabase_offline_cache.dart';
import 'package:horas/data/supabase/supabase_partuturan_service.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gerbang bersama untuk seluruh repository Supabase: memegang client, cache offline,
/// pengunggah media EXIF-stripped, layanan Partuturan, dan mapper DTO/enum domain.
final class SupabaseGateway {
  SupabaseGateway({
    required this.client,
    required this.prefs,
    required this.appConfig,
    SupabaseOfflineCache? cache,
    SupabaseMediaUploader? mediaUploader,
    SupabasePartuturanService? partuturanService,
  }) {
    this.cache = cache ?? SupabaseOfflineCache(prefs);
    this.mediaUploader =
        mediaUploader ??
        SupabaseMediaUploader(client: client, cache: this.cache);
    this.partuturanService =
        partuturanService ??
        SupabasePartuturanService(
          client: client,
          cache: this.cache,
          appConfig: appConfig,
        );
  }

  final SupabaseClient client;
  final SharedPreferences? prefs;
  final AppConfig appConfig;
  late final SupabaseOfflineCache cache;
  late final SupabaseMediaUploader mediaUploader;
  late final SupabasePartuturanService partuturanService;

  Profil? currentSessionProfile;
  bool hadDeletionRecentlyCancelled = false;
  int cachedUnreadMessages = 0;
  int cachedUnreadNotifications = 0;

  final Map<String, String> _signedUrlCache = <String, String>{};
  final Map<String, PersonSummary> _personCache = <String, PersonSummary>{};

  String? get currentUserId =>
      client.auth.currentUser?.id ?? currentSessionProfile?.id;
  DateTime get currentTime => clock.now().toUtc();

  Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Ok<T>(result);
    } on Object catch (e, st) {
      return Err<T>(SupabaseErrorMapper.map(e, st));
    }
  }

  /// Mengambil banyak [PersonSummary] aman privasi sekaligus lewat RPC `get_batch_person_summaries`.
  Future<Map<String, PersonSummary>> getBatchPersonSummaries(
    Iterable<String> userIds,
  ) async {
    final unique = userIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (unique.isEmpty) return <String, PersonSummary>{};

    final missing = unique
        .where((id) => !_personCache.containsKey(id))
        .toList();
    if (missing.isNotEmpty) {
      try {
        final res = await client.rpc<List<Object?>>(
          'get_batch_person_summaries',
          params: <String, Object?>{'p_ids': missing},
        );
        for (final item in res) {
          if (item is Map) {
            final json = item.map((k, v) => MapEntry(k.toString(), v));
            final person = PersonSummary.fromJson(json);
            _personCache[person.id] = person;
          }
        }
      } on Object {
        // Fallback aman bila sebagian profil tidak ditemukan / offline.
      }
    }

    final result = <String, PersonSummary>{};
    for (final id in unique) {
      result[id] = _personCache[id] ?? deletedPersonFallback(id);
    }
    return result;
  }

  void invalidatePersonCache([String? userId]) {
    if (userId == null) {
      _personCache.clear();
    } else {
      _personCache.remove(userId);
    }
  }

  Future<String> resolveStorageUrl(String bucket, String pathOrSeed) async {
    if (pathOrSeed.isEmpty ||
        pathOrSeed.startsWith('data:image/') ||
        pathOrSeed.startsWith('http://') ||
        pathOrSeed.startsWith('https://') ||
        !pathOrSeed.contains('/')) {
      return pathOrSeed;
    }
    final key = '$bucket::$pathOrSeed';
    final cached = _signedUrlCache[key];
    if (cached != null) return cached;

    if (bucket == 'avatars') {
      final pub = client.storage.from('avatars').getPublicUrl(pathOrSeed);
      _signedUrlCache[key] = pub;
      return pub;
    }
    try {
      final signed = await client.storage
          .from(bucket)
          .createSignedUrl(pathOrSeed, 3600);
      _signedUrlCache[key] = signed;
      return signed;
    } on Object {
      return pathOrSeed;
    }
  }

  // ── Pemetaan Domain DTO ───────────────────────────────────────────────────

  static PersonSummary deletedPersonFallback([String id = 'deleted']) {
    return PersonSummary(
      id: id,
      displayName: 'Pengguna terhapus',
      gender: UserGender.male,
      marga: '-',
      subEthnic: SubEthnic.toba,
      city: '',
      proximity: AreaProximity.diKotamu,
      avatarSeed: 'deleted-user',
    );
  }

  Profil profileFromRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? privacyRow,
  }) {
    final privacy = privacyRow != null
        ? privacyFromRow(privacyRow)
        : const PrivacySettings();

    return Profil(
      id: row['id'] as String,
      phoneE164: (row['phone_e164'] as String?) ?? '',
      email: row['email'] as String?,
      displayName: (row['display_name'] as String?) ?? '',
      gender: parseGender(row['gender'] as String?),
      birthYear: (row['birth_year'] as int?) ?? 1998,
      marga: (row['marga'] as String?) ?? '',
      isMargaVerified: !((row['is_custom_marga'] as bool?) ?? false),
      subEthnic: parseSubEthnic(row['sub_ethnic'] as String?),
      motherMarga: row['mother_marga'] as String?,
      city: (row['city'] as String?) ?? '',
      subdistrict: (row['subdistrict'] as String?) ?? '',
      sundut: row['sundut'] as int?,
      homeChurchName: row['home_church'] as String?,
      bio: (row['bio'] as String?) ?? '',
      hobbies: ((row['hobbies'] as List<Object?>?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      campusOrOffice: row['campus_or_office'] as String?,
      websiteUrl: row['website_url'] as String?,
      avatarSeed:
          (row['avatar_path'] as String?) ??
          (row['avatar_seed'] as String?) ??
          'avatar',
      createdAt: parseDate(row['created_at']) ?? clock.now(),
      accountStatus: parseAccountStatus(row['account_status'] as String?),
      lastDisplayNameChangedAt: parseDate(row['display_name_changed_at']),
      followersCount: (row['followers_count'] as int?) ?? 0,
      followingCount: (row['following_count'] as int?) ?? 0,
      connectionsCount: (row['connections_count'] as int?) ?? 0,
      onboardingCompleted: (row['onboarding_completed'] as bool?) ?? false,
      privacySettings: privacy,
    );
  }

  PrivacySettings privacyFromRow(Map<String, dynamic> row) {
    return PrivacySettings(
      motherMarga: parseFieldVisibility(
        row['mother_marga'] as String?,
        FieldVisibility.connectedOnly,
      ),
      showAgeGroup: (row['show_age_group'] as bool?) ?? false,
      subdistrict: parseFieldVisibility(
        row['subdistrict'] as String?,
        FieldVisibility.connectedOnly,
      ),
      joinedCommunities: parseFieldVisibility(
        row['joined_communities'] as String?,
        FieldVisibility.connectedOnly,
      ),
      homeChurch: parseFieldVisibility(
        row['home_church'] as String?,
        FieldVisibility.onlyMe,
      ),
      tarombo: parseFieldVisibility(
        row['tarombo'] as String?,
        FieldVisibility.onlyMe,
      ),
      discoverableInNearbyAndSearch:
          (row['discoverable_in_nearby_and_search'] as bool?) ?? true,
      whoCanSendConnectionRequest: parseConnectionAllowance(
        row['who_can_send_connection_request'] as String?,
      ),
      allowMessagesFromSharedContext:
          (row['allow_messages_from_shared_context'] as bool?) ?? true,
      sendReadReceipts: (row['send_read_receipts'] as bool?) ?? true,
      accountType: row['account_type'] == 'private_account'
          ? AccountVisibilityType.privateAccount
          : AccountVisibilityType.publicAccount,
    );
  }

  Map<String, Object?> privacyToRow(String userId, PrivacySettings s) =>
      <String, Object?>{
        'user_id': userId,
        'mother_marga': fieldVisibilityToSql(s.motherMarga),
        'show_age_group': s.showAgeGroup,
        'subdistrict': fieldVisibilityToSql(s.subdistrict),
        'joined_communities': fieldVisibilityToSql(s.joinedCommunities),
        'home_church': fieldVisibilityToSql(s.homeChurch),
        'tarombo': fieldVisibilityToSql(s.tarombo),
        'discoverable_in_nearby_and_search': s.discoverableInNearbyAndSearch,
        'who_can_send_connection_request': connectionAllowanceToSql(
          s.whoCanSendConnectionRequest,
        ),
        'allow_messages_from_shared_context': s.allowMessagesFromSharedContext,
        'send_read_receipts': s.sendReadReceipts,
        'account_type': s.accountType == AccountVisibilityType.privateAccount
            ? 'private_account'
            : 'public_account',
      };

  // ── Enum Helpers ──────────────────────────────────────────────────────────

  static DateTime? parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  static UserGender parseGender(String? raw) =>
      raw == 'female' ? UserGender.female : UserGender.male;

  static SubEthnic parseSubEthnic(String? raw) {
    for (final s in SubEthnic.values) {
      if (s.name == raw) return s;
    }
    return SubEthnic.toba;
  }

  static AccountStatus parseAccountStatus(String? raw) => switch (raw) {
    'restricted' => AccountStatus.restricted,
    'suspended' => AccountStatus.suspended,
    'permanently_banned' => AccountStatus.permanentlyBanned,
    _ => AccountStatus.active,
  };

  static FieldVisibility parseFieldVisibility(
    String? raw,
    FieldVisibility fallback,
  ) => switch (raw) {
    'everyone' => FieldVisibility.everyone,
    'connected_only' => FieldVisibility.connectedOnly,
    'only_me' => FieldVisibility.onlyMe,
    _ => fallback,
  };

  static String fieldVisibilityToSql(FieldVisibility v) => switch (v) {
    FieldVisibility.everyone => 'everyone',
    FieldVisibility.connectedOnly => 'connected_only',
    FieldVisibility.onlyMe => 'only_me',
  };

  static ConnectionRequestAllowance parseConnectionAllowance(String? raw) =>
      switch (raw) {
        'same_community' => ConnectionRequestAllowance.sameCommunity,
        'no_one' => ConnectionRequestAllowance.noOne,
        _ => ConnectionRequestAllowance.everyone,
      };

  static String connectionAllowanceToSql(ConnectionRequestAllowance a) =>
      switch (a) {
        ConnectionRequestAllowance.everyone => 'everyone',
        ConnectionRequestAllowance.sameCommunity => 'same_community',
        ConnectionRequestAllowance.noOne => 'no_one',
      };

  static PostVisibility parsePostVisibility(String? raw) => switch (raw) {
    'kenalan' => PostVisibility.followersOnly,
    'komunitas' => PostVisibility.specificCommunities,
    _ => PostVisibility.publicPost,
  };

  static String postVisibilityToSql(PostVisibility v) => switch (v) {
    PostVisibility.publicPost => 'publik',
    PostVisibility.followersOnly => 'kenalan',
    PostVisibility.specificCommunities => 'komunitas',
  };

  static PostModerationStatus parsePostModeration(String? raw) => switch (raw) {
    'under_review' => PostModerationStatus.underReview,
    'removed' => PostModerationStatus.removed,
    _ => PostModerationStatus.published,
  };

  static CommunityType parseCommunityType(String? raw) => switch (raw) {
    'punguan_marga' => CommunityType.punguanMarga,
    'kota' => CommunityType.city,
    'kampus_profesi' => CommunityType.campusOrProfession,
    _ => CommunityType.interest,
  };

  static String communityTypeToSql(CommunityType t) => switch (t) {
    CommunityType.punguanMarga => 'punguan_marga',
    CommunityType.city => 'kota',
    CommunityType.campusOrProfession => 'kampus_profesi',
    CommunityType.interest || CommunityType.church => 'minat',
  };

  static CommunityAccessType parseCommunityAccess(String? raw) => switch (raw) {
    'approval_required' => CommunityAccessType.approvalRequired,
    'closed' => CommunityAccessType.closed,
    _ => CommunityAccessType.open,
  };

  static String communityAccessToSql(CommunityAccessType a) => switch (a) {
    CommunityAccessType.open => 'open',
    CommunityAccessType.approvalRequired => 'approval_required',
    CommunityAccessType.closed => 'closed',
  };

  static CommunityRole parseCommunityRole(String? raw) => switch (raw) {
    'owner' => CommunityRole.owner,
    'manager' => CommunityRole.manager,
    _ => CommunityRole.member,
  };

  static String communityRoleToSql(CommunityRole r) => r.name;

  static JoinRequestStatus parseJoinStatus(String? raw) => switch (raw) {
    'approved' => JoinRequestStatus.approved,
    'rejected' => JoinRequestStatus.rejected,
    'expired' => JoinRequestStatus.expired,
    _ => JoinRequestStatus.pending,
  };

  static SportType parseSportType(String? raw) => switch (raw) {
    'futsal' => SportType.futsal,
    'voli' => SportType.volleyball,
    'basket' => SportType.basketball,
    'tenis_meja' => SportType.tableTennis,
    'jogging' => SportType.jogging,
    'lainnya' => SportType.other,
    _ => SportType.badminton,
  };

  static String sportTypeToSql(SportType s) => switch (s) {
    SportType.badminton => 'badminton',
    SportType.futsal => 'futsal',
    SportType.volleyball => 'voli',
    SportType.basketball => 'basket',
    SportType.tableTennis => 'tenis_meja',
    SportType.jogging => 'jogging',
    SportType.other => 'lainnya',
  };

  static SkillLevel parseSkillLevel(String? raw) => switch (raw) {
    'pemula' => SkillLevel.beginner,
    'menengah' => SkillLevel.intermediate,
    'mahir' => SkillLevel.advanced,
    _ => SkillLevel.all,
  };

  static String skillLevelToSql(SkillLevel l) => switch (l) {
    SkillLevel.beginner => 'pemula',
    SkillLevel.intermediate => 'menengah',
    SkillLevel.advanced => 'mahir',
    SkillLevel.all => 'santai',
  };

  static SessionVisibility parseSessionVisibility(String? raw) => switch (raw) {
    'komunitas' => SessionVisibility.communityOnly,
    'kenalan' => SessionVisibility.inviteOnly,
    _ => SessionVisibility.publicInArea,
  };

  static String sessionVisibilityToSql(SessionVisibility v) => switch (v) {
    SessionVisibility.publicInArea => 'terbuka',
    SessionVisibility.communityOnly => 'komunitas',
    SessionVisibility.inviteOnly => 'kenalan',
  };

  static SessionJoinMode parseSessionJoinMode(String? raw) =>
      raw == 'persetujuan_host'
      ? SessionJoinMode.hostApproval
      : SessionJoinMode.instant;

  static String sessionJoinModeToSql(SessionJoinMode m) =>
      m == SessionJoinMode.hostApproval ? 'persetujuan_host' : 'langsung_masuk';

  static SessionStatus parseSessionStatus(String? raw) => switch (raw) {
    'selesai' => SessionStatus.completed,
    'dibatalkan' => SessionStatus.cancelled,
    _ => SessionStatus.upcoming,
  };

  static ParticipantStatus parseParticipantStatus(String? raw) => switch (raw) {
    'pending_approval' => ParticipantStatus.pendingHostApproval,
    'rejected' || 'left_before_start' || 'no_show' => ParticipantStatus.removed,
    _ => ParticipantStatus.joined,
  };

  static ConversationType parseConversationType(String? raw) => switch (raw) {
    'community' => ConversationType.communityGroup,
    'session' => ConversationType.sessionGroup,
    _ => ConversationType.direct,
  };

  static FamilyRelationType parseFamilyRelation(String? raw) => switch (raw) {
    'ayah' => FamilyRelationType.father,
    'ibu' => FamilyRelationType.mother,
    'opung_suhut' => FamilyRelationType.paternalGrandfather,
    'opung_bao' => FamilyRelationType.maternalGrandfather,
    _ => FamilyRelationType.otherAncestor,
  };

  static String familyRelationToSql(FamilyRelationType r) => switch (r) {
    FamilyRelationType.father => 'ayah',
    FamilyRelationType.mother => 'ibu',
    FamilyRelationType.paternalGrandfather => 'opung_suhut',
    FamilyRelationType.maternalGrandfather => 'opung_bao',
    FamilyRelationType.otherAncestor => 'saudara_kandung',
  };

  static LifeStatus parseLifeStatus(String? raw) =>
      raw == 'almarhum' ? LifeStatus.deceased : LifeStatus.alive;

  static NotificationType parseNotificationType(
    String? rawCategory,
    String? actionRoute,
  ) {
    final route = actionRoute ?? '';
    if (rawCategory == 'sistem_keamanan') {
      return route.contains('/appeal') || route.contains('/strikes')
          ? NotificationType.moderationAction
          : NotificationType.accountSecurity;
    }
    if (rawCategory == 'pesan') {
      return route.contains('requests')
          ? NotificationType.messageRequestReceived
          : NotificationType.newMessage;
    }
    if (rawCategory == 'main_olahraga') {
      return NotificationType.sessionJoinOrWaitlistPromoted;
    }
    if (rawCategory == 'komunitas') {
      return NotificationType.communityAnnouncement;
    }
    return NotificationType.connectionAccepted;
  }

  static String notificationTypeToSql(NotificationType t) => switch (t) {
    NotificationType.accountSecurity ||
    NotificationType.moderationAction => 'sistem_keamanan',
    NotificationType.newMessage ||
    NotificationType.messageRequestReceived => 'pesan',
    NotificationType.sessionJoinOrWaitlistPromoted ||
    NotificationType.sessionUpdatedOrCancelled ||
    NotificationType.sessionReminder => 'main_olahraga',
    NotificationType.communityJoinRequest ||
    NotificationType.communityJoinApproved ||
    NotificationType.communityAnnouncement ||
    NotificationType.eventReminder => 'komunitas',
    _ => 'sosial',
  };

  static String reportTargetToSql(ReportTargetType t) => switch (t) {
    ReportTargetType.church => 'court',
    _ => t.name,
  };

  static ReportTargetType parseReportTarget(String? raw) {
    for (final v in ReportTargetType.values) {
      if (v.name == raw) return v;
    }
    return ReportTargetType.post;
  }

  static String reportCategoryToSql(ReportCategory c) => switch (c) {
    ReportCategory.saraHateSpeech => 'ujaran_kebencian_sara',
    ReportCategory.harassment => 'pelecehan',
    ReportCategory.spamScam => 'spam_tautan',
    ReportCategory.fakeIdentity => 'identitas_palsu',
    ReportCategory.inappropriateContent ||
    ReportCategory.wrongPartuturanRule ||
    ReportCategory.other => 'konten_tidak_pantas',
  };

  static ReportCategory parseReportCategory(String? raw) => switch (raw) {
    'ujaran_kebencian_sara' => ReportCategory.saraHateSpeech,
    'pelecehan' => ReportCategory.harassment,
    'spam_tautan' || 'penipuan_judi' => ReportCategory.spamScam,
    'identitas_palsu' => ReportCategory.fakeIdentity,
    _ => ReportCategory.inappropriateContent,
  };

  static ReportStatus parseReportStatus(String? raw) => switch (raw) {
    'in_review' => ReportStatus.inReview,
    'resolved' || 'dismissed' => ReportStatus.completed,
    _ => ReportStatus.received,
  };
}
