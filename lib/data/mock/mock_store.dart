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
import 'package:horas/domain/policies/block_policy.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kMockSessionUserIdPrefsKey = 'horas.mock.session_user_id';
const String kMockLoggedOutPrefsKey = 'horas.mock.logged_out';
const String kMockOwnProfilePrefsKey = 'horas.mock.own_profile';
const String kMockOwnPrivacyPrefsKey = 'horas.mock.own_privacy';
const String kMockRegisteredAccountsPrefsKey = 'horas.mock.registered_accounts';
const String kMockLegalConsentPrefsKey = 'horas.mock.legal_consent';
const String kMockOnboardingDraftPrefsKey = 'horas.mock.onboarding_draft';
const String kMockFeedCachePrefsKey = 'horas.mock.feed_cache_page1';
const String kMockPostDraftPrefsKey = 'horas.mock.post_draft';
const String kMockSearchHistoryPrefsKey = 'horas.mock.search_history';
const String kMockCustomMargasPrefsKey = 'horas.mock.custom_margas';
const String kSecureAuthTokenKey = 'horas.auth.access_token';

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
  late bool isChatAutoReplyEnabled = !appConfig.isProd;
  Duration timeOffset = Duration.zero;
  void Function()? onDebugStateChanged;

  DateTime get now => clock.now().add(timeOffset);

  // ── State In-Memory ─────────────────────────────────────────────────────────
  String? currentUserId = 'u-01';
  String? secureAccessToken = 'mock-jwt-u-01';
  String currentSelectedCity = 'Medan';
  bool hasGivenTaromboConsent = false;
  FieldVisibility taromboParentNamesVisibility = FieldVisibility.onlyMe;
  LegalConsentRecord? savedLegalConsent;
  OnboardingDraft onboardingDraft = const OnboardingDraft();
  AccountRecoverySubmission? latestRecoverySubmission;
  List<Post> cachedFeedPage1 = <Post>[];
  PostDraft? savedPostDraft;
  final List<String> searchHistory = <String>[
    'Simanjuntak',
    'Medan',
    'Punguan',
  ];

  final Map<String, Profil> usersById = <String, Profil>{};
  final Set<String> persistedAccountIds = <String>{};
  final Map<String, DateTime> userLastActiveAt = <String, DateTime>{};
  final List<MargaEntry> margas = <MargaEntry>[];
  final List<WilayahCity> cities = <WilayahCity>[];
  bool nearbyLocationPermissionDenied = false;

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
  final Map<String, Message> retainedReportedMessages = <String, Message>{};
  final Set<Timer> pendingAutoReplyTimers = <Timer>{};
  final List<MessageRequest> messageRequests = <MessageRequest>[];
  final Map<String, List<DateTime>> firstMessageTimestampsByUser =
      <String, List<DateTime>>{};
  final List<AppNotification> notifications = <AppNotification>[];

  // Fase 2 (Story, Kegiatan, Gereja, Kamus)
  final List<Story> stories = <Story>[];
  final Map<String, List<StoryViewer>> storyViewersByStoryId =
      <String, List<StoryViewer>>{};
  final List<CommunityEvent> communityEvents = <CommunityEvent>[];
  final Map<String, List<EventAttendee>> eventAttendeesByEventId =
      <String, List<EventAttendee>>{};
  final List<Church> churches = <Church>[];
  final List<PartuturanDictionaryEntry> partuturanDictionary =
      <PartuturanDictionaryEntry>[];

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
  final Map<String, NotificationPreferences> notificationPrefsByUser =
      <String, NotificationPreferences>{};
  final Map<String, List<LoginHistoryEntry>> loginHistoryByUser =
      <String, List<LoginHistoryEntry>>{};
  final List<SupportTicket> supportTickets = <SupportTicket>[];
  String? recentlyCancelledDeletionUserId;

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

  /// Mendaftarkan marga yang diinput pengguna ke dalam database marga agar tersimpan permanen.
  Future<void> registerMargaInDatabase(
    String rawMarga, {
    SubEthnic subEthnic = SubEthnic.toba,
  }) async {
    final clean = rawMarga.trim();
    if (clean.length < 2) return;
    final exists = margas.any(
      (m) => m.name.toLowerCase() == clean.toLowerCase(),
    );
    if (!exists) {
      margas.add(
        MargaEntry(name: clean, subEthnic: subEthnic, isVerified: true),
      );
    }
    final p = prefs;
    if (p != null) {
      await p.setString(
        kMockCustomMargasPrefsKey,
        jsonEncode(margas.map((m) => m.toJson()).toList()),
      );
    }
  }

  /// Menyimpan sesi login, daftar akun terdaftar/diubah, profil sendiri, dan privasi ke `SharedPreferences` (Bagian C).
  Future<void> persistSessionAndProfile() async {
    final p = prefs;
    if (p == null) {
      return;
    }

    if (currentUserId != null && usersById.containsKey(currentUserId!)) {
      persistedAccountIds.add(currentUserId!);
    }

    final savedAccounts = <Map<String, Object?>>[
      for (final id in persistedAccountIds)
        if (usersById[id] != null) usersById[id]!.toJson(),
    ];
    await p.setString(
      kMockRegisteredAccountsPrefsKey,
      jsonEncode(savedAccounts),
    );

    if (currentUserId == null) {
      await p.setBool(kMockLoggedOutPrefsKey, true);
      await p.remove(kMockSessionUserIdPrefsKey);
      return;
    }
    await p.setBool(kMockLoggedOutPrefsKey, false);
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

  void _bumpSeqFromRestoredId(String id) {
    final parts = id.split('-');
    if (parts.length == 2) {
      final parsed = int.tryParse(parts[1]);
      if (parsed != null && parsed > _seq) {
        _seq = parsed;
      }
    }
  }

  void _restorePersistedSessionAndProfile() {
    final p = prefs;
    if (p == null) {
      return;
    }

    // 1. Pulihkan seluruh akun terdaftar/diubah terlebih dahulu agar login ulang selalu menemukan profilnya
    final savedAccountsJson = p.getString(kMockRegisteredAccountsPrefsKey);
    if (savedAccountsJson != null) {
      try {
        final decoded = jsonDecode(savedAccountsJson) as List<Object?>;
        for (final entry in decoded) {
          if (entry is Map<String, Object?>) {
            final restored = Profil.fromJson(entry);
            if (restored.id.isNotEmpty) {
              usersById[restored.id] = restored;
              persistedAccountIds.add(restored.id);
              _bumpSeqFromRestoredId(restored.id);
              if (restored.marga.trim().length >= 2 &&
                  !margas.any(
                    (m) =>
                        m.name.toLowerCase() ==
                        restored.marga.trim().toLowerCase(),
                  )) {
                margas.add(
                  MargaEntry(
                    name: restored.marga.trim(),
                    subEthnic: restored.subEthnic,
                    isVerified: true,
                  ),
                );
              }
            }
          }
        }
      } on Object {
        // Abaikan bila data lama korup.
      }
    }

    // 2. Pulihkan profil tunggal warisan bila ada
    final savedProfileJson = p.getString(kMockOwnProfilePrefsKey);
    if (savedProfileJson != null) {
      try {
        final decoded = jsonDecode(savedProfileJson) as Map<String, Object?>;
        final restored = Profil.fromJson(decoded);
        if (restored.id.isNotEmpty && !usersById.containsKey(restored.id)) {
          usersById[restored.id] = restored;
          persistedAccountIds.add(restored.id);
          _bumpSeqFromRestoredId(restored.id);
        } else if (restored.id.isNotEmpty) {
          usersById[restored.id] = restored;
          persistedAccountIds.add(restored.id);
        }
      } on Object {
        // Abaikan bila data lama korup.
      }
    }

    // 3. Pulihkan status logout atau sesi aktif & privasinya
    final isLoggedOut = p.getBool(kMockLoggedOutPrefsKey) ?? false;
    final savedUserId = p.getString(kMockSessionUserIdPrefsKey);
    if (isLoggedOut) {
      currentUserId = null;
    } else if (savedUserId != null && usersById.containsKey(savedUserId)) {
      currentUserId = savedUserId;
      currentSpatialCitySync(usersById[savedUserId]!.city);
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
    final savedConsentJson = p.getString(kMockLegalConsentPrefsKey);
    if (savedConsentJson != null) {
      try {
        final decoded = jsonDecode(savedConsentJson) as Map<String, Object?>;
        savedLegalConsent = LegalConsentRecord.fromJson(decoded);
      } on Object {
        // Abaikan bila data lama korup.
      }
    }
    final savedDraftJson = p.getString(kMockOnboardingDraftPrefsKey);
    if (savedDraftJson != null) {
      try {
        final decoded = jsonDecode(savedDraftJson) as Map<String, Object?>;
        onboardingDraft = OnboardingDraft.fromJson(decoded);
      } on Object {
        // Abaikan bila data lama korup.
      }
    }
    final savedFeedCacheJson = p.getString(kMockFeedCachePrefsKey);
    if (savedFeedCacheJson != null) {
      try {
        final decoded = jsonDecode(savedFeedCacheJson) as List<Object?>;
        cachedFeedPage1 = decoded
            .whereType<Map<String, Object?>>()
            .map(Post.fromJson)
            .toList();
      } on Object {
        // Abaikan bila cache lama korup.
      }
    }
    final savedPostDraftJson = p.getString(kMockPostDraftPrefsKey);
    if (savedPostDraftJson != null) {
      try {
        final decoded = jsonDecode(savedPostDraftJson) as Map<String, Object?>;
        savedPostDraft = PostDraft.fromJson(decoded);
      } on Object {
        // Abaikan bila draf lama korup.
      }
    }
    final savedHistory = p.getStringList(kMockSearchHistoryPrefsKey);
    if (savedHistory != null) {
      searchHistory
        ..clear()
        ..addAll(savedHistory);
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
    savedLegalConsent = null;
    onboardingDraft = const OnboardingDraft();
    latestRecoverySubmission = null;
    cachedFeedPage1 = <Post>[];
    savedPostDraft = null;
    searchHistory
      ..clear()
      ..addAll(const <String>['Simanjuntak', 'Medan', 'Punguan']);

    usersById.clear();
    userLastActiveAt.clear();
    margas.clear();
    cities.clear();
    nearbyLocationPermissionDenied = false;
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
    stories.clear();
    storyViewersByStoryId.clear();
    communityEvents.clear();
    eventAttendeesByEventId.clear();
    churches.clear();
    partuturanDictionary.clear();
    dataExportJobs.clear();
    accountDeletionsByUser.clear();
    notificationPrefsByUser.clear();
    loginHistoryByUser.clear();
    supportTickets.clear();
    recentlyCancelledDeletionUserId = null;
    retainedReportedMessages.clear();
    for (final timer in pendingAutoReplyTimers) {
      timer.cancel();
    }
    pendingAutoReplyTimers.clear();
    isChatAutoReplyEnabled = !appConfig.isProd;

    currentUserId = 'u-01';
    currentSelectedCity = 'Medan';
    hasGivenTaromboConsent = false;
    taromboParentNamesVisibility = FieldVisibility.onlyMe;
    _seedAll();

    if (prefs != null) {
      persistedAccountIds.clear();
      await prefs!.setBool(kMockLoggedOutPrefsKey, false);
      await prefs!.remove(kMockRegisteredAccountsPrefsKey);
      await prefs!.remove(kMockOwnProfilePrefsKey);
      await prefs!.remove(kMockOwnPrivacyPrefsKey);
      await persistSessionAndProfile();
    }
    notifyListeners();
  }

  void dispose() {
    for (final timer in pendingAutoReplyTimers) {
      timer.cancel();
    }
    pendingAutoReplyTimers.clear();
    conversationsStreamController.close();
    notificationsStreamController.close();
    for (final controller in messageStreamsByConv.values) {
      controller.close();
    }
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
    return BlockPolicy.isBlockedBetween(
      blocks: blocks,
      userAId: userAId,
      userBId: userBId,
    );
  }

  bool hasUserBlocked(String blockerId, String targetId) {
    return BlockPolicy.hasUserBlocked(
      blocks: blocks,
      blockerId: blockerId,
      targetId: targetId,
    );
  }

  /// AKN-R8 & AC-12: Menghapus data permanen pengguna setelah masa tunggu 30 hari berakhir,
  /// sambil membiarkan pesan chat lama terlihat sebagai "Pengguna terhapus".
  void purgePermanentlyDeletedUser(String userId) {
    usersById.remove(userId);
    persistedAccountIds.remove(userId);
    posts.removeWhere((p) => p.author.id == userId);
    comments.removeWhere((c) => c.author.id == userId);
    savedPosts.removeWhere((s) => s.userId == userId);
    likes.removeWhere((l) => l.user.id == userId);
    familyMembers.removeWhere((f) => f.ownerUserId == userId);
    follows.removeWhere(
      (f) => f.followerId == userId || f.followeeId == userId,
    );
    connections.removeWhere((c) => c.userId == userId || c.friend.id == userId);
    connectionRequests.removeWhere(
      (r) => r.sender.id == userId || r.receiver.id == userId,
    );
    blocks.removeWhere(
      (b) => b.blockerId == userId || b.blockedUser.id == userId,
    );
    devicesByUserId.remove(userId);
    if (currentUserId == userId) {
      currentUserId = null;
    }
    notifyListeners();
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
        targetMotherMarga: target.motherMarga,
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
    final followedBy = isFollowingUser(target.id, effectiveViewer.id);
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

    // PSN-R1 & AC-06: Tombol Pesan aktif bila Terhubung, sudah Mengikuti, diikuti (Follback gaya IG),
    // atau berbagi komunitas/sesi dan penerima mengizinkan pesan dari konteks bersama.
    final canMessage =
        !isSelf &&
        !blocked &&
        (connected ||
            following ||
            followedBy ||
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
      isFollowedBy: followedBy,
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
    final prefs =
        notificationPrefsByUser[recipientId] ?? const NotificationPreferences();
    if (!prefs.isEnabled(type)) {
      return AppNotification(
        id: nextId('notif-suppressed'),
        recipientId: recipientId,
        type: type,
        title: title,
        body: body,
        deepLink: deepLink,
        createdAt: now,
        isRead: true,
      );
    }

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

  /// PSN: Mengelompokkan notifikasi pesan baru belum dibaca per percakapan.
  AppNotification pushGroupedMessageNotification({
    required String recipientId,
    required String conversationId,
    required String title,
    required String body,
    required String deepLink,
  }) {
    final existingIdx = notifications.indexWhere(
      (n) =>
          n.recipientId == recipientId &&
          n.type == NotificationType.newMessage &&
          !n.isRead &&
          n.deepLink.contains('conversationId=$conversationId'),
    );
    if (existingIdx >= 0) {
      final prev = notifications[existingIdx];
      final countMatch = RegExp(r'^\((\d+) pesan baru\)').firstMatch(prev.body);
      final prevCount = countMatch != null
          ? (int.tryParse(countMatch.group(1)!) ?? 1)
          : 1;
      final nextCount = prevCount + 1;
      final updated = AppNotification(
        id: prev.id,
        recipientId: recipientId,
        type: NotificationType.newMessage,
        title: title,
        body: '($nextCount pesan baru) $body',
        deepLink: deepLink,
        createdAt: now,
      );
      notifications.removeAt(existingIdx);
      notifications.insert(0, updated);
      if (!notificationsStreamController.isClosed) {
        notificationsStreamController.add(visibleNotificationsForActiveUser());
      }
      onDebugStateChanged?.call();
      return updated;
    }
    return pushNotificationInternal(
      recipientId: recipientId,
      type: NotificationType.newMessage,
      title: title,
      body: body,
      deepLink: deepLink,
    );
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
      final updatedParticipants = conv.participants
          .map(
            (p) => usersById.containsKey(p.id)
                ? p
                : p.copyWith(displayName: 'Pengguna terhapus'),
          )
          .toList(growable: false);
      final resolvedTitle = conv.type == ConversationType.direct
          ? (updatedParticipants
                    .where((p) => p.id != uid)
                    .firstOrNull
                    ?.displayName ??
                conv.title)
          : conv.title;
      result.add(
        conv.copyWith(title: resolvedTitle, participants: updatedParticipants),
      );
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  void _seedAll() {
    final baseNow = now;
    margas.addAll(MockSeedData.standardMargas);

    // 42 pengguna fiktif
    final seedUsers = MockSeedData.buildUsers(baseNow);
    for (var i = 0; i < seedUsers.length; i++) {
      var u = seedUsers[i];
      if (u.id == 'u-10') {
        u = u.copyWith(
          privacySettings: const PrivacySettings(
            accountType: AccountVisibilityType.privateAccount,
          ),
        );
      }
      usersById[u.id] = u;
      userLastActiveAt[u.id] = baseNow.subtract(Duration(minutes: i * 15));
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

    loginHistoryByUser['u-01'] = <LoginHistoryEntry>[
      LoginHistoryEntry(
        id: 'log-01',
        userId: 'u-01',
        deviceName: 'Samsung Galaxy S24',
        platform: 'Android',
        city: 'Medan',
        loggedInAt: baseNow,
      ),
      LoginHistoryEntry(
        id: 'log-02',
        userId: 'u-01',
        deviceName: 'Xiaomi Pad 6',
        platform: 'Android',
        city: 'Medan',
        loggedInAt: baseNow.subtract(const Duration(days: 4)),
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
      // Tambahkan beberapa anggota biasa di kota yang sama (kecuali komunitas tertutup com-10
      // dan biarkan u-01 belum bergabung di com-02 agar varian Dengan persetujuan bisa diuji)
      if (comm.accessType != CommunityAccessType.closed) {
        for (final uid in allUserIds) {
          if (uid == comm.ownerId || comm.managerIds.contains(uid)) continue;
          if (comm.id == 'com-02' && uid == 'u-01') continue;
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

    // Permintaan gabung komunitas & pengumuman awal
    joinRequests.add(
      JoinRequest(
        id: 'jreq-01',
        communityId: 'com-01',
        applicant: toPersonSummary(
          usersById['u-12']!,
          viewer: usersById['u-01'],
        ),
        status: JoinRequestStatus.pending,
        createdAt: baseNow.subtract(const Duration(days: 1)),
        expiresAt: baseNow.add(const Duration(days: 13)),
      ),
    );
    announcements.add(
      Announcement(
        id: 'ann-01',
        communityId: 'com-01',
        author: toPersonSummary(usersById['u-01']!),
        title: 'Pertemuan Bulanan Punguan',
        body: 'Horas keluarga besar! Pertemuan bulanan diadakan Minggu depan pukul 15.00 WIB.',
        isPinned: true,
        createdAt: baseNow.subtract(const Duration(days: 2)),
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
      if (i < 10) {
        final replier =
            usersById['u-${(((i + 5) % 25) + 1).toString().padLeft(2, '0')}']!;
        comments.add(
          Comment(
            id: 'cmt-$postId-2',
            postId: postId,
            parentCommentId: 'cmt-$postId-1',
            author: toPersonSummary(replier, viewer: usersById['u-01']),
            text:
                'Setuju! Ditunggu agenda berikutnya di ${authorProfile.city}.',
            createdAt: createdAt.add(const Duration(minutes: 40)),
          ),
        );
      }

      // Seed likes untuk BER-08 Daftar suka
      final likeTargetCount = 4 + (i % 6);
      for (var k = 0; k < likeTargetCount; k++) {
        final liker =
            usersById['u-${(((i + k + 2) % 25) + 1).toString().padLeft(2, '0')}']!;
        likes.add(
          Like(
            id: 'like-$postId-$k',
            postId: postId,
            user: toPersonSummary(liker, viewer: usersById['u-01']),
            createdAt: createdAt.add(Duration(minutes: 5 + k)),
          ),
        );
      }
      final idxLast = posts.length - 1;
      posts[idxLast] = posts[idxLast].copyWith(
        likeCount: likeTargetCount,
        commentCount: i < 10 ? 2 : 1,
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

    // Permintaan pesan awal dari konteks bersama (PSN-02)
    final u05Summary = toPersonSummary(
      usersById['u-05']!,
      viewer: usersById['u-01'],
    );
    final reqMsg = Message(
      id: 'msg-req-01',
      conversationId: 'conv-dm-req-01',
      sender: u05Summary,
      text: 'Horas Lae, saya satu punguan Simanjuntak di Medan. Boleh kenalan?',
      createdAt: baseNow.subtract(const Duration(hours: 4)),
    );
    messagesByConversationId['conv-dm-req-01'] = <Message>[reqMsg];
    messageRequests.add(
      MessageRequest(
        id: 'mreq-seed-01',
        conversationId: 'conv-dm-req-01',
        sender: u05Summary,
        receiverId: 'u-01',
        firstMessage: reqMsg,
        sharedContextDescription: 'Berbagi komunitas Punguan Simanjuntak Medan',
        status: MessageRequestStatus.pending,
        createdAt: reqMsg.createdAt,
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

    // Klaim konfirmasi hubungan awal masuk untuk u-01 (TAR-07)
    partuturanClaims.add(
      PartuturanClaim(
        id: 'clm-seed-01',
        sender: toPersonSummary(usersById['u-07']!, viewer: usersById['u-01']),
        receiver: toPersonSummary(
          usersById['u-01']!,
          viewer: usersById['u-07'],
        ),
        claimedTermForReceiver: 'Bere',
        note: 'Boru Panggabean satu generasi di atas.',
        status: PartuturanClaimStatus.pending,
        createdAt: baseNow.subtract(const Duration(days: 1)),
      ),
    );

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

    // Benih Fase 2 (Gereja, Kegiatan, Kamus, Story)
    churches.addAll(MockSeedData.buildChurches());
    communityEvents.addAll(MockSeedData.buildCommunityEvents(baseNow));
    partuturanDictionary.addAll(MockSeedData.buildPartuturanDictionary());

    final u02StoryAuthor = toPersonSummary(
      usersById['u-02']!,
      viewer: usersById['u-01'],
    );
    final u04StoryAuthor = toPersonSummary(
      usersById['u-04']!,
      viewer: usersById['u-01'],
    );
    stories.addAll(<Story>[
      Story(
        id: 'story-01',
        author: u02StoryAuthor,
        mediaSeed: 'story-bona-taon',
        caption: 'Bona Taon 2026 Parsadaan di Medan! Horas!',
        createdAt: baseNow.subtract(const Duration(hours: 3)),
        expiresAt: baseNow.add(const Duration(hours: 21)),
        durationSeconds: 5,
        viewerCount: 6,
      ),
      Story(
        id: 'story-02',
        author: u04StoryAuthor,
        mediaSeed: 'story-koor-naposo',
        isVideo: true,
        durationSeconds: 12,
        caption: 'Latihan koor naposo persiapan festival gereja',
        createdAt: baseNow.subtract(const Duration(hours: 5)),
        expiresAt: baseNow.add(const Duration(hours: 19)),
        viewerCount: 4,
      ),
    ]);
    storyViewersByStoryId['story-01'] = <StoryViewer>[
      StoryViewer(
        id: 'view-01',
        storyId: 'story-01',
        viewer: toPersonSummary(usersById['u-03']!, viewer: usersById['u-01']),
        viewedAt: baseNow.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  // ── Fase 2 Helpers ─────────────────────────────────────────────────────────

  /// Cerita 24 Jam (BER-02, BER-03, BER-R12)
  List<Story> getActiveStories() {
    return stories.where((s) => now.isBefore(s.expiresAt)).toList();
  }

  Story createStory({
    required String mediaSeed,
    required bool isVideo,
    required int durationSeconds,
    String caption = '',
  }) {
    final authorProfile = activeProfile ?? usersById['u-01']!;
    final story = Story(
      id: 'story-${DateTime.now().microsecondsSinceEpoch}',
      author: toPersonSummary(authorProfile, viewer: activeProfile),
      mediaSeed: mediaSeed,
      caption: caption,
      isVideo: isVideo,
      durationSeconds: durationSeconds,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );
    stories.insert(0, story);
    return story;
  }

  List<StoryViewer> getStoryViewers(String storyId) {
    return storyViewersByStoryId[storyId] ?? const <StoryViewer>[];
  }

  void markStoryViewed(String storyId) {
    final idx = stories.indexWhere((s) => s.id == storyId);
    if (idx != -1) {
      final cur = stories[idx];
      if (!cur.isViewedByMe) {
        stories[idx] = cur.copyWith(
          isViewedByMe: true,
          viewerCount: cur.viewerCount + 1,
        );
        final viewerProfile = activeProfile ?? usersById['u-01']!;
        storyViewersByStoryId
            .putIfAbsent(storyId, () => <StoryViewer>[])
            .add(
              StoryViewer(
                id: 'view-${DateTime.now().microsecondsSinceEpoch}',
                storyId: storyId,
                viewer: toPersonSummary(viewerProfile, viewer: activeProfile),
                viewedAt: now,
              ),
            );
      }
    }
  }

  void deleteStory(String storyId) {
    stories.removeWhere((s) => s.id == storyId);
    storyViewersByStoryId.remove(storyId);
  }

  /// Kegiatan Komunitas & Gereja (SEK-09, SEK-R12)
  List<CommunityEvent> getEventsForCommunity(String communityId) {
    return communityEvents.where((e) => e.communityId == communityId).toList();
  }

  CommunityEvent? getEventById(String eventId) {
    final list = communityEvents.where((e) => e.id == eventId).toList();
    return list.isNotEmpty ? list.first : null;
  }

  CommunityEvent createCommunityEvent({
    required String communityId,
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String locationName,
    String? mapLink,
    int? capacity,
  }) {
    final comm = communities.where((c) => c.id == communityId).firstOrNull;
    final event = CommunityEvent(
      id: 'evt-${DateTime.now().microsecondsSinceEpoch}',
      communityId: communityId,
      communityName: comm?.name ?? '',
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      locationName: locationName,
      mapLink: mapLink,
      capacity: capacity,
      myRsvp: EventRsvpStatus.hadir,
      attendeeCount: 1,
    );
    communityEvents.insert(0, event);

    // Otomatis daftarkan pembuat
    final userProfile = activeProfile ?? usersById['u-01']!;
    eventAttendeesByEventId
        .putIfAbsent(event.id, () => <EventAttendee>[])
        .add(
          EventAttendee(
            id: 'att-${DateTime.now().microsecondsSinceEpoch}',
            eventId: event.id,
            user: toPersonSummary(userProfile, viewer: activeProfile),
            status: EventRsvpStatus.hadir,
            updatedAt: now,
          ),
        );
    return event;
  }

  CommunityEvent cancelCommunityEvent(String eventId) {
    final idx = communityEvents.indexWhere((e) => e.id == eventId);
    if (idx != -1) {
      final cancelled = communityEvents[idx].copyWith(isCancelled: true);
      communityEvents[idx] = cancelled;

      // Beri notifikasi ke seluruh peserta yang RSVP (SEK-R12)
      final attendees = eventAttendeesByEventId[eventId] ?? <EventAttendee>[];
      for (final att in attendees) {
        notifications.add(
          AppNotification(
            id: 'notif-${DateTime.now().microsecondsSinceEpoch}-${att.user.id}',
            recipientId: att.user.id,
            type: NotificationType.sessionUpdatedOrCancelled,
            title: 'Kegiatan Dibatalkan',
            body:
                'Kegiatan "${cancelled.title}" telah dibatalkan oleh pengurus.',
            deepLink: 'horas://app/sekitar/kegiatan-detail?id=${cancelled.id}',
            createdAt: now,
          ),
        );
      }
      return cancelled;
    }
    throw const ServerError(
      message: 'Kegiatan tidak ditemukan.',
      referenceCode: 'EVT-NOT-FOUND',
    );
  }

  CommunityEvent rsvpCommunityEvent({
    required String eventId,
    required EventRsvpStatus status,
  }) {
    final idx = communityEvents.indexWhere((e) => e.id == eventId);
    if (idx == -1) {
      throw const ServerError(
        message: 'Kegiatan tidak ditemukan.',
        referenceCode: 'EVT-NOT-FOUND',
      );
    }
    final cur = communityEvents[idx];
    final userProfile = activeProfile ?? usersById['u-01']!;
    final userSummary = toPersonSummary(userProfile, viewer: activeProfile);

    final attendees = eventAttendeesByEventId.putIfAbsent(
      eventId,
      () => <EventAttendee>[],
    );
    final attIdx = attendees.indexWhere((a) => a.user.id == userSummary.id);

    int countDelta = 0;
    if (status == EventRsvpStatus.hadir) {
      if (cur.myRsvp != EventRsvpStatus.hadir) countDelta = 1;
    } else {
      if (cur.myRsvp == EventRsvpStatus.hadir) countDelta = -1;
    }

    if (attIdx != -1) {
      attendees[attIdx] = EventAttendee(
        id: attendees[attIdx].id,
        eventId: eventId,
        user: userSummary,
        status: status,
        updatedAt: now,
      );
    } else {
      attendees.add(
        EventAttendee(
          id: 'att-${DateTime.now().microsecondsSinceEpoch}',
          eventId: eventId,
          user: userSummary,
          status: status,
          updatedAt: now,
        ),
      );
    }

    final updated = cur.copyWith(
      myRsvp: status,
      attendeeCount: (cur.attendeeCount + countDelta).clamp(0, 999999),
    );
    communityEvents[idx] = updated;
    return updated;
  }

  List<EventAttendee> getEventAttendees(String eventId) {
    return eventAttendeesByEventId[eventId] ?? const <EventAttendee>[];
  }

  /// Direktori Gereja Batak (SEK-10, SEK-11, SEK-R13)
  List<Church> getChurches({
    String? city,
    ChurchDenomination? denomination,
    String? query,
  }) {
    var res = List<Church>.from(churches);
    if (city != null && city.trim().isNotEmpty) {
      res = res
          .where((c) => c.city.toLowerCase() == city.toLowerCase())
          .toList();
    }
    if (denomination != null) {
      res = res.where((c) => c.denomination == denomination).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      res = res
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.address.toLowerCase().contains(q) ||
                c.city.toLowerCase().contains(q),
          )
          .toList();
    }
    return res;
  }

  Church? getChurchById(String churchId) {
    final list = churches.where((c) => c.id == churchId).toList();
    return list.isNotEmpty ? list.first : null;
  }

  Church proposeChurch({
    required String name,
    required ChurchDenomination denomination,
    required String address,
    required String city,
    required List<ChurchServiceSchedule> serviceSchedules,
    String contactPhone = '',
    String contactEmail = '',
    double? latitude,
    double? longitude,
  }) {
    final church = Church(
      id: 'church-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      denomination: denomination,
      address: address,
      city: city,
      serviceSchedules: serviceSchedules,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      isVerified: false,
      memberCount: 1,
      latitude: latitude,
      longitude: longitude,
    );
    churches.add(church);
    return church;
  }

  Church setMyHomeChurch(String churchId, {bool isVisible = false}) {
    final idx = churches.indexWhere((c) => c.id == churchId);
    if (idx != -1) {
      // Nonaktifkan gereja sebelumnya
      for (var i = 0; i < churches.length; i++) {
        if (churches[i].isUserHomeChurch) {
          churches[i] = churches[i].copyWith(
            isUserHomeChurch: false,
            memberCount: (churches[i].memberCount - 1).clamp(0, 99999),
          );
        }
      }
      final cur = churches[idx];
      final updated = cur.copyWith(
        isUserHomeChurch: true,
        isHomeChurchVisible: isVisible,
        memberCount: cur.memberCount + 1,
      );
      churches[idx] = updated;
      return updated;
    }
    throw const ServerError(
      message: 'Gereja tidak ditemukan.',
      referenceCode: 'CHU-NOT-FOUND',
    );
  }

  /// Kamus Partuturan (TAR-08)
  List<PartuturanDictionaryEntry> searchPartuturanDictionary({
    String query = '',
    SubEthnic? subEthnic,
  }) {
    var res = List<PartuturanDictionaryEntry>.from(partuturanDictionary);
    if (subEthnic != null) {
      res = res.where((e) => e.subEthnic == subEthnic).toList();
    }
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      res = res
          .where(
            (e) =>
                e.term.toLowerCase().contains(q) ||
                e.meaning.toLowerCase().contains(q) ||
                e.example.toLowerCase().contains(q) ||
                e.category.toLowerCase().contains(q),
          )
          .toList();
    }
    return res;
  }

  /// Grup Buatan Pengguna (PSN-R5)
  Conversation createCustomGroupChat({
    required String title,
    required List<String> memberUserIds,
    String? photoSeed,
  }) {
    final curProfile = activeProfile ?? usersById['u-01']!;
    final participantsList = <PersonSummary>[
      toPersonSummary(curProfile, viewer: curProfile),
    ];
    for (final uid in memberUserIds) {
      if (usersById.containsKey(uid) && uid != curProfile.id) {
        participantsList.add(
          toPersonSummary(usersById[uid]!, viewer: curProfile),
        );
      }
    }

    final convId = 'conv-group-${DateTime.now().microsecondsSinceEpoch}';
    final initialMsg = Message(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: convId,
      sender: toPersonSummary(curProfile, viewer: curProfile),
      text: 'Grup "$title" telah dibuat.',
      isAnnouncement: true,
      createdAt: now,
    );

    final conv = Conversation(
      id: convId,
      type: ConversationType.userGroup,
      title: title,
      participants: participantsList,
      lastMessage: initialMsg,
      updatedAt: initialMsg.createdAt,
    );

    conversations.insert(0, conv);
    messagesByConversationId[convId] = <Message>[initialMsg];
    conversationsStreamController.add(List<Conversation>.from(conversations));
    return conv;
  }
}
