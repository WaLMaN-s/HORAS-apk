import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/app.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/app_router.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/block_policy.dart';
import 'package:horas/domain/policies/horas_policies.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:horas/features/account/presentation/akn01_my_profile_page.dart';
import 'package:horas/features/account/presentation/akn07_settings_page.dart';
import 'package:horas/features/account/presentation/akn10_notification_prefs_page.dart';
import 'package:horas/features/account/presentation/akn14_delete_account_page.dart';
import 'package:horas/features/system/presentation/sis02_report_page.dart';
import 'package:horas/features/system/presentation/sis03_report_status_page.dart';
import 'package:horas/features/system/presentation/sis08_guidelines_page.dart';
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
  group(
    'Prompt 9 - Modul Akun & Sistem (AKN-01..15, SIS-01..08, AC-11/12/14)',
    () {
      test(
        'PRD 7.1 nilai privasi bawaan & kunci jam tenang/keamanan AKN-10',
        () {
          const defaults = PrivacySettings();
          expect(defaults.motherMarga, FieldVisibility.connectedOnly);
          expect(defaults.showAgeGroup, isFalse);
          expect(defaults.subdistrict, FieldVisibility.connectedOnly);
          expect(defaults.joinedCommunities, FieldVisibility.connectedOnly);
          expect(defaults.homeChurch, FieldVisibility.onlyMe);
          expect(defaults.tarombo, FieldVisibility.onlyMe);
          expect(defaults.discoverableInNearbyAndSearch, isTrue);
          expect(
            defaults.whoCanSendConnectionRequest,
            ConnectionRequestAllowance.everyone,
          );
          expect(defaults.allowMessagesFromSharedContext, isTrue);
          expect(defaults.sendReadReceipts, isTrue);
          expect(defaults.accountType, AccountVisibilityType.publicAccount);

          // AKN-10: Keamanan akun & moderasi terkunci aktif
          var notifPrefs = const NotificationPreferences();
          notifPrefs = notifPrefs
              .setTypeEnabled(NotificationType.accountSecurity, false)
              .setTypeEnabled(NotificationType.moderationAction, false)
              .setTypeEnabled(NotificationType.postLikedOrCommented, false);
          expect(
            notifPrefs.isEnabled(NotificationType.accountSecurity),
            isTrue,
          );
          expect(
            notifPrefs.isEnabled(NotificationType.moderationAction),
            isTrue,
          );
          expect(
            notifPrefs.isEnabled(NotificationType.postLikedOrCommented),
            isFalse,
          );

          // Jam tenang 22.00-06.00 berlaku untuk semua kecuali accountSecurity
          final night = DateTime(2026, 6, 1, 23, 30);
          expect(
            HorasPolicies.shouldDelayPushForQuietHours(
              type: NotificationType.accountSecurity,
              now: night,
              prefs: notifPrefs,
            ),
            isFalse,
          );
          expect(
            HorasPolicies.shouldDelayPushForQuietHours(
              type: NotificationType.newMessage,
              now: night,
              prefs: notifPrefs,
            ),
            isTrue,
          );
        },
      );

      test('AC-11 & BlockPolicy terpusat: blokir menyembunyikan profil, postingan, komentar, pencarian, Sekitar, chat, & pesan grup', () async {
        final store = _makeStore();
        final blockRepo = MockBlockRepository(store);
        final profileRepo = MockProfileRepository(store);
        final postRepo = MockPostRepository(store);
        final commentRepo = MockCommentRepository(store);
        final searchRepo = MockSearchRepository(store);
        final nearbyRepo = MockNearbyRepository(store);
        final chatRepo = MockChatRepository(store);

        // u-02 mengirim pesan di grup conv-com-01 sebelum diblokir
        store.currentUserId = 'u-02';
        await chatRepo.sendMessage(
          conversationId: 'conv-com-01',
          text: 'Pesan grup dari u-02',
        );
        store.currentUserId = 'u-01';

        await blockRepo.blockUser('u-02');
        expect(
          BlockPolicy.isBlockedBetween(
            blocks: store.blocks,
            userAId: 'u-01',
            userBId: 'u-02',
          ),
          isTrue,
        );

        // Profil & Sekitar & Pencarian
        expect((await profileRepo.getPersonSummary('u-02')).isErr, isTrue);
        final nearby =
            (await nearbyRepo.getNearbyPeople() as Ok<List<PersonSummary>>)
                .value;
        expect(nearby.any((p) => p.id == 'u-02'), isFalse);
        final u02Name = store.usersById['u-02']!.displayName;
        final searched = (await searchRepo.searchPeople(
          query: u02Name,
        ) as Ok<List<PersonSummary>>).value;
        expect(searched.any((p) => p.id == 'u-02'), isFalse);

        // Postingan & Komentar
        expect((await postRepo.getUserPosts('u-02')).isErr, isTrue);
        final feed = (await postRepo.getFeed() as Ok<List<Post>>).value;
        expect(feed.any((p) => p.author.id == 'u-02'), isFalse);
        final u02Post = store.posts.firstWhere((p) => p.author.id == 'u-02');
        expect(
          (await commentRepo.getComments(
            u02Post.id,
          ) as Ok<List<Comment>>).value,
          isEmpty,
        );

        // Chat DM tertutup & pesan grup dari u-02 disembunyikan bagi pemblokir
        final convs =
            (await chatRepo.getConversations() as Ok<List<Conversation>>).value;
        expect(convs.any((c) => c.id == 'conv-dm-01'), isFalse);
        final groupMsgs = (await chatRepo.getMessages(
          'conv-com-01',
        ) as Ok<List<Message>>).value;
        expect(groupMsgs.any((m) => m.sender.id == 'u-02'), isFalse);

        // Buka blokir -> hubungan tidak dipulihkan otomatis
        await blockRepo.unblockUser('u-02');
        expect(store.isConnectedBetween('u-01', 'u-02'), isFalse);
        expect(store.isFollowingUser('u-01', 'u-02'), isFalse);
      });

      test('AKN-13 ZIP nyata + batas 7 hari & AC-12 Hapus akun dengan Clock (batal < 30 hari, hapus permanen hari ke-30, chat Pengguna terhapus)', () async {
        final store = _makeStore();
        final authRepo = MockAuthRepository(store);
        final lifecycleRepo = MockAccountLifecycleRepository(store);
        final commRepo = MockCommunityRepository(store);
        final chatRepo = MockChatRepository(store);

        // AKN-13: Request export ZIP + build ZIP bytes nyata
        final exp = await lifecycleRepo.requestDataExport(otpCode: '123456');
        expect(exp.isOk, isTrue);
        final zipBytes =
            (await lifecycleRepo.buildExportZipBytes() as Ok<List<int>>).value;
        final archive = ZipDecoder().decodeBytes(zipBytes);
        final names = archive.files.map((f) => f.name).toSet();
        expect(
          names,
          containsAll(<String>[
            'profil.json',
            'postingan.json',
            'tarombo.json',
          ]),
        );

        // Hari ke-2 coba export lagi -> rate limit 7 hari
        store.timeOffset += const Duration(days: 2);
        final expAgain = await lifecycleRepo.requestDataExport(
          otpCode: '123456',
        );
        expect(expAgain.isErr, isTrue);

        // AC-12: Gagal hapus akun bila masih memiliki komunitas
        final blockedByComm = await lifecycleRepo.requestAccountDeletion(
          otpCode: '123456',
        );
        expect(blockedByComm.isErr, isTrue);

        // Serahkan kepemilikan seluruh komunitas milik u-01
        for (final comm
            in store.communities.where((c) => c.ownerId == 'u-01').toList()) {
          await commRepo.transferOwnership(
            communityId: comm.id,
            newOwnerUserId: 'u-02',
          );
        }

        // Ajukan hapus akun (masa tunggu 30 hari)
        final phoneU01 = store.usersById['u-01']!.phoneE164;
        final delOk = await lifecycleRepo.requestAccountDeletion(
          otpCode: '123456',
        );
        expect(delOk.isOk, isTrue);

        // Login ulang pada hari ke-10 -> membatalkan penghapusan
        store.timeOffset += const Duration(days: 10);
        await authRepo.sendOtp(phoneE164: phoneU01);
        final relogin = await authRepo.verifyOtp(
          phoneE164: phoneU01,
          otpCode: '123456',
          deviceName: 'Pixel',
          platform: 'Android',
        );
        expect(relogin.isOk, isTrue);
        expect(authRepo.hadDeletionRecentlyCancelled, isTrue);

        // Ajukan ulang, lalu majukan waktu 31 hari tanpa login -> data terhapus permanen
        await lifecycleRepo.requestAccountDeletion(otpCode: '123456');
        store.timeOffset += const Duration(days: 31);
        final statusAfter30 =
            (await lifecycleRepo.getAccountDeletionStatus()
                    as Ok<AccountDeletion?>)
                .value;
        expect(statusAfter30?.isPermanentlyDeleted, isTrue);
        expect(store.usersById.containsKey('u-01'), isFalse);

        // Pesan lama tetap ada dan menampilkan "Pengguna terhapus" ke lawan bicara (u-02)
        store.currentUserId = 'u-02';
        final msgsForU02 = (await chatRepo.getMessages(
          'conv-dm-01',
        ) as Ok<List<Message>>).value;
        expect(msgsForU02, isNotEmpty);
        final convsForU02 =
            (await chatRepo.getConversations() as Ok<List<Conversation>>).value;
        expect(
          convsForU02.firstWhere((c) => c.id == 'conv-dm-01').title,
          AppStrings.psn03DeletedUserLabel,
        );
      });

      test('AC-14: Laporan postingan masuk status Diterima tanpa membocorkan pelapor ke terlapor', () async {
        final store = _makeStore();
        final reportRepo = MockReportRepository(store);
        final debugRepo = MockDebugSimulationRepository(store);

        final u02Post = store.posts.firstWhere((p) => p.author.id == 'u-02');
        final repRes = await reportRepo.submitReport(
          targetType: ReportTargetType.post,
          targetId: u02Post.id,
          category: ReportCategory.saraHateSpeech,
          note: 'Mengandung ujaran tidak pantas',
        );
        expect(repRes.isOk, isTrue);
        final rep = (repRes as Ok<Report>).value;
        expect(rep.status, ReportStatus.received);

        // Pelapor melihat di getMyReports; terlapor (u-02) tidak melihat identitas pelapor
        final myReports =
            (await reportRepo.getMyReports() as Ok<List<Report>>).value;
        expect(myReports.any((r) => r.id == rep.id), isTrue);

        store.currentUserId = 'u-02';
        final u02Reports =
            (await reportRepo.getMyReports() as Ok<List<Report>>).value;
        expect(u02Reports.any((r) => r.id == rep.id), isFalse);

        // Ubah status dari Panel Debug ke Selesai -> notifikasi ke pelapor
        debugRepo.updateReportStatusForDebug(
          reportId: rep.id,
          status: ReportStatus.completed,
          outcome: ReportOutcome.actionTaken,
        );
        expect(
          store.notifications.any(
            (n) =>
                n.recipientId == 'u-01' &&
                n.type == NotificationType.reportOutcome,
          ),
          isTrue,
        );
      });

      testWidgets(
        'Widget test Alur A7 (Lapor + Blokir -> Status Laporan) & Alur A8 + SIS-08 tanpa login',
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

          // Alur A7: Navigasi langsung ke /report untuk postingan milik u-02, centang Blokir juga, kirim -> SIS-03
          final router = container.read(appRouterProvider);
          router
              .push('/report?targetType=post&targetId=post-02&userId=u-02')
              .ignore();
          await tester.pumpAndSettle();
          expect(find.byType(Sis02ReportPage), findsOneWidget);

          await tester.scrollUntilVisible(
            find.text(AppStrings.sis02AlsoBlockLabel),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.text(AppStrings.sis02AlsoBlockLabel));
          await tester.pumpAndSettle();

          await tester.scrollUntilVisible(
            find.text(AppStrings.sis02SubmitBtn),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.text(AppStrings.sis02SubmitBtn));
          await tester.pumpAndSettle();
          expect(find.byType(Sis03ReportStatusPage), findsOneWidget);
          expect(find.text('Diterima'), findsOneWidget);

          // Alur A8 & Pengaturan Akun: kembali lalu buka Tab Akun -> Pengaturan -> AKN-10 & AKN-14
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text(AppStrings.tabAkun));
          await tester.pumpAndSettle();
          expect(find.byType(Akn01MyProfilePage), findsOneWidget);

          await tester.tap(find.byTooltip(AppStrings.semanticsSettings));
          await tester.pumpAndSettle();
          expect(find.byType(Akn07SettingsPage), findsOneWidget);

          final settingsScrollable = find.descendant(
            of: find.byType(Akn07SettingsPage),
            matching: find.byType(Scrollable),
          );
          await tester.scrollUntilVisible(
            find.text(AppStrings.akn10Title),
            200,
            scrollable: settingsScrollable,
          );
          await tester.ensureVisible(find.text(AppStrings.akn10Title));
          await tester.pumpAndSettle();
          await tester.tap(find.text(AppStrings.akn10Title));
          await tester.pumpAndSettle();
          expect(find.byType(Akn10NotificationPrefsPage), findsOneWidget);
          expect(find.text(AppStrings.akn10LockedSecurityNote), findsOneWidget);
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();

          await tester.scrollUntilVisible(
            find.text(AppStrings.akn14Title),
            200,
            scrollable: settingsScrollable,
          );
          await tester.ensureVisible(find.text(AppStrings.akn14Title));
          await tester.pumpAndSettle();
          await tester.tap(find.text(AppStrings.akn14Title));
          await tester.pumpAndSettle();
          expect(find.byType(Akn14DeleteAccountPage), findsOneWidget);
          expect(find.text(AppStrings.akn14ConsequenceTitle), findsOneWidget);

          // SIS-08 Pedoman komunitas dapat dibuka tanpa login
          await container.read(authRepositoryProvider).logout();
          router.go(AppPages.sis08.routePath);
          await tester.pumpAndSettle();
          expect(find.byType(Sis08GuidelinesPage), findsOneWidget);
          expect(find.text(AppStrings.sis08PublicReadNotice), findsOneWidget);
        },
      );
    },
  );
}
