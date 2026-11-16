import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/app.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/app_router.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/features/account/presentation/akn02_edit_profile_page.dart';
import 'package:horas/features/tarombo/presentation/tar01_dashboard_page.dart';
import 'package:horas/features/tarombo/presentation/tar02_tree_page.dart';
import 'package:horas/features/tarombo/presentation/tar05_relationship_detail_page.dart';
import 'package:horas/features/tarombo/presentation/tarombo_controller.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Prompt 6 - Modul Tarombo (TAR-01..TAR-07, AC-03, AC-04, Alur A3)', () {
    test('Hitung kelengkapan 5 butir, persetujuan TAR-R2, satu klaim aktif, klaim ditolak tanpa notifikasi, & hapus seluruh data', () async {
      final store = MockStore(
        appConfig: const AppConfig(
          env: AppEnvironment.dev,
          useMockBackend: true,
          allowDraftRules: true,
        ),
        enableNetworkLatency: false,
      );
      final taromboRepo = MockTaromboRepository(store);
      final partuturanRepo = MockPartuturanRepository(store);

      // 1. Kelengkapan awal u-01: motherMarga + father + mother + paternalGrandfather = 80%
      expect((await taromboRepo.getCompletenessPercent() as Ok<int>).value, 80);

      // Tambah maternalGrandfather -> mencapai 100%
      await taromboRepo.upsertFamilyMember(
        relationType: FamilyRelationType.maternalGrandfather,
        fullName: 'Op. Sitorus Bao',
        marga: 'Sitorus',
        gender: UserGender.male,
        lifeStatus: LifeStatus.deceased,
      );
      expect(
        (await taromboRepo.getCompletenessPercent() as Ok<int>).value,
        100,
      );

      // 2. Satu klaim aktif per pasangan (TAR-R7) & klaim ditolak tanpa notifikasi
      final notifBefore = store.notifications
          .where((n) => n.recipientId == 'u-01')
          .length;
      final claimRes = await taromboRepo.sendKinshipClaim(
        targetUserId: 'u-06',
        claimedTermForTarget: 'Lae',
      );
      expect(claimRes.isOk, isTrue);

      final duplicateClaim = await taromboRepo.sendKinshipClaim(
        targetUserId: 'u-06',
        claimedTermForTarget: 'Lae',
      );
      expect(duplicateClaim.isErr, isTrue);

      // u-06 menolak klaim -> pengirim u-01 TIDAK mendapat notifikasi penolakan
      store.currentUserId = 'u-06';
      await taromboRepo.respondKinshipClaim(
        claimId: (claimRes as Ok<PartuturanClaim>).value.id,
        accept: false,
      );
      store.currentUserId = 'u-01';
      final notifAfterReject = store.notifications
          .where((n) => n.recipientId == 'u-01')
          .length;
      expect(notifAfterReject, notifBefore);

      // 3. Klaim diterima meningkatkan keyakinan ke Tinggi
      final tulClaim = await taromboRepo.sendKinshipClaim(
        targetUserId: 'u-03',
        claimedTermForTarget: 'Tulang',
      );
      store.currentUserId = 'u-03';
      await taromboRepo.respondKinshipClaim(
        claimId: (tulClaim as Ok<PartuturanClaim>).value.id,
        accept: true,
      );
      store.currentUserId = 'u-01';
      final evalHigh = (await partuturanRepo.evaluateWithUser(
        'u-03',
      ) as Ok<PartuturanResult>).value;
      expect(evalHigh.confidence, PartuturanConfidence.tinggi);

      // 4. Hapus seluruh data tarombo (TAR-R10)
      await taromboRepo.deleteAllMyTarombo();
      final membersAfterDelete =
          (await taromboRepo.getMyFamilyMembers() as Ok<List<FamilyMember>>)
              .value;
      expect(membersAfterDelete, isEmpty);
      // Hanya motherMarga tersisa di profil (20%)
      expect((await taromboRepo.getCompletenessPercent() as Ok<int>).value, 20);
    });

    testWidgets(
      'Widget test AC-03, AC-04, TAR-02 CustomPainter, TAR-R2 persetujuan, hapus data, & Alur A3 sampai Tinggi',
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

        // Buka Tarombo lewat Tab Akun -> Edit Profil (terintegrasi tanpa Saran Kerabat)
        await tester.tap(find.text(AppStrings.tabAkun));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(AppStrings.akn02Title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.akn02Title));
        await tester.pumpAndSettle();
        expect(find.byType(Akn02EditProfilePage), findsOneWidget);

        final editScroll = find
            .descendant(
              of: find.byType(Akn02EditProfilePage),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text(AppStrings.akn02TaromboSectionTitle),
          250,
          scrollable: editScroll,
        );
        await tester.pumpAndSettle();
        expect(find.text('80% Lengkap'), findsOneWidget);
        expect(find.text(AppStrings.tar01SuggestionsTitle), findsNothing);

        // Buka TAR-02 Pohon Silsilah: ada InteractiveViewer, CustomPaint, dan keterangan Pohon penuh menyusul
        await tester.scrollUntilVisible(
          find.text(AppStrings.tar01OpenTreeBtn),
          250,
          scrollable: editScroll,
        );
        await tester.ensureVisible(find.text(AppStrings.tar01OpenTreeBtn));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.tar01OpenTreeBtn));
        await tester.pumpAndSettle();
        expect(find.byType(Tar02TreePage), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
        expect(find.text(AppStrings.tar02SubtitleFullTreeSoon), findsOneWidget);

        // AC-04: Pengguna sub-suku mode netral (u-08 Karo) membuka TAR-05 -> tanpa PartuturanBadge
        final store = container.read(mockStoreProvider);
        final router = container.read(appRouterProvider);
        store.currentUserId = 'u-08';
        router.go(AppPages.taromboPath);
        await tester.pumpAndSettle();
        expect(find.byType(Tar01DashboardPage), findsOneWidget);
        expect(find.text(AppStrings.tar01SuggestionsTitle), findsNothing);

        final neutralPush = router.push(
          '${AppPages.tar05.routePath}?userId=u-03',
        );
        await tester.pumpAndSettle();
        neutralPush.ignore();
        expect(find.byType(Tar05RelationshipDetailPage), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Tar05RelationshipDetailPage),
            matching: find.byType(PartuturanBadge),
          ),
          findsNothing,
        );
        expect(find.text(AppStrings.sek04NeutralModeHint), findsOneWidget);

        // AC-03 & Alur A3: u-01 buka TAR-05 untuk u-03 (Bona Sitorus) -> Kemungkinan: Tulang (Perkiraan)
        store.currentUserId = 'u-01';
        router.go(AppPages.taromboPath);
        await tester.pumpAndSettle();
        final tulPush = router.push('${AppPages.tar05.routePath}?userId=u-03');
        await tester.pumpAndSettle();
        tulPush.ignore();
        expect(find.text('Kemungkinan: Tulang'), findsAtLeastNWidgets(1));
        expect(find.text(AppStrings.termPerkiraan), findsOneWidget);
        expect(
          find.text(AppStrings.sek04KinshipAcceptQuestion),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.sek04KinshipRejectQuestion),
          findsOneWidget,
        );
        expect(find.text(AppStrings.tar05SendWeAreKinBtn), findsOneWidget);

        // Ketuk Konfirmasi -> mengirim klaim Kami kerabat
        await tester.tap(find.text(AppStrings.sek04KinshipAcceptQuestion));
        await tester.pumpAndSettle();

        // u-03 menyetujui klaim di TAR-07 -> u-01 membuka kembali TAR-05 -> naik menjadi Tinggi
        store.currentUserId = 'u-03';
        await container.read(taromboControllerProvider.notifier).loadAll();
        router.go(AppPages.tar07.routePath);
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.sek04AcceptBtn).first);
        await tester.pumpAndSettle();

        store.currentUserId = 'u-01';
        await container.read(taromboControllerProvider.notifier).loadAll();
        final afterPush = router.push(
          '${AppPages.tar05.routePath}?userId=u-03',
        );
        await tester.pumpAndSettle();
        afterPush.ignore();
        expect(find.text('Dia adalah Tulangmu'), findsAtLeastNWidgets(1));

        // TAR-R2 Persetujuan data keluarga muncul saat belum disetujui ketika membuka Tambah Anggota
        router.go(AppPages.taromboPath);
        await tester.pumpAndSettle();
        final addMemberBtn = find.text(AppStrings.tar01AddMemberBtn);
        await tester.ensureVisible(addMemberBtn);
        await tester.pumpAndSettle();
        await tester.tap(addMemberBtn);
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.tarConsentTitle), findsOneWidget);
        await tester.tap(find.text(AppStrings.tarConsentAcceptBtn));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.tar03Title), findsOneWidget);

        // Hapus seluruh data tarombo lewat tombol dengan ConfirmDialog
        router.go(AppPages.taromboPath);
        await tester.pumpAndSettle();
        final tarScrollable = find.descendant(
          of: find.byType(Tar01DashboardPage),
          matching: find.byType(Scrollable),
        );
        final deleteBtn = find.text(AppStrings.tar01DeleteAllBtn);
        await tester.scrollUntilVisible(
          deleteBtn,
          250,
          scrollable: tarScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.tar01DeleteAllConfirmTitle),
          findsOneWidget,
        );
        await tester.tap(find.text(AppStrings.tar01DeleteAllBtn).last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('20% Lengkap'),
          -250,
          scrollable: tarScrollable,
        );
        expect(find.text('20% Lengkap'), findsOneWidget);
      },
    );
  });
}
