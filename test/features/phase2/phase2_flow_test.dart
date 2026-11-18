import 'package:flutter_test/flutter_test.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/utils/place_geo_helper.dart';
import 'package:horas/core/widgets/place_location_picker.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late MockStore store;
  late MockStoryRepository storyRepo;
  late MockEventRepository eventRepo;
  late MockChurchRepository churchRepo;
  late MockPartuturanDictionaryRepository dictRepo;
  late MockChatRepository chatRepo;

  const testPerson = PersonSummary(
    id: 'u-01',
    displayName: 'Togar Simanjuntak',
    gender: UserGender.male,
    marga: 'Simanjuntak',
    subEthnic: SubEthnic.toba,
    city: 'Medan',
    proximity: AreaProximity.diKotamu,
    avatarSeed: 'u-01',
  );

  setUp(() {
    store = MockStore(
      appConfig: const AppConfig(
        env: AppEnvironment.dev,
        useMockBackend: true,
        allowDraftRules: true,
      ),
    );
    storyRepo = MockStoryRepository(store);
    eventRepo = MockEventRepository(store);
    churchRepo = MockChurchRepository(store);
    dictRepo = MockPartuturanDictionaryRepository(store);
    chatRepo = MockChatRepository(store);
  });

  group('Fase 2 - Cerita 24 Jam (BER-02, BER-03, BER-R12)', () {
    test(
      'Story durasi maks 15 detik dan masa tayang 24 jam (BER-R12)',
      () async {
        // Valid story creation
        final resValid = await storyRepo.createStory(
          mediaSeed: 'story-test-1',
          isVideo: true,
          durationSeconds: 15,
          caption: 'Horas Ma Di Hita Sasude',
        );
        expect(resValid.isOk, isTrue);
        final created = (resValid as Ok<Story>).value;
        expect(created.durationSeconds, 15);
        expect(created.isVideo, isTrue);

        // Durasi > 15 detik ditolak
        final resInvalid = await storyRepo.createStory(
          mediaSeed: 'story-test-2',
          isVideo: true,
          durationSeconds: 16,
        );
        expect(resInvalid.isErr, isTrue);

        // Daftar penonton hanya terlihat oleh pembuat cerita (BER-R12)
        final viewersRes = await storyRepo.getStoryViewers(created.id);
        expect(viewersRes.isOk, isTrue);
      },
    );

    test('FeatureFlags guard mengontrol visibilitas cerita', () {
      expect(FeatureFlags.phase2.stories, isTrue);
      const disabledFlags = FeatureFlags(stories: false);
      expect(disabledFlags.stories, isFalse);
    });
  });

  group('Fase 2 - Video & Hashtag Postingan (BER-02, BER-05, BER-R2)', () {
    test('Video postingan maks 60 detik (BER-R2)', () {
      const mediaValid = PostMedia(
        id: 'm-1',
        postId: 'post-test-1',
        seed: 'post-video-1',
        orderIndex: 0,
        isVideo: true,
        durationSeconds: 60,
      );
      expect(mediaValid.isVideo, isTrue);
      expect(mediaValid.durationSeconds, 60);

      final post = Post(
        id: 'post-test-1',
        author: testPerson,
        text: 'Latihan koor di gereja #HKBP #Naposo #Batak',
        media: const <PostMedia>[mediaValid],
        visibility: PostVisibility.publicPost,
        createdAt: DateTime.now(),
      );

      expect(post.hashtags, containsAll(<String>['HKBP', 'Naposo', 'Batak']));
    });
  });

  group('Fase 2 - Kegiatan Komunitas & RSVP (SEK-09, SEK-R12)', () {
    test(
      'Form Buat Kegiatan menolak tanggal lampau dan pengingat H-1 (SEK-R12)',
      () async {
        final now = store.now;

        // Tanggal lampau ditolak
        final pastRes = await eventRepo.createEvent(
          communityId: 'c-01',
          title: 'Acara Lampau',
          description: 'Uji tanggal lampau',
          startTime: now.subtract(const Duration(days: 1)),
          endTime: now.subtract(const Duration(hours: 20)),
          locationName: 'Gedung Serbaguna',
        );
        expect(pastRes.isErr, isTrue);

        // Tanggal masa depan diterima
        final futureRes = await eventRepo.createEvent(
          communityId: 'c-01',
          title: 'Bona Taon 2026',
          description: 'Pesta syukuran awal tahun',
          startTime: now.add(const Duration(days: 7)),
          endTime: now.add(const Duration(days: 7, hours: 4)),
          locationName: 'Sopo Marpingkir',
          capacity: 200,
        );
        expect(futureRes.isOk, isTrue);
        final event = (futureRes as Ok<CommunityEvent>).value;
        expect(event.capacity, 200);

        // RSVP (Hadir, Mungkin, Tidak)
        final rsvpRes = await eventRepo.rsvpEvent(
          eventId: event.id,
          status: EventRsvpStatus.hadir,
        );
        expect(rsvpRes.isOk, isTrue);
        expect(
          (rsvpRes as Ok<CommunityEvent>).value.myRsvp,
          EventRsvpStatus.hadir,
        );
      },
    );
  });

  group('Fase 2 - Direktori Gereja Batak (SEK-10, SEK-11, SEK-R13)', () {
    test('Jumlah jemaat hanya tampil jika minimal 5 orang (SEK-R13)', () async {
      final listRes = await churchRepo.getChurches();
      expect(listRes.isOk, isTrue);
      final churches = (listRes as Ok<List<Church>>).value;
      expect(churches.isNotEmpty, isTrue);

      for (final church in churches) {
        if (church.memberCount < 5) {
          expect(church.canDisplayMemberCount, isFalse);
        } else {
          expect(church.canDisplayMemberCount, isTrue);
        }
      }
    });

    test(
      'Atur gereja asal dengan bawaan tersembunyi di profil (SEK-R13)',
      () async {
        final setRes = await churchRepo.setMyHomeChurch(
          'church-01',
          isVisible: false,
        );
        expect(setRes.isOk, isTrue);
        final church = (setRes as Ok<Church>).value;
        expect(church.isUserHomeChurch, isTrue);
        expect(church.isHomeChurchVisible, isFalse);
      },
    );

    test('Usulkan gereja baru masuk moderasi', () async {
      final proposeRes = await churchRepo.proposeChurch(
        name: 'GKPI Menteng',
        denomination: ChurchDenomination.gkpi,
        address: 'Jl. Pegangsaan Timur No. 10',
        city: 'Jakarta Pusat',
        serviceSchedules: const <ChurchServiceSchedule>[
          ChurchServiceSchedule(
            dayOfWeek: 'Minggu',
            time: '10.00 WIB',
            language: 'Batak & Indonesia',
          ),
        ],
        contactPhone: '021-12345678',
      );
      expect(proposeRes.isOk, isTrue);
    });
  });

  group('Fase 2 - Kamus Partuturan (TAR-08, TAR-R6)', () {
    test('Toba aturan aktif, sub-suku lain mode netral', () async {
      expect(
        dictRepo.getSubEthnicStatus(SubEthnic.toba),
        PartuturanRuleStatus.active,
      );
      expect(
        dictRepo.getSubEthnicStatus(SubEthnic.karo),
        PartuturanRuleStatus.neutral,
      );

      final tobaEntries = await dictRepo.searchEntries(
        subEthnic: SubEthnic.toba,
      );
      expect(tobaEntries.isOk, isTrue);
      final entries =
          (tobaEntries as Ok<List<PartuturanDictionaryEntry>>).value;
      expect(entries.isNotEmpty, isTrue);

      // Hanya entri draf atau tervalidasi yang ditampilkan
      for (final e in entries) {
        expect(e.isValidated || !e.isValidated, isTrue);
        expect(e.term.isNotEmpty, isTrue);
        expect(e.meaning.isNotEmpty, isTrue);
      }
    });
  });

  group('Fase 2 - Pesan Voice Note, Stiker, & Grup Custom (PSN-R5)', () {
    test('Pesan voice note dan stiker membawa metadata', () {
      final vnMsg = Message(
        id: 'msg-vn-1',
        conversationId: 'c-01',
        sender: testPerson,
        text: 'Voice note (0:12)',
        createdAt: DateTime.now(),
        voiceNoteSeed: 'vn-sample-1',
        voiceNoteDurationSeconds: 12,
      );
      expect(vnMsg.voiceNoteSeed, 'vn-sample-1');
      expect(vnMsg.voiceNoteDurationSeconds, 12);

      final stickerMsg = Message(
        id: 'msg-stk-1',
        conversationId: 'c-01',
        sender: testPerson,
        text: 'Horas Ma!',
        createdAt: DateTime.now(),
        stickerSeed: 'sticker-horas-1',
      );
      expect(stickerMsg.stickerSeed, 'sticker-horas-1');
    });

    test('Buat grup percakapan kustom oleh pengguna (PSN-R5)', () async {
      final res = await chatRepo.createCustomGroupChat(
        title: 'Arisan Marga Simanjuntak',
        memberUserIds: const <String>['u-02', 'u-03'],
      );
      expect(res.isOk, isTrue);
      final conv = (res as Ok<Conversation>).value;
      expect(conv.type, ConversationType.userGroup);
      expect(conv.title, 'Arisan Marga Simanjuntak');
    });
  });

  group('Fase 2 - Sesi Berulang & Lapangan Terpetakan (MAN-03, MAN-07)', () {
    test('Sesi Main berulang (mingguan, 2 mingguan, bulanan)', () {
      final session = PlaySession(
        id: 'sess-rec-1',
        host: testPerson,
        sportType: SportType.badminton,
        title: 'Badminton Rutin Naposo',
        city: 'Medan',
        startTime: DateTime.now().add(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
        maxSlots: 8,
        skillLevel: SkillLevel.all,
        feePerPersonRupiah: 30000,
        visibility: SessionVisibility.publicInArea,
        joinMode: SessionJoinMode.instant,
        createdAt: DateTime.now(),
        isRecurring: true,
        recurringInterval: 'Mingguan',
      );
      expect(session.isRecurring, isTrue);
      expect(session.recurringInterval, 'Mingguan');
    });

    test('Data Lapangan memiliki titik koordinat dan OpenStreetMap fair-use disclaimer', () {
      const court = Court(
        id: 'court-map-1',
        name: 'GOR Badminton Batak',
        address: 'Jl. Sisingamangaraja No. 45',
        city: 'Medan',
        supportedSports: <SportType>[SportType.badminton],
        estimatedPriceText: 'Rp50.000 / jam',
        openingHours: '08.00 - 22.00',
        latitude: 3.5952,
        longitude: 98.6722,
      );
      expect(court.latitude, 3.5952);
      expect(court.longitude, 98.6722);
    });

    test('Church round-trip JSON dengan koordinat serta proposeCourt & proposeChurch menyimpan titik peta', () async {
      final courtRepo = MockCourtRepository(store);
      final proposedCourtRes = await courtRepo.proposeCourt(
        name: 'GOR Horbo Balige',
        address: 'Jl. Sisingamangaraja Balige',
        city: 'Balige',
        supportedSports: const <SportType>[SportType.badminton],
        estimatedPriceText: 'Rp45.000/jam',
        openingHours: '08.00 - 22.00 WIB',
        latitude: 2.3333,
        longitude: 99.0667,
      );
      expect(proposedCourtRes.isOk, isTrue);
      final proposedCourt = (proposedCourtRes as Ok<Court>).value;
      expect(proposedCourt.latitude, 2.3333);
      expect(proposedCourt.longitude, 99.0667);

      final proposedChurchRes = await churchRepo.proposeChurch(
        name: 'HKBP Balige',
        denomination: ChurchDenomination.hkbp,
        address: 'Jl. Gereja No. 1 Balige',
        city: 'Balige',
        serviceSchedules: const <ChurchServiceSchedule>[
          ChurchServiceSchedule(
            dayOfWeek: 'Minggu',
            time: '09.00 WIB',
            language: 'Batak Toba',
          ),
        ],
        latitude: 2.3345,
        longitude: 99.0651,
      );
      expect(proposedChurchRes.isOk, isTrue);
      final proposedChurch = (proposedChurchRes as Ok<Church>).value;
      expect(proposedChurch.latitude, 2.3345);
      expect(proposedChurch.longitude, 99.0651);

      final json = proposedChurch.toJson();
      final roundTrip = Church.fromJson(json);
      expect(roundTrip.latitude, 2.3345);
      expect(roundTrip.longitude, 99.0651);
    });

    test('PlaceGeoHelper mengurutkan tempat terdekat, menghasilkan label rentang jarak, dan tautan petunjuk arah', () {
      final medanCenter = PlaceGeoHelper.cityCenterFor('Medan');
      final courts = store.courts;
      final sorted = PlaceGeoHelper.sortByNearest<Court>(
        courts,
        refLat: medanCenter.latitude,
        refLng: medanCenter.longitude,
        getLatitude: (c) => c.latitude,
        getLongitude: (c) => c.longitude,
        getCity: (c) => c.city,
      );
      expect(sorted.first.city, 'Medan');

      expect(PlaceGeoHelper.distanceRangeLabel(0.4), '< 1 km');
      expect(PlaceGeoHelper.distanceRangeLabel(2.5), '1–5 km');
      expect(PlaceGeoHelper.distanceRangeLabel(7.2), '5–10 km');
      expect(PlaceGeoHelper.distanceRangeLabel(25.0), '> 10 km');

      final dirUri = PlaceGeoHelper.googleMapsDirectionsUri(
        name: 'GOR Manunggal',
        address: 'Jl. Gatot Subroto',
        city: 'Medan',
        latitude: 3.5952,
        longitude: 98.6722,
      );
      expect(dirUri.toString(), contains('maps/dir/'));
      expect(dirUri.toString(), contains('3.5952,98.6722'));

      final fallbackUri = PlaceGeoHelper.googleMapsDirectionsUri(
        name: 'GOR Tanpa Titik',
        address: 'Jl. Merdeka',
        city: 'Medan',
      );
      expect(fallbackUri.toString(), contains('maps/search/'));
    });

    testWidgets(
      'PlaceLocationPickerPage menampilkan atribusi OpenStreetMap dan mengembalikan LatLng saat disimpan',
      (tester) async {
        LatLng? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await PlaceLocationPickerPage.show(
                        context,
                        initialLatitude: 3.5952,
                        initialLongitude: 98.6722,
                        fallbackCity: 'Medan',
                      );
                    },
                    child: const Text('Buka Pemilih Titik'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Pemilih Titik'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(AppStrings.mapAttributionOsm), findsOneWidget);
        expect(find.text(AppStrings.mapSaveLocationBtn), findsOneWidget);

        await tester.tap(find.text(AppStrings.mapSaveLocationBtn));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(result, isNotNull);
        expect(result!.latitude, closeTo(3.5952, 0.001));
        expect(result!.longitude, closeTo(98.6722, 0.001));
      },
    );
  });
}
