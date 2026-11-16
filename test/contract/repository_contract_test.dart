import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/utils/push_notification_service.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/data/supabase/supabase_repositories.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/repositories/repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Konfigurasi target kontrak repository (Mock atau Supabase lokal).
final class ContractHarness {
  ContractHarness({
    required this.label,
    required this.isLiveSupabase,
    required this.profileRepo,
    required this.followRepo,
    required this.connectionRepo,
    required this.blockRepo,
    required this.postRepo,
    required this.commentRepo,
    required this.searchRepo,
    required this.nearbyRepo,
    required this.communityRepo,
    required this.sessionRepo,
    required this.courtRepo,
    required this.chatRepo,
    required this.notificationRepo,
    required this.reportRepo,
    required this.taromboRepo,
    required this.partuturanRepo,
    required this.supportRepo,
    required this.peerSameCityId,
    required this.peerSharedContextId,
    required this.peerStrangerId,
    required this.closedCommunityId,
    required this.cleanup,
  });

  final String label;
  final bool isLiveSupabase;
  final ProfileRepository profileRepo;
  final FollowRepository followRepo;
  final ConnectionRepository connectionRepo;
  final BlockRepository blockRepo;
  final PostRepository postRepo;
  final CommentRepository commentRepo;
  final SearchRepository searchRepo;
  final NearbyRepository nearbyRepo;
  final CommunityRepository communityRepo;
  final SessionRepository sessionRepo;
  final CourtRepository courtRepo;
  final ChatRepository chatRepo;
  final NotificationRepository notificationRepo;
  final ReportRepository reportRepo;
  final TaromboRepository taromboRepo;
  final PartuturanRepository partuturanRepo;
  final SupportRepository supportRepo;
  final String peerSameCityId;
  final String peerSharedContextId;
  final String peerStrangerId;
  final String closedCommunityId;
  final Future<void> Function() cleanup;
}

Future<ContractHarness> _buildMockHarness() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final store = MockStore(
    appConfig: const AppConfig(
      env: AppEnvironment.dev,
      useMockBackend: true,
      allowDraftRules: true,
    ),
    prefs: prefs,
    enableNetworkLatency: false,
  );
  final chatRepo = MockChatRepository(store);
  return ContractHarness(
    label: 'MockBackend',
    isLiveSupabase: false,
    profileRepo: MockProfileRepository(store),
    followRepo: MockFollowRepository(store),
    connectionRepo: MockConnectionRepository(store),
    blockRepo: MockBlockRepository(store),
    postRepo: MockPostRepository(store),
    commentRepo: MockCommentRepository(store),
    searchRepo: MockSearchRepository(store),
    nearbyRepo: MockNearbyRepository(store),
    communityRepo: MockCommunityRepository(store, chatRepo),
    sessionRepo: MockSessionRepository(store, chatRepo),
    courtRepo: MockCourtRepository(store),
    chatRepo: chatRepo,
    notificationRepo: MockNotificationRepository(store),
    reportRepo: MockReportRepository(store),
    taromboRepo: MockTaromboRepository(store),
    partuturanRepo: MockPartuturanRepository(store),
    supportRepo: MockSupportRepository(store),
    peerSameCityId: 'u-03',
    peerSharedContextId: 'u-06',
    peerStrangerId: 'u-36',
    closedCommunityId: 'com-10',
    cleanup: () async {
      store.dispose();
    },
  );
}

Future<ContractHarness?> _buildSupabaseHarnessIfConfigured() async {
  const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  const runLive = bool.fromEnvironment(
    'RUN_LIVE_SUPABASE_TESTS',
    defaultValue: false,
  );
  if (!runLive || url.isEmpty || anonKey.isEmpty) {
    return null;
  }

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final client = SupabaseClient(
    url,
    anonKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  // Login ke pengguna uji u-01 via test OTP lokal
  await client.auth.verifyOTP(
    phone: '+628121000001',
    token: '123456',
    type: OtpType.sms,
  );

  final gw = SupabaseGateway(
    client: client,
    prefs: prefs,
    appConfig: const AppConfig(
      env: AppEnvironment.dev,
      useMockBackend: false,
      allowDraftRules: true,
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
    ),
  );
  final authRepo = SupabaseAuthRepository(gw);
  await authRepo.restoreSessionProfile();
  final postRepo = SupabasePostRepository(gw);
  final chatRepo = SupabaseChatRepository(gw);
  final notifRepo = SupabaseNotificationRepository(gw);

  return ContractHarness(
    label: 'SupabaseLocal',
    isLiveSupabase: true,
    profileRepo: SupabaseProfileRepository(gw, authRepo),
    followRepo: SupabaseFollowRepository(gw),
    connectionRepo: SupabaseConnectionRepository(gw),
    blockRepo: SupabaseBlockRepository(gw),
    postRepo: postRepo,
    commentRepo: SupabaseCommentRepository(gw, postRepo),
    searchRepo: SupabaseSearchRepository(gw),
    nearbyRepo: SupabaseNearbyRepository(gw),
    communityRepo: SupabaseCommunityRepository(gw),
    sessionRepo: SupabaseSessionRepository(gw),
    courtRepo: SupabaseCourtRepository(gw),
    chatRepo: chatRepo,
    notificationRepo: notifRepo,
    reportRepo: SupabaseReportRepository(gw),
    taromboRepo: SupabaseTaromboRepository(gw),
    partuturanRepo: SupabasePartuturanRepository(gw),
    supportRepo: SupabaseSupportRepository(gw),
    peerSameCityId: '00000000-0000-4000-8000-000000000003',
    peerSharedContextId: '00000000-0000-4000-8000-000000000004',
    peerStrangerId: '00000000-0000-4000-8000-000000000011',
    closedCommunityId: '20000000-0000-4000-8000-000000000010',
    cleanup: () async {
      chatRepo.dispose();
      notifRepo.dispose();
      await client.dispose();
    },
  );
}

void _registerContractSuite(
  String suiteName,
  Future<ContractHarness?> Function() createHarness,
) {
  group('ContractSuite [$suiteName]', () {
    test('AC-07, TAR-R5 & Search/Nearby privacy parity', () async {
      final h = await createHarness();
      if (h == null) return;
      addTearDown(h.cleanup);

      final summaryRes = await h.profileRepo.getPersonSummary(h.peerSameCityId);
      expect(summaryRes.isOk, isTrue);
      final summary = (summaryRes as Ok<PersonSummary>).value;
      expect(summary.marga, isNotEmpty);
      expect(summary.partuturan?.isEstimate ?? true, isTrue);

      final nearbyRes = await h.nearbyRepo.getNearbyPeople(city: 'Medan');
      expect(nearbyRes.isOk, isTrue);
      expect((nearbyRes as Ok<List<PersonSummary>>).value, isNotEmpty);

      final margasRes = await h.profileRepo.getStandardMargaList();
      expect(margasRes.isOk, isTrue);
      expect(
        (margasRes as Ok<List<MargaEntry>>).value.length,
        greaterThanOrEqualTo(60),
      );
    });

    test('AC-13 closed community visibility & Support FAQ parity', () async {
      final h = await createHarness();
      if (h == null) return;
      addTearDown(h.cleanup);

      final commsRes = await h.searchRepo.searchCommunities(query: 'Ompung');
      expect(commsRes.isOk, isTrue);
      final comms = (commsRes as Ok<List<Community>>).value;
      expect(comms.any((c) => c.id == h.closedCommunityId), isFalse);

      final joinClosed = await h.communityRepo.joinCommunity(
        h.closedCommunityId,
      );
      expect(joinClosed.isErr, isTrue);

      final faqRes = await h.supportRepo.getHelpArticles();
      expect(faqRes.isOk, isTrue);
      expect(
        (faqRes as Ok<List<HelpArticle>>).value.length,
        greaterThanOrEqualTo(4),
      );
    });

    test(
      'Post & Comment CRUD, validation & offline cache page-1 (AC-15)',
      () async {
        final h = await createHarness();
        if (h == null) return;
        addTearDown(h.cleanup);

        // Validasi panjang karakter ditolak konsisten
        final tooLong = await h.postRepo.createPost(
          text: 'A' * 2005,
          visibility: PostVisibility.publicPost,
        );
        expect(tooLong.isErr, isTrue);
        expect((tooLong as Err<Post>).failure, isA<ValidationError>());

        final feedRes = await h.postRepo.getFeed(page: 1, pageSize: 5);
        expect(feedRes.isOk, isTrue);
        expect((feedRes as Ok<List<Post>>).value, isNotEmpty);
        expect(h.postRepo.getCachedFeedPage1(), isNotEmpty);

        final createdRes = await h.postRepo.createPost(
          text: 'Uji kontrak postingan Horas!',
          visibility: PostVisibility.publicPost,
        );
        expect(createdRes.isOk, isTrue);
        final post = (createdRes as Ok<Post>).value;

        final liked = await h.postRepo.toggleLike(post.id);
        expect(liked.isOk, isTrue);
        expect((liked as Ok<Post>).value.isLikedByMe, isTrue);

        final commentRes = await h.commentRepo.addComment(
          postId: post.id,
          text: 'Mantap Lae!',
        );
        expect(commentRes.isOk, isTrue);

        final delRes = await h.postRepo.deletePost(post.id);
        expect(delRes.isOk, isTrue);
      },
    );

    test(
      'Session MAN-R7 anti-betting, Courts & Tarombo/Partuturan (< 200ms)',
      () async {
        final h = await createHarness();
        if (h == null) return;
        addTearDown(h.cleanup);

        final bettingRes = await h.sessionRepo.createSession(
          sportType: SportType.badminton,
          title: 'Main Taruhan Uang',
          city: 'Medan',
          startTime: DateTime.now().toUtc().add(const Duration(days: 3)),
          endTime: DateTime.now().toUtc().add(
            const Duration(days: 3, hours: 2),
          ),
          maxSlots: 4,
          skillLevel: SkillLevel.intermediate,
          feePerPersonRupiah: 20000,
          visibility: SessionVisibility.publicInArea,
          joinMode: SessionJoinMode.instant,
          notes: 'Ada voor taruhan',
        );
        expect(bettingRes.isErr, isTrue);
        expect(
          (bettingRes as Err<PlaySession>).failure,
          isA<ValidationError>(),
        );

        final courtsRes = await h.courtRepo.getCourts(city: 'Medan');
        expect(courtsRes.isOk, isTrue);
        expect((courtsRes as Ok<List<Court>>).value, isNotEmpty);

        // Partuturan < 200ms dari cache/aset
        await h.partuturanRepo.evaluateManual(
          viewerMarga: 'Simanjuntak',
          viewerGender: UserGender.male,
          subEthnic: SubEthnic.toba,
          targetMarga: 'Sitorus',
          targetGender: UserGender.male,
          generationInfo: const GenerationInfo(
            delta: 1,
            source: GenerationSource.sundut,
          ),
          viewerMotherMarga: 'Sitorus',
        );
        final sw = Stopwatch()..start();
        final evalRes = await h.partuturanRepo.evaluateManual(
          viewerMarga: 'Simanjuntak',
          viewerGender: UserGender.male,
          subEthnic: SubEthnic.toba,
          targetMarga: 'Sitorus',
          targetGender: UserGender.male,
          generationInfo: const GenerationInfo(
            delta: 1,
            source: GenerationSource.sundut,
          ),
          viewerMotherMarga: 'Sitorus',
        );
        sw.stop();
        expect(evalRes.isOk, isTrue);
        expect((evalRes as Ok<PartuturanResult>).value.istilah, 'Tulang');
        expect(sw.elapsedMilliseconds, lessThan(200));

        final upRes = await h.taromboRepo.upsertFamilyMember(
          relationType: FamilyRelationType.father,
          fullName: 'Oppung Test',
          marga: 'Simanjuntak',
          gender: UserGender.male,
          lifeStatus: LifeStatus.alive,
        );
        expect(upRes.isOk, isTrue);
        final pctRes = await h.taromboRepo.getCompletenessPercent();
        expect(pctRes.isOk, isTrue);
        expect((pctRes as Ok<int>).value, greaterThanOrEqualTo(40));
        await h.taromboRepo.deleteFamilyMember(
          (upRes as Ok<FamilyMember>).value.id,
        );
      },
    );

    test('AC-06 & AC-16 chat rules + AC-11 block/unblock', () async {
      final h = await createHarness();
      if (h == null) return;
      addTearDown(h.cleanup);

      // Orang asing tanpa komunitas/sesi bersama ditolak
      final denied = await h.chatRepo.sendFirstMessageToUser(
        targetUserId: h.peerStrangerId,
        text: 'Halo orang asing!',
      );
      expect(denied.isErr, isTrue);

      // Pengguna berbagi konteks + tautan -> hasScamWarning == true (AC-16)
      final reqMsg = await h.chatRepo.sendFirstMessageToUser(
        targetUserId: h.peerSharedContextId,
        text: 'Tolong transfer ke https://contoh.invalid',
      );
      expect(reqMsg.isOk, isTrue);
      expect((reqMsg as Ok<Message>).value.hasScamWarning, isTrue);

      // Blokir lalu buka blokir (AC-11)
      final blkRes = await h.blockRepo.blockUser(h.peerStrangerId);
      expect(blkRes.isOk, isTrue);
      expect(
        h.blockRepo.isBlockedBetween(
          h.isLiveSupabase ? '00000000-0000-4000-8000-000000000001' : 'u-01',
          h.peerStrangerId,
        ),
        isTrue,
      );

      final blockedLookup = await h.profileRepo.getPersonSummary(
        h.peerStrangerId,
      );
      expect(blockedLookup.isErr, isTrue);
      await h.blockRepo.unblockUser(h.peerStrangerId);
    });
  });
}

void main() {
  test('SupabaseErrorMapper maps all 7 AppError variants accurately', () {
    expect(
      SupabaseErrorMapper.map(const SocketException('offline')),
      isA<OfflineError>(),
    );
    expect(
      SupabaseErrorMapper.map(
        const PostgrestException(
          message: 'HORAS_ERR|RATE_LIMITED|2030-01-01T00:00:00Z|kenalan|Tunggu 30 hari',
        ),
      ),
      isA<RateLimitedError>().having(
        (e) => e.retryAt,
        'retryAt',
        DateTime.utc(2030, 1, 1),
      ),
    );
    expect(
      SupabaseErrorMapper.map(
        const PostgrestException(
          message: 'HORAS_ERR|SUSPENDED||true|Akun ditangguhkan',
        ),
      ),
      isA<SuspendedError>(),
    );
    expect(
      SupabaseErrorMapper.map(
        const PostgrestException(
          message: 'HORAS_ERR|PERMISSION_DENIED||auth|Ditolak',
        ),
      ),
      isA<PermissionDeniedError>(),
    );
    expect(
      SupabaseErrorMapper.map(
        const PostgrestException(
          message: 'HORAS_ERR|CONTENT_UNAVAILABLE||target|Tidak ditemukan',
        ),
      ),
      isA<UnavailableError>(),
    );
    expect(
      SupabaseErrorMapper.map(
        const PostgrestException(
          message: 'HORAS_ERR|VALIDATION_ERROR||notes|Dilarang judi',
        ),
      ),
      isA<ValidationError>().having((e) => e.field, 'field', 'notes'),
    );
    expect(
      SupabaseErrorMapper.map(
        const PostgrestException(message: 'unknown db err'),
      ),
      isA<ServerError>().having(
        (e) => e.referenceCode,
        'referenceCode',
        startsWith('HRS-'),
      ),
    );
  });

  test('PushNotificationService maps PRD 9 payloads and initializes safely without Firebase config', () async {
    expect(
      PushNotificationService.resolveDeepLinkFromData(<String, dynamic>{
        'type': 'newMessage',
        'targetId': 'conv-1',
      }),
      '/pesan/pribadi?id=conv-1',
    );
    expect(
      PushNotificationService.resolveDeepLinkFromData(<String, dynamic>{
        'deepLink': 'horas://app/main/sesi-detail?id=ses-9',
      }),
      '/main/sesi-detail?id=ses-9',
    );

    final service = PushNotificationService();
    await service.initialize(onDeepLinkTap: (_) {});
    expect(service.isConfigured, isFalse);
  });

  _registerContractSuite('Mock', _buildMockHarness);
  _registerContractSuite('SupabaseLocal', _buildSupabaseHarnessIfConfigured);
}
