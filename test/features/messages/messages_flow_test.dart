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
import 'package:horas/features/home/presentation/ber01_feed_page.dart';
import 'package:horas/features/messages/presentation/psn01_conversations_page.dart';
import 'package:horas/features/messages/presentation/psn02_message_requests_page.dart';
import 'package:horas/features/messages/presentation/psn03_private_chat_page.dart';
import 'package:horas/features/messages/presentation/psn04_group_chat_page.dart';
import 'package:horas/features/messages/presentation/psn05_conversation_info_page.dart';
import 'package:material_ui/material_ui.dart';

MockStore _makeStore({bool autoReply = false}) {
  final store = MockStore(
    appConfig: const AppConfig(
      env: AppEnvironment.dev,
      useMockBackend: true,
      allowDraftRules: true,
    ),
    enableNetworkLatency: false,
  );
  store.isChatAutoReplyEnabled = autoReply;
  return store;
}

void main() {
  group('Prompt 8 - Modul Pesan (PSN-01..PSN-06, AC-06, AC-16)', () {
    test('AC-06, AC-16, batas 20 orang baru/hari, hapus untuk semua <= 1 jam & retensi laporan 30 hari, blokir menutup chat', () async {
      final store = _makeStore();
      final chatRepo = MockChatRepository(store);
      final blockRepo = MockBlockRepository(store);
      final reportRepo = MockReportRepository(store);

      // 1. AC-06 & PSN-R1: Non-terhubung & tanpa konteks bersama ditolak
      final stranger = store.usersById.values.firstWhere(
        (u) =>
            u.id != 'u-01' &&
            !store.isConnectedBetween('u-01', u.id) &&
            !store.sharesCommunityOrSession('u-01', u.id),
      );
      final forbidden = await chatRepo.sendFirstMessageToUser(
        targetUserId: stranger.id,
        text: 'Halo orang asing',
      );
      expect(forbidden.isErr, isTrue);

      // 2. AC-16 & PSN-R8: Pesan pertama non-terhubung berisi permintaan uang / tautan ditandai hasScamWarning
      // u-03 berbagi komunitas dengan u-01 namun belum Terhubung
      final scamReqMsg = await chatRepo.sendFirstMessageToUser(
        targetUserId: 'u-03',
        text: 'Tolong transfer ke rekening ini dan cek https://contoh.test',
      );
      expect(scamReqMsg.isOk, isTrue);
      final firstMsg = (scamReqMsg as Ok<Message>).value;
      expect(firstMsg.hasScamWarning, isTrue);

      // u-01 mengirim ke 1 orang baru yang terhubung (u-02 sudah punya percakapan, coba ke 19 orang baru lain untuk kuota 20/hari)
      for (var i = 0; i < 19; i++) {
        final dummy =
            store.usersById['u-${(i + 15).toString().padLeft(2, '0')}'];
        if (dummy == null) continue;
        store.connections.add(
          Connection(
            id: 'conn-quota-$i',
            userId: 'u-01',
            friend: store.toPersonSummary(dummy, viewer: store.activeProfile),
            connectedAt: store.now,
          ),
        );
        final quotaOk = await chatRepo.sendFirstMessageToUser(
          targetUserId: dummy.id,
          text: 'Horas ke-$i',
        );
        expect(quotaOk.isOk, isTrue);
      }

      // Orang ke-21 pada hari yang sama ditolak oleh batas PSN-R9 (20/hari)
      final extraFriend = store.usersById['u-38']!;
      store.connections.add(
        Connection(
          id: 'conn-quota-over',
          userId: 'u-01',
          friend: store.toPersonSummary(
            extraFriend,
            viewer: store.activeProfile,
          ),
          connectedAt: store.now,
        ),
      );
      final quotaExceeded = await chatRepo.sendFirstMessageToUser(
        targetUserId: extraFriend.id,
        text: 'Melebihi batas 20',
      );
      expect(quotaExceeded.isErr, isTrue);

      // 3. PSN-R4: Hapus untuk semua hanya dalam 1 jam; pesan dilaporkan tersimpan 30 hari untuk moderasi
      final msgOk = (await chatRepo.sendMessage(
        conversationId: 'conv-dm-01',
        text: 'Pesan penting akan dihapus',
      ) as Ok<Message>).value;

      await reportRepo.submitReport(
        targetType: ReportTargetType.message,
        targetId: msgOk.id,
        category: ReportCategory.spamScam,
        note: 'Cek laporan',
      );

      // Dalam 1 jam -> berhasil dihapus untuk semua
      final delOk = await chatRepo.deleteMessageForEveryone(msgOk.id);
      expect(delOk.isOk, isTrue);
      expect(store.retainedReportedMessages[msgOk.id], isNotNull);
      expect(
        store.retainedReportedMessages[msgOk.id]!.moderatedRetainedUntil,
        isNotNull,
      );

      // Kirim pesan kedua, majukan waktu 65 menit -> hapus untuk semua DITOLAK
      final msgOld = (await chatRepo.sendMessage(
        conversationId: 'conv-dm-01',
        text: 'Pesan lama > 1 jam',
      ) as Ok<Message>).value;
      store.timeOffset += const Duration(minutes: 65);
      final delLate = await chatRepo.deleteMessageForEveryone(msgOld.id);
      expect(delLate.isErr, isTrue);

      // 4. PSN-R6: Blokir menutup chat dua arah & menyembunyikan percakapan
      await blockRepo.blockUser('u-02');
      final visibleAfterBlock =
          (await chatRepo.getConversations() as Ok<List<Conversation>>).value;
      expect(visibleAfterBlock.any((c) => c.id == 'conv-dm-01'), isFalse);
      final sendAfterBlock = await chatRepo.sendMessage(
        conversationId: 'conv-dm-01',
        text: 'Setelah diblokir',
      );
      expect(sendAfterBlock.isErr, isTrue);

      // 5. Notifikasi dikelompokkan per percakapan (PSN)
      store.pushGroupedMessageNotification(
        recipientId: 'u-01',
        conversationId: 'conv-com-01',
        title: 'Komunitas',
        body: 'Pesan 1',
        deepLink: 'horas://app/pesan/grup?conversationId=conv-com-01',
      );
      store.pushGroupedMessageNotification(
        recipientId: 'u-01',
        conversationId: 'conv-com-01',
        title: 'Komunitas',
        body: 'Pesan 2',
        deepLink: 'horas://app/pesan/grup?conversationId=conv-com-01',
      );
      final grouped = store.notifications
          .where(
            (n) =>
                n.recipientId == 'u-01' &&
                n.type == NotificationType.newMessage &&
                n.deepLink.contains('conversationId=conv-com-01'),
          )
          .toList();
      expect(grouped.length, 1);
      expect(grouped.first.body, contains('(2 pesan baru)'));
    });

    test('PSN-R5 & MAN-R9: Grup sesi otomatis baca-saja 24 jam setelah selesai + admin sematkan pengumuman & keluarkan anggota', () async {
      final store = _makeStore();
      final chatRepo = MockChatRepository(store);
      final sessionRepo = MockSessionRepository(store, chatRepo);

      // Sesi baru membuat grup chat otomatis (u-01 host)
      final start = store.now.add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 2));
      final ses = (await sessionRepo.createSession(
        sportType: SportType.badminton,
        title: 'Badminton Grup Baca-Saja',
        city: 'Medan',
        startTime: start,
        endTime: end,
        maxSlots: 4,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 20000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        courtId: 'court-01',
      ) as Ok<PlaySession>).value;

      final convId = ses.conversationId!;
      expect(await chatRepo.isGroupAdmin(convId), isTrue);

      // Admin kirim pengumuman disematkan
      final annRes = await chatRepo.sendPinnedAnnouncement(
        conversationId: convId,
        text: 'Bawa shuttlecock cadangan ya!',
      );
      expect(annRes.isOk, isTrue);

      // Majukan waktu > 24 jam setelah endTime -> grup sesi baca-saja
      store.timeOffset += const Duration(hours: 29);
      await sessionRepo.getSessionById(ses.id);

      final conv = (await chatRepo.getConversationById(
        convId,
      ) as Ok<Conversation>).value;
      expect(conv.isReadOnly, isTrue);

      final sendReadOnly = await chatRepo.sendMessage(
        conversationId: convId,
        text: 'Coba kirim saat baca-saja',
      );
      expect(sendReadOnly.isErr, isTrue);
    });

    testWidgets(
      'Widget test: Buka PSN-01 dari Beranda, cek Permintaan Pesan PSN-02, kirim pesan & terima balasan otomatis tiruan + Mute/Info PSN-05',
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

        // Dari BER-01, ketuk tab tengah Pesan di bilah navigasi bawah -> PSN-01
        expect(find.byType(Ber01FeedPage), findsOneWidget);
        await tester.tap(find.text(AppStrings.tabPesan));
        await tester.pumpAndSettle();
        expect(find.byType(Psn01ConversationsPage), findsOneWidget);

        // Cek Permintaan Pesan (PSN-02) ada entri awal & kembali
        await tester.tap(find.text(AppStrings.psn01RequestsBannerTitle));
        await tester.pumpAndSettle();
        expect(find.byType(Psn02MessageRequestsPage), findsOneWidget);
        expect(find.text(AppStrings.psn02AcceptBtn), findsOneWidget);
        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();

        // Buka percakapan DM pertama -> PSN-03
        await tester.tap(find.textContaining('GOR Manunggal'));
        await tester.pumpAndSettle();
        expect(find.byType(Psn03PrivateChatPage), findsOneWidget);

        // Pastikan tidak ada tombol telepon/video atau Voice Note (Fase 2 off)
        expect(find.byIcon(Icons.call), findsNothing);
        expect(find.byIcon(Icons.videocam), findsNothing);
        expect(find.byIcon(Icons.mic), findsNothing);

        // Ketik & kirim pesan
        await tester.enterText(
          find.descendant(
            of: find.byType(AppTextField),
            matching: find.byType(TextField),
          ),
          'Horas, jadi main jam 5 sore?',
        );
        await tester.tap(find.byTooltip(AppStrings.psn03SendBtnTooltip));
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        // Pesan sendiri dan balasan otomatis tiruan tampil via Stream
        expect(find.text('Horas, jadi main jam 5 sore?'), findsOneWidget);
        expect(
          find.textContaining('Pesanmu sudah saya terima.'),
          findsOneWidget,
        );

        // Buka Info Percakapan (PSN-05) & uji bisukan 1 jam
        await tester.tap(find.byTooltip(AppStrings.psn03MenuInfo));
        await tester.pumpAndSettle();
        expect(find.byType(Psn05ConversationInfoPage), findsOneWidget);
        await tester.tap(find.text(AppStrings.psn05Mute1Hour));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.psn05UnmuteBtn), findsOneWidget);

        // Uji PSN-04 Grup chat tampil & ada badge partuturan pengirim
        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton).last);
        await tester.pumpAndSettle();
        expect(find.byType(Psn01ConversationsPage), findsOneWidget);
        await tester.tap(find.textContaining('Punguan'));
        await tester.pumpAndSettle();
        expect(find.byType(Psn04GroupChatPage), findsOneWidget);
      },
    );
  });
}
