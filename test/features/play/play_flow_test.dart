import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/app.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/horas_policies.dart';
import 'package:horas/features/play/presentation/man01_play_page.dart';
import 'package:horas/features/play/presentation/man03_create_session_page.dart';
import 'package:horas/features/play/presentation/man04_session_detail_page.dart';
import 'package:horas/features/play/presentation/man05_participants_page.dart';
import 'package:horas/features/play/presentation/man06_patungan_page.dart';
import 'package:material_ui/material_ui.dart';

MockStore _makeStore() => MockStore(
  appConfig: const AppConfig(
    env: AppEnvironment.dev,
    useMockBackend: true,
    allowDraftRules: true,
  ),
  enableNetworkLatency: false,
);

void main() {
  group('Prompt 7 - Modul Main (MAN-01..MAN-09, AC-08, AC-09, Alur A4)', () {
    test('Validasi waktu (<1 jam / >60 hari), slot 2-50, biaya 0-1jt, filter taruhan/judi, dan batas 5 sesi aktif', () async {
      final store = _makeStore();
      final chatRepo = MockChatRepository(store);
      final sessionRepo = MockSessionRepository(store, chatRepo);
      final baseNow = store.now;

      // 1. Waktu mulai < 1 jam ditolak
      final tooSoon = await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Badminton Kilat',
        city: 'Medan',
        startTime: baseNow.add(const Duration(minutes: 30)),
        endTime: baseNow.add(const Duration(hours: 2)),
        maxSlots: 4,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 20000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-01',
      );
      expect(tooSoon.isErr, isTrue);

      // 2. Waktu mulai > 60 hari ditolak
      final tooFar = await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Badminton Tahun Depan',
        city: 'Medan',
        startTime: baseNow.add(const Duration(days: 61)),
        endTime: baseNow.add(const Duration(days: 61, hours: 2)),
        maxSlots: 4,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 20000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-01',
      );
      expect(tooFar.isErr, isTrue);

      // 3. Slot di luar 2-50 ditolak
      final badSlots = await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Badminton Sendiri',
        city: 'Medan',
        startTime: baseNow.add(const Duration(hours: 3)),
        endTime: baseNow.add(const Duration(hours: 5)),
        maxSlots: 1,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 20000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-01',
      );
      expect(badSlots.isErr, isTrue);

      // 4. Biaya > Rp1.000.000 ditolak
      final badFee = await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Badminton Sultan',
        city: 'Medan',
        startTime: baseNow.add(const Duration(hours: 3)),
        endTime: baseNow.add(const Duration(hours: 5)),
        maxSlots: 4,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 1500000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-01',
      );
      expect(badFee.isErr, isTrue);

      // 5. Filter kata taruhan / judi (MAN-R7)
      final gamblingSession = await sessionRepo.createSession(
        sportType: SportType.futsal,
        title: 'Futsal Taruhan Berhadiah',
        city: 'Medan',
        startTime: baseNow.add(const Duration(hours: 3)),
        endTime: baseNow.add(const Duration(hours: 5)),
        maxSlots: 10,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 30000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-02',
      );
      expect(gamblingSession.isErr, isTrue);

      // 6. Batas 5 sesi aktif per host (switch ke u-10 yang belum punya sesi aktif)
      store.currentUserId = 'u-10';
      for (var i = 0; i < 5; i++) {
        final okRes = await sessionRepo.createSession(
          sportType: SportType.jogging,
          title: 'Jogging Pagi #$i',
          city: 'Medan',
          startTime: baseNow.add(Duration(days: i + 1, hours: 2)),
          endTime: baseNow.add(Duration(days: i + 1, hours: 3)),
          maxSlots: 6,
          skillLevel: SkillLevel.all,
          feePerPersonRupiah: 0,
          visibility: SessionVisibility.publicInArea,
          joinMode: SessionJoinMode.instant,
          manualLocationSummary: 'Lapangan Merdeka Medan',
        );
        expect(okRes.isOk, isTrue);
      }
      final sixthRes = await sessionRepo.createSession(
        sportType: SportType.jogging,
        title: 'Jogging Pagi #6',
        city: 'Medan',
        startTime: baseNow.add(const Duration(days: 7, hours: 2)),
        endTime: baseNow.add(const Duration(days: 7, hours: 3)),
        maxSlots: 6,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 0,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        manualLocationSummary: 'Lapangan Merdeka Medan',
      );
      expect(sixthRes.isErr, isTrue);
    });

    test('Patungan membulatkan ke atas ke kelipatan Rp500 (MAN-R7)', () {
      expect(
        HorasPolicies.calculatePatunganPerPerson(
          totalRupiah: 50000,
          participantCount: 3,
        ),
        17000,
      );
      expect(
        HorasPolicies.calculatePatunganPerPerson(
          totalRupiah: 100000,
          participantCount: 4,
        ),
        25000,
      );
      expect(
        HorasPolicies.calculatePatunganPerPerson(
          totalRupiah: 10001,
          participantCount: 2,
        ),
        5500,
      );
    });

    test('AC-08: FIFO waitlist auto-promosi + notifikasi & keluar tanpa catatan dalam 1 jam', () async {
      final store = _makeStore();
      final chatRepo = MockChatRepository(store);
      final sessionRepo = MockSessionRepository(store, chatRepo);

      // Host u-09 buat sesi dengan maxSlots: 2 (host + 1 peserta). Start 2 jam lagi (< 3 jam!)
      store.currentUserId = 'u-09';
      final start = store.now.add(const Duration(hours: 2));
      final created = (await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Duel Tunggal FIFO',
        city: 'Medan',
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
        maxSlots: 2,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 25000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-01',
      ) as Ok<PlaySession>).value;

      // u-02 isi slot terakhir
      store.currentUserId = 'u-02';
      final join2 = await sessionRepo.joinSession(created.id);
      expect(
        (join2 as Ok<({Participant? participant, WaitlistEntry? waitlist})>)
            .value
            .participant
            ?.status,
        ParticipantStatus.joined,
      );

      // u-03 dan u-04 masuk daftar tunggu urutan 1 dan 2
      store.currentUserId = 'u-03';
      final wait3 = await sessionRepo.joinSession(created.id);
      expect(
        (wait3 as Ok<({Participant? participant, WaitlistEntry? waitlist})>)
            .value
            .waitlist
            ?.position,
        1,
      );

      store.currentUserId = 'u-04';
      final wait4 = await sessionRepo.joinSession(created.id);
      expect(
        (wait4 as Ok<({Participant? participant, WaitlistEntry? waitlist})>)
            .value
            .waitlist
            ?.position,
        2,
      );

      // u-02 keluar -> u-03 otomatis promosi & terima notifikasi, u-04 jadi urutan 1
      store.currentUserId = 'u-02';
      await sessionRepo.leaveSession(created.id);

      final participantsAfter = (await sessionRepo.getParticipants(
        created.id,
      ) as Ok<List<Participant>>).value;
      final promoted3 = participantsAfter.firstWhere(
        (p) => p.user.id == 'u-03',
      );
      expect(promoted3.status, ParticipantStatus.joined);
      expect(promoted3.promotedFromWaitlistAt, isNotNull);

      final waitlistAfter = (await sessionRepo.getWaitlist(
        created.id,
      ) as Ok<List<WaitlistEntry>>).value;
      expect(waitlistAfter.length, 1);
      expect(waitlistAfter.first.user.id, 'u-04');
      expect(waitlistAfter.first.position, 1);

      final promoNotif = store.notifications.any(
        (n) =>
            n.recipientId == 'u-03' &&
            n.type == NotificationType.sessionJoinOrWaitlistPromoted,
      );
      expect(promoNotif, isTrue);

      // u-03 keluar dalam 1 jam (walau start < 3 jam lagi) -> TANPA catatan keandalan (AC-08)
      store.timeOffset += const Duration(minutes: 20);
      store.currentUserId = 'u-03';
      await sessionRepo.leaveSession(created.id);

      store.currentUserId = 'u-09';
      final marksFor3 = (await sessionRepo.getReliabilityMarksForHost(
        'u-03',
      ) as Ok<List<ReliabilityMark>>).value;
      expect(marksFor3, isEmpty);
    });

    test('AC-09: Keluar mendadak < 3 jam, tidak hadir oleh host, dan 3 catatan dalam 30 hari blokir 7 hari', () async {
      final store = _makeStore();
      final chatRepo = MockChatRepository(store);
      final sessionRepo = MockSessionRepository(store, chatRepo);

      // Buat 2 sesi < 3 jam & 1 sesi untuk no-show, lalu u-08 dapat 3 catatan keandalan
      store.currentUserId = 'u-09';
      final startNear = store.now.add(const Duration(hours: 2));
      final s1 = (await sessionRepo.createSession(
        sportType: SportType.futsal,
        title: 'Futsal Keandalan 1',
        city: 'Medan',
        startTime: startNear,
        endTime: startNear.add(const Duration(hours: 2)),
        maxSlots: 8,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 20000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-02',
      ) as Ok<PlaySession>).value;
      final s2 = (await sessionRepo.createSession(
        sportType: SportType.futsal,
        title: 'Futsal Keandalan 2',
        city: 'Medan',
        startTime: startNear,
        endTime: startNear.add(const Duration(hours: 2)),
        maxSlots: 8,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 20000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-02',
      ) as Ok<PlaySession>).value;
      final s3 = (await sessionRepo.createSession(
        sportType: SportType.futsal,
        title: 'Futsal Keandalan 3',
        city: 'Medan',
        startTime: store.now.add(const Duration(hours: 5)),
        endTime: store.now.add(const Duration(hours: 7)),
        maxSlots: 8,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 20000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-02',
      ) as Ok<PlaySession>).value;
      final s4 = (await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Sesi Target Blokir',
        city: 'Medan',
        startTime: store.now.add(const Duration(days: 2)),
        endTime: store.now.add(const Duration(days: 2, hours: 2)),
        maxSlots: 6,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 25000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-01',
      ) as Ok<PlaySession>).value;

      // u-08 gabung s1, s2, s3 lalu keluar mendadak di s1 & s2
      store.currentUserId = 'u-08';
      await sessionRepo.joinSession(s1.id);
      await sessionRepo.joinSession(s2.id);
      final join3 = await sessionRepo.joinSession(s3.id);
      final p3 =
          (join3 as Ok<({Participant? participant, WaitlistEntry? waitlist})>)
              .value
              .participant!;

      await sessionRepo.leaveSession(s1.id);
      await sessionRepo.leaveSession(s2.id);

      // Host u-09 menandai u-08 Tidak Hadir pada s3 (catatan ke-3)
      store.currentUserId = 'u-09';
      await sessionRepo.markAttendance(
        sessionId: s3.id,
        participantId: p3.id,
        attended: false,
      );

      final marks = (await sessionRepo.getReliabilityMarksForHost(
        'u-08',
      ) as Ok<List<ReliabilityMark>>).value;
      expect(marks.length, 3);

      // u-08 ditolak gabung s4 selama 7 hari
      store.currentUserId = 'u-08';
      final blockedJoin = await sessionRepo.joinSession(s4.id);
      expect(blockedJoin.isErr, isTrue);
      final errMsg =
          (blockedJoin
                  as Err<({Participant? participant, WaitlistEntry? waitlist})>)
              .failure
              .message;
      expect(errMsg, contains('Belum bisa bergabung selama 7 hari'));

      // Setelah 8 hari berlalu, pembatasan berakhir
      store.timeOffset += const Duration(days: 8);
      final unblockedJoin = await sessionRepo.joinSession(s4.id);
      expect(unblockedJoin.isOk, isTrue);
    });

    test('MAN-R9 & MAN-R11 & MAN-R10: Siklus selesai 2j, chat baca-saja 24j, jam tenang 22.00-06.00, & >3 laporan lapangan', () async {
      final store = _makeStore();
      final chatRepo = MockChatRepository(store);
      final sessionRepo = MockSessionRepository(store, chatRepo);
      final reportRepo = MockReportRepository(store);
      final courtRepo = MockCourtRepository(store);

      // MAN-R11: Jam tenang 22.00-06.00 bergeser ke 06.00
      expect(
        HorasPolicies.adjustReminderForQuietHours(DateTime(2026, 6, 1, 22, 30)),
        DateTime(2026, 6, 2, 6, 0),
      );
      expect(
        HorasPolicies.adjustReminderForQuietHours(DateTime(2026, 6, 2, 3, 15)),
        DateTime(2026, 6, 2, 6, 0),
      );
      final midnightReminders = HorasPolicies.computeSessionReminders(
        sessionStartTime: DateTime(2026, 6, 5, 1, 0),
        now: DateTime(2026, 6, 3, 10, 0),
      );
      // 2 jam sebelum 01:00 = 23:00 hari sebelumnya -> geser ke 06:00 hari H
      expect(
        midnightReminders.reminder2HoursBefore,
        DateTime(2026, 6, 5, 6, 0),
      );

      // MAN-R9: Sesi selesai +2 jam & chat baca-saja +24 jam
      store.currentUserId = 'u-01';
      final created = (await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Sesi Siklus Hidup',
        city: 'Medan',
        startTime: store.now.add(const Duration(hours: 2)),
        endTime: store.now.add(const Duration(hours: 4)),
        maxSlots: 4,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 20000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-01',
      ) as Ok<PlaySession>).value;
      expect(created.conversationId, isNotNull);

      store.timeOffset += const Duration(hours: 7);
      final afterCompleted = (await sessionRepo.getSessionById(
        created.id,
      ) as Ok<PlaySession>).value;
      expect(afterCompleted.status, SessionStatus.completed);

      store.timeOffset += const Duration(hours: 22);
      await sessionRepo.getSessionById(created.id);
      final convs =
          (await chatRepo.getConversations() as Ok<List<Conversation>>).value;
      final sessionChat = convs.firstWhere(
        (c) => c.id == created.conversationId,
      );
      expect(sessionChat.isReadOnly, isTrue);

      // MAN-R10: > 3 laporan info salah menandai lapangan untuk ditinjau (1 laporan per pelapor)
      for (final reporterId in <String>['u-01', 'u-02', 'u-03', 'u-04']) {
        store.currentUserId = reporterId;
        await reportRepo.submitReport(
          targetType: ReportTargetType.court,
          targetId: 'court-01',
          category: ReportCategory.other,
          note: 'Jam operasional salah oleh $reporterId',
        );
      }
      final courtAfter =
          (await courtRepo.getCourtById('court-01') as Ok<Court>).value;
      expect(courtAfter.wrongInfoReportCount, 4);
      expect(courtAfter.status, CourtModerationStatus.flaggedForReview);
    });

    testWidgets(
      'Alur A4: MAN-01 -> MAN-03 Buat sesi -> MAN-04 Detail -> MAN-06 Patungan -> MAN-05 Peserta',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            enableMockNetworkLatencyProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HorasApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Buka Tab Main (MAN-01)
        await tester.tap(find.text(AppStrings.tabMain));
        await tester.pumpAndSettle();
        expect(find.byType(Man01PlayPage), findsOneWidget);

        // Pastikan tombol Buat Sesi (+) terbuka -> MAN-03
        await tester.tap(find.byTooltip(AppStrings.man01CreateSessionBtn));
        await tester.pumpAndSettle();
        expect(find.byType(Man03CreateSessionPage), findsOneWidget);
        expect(find.text(AppStrings.man03NoGamblingBanner), findsOneWidget);

        // Isi judul sesi
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(AppTextField, AppStrings.man03TitleLabel),
            matching: find.byType(TextField),
          ),
          'Badminton Alur A4 Medan',
        );
        await tester.pumpAndSettle();

        // Gulung ke tombol Terbitkan Sesi dan tekan
        await tester.scrollUntilVisible(
          find.text(AppStrings.man03SubmitBtn),
          300,
          scrollable: find
              .descendant(
                of: find.byType(Man03CreateSessionPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.man03SubmitBtn));
        await tester.pumpAndSettle();

        // Kembali ke MAN-01 dan sesi baru tampil
        expect(find.byType(Man01PlayPage), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Badminton Alur A4 Medan'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(Man01PlayPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Badminton Alur A4 Medan'), findsOneWidget);

        // Ketuk kartu sesi baru -> MAN-04 Detail Sesi
        await tester.tap(find.text('Badminton Alur A4 Medan'));
        await tester.pumpAndSettle();
        expect(find.byType(Man04SessionDetailPage), findsOneWidget);

        // Buka Patungan (MAN-06) dan verifikasi disclaimer serta tidak ada input rekening
        await tester.scrollUntilVisible(
          find.text(AppStrings.man04PatunganBtn),
          200,
          scrollable: find
              .descendant(
                of: find.byType(Man04SessionDetailPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.man04PatunganBtn));
        await tester.pumpAndSettle();
        expect(find.byType(Man06PatunganPage), findsOneWidget);
        expect(find.text(AppStrings.man06DisclaimerBanner), findsOneWidget);
        expect(find.textContaining('Rekening'), findsNothing);
        await tester.tap(find.text(AppStrings.man06RecalculateBtn));
        await tester.pumpAndSettle();

        // Kembali ke MAN-04 lalu buka Peserta & Daftar Tunggu (MAN-05)
        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();
        expect(find.byType(Man04SessionDetailPage), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text(AppStrings.man04ParticipantsBtn),
          200,
          scrollable: find
              .descendant(
                of: find.byType(Man04SessionDetailPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.man04ParticipantsBtn));
        await tester.pumpAndSettle();
        expect(find.byType(Man05ParticipantsPage), findsOneWidget);
        expect(find.text(AppStrings.man05JoinedSection), findsOneWidget);
        expect(find.text(AppStrings.man05EmptyWaitlist), findsOneWidget);
      },
    );
  });
}
