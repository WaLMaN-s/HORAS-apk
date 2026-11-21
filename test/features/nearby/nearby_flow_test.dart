import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/app.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/app_router.dart';
import 'package:horas/core/theme/horas_colors.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/nearby/presentation/sek01_nearby_page.dart';
import 'package:horas/features/nearby/presentation/sek04_person_profile_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Prompt 5 - Modul Sekitar (SEK-01..SEK-08, SEK-12)', () {
    test('AC-05, batas Kenalan 10/hari, blokir kirim ulang 30 hari, urutan SEK-R1, AC-13 & SEK-R11 ChatRepository', () async {
      final store = MockStore(
        appConfig: const AppConfig(
          env: AppEnvironment.dev,
          useMockBackend: true,
          allowDraftRules: true,
        ),
        enableNetworkLatency: false,
      );
      final connRepo = MockConnectionRepository(store);
      final nearbyRepo = MockNearbyRepository(store);
      final chatRepo = MockChatRepository(store);
      final commRepo = MockCommunityRepository(store, chatRepo);
      final searchRepo = MockSearchRepository(store);

      // 1. Urutan SEK-R1: kerabat keyakinan tinggi/sedang lebih dulu daripada non-kerabat
      final peopleRes = await nearbyRepo.getNearbyPeople(
        city: 'Medan',
        page: 1,
      );
      final people = (peopleRes as Ok<List<PersonSummary>>).value;
      expect(people, isNotEmpty);
      expect(people.length, lessThanOrEqualTo(20));
      final firstKinship = people.first.partuturan;
      expect(firstKinship != null && !firstKinship.modeNetral, isTrue);

      // AC-07: Pastikan JSON seluruh hasil Sekitar bebas field terlarang
      for (final p in people) {
        final json = p.toJson();
        expect(json.containsKey('phoneE164'), isFalse);
        expect(json.containsKey('birthYear'), isFalse);
        expect(json.containsKey('latitude'), isFalse);
        expect(json.containsKey('longitude'), isFalse);
        expect(json.containsKey('distanceKm'), isFalse);
      }

      // 2. AC-05: B menolak permintaan Kenalan A -> tanpa notifikasi ke A & blokir kirim ulang 30 hari
      final notifCountBefore = store.notifications
          .where((n) => n.recipientId == 'u-01')
          .length;
      final sentReqRes = await connRepo.sendConnectionRequest(
        targetUserId: 'u-06',
        introMessage: 'Horas Lae!',
      );
      final sentReq = (sentReqRes as Ok<ConnectionRequest>).value;

      store.currentUserId = 'u-06';
      final rejectRes = await connRepo.respondToConnectionRequest(
        requestId: sentReq.id,
        accept: false,
      );
      expect(rejectRes.isOk, isTrue);

      store.currentUserId = 'u-01';
      final notifCountAfter = store.notifications
          .where((n) => n.recipientId == 'u-01')
          .length;
      expect(notifCountAfter, notifCountBefore);

      final retryBefore30Days = await connRepo.sendConnectionRequest(
        targetUserId: 'u-06',
        introMessage: 'Coba kirim lagi',
      );
      expect(retryBefore30Days.isErr, isTrue);

      // Maju 31 hari: dapat mengirim ulang
      store.timeOffset = const Duration(days: 31);
      final retryAfter30Days = await connRepo.sendConnectionRequest(
        targetUserId: 'u-06',
        introMessage: 'Horas lagi Lae',
      );
      expect(retryAfter30Days.isOk, isTrue);

      // 3. Batas 10 permintaan Kenalan baru per hari
      final targets = store.usersById.values
          .where((u) => u.id != 'u-01' && u.id != 'u-06')
          .take(10)
          .toList();
      for (var i = 0; i < 9; i++) {
        final res = await connRepo.sendConnectionRequest(
          targetUserId: targets[i].id,
          introMessage: 'Salam kenal ${i + 1}',
        );
        expect(res.isOk, isTrue);
      }
      final overLimit = await connRepo.sendConnectionRequest(
        targetUserId: targets[9].id,
        introMessage: 'Permintaan ke-11',
      );
      expect(overLimit.isErr, isTrue);
      expect(
        (overLimit as Err<ConnectionRequest>).failure,
        isA<RateLimitedError>(),
      );

      // 4. AC-13: Komunitas tertutup (com-10) tidak muncul di pencarian & daftar anggota bagi non-anggota u-01
      final searchComms = await searchRepo.searchCommunities(query: 'Ompung');
      expect(
        (searchComms as Ok<List<Community>>).value.any((c) => c.id == 'com-10'),
        isFalse,
      );
      final closedMembers = await commRepo.getMembers('com-10');
      expect(closedMembers.isErr, isTrue);

      // 5. SEK-R11: Buat komunitas via CommunityRepository membuat chat grup via ChatRepository
      final createdCommRes = await commRepo.createCommunity(
        name: 'Badminton Perantau Medan',
        type: CommunityType.interest,
        accessType: CommunityAccessType.open,
        city: 'Medan',
        description: 'Kumpul main badminton rutin',
      );
      final createdComm = (createdCommRes as Ok<Community>).value;
      expect(
        store.conversations.any((c) => c.communityId == createdComm.id),
        isTrue,
      );
    });

    testWidgets(
      'AC-06, AC-07 tampilan, SEK-04 varian privat/konteks bersama, dan Alur A2 Kenalan sampai Terhubung',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            enableMockNetworkLatencyProvider.overrideWithValue(false),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
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

        // Buka Tab Sekitar (SEK-01) dan pastikan Gereja (Fase 2) tidak tampil
        await tester.tap(find.text(AppStrings.tabSekitar));
        await tester.pumpAndSettle();
        expect(find.byType(Sek01NearbyPage), findsOneWidget);
        expect(find.text(AppStrings.sek10Title), findsNothing);
        expect(find.text('Gereja'), findsNothing);

        // AC-07: Kartu ringkas di Sekitar tanpa km / +62 / pill komunitas sama yang membuat kartu tebal
        expect(find.textContaining('km'), findsNothing);
        expect(find.textContaining('+62'), findsNothing);
        expect(find.textContaining('komunitas sama'), findsNothing);
        expect(HorasColors.dark.background, equals(const Color(0xFF0A0A0A)));
        expect(HorasColors.dark.surface, equals(const Color(0xFF101010)));

        // AC-06: Buka profil pengguna u-15 (tidak terhubung & tidak berbagi komunitas/sesi)
        final router = container.read(appRouterProvider);
        Future<void> openProfile(String id) async {
          router.go(AppPages.sekitarPath);
          await tester.pumpAndSettle();
          final pushed = router.push('${AppPages.sek04.routePath}?id=$id');
          await tester.pumpAndSettle();
          pushed.ignore();
        }

        await openProfile('u-15');
        expect(find.byType(Sek04PersonProfilePage), findsOneWidget);
        // Tombol Pesan TIDAK BOLEH ADA di halaman profil orang lain (AC-06)
        expect(
          find.descendant(
            of: find.byType(Sek04PersonProfilePage),
            matching: find.text(AppStrings.termPesan),
          ),
          findsNothing,
        );
        expect(
          find.textContaining(AppStrings.sek04MessageRequestBadge),
          findsNothing,
        );

        // Varian akun Privat (u-10): nama/marga tampil, konten tersembunyi
        await openProfile('u-10');
        expect(find.text('Hendra Siahaan'), findsAtLeastNWidgets(1));
        expect(find.text(AppStrings.sek04PrivateAccountTitle), findsOneWidget);

        // Alur A2: u-01 buka profil u-03 (Bona Sitorus, berbagi komunitas -> Pesan Permintaan pesan)
        await openProfile('u-03');
        expect(find.text('Bona Sitorus'), findsAtLeastNWidgets(1));
        expect(
          find.textContaining(AppStrings.sek04MessageRequestBadge),
          findsOneWidget,
        );

        // Ketuk Kenalan -> Sheet Kenalan -> Kirim Kenalan -> status Terkirim
        await tester.tap(find.text(AppStrings.termKenalan));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.sek04SheetKenalanTitle), findsOneWidget);
        await tester.tap(find.text(AppStrings.sek04SendKenalanBtn));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.sek04ConnectionSent), findsOneWidget);

        // Beralih sebagai penerima (u-03), buka profil u-01 lalu Terima permintaan Kenalan
        final store = container.read(mockStoreProvider);
        store.currentUserId = 'u-03';
        await openProfile('u-01');
        expect(find.text(AppStrings.sek04AcceptBtn), findsOneWidget);
        await tester.tap(find.text(AppStrings.sek04AcceptBtn));
        await tester.pumpAndSettle();

        // Kembali ke u-01: profil u-03 sekarang berstatus Terhubung & tombol Pesan aktif penuh,
        // serta menampilkan postingan dan galeri 2+ foto geser samping gaya Threads
        final postRepo = MockPostRepository(store);
        store.currentUserId = 'u-03';
        await postRepo.createPost(
          text: 'Dua foto latihan Bona',
          visibility: PostVisibility.publicPost,
          mediaSeeds: const <String>['bona-1', 'bona-2'],
        );
        store.currentUserId = 'u-01';
        await openProfile('u-03');
        expect(find.text(AppStrings.termTerhubung), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Sek04PersonProfilePage),
            matching: find.text(AppStrings.termPesan),
          ),
          findsOneWidget,
        );
        final sek04Scroll = find
            .descendant(
              of: find.byType(Sek04PersonProfilePage),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text(AppStrings.sek04PhotosTab),
          250,
          scrollable: sek04Scroll,
        );
        await tester.ensureVisible(find.text(AppStrings.sek04PhotosTab));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.sek04PhotosTab));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Dua foto latihan Bona'),
          250,
          scrollable: sek04Scroll,
        );
        expect(
          find.descendant(
            of: find.byType(Sek04PersonProfilePage),
            matching: find.byType(PostCard),
          ),
          findsWidgets,
        );
        final horizontalLists = tester
            .widgetList<ListView>(
              find.descendant(
                of: find.byType(Sek04PersonProfilePage),
                matching: find.byType(ListView),
              ),
            )
            .where((lv) => lv.scrollDirection == Axis.horizontal)
            .toList();
        expect(horizontalLists, isNotEmpty);
      },
    );

    testWidgets(
      'SEK-04 gaya Instagram: tampil tombol Follback jika pengguna lain follow duluan dan tombol Pesan tepat di sampingnya',
      (tester) async {
        final store = MockStore(
          appConfig: const AppConfig(
            env: AppEnvironment.dev,
            useMockBackend: true,
            allowDraftRules: true,
          ),
          enableNetworkLatency: false,
        );
        // u-07 mengikuti u-01 duluan, namun u-01 belum mengikuti u-07
        store.follows.add(
          Follow(
            id: 'fol-u07-u01',
            followerId: 'u-07',
            followeeId: 'u-01',
            createdAt: store.now,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            enableMockNetworkLatencyProvider.overrideWithValue(false),
            mockStoreProvider.overrideWithValue(store),
            featureFlagsProvider.overrideWithValue(const FeatureFlags()),
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

        final router = container.read(appRouterProvider);
        router.push('${AppPages.sek04.routePath}?id=u-07').ignore();
        await tester.pumpAndSettle();

        expect(find.byType(Sek04PersonProfilePage), findsOneWidget);
        expect(find.text(AppStrings.termFollback), findsOneWidget);
        expect(find.text(AppStrings.sek04FollowsYouNotice), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Sek04PersonProfilePage),
            matching: find.text(AppStrings.termPesan),
          ),
          findsOneWidget,
        );

        // Ketuk Follback -> berubah menjadi Mengikuti dan Saling mengikuti
        await tester.tap(find.text(AppStrings.termFollback));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.termMengikuti), findsOneWidget);
        expect(find.text(AppStrings.sek04MutualFollowNotice), findsOneWidget);
      },
    );
  });
}
