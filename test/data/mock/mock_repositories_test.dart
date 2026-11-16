import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/widgets/debug_panel_sheet.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late MockStore store;

  setUp(() {
    store = MockStore(
      appConfig: const AppConfig(
        env: AppEnvironment.dev,
        useMockBackend: true,
        allowDraftRules: true,
      ),
      enableNetworkLatency: false,
    );
  });

  group('Bagian C & D - Data Tiruan, Validasi Repository, Notifikasi & Panel Debug', () {
    test('Data benih tiruan memuat ~42 pengguna, ~65 marga, 10 komunitas, 12 sesi, 10 lapangan, 30 postingan, dan 40+ kota', () {
      expect(store.usersById.length, greaterThanOrEqualTo(40));
      expect(store.margas.length, greaterThanOrEqualTo(60));
      expect(store.communities.length, 10);
      expect(store.sessions.length, 12);
      expect(store.courts.length, 10);
      expect(store.posts.length, 30);
      expect(store.cities.length, greaterThanOrEqualTo(40));
    });

    test('AC-05: Penolakan permintaan Kenalan tidak memberi tahu pengirim & mencegah kirim ulang selama 30 hari', () async {
      final connRepo = MockConnectionRepository(store);

      // u-01 mengirim Kenalan ke u-06
      final sent = await connRepo.sendConnectionRequest(
        targetUserId: 'u-06',
        introMessage: 'Horas Lae!',
      );
      expect(sent.isOk, isTrue);
      final reqId = (sent as Ok<ConnectionRequest>).value.id;

      final notifsForU01Before = store.notifications
          .where((n) => n.recipientId == 'u-01')
          .length;

      // u-06 menolak
      store.currentUserId = 'u-06';
      final responded = await connRepo.respondToConnectionRequest(
        requestId: reqId,
        accept: false,
      );
      expect(responded.isOk, isTrue);

      // u-01 tidak menerima notifikasi penolakan
      final notifsForU01After = store.notifications
          .where((n) => n.recipientId == 'u-01')
          .length;
      expect(notifsForU01After, notifsForU01Before);

      // u-01 mencoba mengirim ulang sebelum 30 hari -> ditolak (RateLimited)
      store.currentUserId = 'u-01';
      final retry = await connRepo.sendConnectionRequest(
        targetUserId: 'u-06',
        introMessage: 'Horas lagi!',
      );
      expect(retry.isErr, isTrue);
    });

    test('AC-06 & AC-16: Pesan ditolak bila tidak terhubung & tanpa konteks bersama; pesan pertama non-terhubung dengan tautan/uang diberi peringatan penipuan', () async {
      final chatRepo = MockChatRepository(store);
      final profileRepo = MockProfileRepository(store);

      // u-01 (Medan) dan u-36 (Pematangsiantar) belum terhubung dan tidak berbagi komunitas/sesi
      final summaryRes = await profileRepo.getPersonSummary('u-36');
      final u36Summary = (summaryRes as Ok<PersonSummary>).value;
      expect(u36Summary.canMessage, isFalse);

      final forbiddenMsg = await chatRepo.sendFirstMessageToUser(
        targetUserId: 'u-36',
        text: 'Horas!',
      );
      expect(forbiddenMsg.isErr, isTrue);

      // u-01 dan u-06 berbagi komunitas di Medan namun belum Terhubung -> masuk Permintaan Pesan
      // Mengandung kata transfer/tautan -> hasScamWarning == true (AC-16)
      final sharedContextMsg = await chatRepo.sendFirstMessageToUser(
        targetUserId: 'u-06',
        text: 'Tolong transfer uang ke rekening ini https://contoh.link',
      );
      expect(sharedContextMsg.isOk, isTrue);
      final msg = (sharedContextMsg as Ok<Message>).value;
      expect(msg.hasScamWarning, isTrue);
    });

    test('AC-08 & AC-09: Sesi penuh masuk daftar tunggu FIFO urutan 1; saat peserta keluar < 3 jam otomatis naik + notifikasi + catatan keandalan', () async {
      final sessionRepo = MockSessionRepository(store);

      // Buat sesi slot 2 yang mulai 2 jam dari sekarang
      final created = await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Sesi Uji Slot 2',
        city: 'Medan',
        startTime: store.now.add(const Duration(hours: 2)),
        endTime: store.now.add(const Duration(hours: 4)),
        maxSlots: 2,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 30000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
      );
      final sessionId = (created as Ok<PlaySession>).value.id;

      // Peserta ke-2 (u-02) bergabung -> slot penuh (2/2)
      store.currentUserId = 'u-02';
      final join2 = await sessionRepo.joinSession(sessionId);
      expect(
        (join2 as Ok<({Participant? participant, WaitlistEntry? waitlist})>)
            .value
            .participant,
        isNotNull,
      );

      // Peserta ke-3 (u-04) bergabung -> masuk daftar tunggu urutan 1 (AC-08)
      store.currentUserId = 'u-04';
      final join3 = await sessionRepo.joinSession(sessionId);
      expect(
        (join3 as Ok<({Participant? participant, WaitlistEntry? waitlist})>)
            .value
            .waitlist
            ?.position,
        1,
      );

      // Peserta ke-2 (u-02) keluar < 3 jam sebelum mulai ->
      // 1) u-02 mendapat catatan keandalan (AC-09)
      // 2) u-04 otomatis naik menjadi peserta & menerima notifikasi (AC-08)
      store.currentUserId = 'u-02';
      await sessionRepo.leaveSession(sessionId);

      final u02Marks = store.reliabilityMarks
          .where((m) => m.userId == 'u-02')
          .toList();
      expect(u02Marks, isNotEmpty);

      final currentParticipants = store.participants
          .where((p) => p.sessionId == sessionId)
          .map((p) => p.user.id)
          .toList();
      expect(currentParticipants, contains('u-04'));

      final promotedNotif = store.notifications.any(
        (n) =>
            n.recipientId == 'u-04' &&
            n.type == NotificationType.sessionJoinOrWaitlistPromoted,
      );
      expect(promotedNotif, isTrue);
    });

    test('AC-10, AC-11, AC-13, AC-14: EXIF lokasi dihapus, Blokir dua arah, Komunitas tertutup tersembunyi, Laporan berstatus Diterima', () async {
      final postRepo = MockPostRepository(store);
      final blockRepo = MockBlockRepository(store);
      final profileRepo = MockProfileRepository(store);
      final searchRepo = MockSearchRepository(store);
      final reportRepo = MockReportRepository(store);

      // AC-10: Foto dengan EXIF lokasi dibersihkan saat diposting
      final postRes = await postRepo.createPost(
        text: 'Suasana sore',
        visibility: PostVisibility.publicPost,
        mediaSeeds: const <String>['seed-foto-1'],
        mediaSizesBytes: const <int>[1024 * 500],
        rawExifPerMedia: const <Map<String, String>>[
          <String, String>{
            'CameraModel': 'Galaxy',
            'GPSLatitude': '3.5952',
            'GPSLongitude': '98.6722',
          },
        ],
      );
      final createdPost = (postRes as Ok<Post>).value;
      expect(createdPost.media.single.exifLocationStripped, isTrue);
      expect(
        createdPost.media.single.metadata.containsKey('GPSLatitude'),
        isFalse,
      );
      expect(createdPost.media.single.metadata['CameraModel'], 'Galaxy');

      // AC-11: u-01 memblokir u-02 -> tidak saling terlihat & koneksi dihapus
      await blockRepo.blockUser('u-02');
      expect((await profileRepo.getPersonSummary('u-02')).isErr, isTrue);
      expect(store.isConnectedBetween('u-01', 'u-02'), isFalse);

      // AC-13: Komunitas tertutup (com-10, milik u-06) tidak muncul di pencarian bagi u-01
      final commSearch = await searchRepo.searchCommunities(query: 'Ompung');
      expect(
        (commSearch as Ok<List<Community>>).value.any((c) => c.id == 'com-10'),
        isFalse,
      );

      // AC-14: Laporan postingan masuk berstatus Diterima & terlihat di getMyReports
      final repRes = await reportRepo.submitReport(
        targetType: ReportTargetType.post,
        targetId: 'post-05',
        category: ReportCategory.spamScam,
        note: 'Indikasi spam',
      );
      final report = (repRes as Ok<Report>).value;
      expect(report.status, ReportStatus.received);
      final myReports =
          (await reportRepo.getMyReports() as Ok<List<Report>>).value;
      expect(myReports.any((r) => r.id == report.id), isTrue);
    });

    test(
      'Tarombo & Klaim Kerabat meningkatkan keyakinan partuturan ke Tinggi',
      () async {
        final taromboRepo = MockTaromboRepository(store);
        final partuturanRepo = MockPartuturanRepository(store);

        // Sebelum klaim: u-01 (Simanjuntak, ibu Sitorus, 1996) ke u-03 (Bona Sitorus, 1970) -> Sedang
        final before = (await partuturanRepo.evaluateWithUser(
          'u-03',
        ) as Ok<PartuturanResult>).value;
        expect(before.confidence, PartuturanConfidence.sedang);
        expect(before.displayBadgeText, 'Kemungkinan: Tulang');

        // Kirim klaim & u-03 menyetujui
        final claimRes = await taromboRepo.sendKinshipClaim(
          targetUserId: 'u-03',
          claimedTermForTarget: 'Tulang',
        );
        final claimId = (claimRes as Ok<PartuturanClaim>).value.id;

        store.currentUserId = 'u-03';
        await taromboRepo.respondKinshipClaim(claimId: claimId, accept: true);

        store.currentUserId = 'u-01';
        final after = (await partuturanRepo.evaluateWithUser(
          'u-03',
        ) as Ok<PartuturanResult>).value;
        expect(after.confidence, PartuturanConfidence.tinggi);
        expect(after.displayBadgeText, 'Dia adalah Tulangmu');
      },
    );

    testWidgets(
      'DebugPanelSheet tampil pada build non-prod dan mengubah state simulasi',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              enableMockNetworkLatencyProvider.overrideWithValue(false),
            ],
            child: const MaterialApp(home: Scaffold(body: DebugPanelSheet())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.debugToggleOffline), findsOneWidget);
        expect(find.text(AppStrings.debugClockAdvance30Days), findsOneWidget);

        await tester.tap(find.text(AppStrings.debugClockAdvance30Days));
        await tester.pump();
        expect(find.textContaining('+720j'), findsOneWidget);
      },
    );
  });
}
