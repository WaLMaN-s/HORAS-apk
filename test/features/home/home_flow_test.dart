import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/app.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/home/presentation/ber01_feed_page.dart';
import 'package:horas/features/home/presentation/home_feed_controller.dart';
import 'package:horas/features/nearby/presentation/sek04_person_profile_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Prompt 4 - Modul Beranda (BER-01, BER-04..BER-10, AC-10, AC-15)', () {
    test('Batas 20 postingan/24 jam, batas 60 komentar/jam, filter Sedang ditinjau, akses postingan terbatas (BER-R9), & AC-10 hapus EXIF', () async {
      final store = MockStore(
        appConfig: const AppConfig(
          env: AppEnvironment.dev,
          useMockBackend: true,
          allowDraftRules: true,
        ),
        enableNetworkLatency: false,
      );
      final postRepo = MockPostRepository(store);
      final commentRepo = MockCommentRepository(store);

      // 1. Filter kata / spam -> Sedang ditinjau (BER-R11)
      final spamPost = await postRepo.createPost(
        text: 'Cek promo slot gacor hari ini',
        visibility: PostVisibility.publicPost,
      );
      expect(
        (spamPost as Ok<Post>).value.moderationStatus,
        PostModerationStatus.underReview,
      );

      // 2. Tautan eksternal akun baru (< 7 hari) -> Sedang ditinjau (BER-R10)
      final newUser = store.usersById['u-02']!.copyWith(
        createdAt: store.now.subtract(const Duration(days: 2)),
      );
      store.usersById['u-02'] = newUser;
      store.currentUserId = 'u-02';
      final newAccLinkPost = await postRepo.createPost(
        text: 'Info acara https://horas.id',
        visibility: PostVisibility.publicPost,
      );
      expect(
        (newAccLinkPost as Ok<Post>).value.moderationStatus,
        PostModerationStatus.underReview,
      );
      // Akun lain tidak dapat membuka tautan postingan yang sedang ditinjau
      store.currentUserId = 'u-01';
      expect(
        (await postRepo.getPostById(newAccLinkPost.value.id)).isErr,
        isTrue,
      );

      // 3. Tautan ke postingan terbatas (followersOnly) dari akun yg tidak diikuti -> ditolak (BER-R9)
      store.currentUserId = 'u-36';
      final limitedPost = await postRepo.createPost(
        text: 'Khusus pengikut u-36',
        visibility: PostVisibility.followersOnly,
      );
      final limitedId = (limitedPost as Ok<Post>).value.id;
      store.currentUserId = 'u-01';
      expect((await postRepo.getPostById(limitedId)).isErr, isTrue);

      // 4. AC-10: EXIF lokasi pada foto dibuang server
      final photoPost = await postRepo.createPost(
        text: 'Foto Danau Toba',
        visibility: PostVisibility.publicPost,
        mediaSeeds: const <String>['seed-toba'],
        mediaSizesBytes: const <int>[200000],
        rawExifPerMedia: const <Map<String, String>>[
          <String, String>{
            'GPSLatitude': '2.6114',
            'GPSLongitude': '98.8281',
            'Make': 'AndroidCam',
          },
        ],
      );
      final media = (photoPost as Ok<Post>).value.media.single;
      expect(media.exifLocationStripped, isTrue);
      expect(media.metadata.containsKey('GPSLatitude'), isFalse);
      expect(media.metadata.containsKey('GPSLongitude'), isFalse);

      // 5. Batas 20 postingan per 24 jam (BER-R10)
      final recentThreshold = store.now.subtract(const Duration(hours: 24));
      final existingRecentCount = store.posts
          .where(
            (p) =>
                p.author.id == 'u-01' && !p.createdAt.isBefore(recentThreshold),
          )
          .length;
      final remaining = 20 - existingRecentCount;
      for (var i = 0; i < remaining; i++) {
        final r = await postRepo.createPost(
          text: 'Postingan tambahan ke-${i + 1}',
          visibility: PostVisibility.publicPost,
        );
        expect(r.isOk, isTrue);
      }
      final over20 = await postRepo.createPost(
        text: 'Postingan ke-21',
        visibility: PostVisibility.publicPost,
      );
      expect(over20.isErr, isTrue);
      expect((over20 as Err<Post>).failure, isA<RateLimitedError>());

      // 6. Batas 60 komentar per jam (BER-R5, BER-R10)
      final targetPostId = photoPost.value.id;
      for (var i = 0; i < 60; i++) {
        final c = await commentRepo.addComment(
          postId: targetPostId,
          text: 'Komentar ke-${i + 1}',
        );
        expect(c.isOk, isTrue);
      }
      final over60 = await commentRepo.addComment(
        postId: targetPostId,
        text: 'Komentar ke-61',
      );
      expect(over60.isErr, isTrue);
      expect((over60 as Err<Comment>).failure, isA<RateLimitedError>());
    });

    testWidgets(
      'Widget test Alur A6: Buat postingan di BER-04 + pilih foto di BER-05 -> tayang di feed BER-01, tanpa baris Story',
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

        // Pastikan Beranda tampil tanpa baris Story (Fase 2 flag off)
        expect(find.byType(Ber01FeedPage), findsOneWidget);
        expect(find.text(AppStrings.ber02Title), findsNothing);
        expect(find.text(AppStrings.ber03Title), findsNothing);

        // Ketuk ikon + untuk langsung membuka Buat Postingan (BER-04)
        await tester.tap(find.bySemanticsLabel(AppStrings.semanticsCreatePost));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.ber04Title), findsOneWidget);

        // Tulis teks postingan
        await tester.enterText(
          find.byType(TextField),
          'Horas keluarga besar di Medan!',
        );
        await tester.pump();

        // Buka BER-05 Pilih & Edit Media, tambah foto contoh, lalu Gunakan Foto
        await tester.tap(find.text(AppStrings.ber04AddMediaBtn));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.ber05Title), findsOneWidget);
        await tester.tap(find.text(AppStrings.ber05AddSamplePhotoBtn).first);
        await tester.pumpAndSettle();
        expect(find.text('1/10 foto'), findsOneWidget);
        await tester.tap(find.text(AppStrings.ber05ApplyBtn));
        await tester.pumpAndSettle();

        // Terbitkan postingan dari BER-04
        expect(find.text('1/10 foto'), findsOneWidget);
        final submitFinder = find.text(AppStrings.ber04SubmitBtn).first;
        await tester.ensureVisible(submitFinder);
        await tester.pumpAndSettle();
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        // Kembali ke Feed BER-01 dan postingan baru tampil di urutan teratas
        expect(find.byType(Ber01FeedPage), findsOneWidget);
        expect(find.text('Horas keluarga besar di Medan!'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-15: Saat perangkat offline, feed menampilkan data cache tersimpan dengan penanda offline dan tombol Coba lagi',
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

        // Pastikan halaman pertama sudah termuat & tersimpan di cache lokal
        expect(find.byType(Ber01FeedPage), findsOneWidget);
        expect(
          container.read(postRepositoryProvider).getCachedFeedPage1(),
          isNotEmpty,
        );

        // Simulasikan kondisi Offline via DebugSimulationRepository lalu segarkan feed
        container.read(debugSimulationRepositoryProvider).setOffline(true);
        await container.read(homeFeedControllerProvider.notifier).loadInitial();
        await tester.pumpAndSettle();

        // AC-15: Banner penanda offline & tombol Coba lagi tampil bersama postingan tersimpan
        expect(find.text(AppStrings.stateOfflineCachedBanner), findsOneWidget);
        expect(find.text(AppStrings.actionRetry), findsOneWidget);
      },
    );

    testWidgets(
      'BER-09 & BER-10: Pencarian menampilkan riwayat, saran, serta hasil Orang & Komunitas saja (tanpa Gereja dan Postingan)',
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

        // Buka BER-09 Pencarian dari bilah atas Beranda
        await tester.tap(find.bySemanticsLabel(AppStrings.semanticsSearch));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.ber09HistoryHeader), findsOneWidget);

        // Ketuk salah satu saran pencarian -> menuju BER-10 Hasil Pencarian
        await tester.tap(find.text('Simanjuntak').first);
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.ber10TabPeople), findsOneWidget);
        expect(find.text(AppStrings.ber10TabCommunities), findsOneWidget);
        // Pastikan tab Gereja & Postingan (Fase 2) TIDAK tampil
        expect(find.text('Gereja'), findsNothing);
        expect(find.text('Postingan'), findsNothing);
      },
    );

    testWidgets(
      'Beranda bergaya Threads: kotak postingan cepat, klik profil pengguna lain, & galeri foto geser horizontal bersih',
      (tester) async {
        final store = MockStore(
          appConfig: const AppConfig(
            env: AppEnvironment.dev,
            useMockBackend: true,
            allowDraftRules: true,
          ),
          enableNetworkLatency: false,
        );
        final postRepo = MockPostRepository(store);
        await postRepo.createPost(
          text: 'Galeri Toba tanpa teks overlay',
          visibility: PostVisibility.publicPost,
          mediaSeeds: const <String>['toba-a', 'toba-b'],
        );

        final container = ProviderContainer(
          overrides: [
            enableMockNetworkLatencyProvider.overrideWithValue(false),
            mockStoreProvider.overrideWithValue(store),
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

        // 1. Kotak postingan cepat di atas Beranda tampil & membuka BER-04
        expect(find.text(AppStrings.ber01ComposerPrompt), findsOneWidget);
        // Nama tampil tanpa teks marga merah ganda
        expect(
          find.descendant(
            of: find.byType(PostCard).first,
            matching: find.text('Marbun'),
          ),
          findsNothing,
        );

        // 2. Galeri multi-foto dapat digeser ke samping (ListView horizontal) tanpa teks "1/2"
        final horizontalLists = tester
            .widgetList<ListView>(find.byType(ListView))
            .where((lv) => lv.scrollDirection == Axis.horizontal)
            .toList();
        expect(horizontalLists, isNotEmpty);
        expect(find.text('1/2'), findsNothing);

        // 3. Ketuk nama/avatar pengguna lain di Beranda -> membuka SEK-04 profilnya
        final otherAuthorPost = container
            .read(homeFeedControllerProvider)
            .posts
            .firstWhere((p) => p.author.id != 'u-01');
        final feedScrollable = find
            .descendant(
              of: find.byType(Ber01FeedPage),
              matching: find.byType(Scrollable),
            )
            .first;
        final authorNameFinder = find.text(otherAuthorPost.author.displayName);
        await tester.scrollUntilVisible(
          authorNameFinder,
          250,
          scrollable: feedScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(authorNameFinder.first);
        await tester.pumpAndSettle();
        expect(find.byType(Sek04PersonProfilePage), findsOneWidget);
        expect(find.text(otherAuthorPost.author.displayName), findsWidgets);

        // Kembali ke Beranda dan uji kotak postingan cepat -> BER-04
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final composerPrompt = find.text(AppStrings.ber01ComposerPrompt);
        await tester.scrollUntilVisible(
          composerPrompt,
          -250,
          scrollable: feedScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(composerPrompt);
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.ber04Title), findsOneWidget);
      },
    );
  });
}
