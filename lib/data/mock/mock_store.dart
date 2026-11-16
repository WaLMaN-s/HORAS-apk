import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/utils/reference_code.dart';
import 'package:horas/data/mock/mock_seed_data.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/partuturan/partuturan_engine.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kMockSessionUserIdPrefsKey = 'horas.mock.session_user_id';
const String kMockOwnProfilePrefsKey = 'horas.mock.own_profile';
const String kMockOwnPrivacyPrefsKey = 'horas.mock.own_privacy';

/// Penyimpanan in-memory pusat untuk seluruh repository tiruan (Prompt 2 Bagian C & D).
final class MockStore {
  MockStore({
    required this.appConfig,
    this.prefs,
    this.enableNetworkLatency = true,
    this.customTobaRulesJson,
  }) {
    _initEngine();
    _seedAll();
    _restorePersistedSessionAndProfile();
  }

  final AppConfig appConfig;
  final SharedPreferences? prefs;
  final bool enableNetworkLatency;
  final String? customTobaRulesJson;

  final Random _random = Random(42);
  final GenerationResolver generationResolver = const GenerationResolver();
  late PartuturanEngine partuturanEngine;

  // ── Simulasi Panel Debug (Bagian D) ─────────────────────────────────────────
  bool isOffline = false;
  bool isServerError = false;
  bool isEmptyState = false;
  bool isSlowNetwork = false;
  Duration timeOffset = Duration.zero;
  void Function()? onDebugStateChanged;

  DateTime get now => clock.now().add(timeOffset);

  // ── State In-Memory ─────────────────────────────────────────────────────────
  String? currentUserId = 'u-01';
  String currentSelectedCity = 'Medan';
  bool hasGivenTaromboConsent = false;

  final Map<String, Profil> usersById = <String, Profil>{};
  final List<MargaEntry> margas = <MargaEntry>[];
  final List<WilayahCity> cities = <WilayahCity>[];

  // OTP tracking per nomor HP
  final Map<String, List<DateTime>> otpRequestTimesByPhone =
      <String, List<DateTime>>{};
  final Map<String, String> issuedOtpCodeByPhone = <String, String>{};
  final Map<String, DateTime> issuedOtpTimeByPhone = <String, DateTime>{};
  final Map<String, int> otpWrongAttemptsByPhone = <String, int>{};
  final Map<String, DateTime> otpLockedUntilByPhone = <String, DateTime>{};

  // Relasi sosial & perangkat
  final Map<String, List<Device>> devicesByUserId = <String, List<Device>>{};
  final List<Follow> follows = <Follow>[];
  final List<Connection> connections = <Connection>[];
  final List<ConnectionRequest> connectionRequests = <ConnectionRequest>[];
  final List<Block> blocks = <Block>[];

  // Beranda
  final List<Post> posts = <Post>[];
  final List<Comment> comments = <Comment>[];
  final List<Like> likes = <Like>[];
  final List<SavedPost> savedPosts = <SavedPost>[];
  final Map<String, List<DateTime>> commentTimestampsByUser =
      <String, List<DateTime>>{};

  // Komunitas
  final List<Community> communities = <Community>[];
  final List<Membership> memberships = <Membership>[];
  final List<JoinRequest> joinRequests = <JoinRequest>[];
  final List<Announcement> announcements = <Announcement>[];

  // Main & Lapangan
  final List<Court> courts = <Court>[];
  final List<PlaySession> sessions = <PlaySession>[];
  final List<Participant> participants = <Participant>[];
  final List<WaitlistEntry> waitlistEntries = <WaitlistEntry>[];
  final List<PaymentShare> paymentShares = <PaymentShare>[];
  final List<ReliabilityMark> reliabilityMarks = <ReliabilityMark>[];

  // Pesan & Notifikasi
  final List<Conversation> conversations = <Conversation>[];
  final Map<String, List<Message>> messagesByConversationId =
      <String, List<Message>>{};
  final List<MessageRequest> messageRequests = <MessageRequest>[];
  final Map<String, List<DateTime>> firstMessageTimestampsByUser =
      <String, List<DateTime>>{};
  final List<AppNotification> notifications = <AppNotification>[];

  final StreamController<List<Conversation>> conversationsStreamController =
      StreamController<List<Conversation>>.broadcast();
  final Map<String, StreamController<List<Message>>> messageStreamsByConv =
      <String, StreamController<List<Message>>>{};
  final StreamController<List<AppNotification>> notificationsStreamController =
      StreamController<List<AppNotification>>.broadcast();

  // Tarombo & Partuturan
  final List<FamilyMember> familyMembers = <FamilyMember>[];
  final List<PartuturanClaim> partuturanClaims = <PartuturanClaim>[];
  final List<PartuturanFeedback> partuturanFeedbacks = <PartuturanFeedback>[];

  // Sistem, Moderasi, Siklus Hidup Akun
  final List<Report> reports = <Report>[];
  final List<Strike> strikes = <Strike>[];
  final List<Appeal> appeals = <Appeal>[];
  final List<VerificationRequest> verificationRequests =
      <VerificationRequest>[];
  final List<DataExportJob> dataExportJobs = <DataExportJob>[];
  final Map<String, AccountDeletion> accountDeletionsByUser =
      <String, AccountDeletion>{};

  int _seq = 1000;
  String nextId(String prefix) => '$prefix-${++_seq}';

  void _initEngine() {
    final tobaSet = PartuturanRuleSet.fromJsonString(
      customTobaRulesJson ?? MockSeedData.tobaV0RulesJson,
    );
    partuturanEngine = PartuturanEngine(
      ruleSetsBySubSuku: <String, PartuturanRuleSet>{'toba': tobaSet},
      allowDraftRules: appConfig.allowDraftRules,
    );
  }

  void updateEngineAllowDraftRules(bool allowDraft) {
    final tobaSet = PartuturanRuleSet.fromJsonString(
      customTobaRulesJson ?? MockSeedData.tobaV0RulesJson,
    );
    partuturanEngine = PartuturanEngine(
      ruleSetsBySubSuku: <String, PartuturanRuleSet>{'toba': tobaSet},
      allowDraftRules: allowDraft,
    );
  }

  /// Simulasi latensi 300–800 ms dan skenario Panel Debug (Offline/ServerError/Suspended).
  Future<Result<void>> simulateNetworkCall({
    bool checkAccountStatus = true,
  }) async {
    if (enableNetworkLatency) {
      final baseMs = 300 + _random.nextInt(501);
      final extraMs = isSlowNetwork ? 1200 : 0;
      await Future<void>.delayed(Duration(milliseconds: baseMs + extraMs));
    }
    if (isOffline) {
      return const Err<void>(
        OfflineError(message: AppStrings.stateOfflineMessage),
      );
    }
    if (isServerError) {
      return Err<void>(
        ServerError(
          message: AppStrings.stateServerErrorMessage,
          referenceCode: ReferenceCode.generate(
            seed: now.millisecondsSinceEpoch,
          ),
        ),
      );
    }
    if (checkAccountStatus) {
      final me = activeProfile;
      if (me != null &&
          (me.accountStatus == AccountStatus.suspended ||
              me.accountStatus == AccountStatus.restricted)) {
        return const Err<void>(
          SuspendedError(
            message: AppStrings.stateAccountRestrictedDefaultReason,
          ),
        );
      }
    }
    return const Ok<void>(null);
  }

  Profil? get activeProfile =>
      currentUserId != null ? usersById[currentUserId!] : null;

  /// Menyimpan sesi login, profil sendiri, dan pengaturan privasi ke `SharedPreferences` (Bagian C).
  Future<void> persistSessionAndProfile() async {
    final p = prefs;
    if (p == null) {
      return;
    }
    if (currentUserId == null) {
      await p.remove(kMockSessionUserIdPrefsKey);
      return;
    }
    await p.setString(kMockSessionUserIdPrefsKey, currentUserId!);
    final me = activeProfile;
    if (me != null) {
      await p.setString(kMockOwnProfilePrefsKey, jsonEncode(me.toJson()));
      await p.setString(
        kMockOwnPrivacyPrefsKey,
        jsonEncode(me.privacySettings.toJson()),
      );
    }
  }

  void _restorePersistedSessionAndProfile() {
    final p = prefs;
    if (p == null) {
      return;
    }
    final savedUserId = p.getString(kMockSessionUserIdPrefsKey);
    if (savedUserId != null && usersById.containsKey(savedUserId)) {
      currentUserId = savedUserId;
    }
    final savedProfileJson = p.getString(kMockOwnProfilePrefsKey);
    if (savedProfileJson != null) {
      try {
        final decoded = jsonDecode(savedProfileJson) as Map<String, Object?>;
        final restored = Profil.fromJson(decoded);
        if (restored.id.isNotEmpty) {
          usersById[restored.id] = restored;
          currentSpatialCitySync(restored.city);
        }
      } on Object {
        // Abaikan bila data lama korup.
      }
    }
    final savedPrivacyJson = p.getString(kMockOwnPrivacyPrefsKey);
    if (savedPrivacyJson != null && currentUserId != null) {
      try {
        final decoded = jsonDecode(savedPrivacyJson) as Map<String, Object?>;
        final privacy = PrivacySettings.fromJson(decoded);
        final me = usersById[currentUserId!];
        if (me != null) {
          usersById[currentUserId!] = me.copyWith(privacySettings: privacy);
        }
      } on Object {
        // Abaikan bila data lama korup.
      }
    }
  }

  void currentSpatialCitySync(String city) {
    if (city.isNotEmpty) {
      currentSelectedCity = city;
    }
  }

  /// Mereset seluruh data tiruan ke kondisi benih awal.
  Future<void> resetAllData() async {
    isOffline = false;
    isServerError = false;
    isEmptyState = false;
    isSlowNetwork = false;
    timeOffset = Duration.zero;
    hasGivenTaromboConsent = false;

    usersById.clear();
    margas.clear();
    cities.clear();
    otpRequestTimesByPhone.clear();
    issuedOtpCodeByPhone.clear();
    issuedOtpTimeByPhone.clear();
    otpWrongAttemptsByPhone.clear();
    otpLockedUntilByPhone.clear();
    devicesByUserId.clear();
    follows.clear();
    connections.clear();
    connectionRequests.clear();
    blocks.clear();
    posts.clear();
    comments.clear();
    likes.clear();
    savedPosts.clear();
    commentTimestampsByUser.clear();
    communities.clear();
    memberships.clear();
    joinRequests.clear();
    announcements.clear();
    courts.clear();
    sessions.clear();
    participants.clear();
    waitlistEntries.clear();
    paymentShares.clear();
    reliabilityMarks.clear();
    conversations.clear();
    messagesByConversationId.clear();
    messageRequests.clear();
    firstMessageTimestampsByUser.clear();
    notifications.clear();
    familyMembers.clear();
    partuturanClaims.clear();
    partuturanFeedbacks.clear();
    reports.clear();
    strikes.clear();
    appeals.clear();
    verificationRequests.clear();
    dataExportJobs.clear();
    accountDeletionsByUser.clear();

    currentUserId = 'u-01';
    currentSelectedCity = 'Medan';
    _seedAll();

    if (prefs != null) {
      await prefs!.remove(kMockOwnProfilePrefsKey);
      await prefs!.remove(kMockOwnPrivacyPrefsKey);
      await persistSessionAndProfile();
    }
    notifyListeners();
  }

  void notifyListeners() {
    onDebugStateChanged?.call();
    if (!conversationsStreamController.isClosed) {
      conversationsStreamController.add(visibleConversationsForActiveUser());
    }
    if (!notificationsStreamController.isClosed) {
      notificationsStreamController.add(visibleNotificationsForActiveUser());
    }
  }

  bool isBlockedBetween(String userAId, String userBId) {
    return blocks.any(
      (b) =>
          (b.blockerId == userAId && b.blockedUser.id == userBId) ||
          (b.blockerId == userBId && b.blockedUser.id == userAId),
    );
  }

  bool isConnectedBetween(String userAId, String userBId) {
    if (userAId == userBId) return true;
    return connections.any(
      (c) =>
          (c.userId == userAId && c.friend.id == userBId) ||
          (c.userId == userBId && c.friend.id == userAId),
    );
  }

  bool isFollowingUser(String followerId, String followeeId) {
    return follows.any(
      (f) =>
          f.followerId == followerId &&
          f.followeeId == followeeId &&
          !f.isPendingApproval,
    );
  }

  Set<String> communityIdsForUser(String userId) {
    return memberships
        .where((m) => m.user.id == userId)
        .map((m) => m.communityId)
        .toSet();
  }

  Set<String> sessionIdsForUser(String userId) {
    return participants
        .where(
          (p) => p.user.id == userId && p.status == ParticipantStatus.joined,
        )
        .map((p) => p.sessionId)
        .toSet();
  }

  bool sharesCommunityOrSession(String userAId, String userBId) {
    final commsA = communityIdsForUser(userAId);
    final commsB = communityIdsForUser(userBId);
    if (commsA.intersection(commsB).isNotEmpty) {
      return true;
    }
    final sessA = sessionIdsForUser(userAId);
    final sessB = sessionIdsForUser(userBId);
    return sessA.intersection(sessB).isNotEmpty;
  }

  String? confirmedKinshipTermBetween(String viewerId, String targetId) {
    for (final claim in partuturanClaims) {
      if (claim.status == PartuturanClaimStatus.accepted) {
        if (claim.sender.id == viewerId && claim.receiver.id == targetId) {
          return claim.claimedTermForReceiver;
        }
        if (claim.receiver.id == viewerId && claim.sender.id == targetId) {
          return claim.claimedTermForReceiver;
        }
      }
    }
    return null;
  }

  PartuturanResult evaluatePartuturanForUsers({
    required Profil viewer,
    required Profil target,
  }) {
    if (!viewer.isMargaVerified || !target.isMargaVerified) {
      final same = viewer.marga.toLowerCase() == target.marga.toLowerCase();
      return PartuturanResult(
        confidence: PartuturanConfidence.rendah,
        penjelasanJalur: '',
        versiAturan: 'unverified-marga',
        modeNetral: true,
        isSemarga: same,
      );
    }

    final genInfo = generationResolver.resolve(
      viewerSundut: viewer.sundut,
      targetSundut: target.sundut,
      viewerBirthYear: viewer.birthYear,
      targetBirthYear: target.birthYear,
    );

    final confirmedTerm = confirmedKinshipTermBetween(viewer.id, target.id);

    return partuturanEngine.evaluate(
      PartuturanEvaluationInput(
        viewerMarga: viewer.marga,
        viewerGender: viewer.gender,
        viewerMotherMarga: viewer.motherMarga,
        subEthnic: viewer.subEthnic,
        targetMarga: target.marga,
        targetGender: target.gender,
        generationInfo: genInfo,
        confirmedKinshipTerm: confirmedTerm,
      ),
    );
  }

  /// Mengonversi [Profil] menjadi [PersonSummary] yang aman privasi (SEK-R2, SEK-R4, AC-07).
  ///
  /// TIDAK PERNAH menyertakan nomor HP, tahun lahir, usia pasti, koordinat, atau jarak km.
  PersonSummary toPersonSummary(Profil target, {Profil? viewer}) {
    final effectiveViewer = viewer ?? activeProfile ?? target;
    final isSelf = effectiveViewer.id == target.id;
    final connected = isConnectedBetween(effectiveViewer.id, target.id);
    final following = isFollowingUser(effectiveViewer.id, target.id);
    final blocked = isBlockedBetween(effectiveViewer.id, target.id);

    final proximity =
        (effectiveViewer.city.toLowerCase() == target.city.toLowerCase() &&
            effectiveViewer.subdistrict.toLowerCase() ==
                target.subdistrict.toLowerCase())
        ? AreaProximity.diKecamatanmu
        : AreaProximity.diKotamu;

    final viewerComms = communityIdsForUser(effectiveViewer.id);
    final targetComms = communityIdsForUser(target.id);
    final sharedCommsCount = viewerComms.intersection(targetComms).length;

    final sameMarga =
        effectiveViewer.marga.trim().toLowerCase() ==
        target.marga.trim().toLowerCase();

    final partuturan = isSelf
        ? null
        : evaluatePartuturanForUsers(viewer: effectiveViewer, target: target);

    final privacy = target.privacySettings;
    bool canSeeField(FieldVisibility vis) {
      if (isSelf) return true;
      return switch (vis) {
        FieldVisibility.everyone => true,
        FieldVisibility.connectedOnly => connected,
        FieldVisibility.onlyMe => false,
      };
    }

    final visibleMotherMarga = canSeeField(privacy.motherMarga)
        ? target.motherMarga
        : null;
    final visibleSubdistrict = canSeeField(privacy.subdistrict)
        ? target.subdistrict
        : null;
    final visibleHomeChurch = canSeeField(privacy.homeChurch)
        ? target.homeChurchName
        : null;

    String? visibleAgeGroup;
    if (isSelf || privacy.showAgeGroup) {
      final age = now.year - target.birthYear;
      visibleAgeGroup = _ageGroupLabel(age);
    }

    // PSN-R1 & AC-06: Tombol Pesan hanya aktif bila Terhubung atau berbagi komunitas/sesi
    // dan penerima mengizinkan pesan dari konteks bersama.
    final canMessage =
        !isSelf &&
        !blocked &&
        (connected ||
            (sharesCommunityOrSession(effectiveViewer.id, target.id) &&
                privacy.allowMessagesFromSharedContext));

    final hideContentForPrivate =
        !isSelf &&
        !connected &&
        !following &&
        privacy.accountType == AccountVisibilityType.privateAccount;

    return PersonSummary(
      id: target.id,
      displayName: target.displayName,
      gender: target.gender,
      marga: target.marga,
      subEthnic: target.subEthnic,
      city: target.city,
      proximity: proximity,
      avatarSeed: target.avatarSeed,
      sharedCommunitiesCount: sharedCommsCount,
      isSameMarga: sameMarga,
      partuturan: partuturan,
      visibleMotherMarga: visibleMotherMarga,
      visibleSubdistrict: visibleSubdistrict,
      visibleAgeGroup: visibleAgeGroup,
      visibleHomeChurch: visibleHomeChurch,
      bio: hideContentForPrivate ? '' : target.bio,
      hobbies: hideContentForPrivate ? const <String>[] : target.hobbies,
      campusOrOffice: hideContentForPrivate ? null : target.campusOrOffice,
      websiteUrl: hideContentForPrivate ? null : target.websiteUrl,
      isPrivateAccount:
          privacy.accountType == AccountVisibilityType.privateAccount,
      isFollowing: following,
      isConnected: connected,
      canMessage: canMessage,
    );
  }

  static String _ageGroupLabel(int age) {
    if (age < 25) return '17-24';
    if (age < 35) return '25-34';
    if (age < 45) return '35-44';
    if (age < 55) return '45-54';
    return '55+';
  }

  /// Menambahkan notifikasi baru dan memancarkannya ke stream (PRD bagian 9 -> SIS-01).
  AppNotification pushNotificationInternal({
    required String recipientId,
    required NotificationType type,
    required String title,
    required String body,
    required String deepLink,
  }) {
    final item = AppNotification(
      id: nextId('notif'),
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      deepLink: deepLink,
      createdAt: now,
    );
    notifications.insert(0, item);
    if (!notificationsStreamController.isClosed) {
      notificationsStreamController.add(visibleNotificationsForActiveUser());
    }
    onDebugStateChanged?.call();
    return item;
  }

  List<AppNotification> visibleNotificationsForActiveUser() {
    if (isEmptyState || currentUserId == null) {
      return const <AppNotification>[];
    }
    final cutoff = now.subtract(const Duration(days: 90)); // SIS-R1: 90 hari
    return notifications
        .where(
          (n) => n.recipientId == currentUserId && n.createdAt.isAfter(cutoff),
        )
        .toList(growable: false);
  }

  List<Conversation> visibleConversationsForActiveUser() {
    if (isEmptyState || currentUserId == null) {
      return const <Conversation>[];
    }
    final uid = currentUserId!;
    final result = <Conversation>[];
    for (final conv in conversations) {
      final isParticipant = conv.participants.any((p) => p.id == uid);
      if (!isParticipant) continue;
      if (conv.type == ConversationType.direct) {
        final other = conv.participants.where((p) => p.id != uid).firstOrNull;
        if (other != null && isBlockedBetween(uid, other.id)) {
          continue; // PSN-R6, AC-11: blokir menyembunyikan percakapan pribadi
        }
      }
      result.add(conv);
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  void _seedAll() {
    final baseNow = now;
    margas.addAll(MockSeedData.standardMargas);

    // 42 pengguna fiktif
    for (final u in MockSeedData.buildUsers(baseNow)) {
      usersById[u.id] = u;
    }

    // Kota wilayah bawaan (40+ kota)
    const defaultCities = <(String, String, String, List<String>)>[
      (
        'mdn',
        'Medan',
        'Sumatera Utara',
        <String>[
          'Medan Baru',
          'Medan Selayang',
          'Medan Helvetia',
          'Medan Sunggal',
          'Medan Denai',
          'Medan Tuntungan',
          'Medan Kota',
          'Medan Perjuangan',
        ],
      ),
      (
        'pms',
        'Pematangsiantar',
        'Sumatera Utara',
        <String>[
          'Siantar Timur',
          'Siantar Barat',
          'Siantar Utara',
          'Siantar Selatan',
          'Siantar Marihat',
          'Siantar Sitalasari',
        ],
      ),
      (
        'blg',
        'Balige',
        'Sumatera Utara',
        <String>['Balige', 'Laguboti', 'Porsea'],
      ),
      (
        'trt',
        'Tarutung',
        'Sumatera Utara',
        <String>['Tarutung', 'Sipoholon', 'Siborongborong'],
      ),
      ('sdk', 'Sidikalang', 'Sumatera Utara', <String>['Sidikalang', 'Sumbul']),
      (
        'kbj',
        'Kabanjahe',
        'Sumatera Utara',
        <String>['Kabanjahe', 'Berastagi'],
      ),
      (
        'dls',
        'Doloksanggul',
        'Sumatera Utara',
        <String>['Doloksanggul', 'Lintong Nihuta'],
      ),
      (
        'pgr',
        'Pangururan',
        'Sumatera Utara',
        <String>['Pangururan', 'Simanindo'],
      ),
      ('rtp', 'Rantauprapat', 'Sumatera Utara', <String>['Rantau Utara']),
      (
        'psp',
        'Padangsidimpuan',
        'Sumatera Utara',
        <String>['Padangsidimpuan Utara'],
      ),
      ('sbg', 'Sibolga', 'Sumatera Utara', <String>['Sibolga Kota']),
      ('bnj', 'Binjai', 'Sumatera Utara', <String>['Binjai Kota']),
      (
        'tbt',
        'Tebing Tinggi',
        'Sumatera Utara',
        <String>['Tebing Tinggi Kota'],
      ),
      ('lbp', 'Lubuk Pakam', 'Sumatera Utara', <String>['Lubuk Pakam']),
      ('gnt', 'Gunungtua', 'Sumatera Utara', <String>['Padang Bolak']),
      ('kis', 'Kisaran', 'Sumatera Utara', <String>['Kisaran Barat']),
      (
        'jkp',
        'Jakarta Pusat',
        'DKI Jakarta',
        <String>['Menteng', 'Cempaka Putih', 'Kemayoran'],
      ),
      (
        'jks',
        'Jakarta Selatan',
        'DKI Jakarta',
        <String>[
          'Tebet',
          'Pasar Minggu',
          'Kebayoran Baru',
          'Cilandak',
          'Setiabudi',
        ],
      ),
      (
        'jkt',
        'Jakarta Timur',
        'DKI Jakarta',
        <String>[
          'Cawang',
          'Rawamangun',
          'Duren Sawit',
          'Matraman',
          'Kramat Jati',
        ],
      ),
      (
        'jkb',
        'Jakarta Barat',
        'DKI Jakarta',
        <String>['Grogol Petamburan', 'Kebon Jeruk'],
      ),
      (
        'jku',
        'Jakarta Utara',
        'DKI Jakarta',
        <String>['Kelapa Gading', 'Tanjung Priok'],
      ),
      (
        'bdg',
        'Bandung',
        'Jawa Barat',
        <String>[
          'Coblong',
          'Sukajadi',
          'Buahbatu',
          'Lengkong',
          'Antapani',
          'Cibeunying Kaler',
        ],
      ),
      ('bks', 'Bekasi', 'Jawa Barat', <String>['Bekasi Selatan', 'Rawalumbu']),
      ('dpk', 'Depok', 'Jawa Barat', <String>['Beji', 'Cimanggis']),
      ('bgr', 'Bogor', 'Jawa Barat', <String>['Bogor Tengah', 'Cibinong']),
      ('tng', 'Tangerang', 'Banten', <String>['Karawaci', 'Cipondoh']),
      ('tgs', 'Tangerang Selatan', 'Banten', <String>['Serpong', 'Bintaro']),
      (
        'btm',
        'Batam',
        'Kepulauan Riau',
        <String>[
          'Batam Kota',
          'Batu Aji',
          'Sagulung',
          'Sekupang',
          'Lubuk Baja',
          'Nongsa',
        ],
      ),
      (
        'tpi',
        'Tanjungpinang',
        'Kepulauan Riau',
        <String>['Tanjungpinang Barat'],
      ),
      ('pkb', 'Pekanbaru', 'Riau', <String>['Tampan', 'Sukajadi']),
      ('dmi', 'Dumai', 'Riau', <String>['Dumai Timur']),
      ('pdg', 'Padang', 'Sumatera Barat', <String>['Padang Barat']),
      ('plg', 'Palembang', 'Sumatera Selatan', <String>['Ilir Timur I']),
      ('jmb', 'Jambi', 'Jambi', <String>['Kota Baru']),
      ('bdl', 'Bandar Lampung', 'Lampung', <String>['Rajabasa']),
      ('sby', 'Surabaya', 'Jawa Timur', <String>['Gubeng', 'Wonokromo']),
      ('mlg', 'Malang', 'Jawa Timur', <String>['Lowokwaru']),
      ('ygk', 'Yogyakarta', 'DI Yogyakarta', <String>['Depok Sleman']),
      ('smg', 'Semarang', 'Jawa Tengah', <String>['Tembalang']),
      ('dps', 'Denpasar', 'Bali', <String>['Denpasar Selatan']),
      ('bpn', 'Balikpapan', 'Kalimantan Timur', <String>['Balikpapan Selatan']),
      ('ptk', 'Pontianak', 'Kalimantan Barat', <String>['Pontianak Selatan']),
      ('mks', 'Makassar', 'Sulawesi Selatan', <String>['Panakkukang']),
    ];
    for (final c in defaultCities) {
      cities.add(
        WilayahCity(id: c.$1, name: c.$2, province: c.$3, subdistricts: c.$4),
      );
    }

    // Perangkat awal untuk u-01
    devicesByUserId['u-01'] = <Device>[
      Device(
        id: 'dev-01',
        userId: 'u-01',
        deviceName: 'Samsung Galaxy S24',
        platform: 'Android',
        loggedInAt: baseNow.subtract(const Duration(days: 10)),
        lastActiveAt: baseNow,
        isCurrent: true,
      ),
      Device(
        id: 'dev-02',
        userId: 'u-01',
        deviceName: 'Xiaomi Pad 6',
        platform: 'Android',
        loggedInAt: baseNow.subtract(const Duration(days: 4)),
        lastActiveAt: baseNow.subtract(const Duration(hours: 5)),
      ),
    ];

    // 10 Lapangan & 10 Komunitas
    courts.addAll(MockSeedData.buildCourts());
    communities.addAll(MockSeedData.buildCommunities(baseNow));

    // Keanggotaan komunitas awal
    final allUserIds = usersById.keys.toList();
    for (var i = 0; i < communities.length; i++) {
      final comm = communities[i];
      final ownerProfile = usersById[comm.ownerId]!;
      memberships.add(
        Membership(
          id: 'mem-${comm.id}-${comm.ownerId}',
          communityId: comm.id,
          user: toPersonSummary(ownerProfile, viewer: usersById['u-01']),
          role: CommunityRole.owner,
          joinedAt: comm.createdAt,
        ),
      );
      for (final mgrId in comm.managerIds) {
        if (mgrId == comm.ownerId) continue;
        final mgrProfile = usersById[mgrId]!;
        memberships.add(
          Membership(
            id: 'mem-${comm.id}-$mgrId',
            communityId: comm.id,
            user: toPersonSummary(mgrProfile, viewer: usersById['u-01']),
            role: CommunityRole.manager,
            joinedAt: comm.createdAt.add(const Duration(days: 1)),
          ),
        );
      }
      // Tambahkan beberapa anggota biasa di kota yang sama (kecuali komunitas tertutup com-10)
      if (comm.accessType != CommunityAccessType.closed) {
        for (final uid in allUserIds) {
          if (uid == comm.ownerId || comm.managerIds.contains(uid)) continue;
          final p = usersById[uid]!;
          if (p.city == comm.city) {
            memberships.add(
              Membership(
                id: 'mem-${comm.id}-$uid',
                communityId: comm.id,
                user: toPersonSummary(p, viewer: usersById['u-01']),
                role: CommunityRole.member,
                joinedAt: comm.createdAt.add(const Duration(days: 2)),
              ),
            );
          }
        }
      }
    }

    // Ikuti & Kenalan awal untuk u-01
    for (final targetId in const <String>[
      'u-02',
      'u-03',
      'u-04',
      'u-05',
      'u-11',
      'u-21',
    ]) {
      follows.add(
        Follow(
          id: 'fol-u01-$targetId',
          followerId: 'u-01',
          followeeId: targetId,
          createdAt: baseNow.subtract(const Duration(days: 15)),
        ),
      );
    }
    for (final friendId in const <String>['u-02', 'u-04', 'u-11']) {
      final fProfile = usersById[friendId]!;
      connections.add(
        Connection(
          id: 'conn-u01-$friendId',
          userId: 'u-01',
          friend: toPersonSummary(fProfile, viewer: usersById['u-01']),
          connectedAt: baseNow.subtract(const Duration(days: 12)),
        ),
      );
    }

    // Permintaan Kenalan masuk untuk u-01
    connectionRequests.add(
      ConnectionRequest(
        id: 'creq-01',
        sender: toPersonSummary(usersById['u-05']!, viewer: usersById['u-01']),
        receiver: toPersonSummary(
          usersById['u-01']!,
          viewer: usersById['u-05'],
        ),
        introMessage: 'Horas Lae! Kita satu komunitas di Medan.',
        status: ConnectionRequestStatus.pending,
        createdAt: baseNow.subtract(const Duration(days: 1)),
        expiresAt: baseNow.add(const Duration(days: 29)),
      ),
    );

    // 12 Sesi Main
    final sessionSpecs =
        <
          (
            String id,
            String hostId,
            SportType sport,
            String title,
            String courtId,
            String city,
            int hoursAhead,
            int maxSlots,
            SkillLevel level,
            int fee,
          )
        >[
          (
            'ses-01',
            'u-01',
            SportType.badminton,
            'Badminton Naposo Medan',
            'court-01',
            'Medan',
            24,
            12,
            SkillLevel.beginner,
            35000,
          ),
          (
            'ses-02',
            'u-04',
            SportType.futsal,
            'Futsal Dongan Sahuta Medan',
            'court-02',
            'Medan',
            48,
            14,
            SkillLevel.all,
            40000,
          ),
          (
            'ses-03',
            'u-06',
            SportType.volleyball,
            'Voli Sore Manunggal',
            'court-01',
            'Medan',
            72,
            12,
            SkillLevel.intermediate,
            25000,
          ),
          (
            'ses-04',
            'u-11',
            SportType.badminton,
            'Tepok Bulu Perantau Tebet',
            'court-03',
            'Jakarta Selatan',
            30,
            8,
            SkillLevel.all,
            50000,
          ),
          (
            'ses-05',
            'u-15',
            SportType.basketball,
            'Basket Minggu Pagi Jaksel',
            'court-03',
            'Jakarta Selatan',
            60,
            10,
            SkillLevel.intermediate,
            45000,
          ),
          (
            'ses-06',
            'u-14',
            SportType.futsal,
            'Futsal Punguan Jaktim',
            'court-04',
            'Jakarta Timur',
            36,
            16,
            SkillLevel.all,
            40000,
          ),
          (
            'ses-07',
            'u-21',
            SportType.basketball,
            'Basket Mahasiswa Bandung',
            'court-05',
            'Bandung',
            20,
            10,
            SkillLevel.all,
            25000,
          ),
          (
            'ses-08',
            'u-25',
            SportType.badminton,
            'Badminton Lodaya Bandung',
            'court-06',
            'Bandung',
            50,
            8,
            SkillLevel.beginner,
            35000,
          ),
          (
            'ses-09',
            'u-29',
            SportType.futsal,
            'Futsal Sabtu Malam Batu Aji',
            'court-08',
            'Batam',
            40,
            14,
            SkillLevel.all,
            40000,
          ),
          (
            'ses-10',
            'u-33',
            SportType.badminton,
            'Badminton Batam Center',
            'court-07',
            'Batam',
            65,
            8,
            SkillLevel.intermediate,
            40000,
          ),
          (
            'ses-11',
            'u-36',
            SportType.badminton,
            'Badminton Merdeka Siantar',
            'court-09',
            'Pematangsiantar',
            28,
            10,
            SkillLevel.all,
            25000,
          ),
          (
            'ses-12',
            'u-37',
            SportType.jogging,
            'Lari Pagi Taman Bunga Siantar',
            'court-10',
            'Pematangsiantar',
            18,
            20,
            SkillLevel.all,
            0,
          ),
        ];

    for (final s in sessionSpecs) {
      final hostProfile = usersById[s.$2]!;
      final court = courts.firstWhere((c) => c.id == s.$5);
      final start = baseNow.add(Duration(hours: s.$7));
      final end = start.add(const Duration(hours: 2));
      final convId = 'conv-${s.$1}';

      final session = PlaySession(
        id: s.$1,
        host: toPersonSummary(hostProfile, viewer: usersById['u-01']),
        sportType: s.$3,
        title: s.$4,
        courtId: court.id,
        courtName: court.name,
        city: s.$6,
        startTime: start,
        endTime: end,
        maxSlots: s.$8,
        skillLevel: s.$9,
        feePerPersonRupiah: s.$10,
        notes: 'Bawa raket/sepatu olahraga masing-masing. Horas!',
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        participantCount: 2,
        isJoinedByMe: s.$2 == 'u-01' || s.$1 == 'ses-02',
        conversationId: convId,
        createdAt: baseNow.subtract(const Duration(days: 2)),
      );
      sessions.add(session);

      final hostSummary = toPersonSummary(
        hostProfile,
        viewer: usersById['u-01'],
      );
      participants.add(
        Participant(
          id: 'part-${s.$1}-${s.$2}',
          sessionId: s.$1,
          user: hostSummary,
          status: ParticipantStatus.joined,
          joinedAt: session.createdAt,
        ),
      );
      paymentShares.add(
        PaymentShare(
          id: 'pay-${s.$1}-${s.$2}',
          sessionId: s.$1,
          participant: hostSummary,
          amountRupiah: s.$10,
          participantMarkedPaid: true,
          hostConfirmedPaid: true,
          updatedAt: session.createdAt,
        ),
      );
    }

    // 30 Postingan Beranda
    const postTemplates = <String>[
      'Horas! Senang sekali hari ini berkumpul bersama punguan di {city}. Semoga sehat selalu untuk kita semua.',
      'Terima kasih buat dongan sahuta di {city} yang sudah ikut sesi olahraga sore tadi!',
      'Baru selesai melengkapi pohon silsilah 3 generasi di Tarombo HORAS. Ternyata banyak kerabat satu sundut di {city}.',
      'Ngopi sore sambil diskusi kegiatan bulanan komunitas di {city}.',
      'Selamat berakhir pekan keluarga besar HORAS di {city} dan perantauan!',
    ];

    for (var i = 0; i < 30; i++) {
      final authorProfile =
          usersById['u-${((i % 25) + 1).toString().padLeft(2, '0')}']!;
      final textTemplate = postTemplates[i % postTemplates.length];
      final postId = 'post-${(i + 1).toString().padLeft(2, '0')}';
      final createdAt = baseNow.subtract(Duration(hours: (i + 1) * 3));

      posts.add(
        Post(
          id: postId,
          author: toPersonSummary(authorProfile, viewer: usersById['u-01']),
          text: textTemplate.replaceAll('{city}', authorProfile.city),
          media: <PostMedia>[
            PostMedia(
              id: 'med-$postId-1',
              postId: postId,
              seed: 'post-seed-$postId-${authorProfile.marga}',
              orderIndex: 0,
            ),
          ],
          visibility: PostVisibility.publicPost,
          cityTag: authorProfile.city,
          likeCount: 4 + (i % 15),
          commentCount: 1 + (i % 4),
          createdAt: createdAt,
        ),
      );

      final commenterProfile =
          usersById['u-${(((i + 3) % 25) + 1).toString().padLeft(2, '0')}']!;
      comments.add(
        Comment(
          id: 'cmt-$postId-1',
          postId: postId,
          author: toPersonSummary(commenterProfile, viewer: usersById['u-01']),
          text: 'Horas! Mantap sekali kegiatannya di ${authorProfile.city}.',
          createdAt: createdAt.add(const Duration(minutes: 25)),
        ),
      );
    }

    // Percakapan & Pesan awal
    final u01Summary = toPersonSummary(usersById['u-01']!);
    final u02Summary = toPersonSummary(
      usersById['u-02']!,
      viewer: usersById['u-01'],
    );
    final u04Summary = toPersonSummary(
      usersById['u-04']!,
      viewer: usersById['u-01'],
    );

    final msg1 = Message(
      id: 'msg-01',
      conversationId: 'conv-dm-01',
      sender: u02Summary,
      text: 'Horas Ito! Jadi ikut sesi badminton besok sore di GOR Manunggal?',
      deliveryStatus: MessageDeliveryStatus.delivered,
      createdAt: baseNow.subtract(const Duration(minutes: 45)),
    );
    messagesByConversationId['conv-dm-01'] = <Message>[msg1];
    conversations.add(
      Conversation(
        id: 'conv-dm-01',
        type: ConversationType.direct,
        title: u02Summary.displayName,
        participants: <PersonSummary>[u01Summary, u02Summary],
        lastMessage: msg1,
        unreadCount: 1,
        updatedAt: msg1.createdAt,
      ),
    );

    final msg2 = Message(
      id: 'msg-02',
      conversationId: 'conv-com-01',
      sender: u04Summary,
      text: 'Horas keluarga besar punguan! Jangan lupa pertemuan minggu depan.',
      deliveryStatus: MessageDeliveryStatus.read,
      createdAt: baseNow.subtract(const Duration(hours: 2)),
    );
    messagesByConversationId['conv-com-01'] = <Message>[msg2];
    conversations.add(
      Conversation(
        id: 'conv-com-01',
        type: ConversationType.communityGroup,
        title: communities.first.name,
        communityId: communities.first.id,
        participants: <PersonSummary>[u01Summary, u02Summary, u04Summary],
        lastMessage: msg2,
        unreadCount: 1,
        updatedAt: msg2.createdAt,
      ),
    );

    // Anggota Tarombo awal milik u-01 (3 generasi)
    familyMembers.addAll(<FamilyMember>[
      const FamilyMember(
        id: 'fam-01',
        ownerUserId: 'u-01',
        relationType: FamilyRelationType.father,
        fullName: 'St. Maringan Simanjuntak',
        marga: 'Simanjuntak',
        gender: UserGender.male,
        birthYear: 1966,
        lifeStatus: LifeStatus.alive,
      ),
      const FamilyMember(
        id: 'fam-02',
        ownerUserId: 'u-01',
        relationType: FamilyRelationType.mother,
        fullName: 'Risma br. Sitorus',
        marga: 'Sitorus',
        gender: UserGender.female,
        birthYear: 1969,
        lifeStatus: LifeStatus.alive,
      ),
      const FamilyMember(
        id: 'fam-03',
        ownerUserId: 'u-01',
        relationType: FamilyRelationType.paternalGrandfather,
        fullName: 'Op. Rudi Simanjuntak',
        marga: 'Simanjuntak',
        gender: UserGender.male,
        birthYear: 1938,
        lifeStatus: LifeStatus.deceased,
      ),
    ]);

    // Notifikasi awal untuk u-01
    notifications.addAll(<AppNotification>[
      AppNotification(
        id: 'notif-seed-01',
        recipientId: 'u-01',
        type: NotificationType.connectionRequestReceived,
        title: 'Permintaan Kenalan Baru',
        body: 'Rina Sitorus mengirim permintaan Kenalan kepadamu.',
        deepLink: 'horas://app/akun/kenalan',
        createdAt: baseNow.subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: 'notif-seed-02',
        recipientId: 'u-01',
        type: NotificationType.postLikedOrCommented,
        title: 'Komentar Baru di Postinganmu',
        body: 'Dewi Simanjuntak mengomentari postinganmu.',
        deepLink: 'horas://app/beranda/postingan-detail',
        createdAt: baseNow.subtract(const Duration(hours: 8)),
      ),
      AppNotification(
        id: 'notif-seed-03',
        recipientId: 'u-01',
        type: NotificationType.communityAnnouncement,
        title: 'Pengumuman Punguan Simanjuntak',
        body: 'Jadwal kumpul bulanan telah diperbarui oleh pengurus.',
        deepLink: 'horas://app/sekitar/komunitas-detail',
        createdAt: baseNow.subtract(const Duration(days: 1)),
      ),
    ]);
  }
}
