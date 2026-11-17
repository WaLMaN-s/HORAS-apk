import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas/app.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/features/auth/presentation/auth_placeholder_page.dart';
import 'package:horas/features/nearby/presentation/sek01_nearby_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Prompt 3 - Modul Autentikasi (AUT-01 .. AUT-07, Alur A1, AC-01, AC-02)', () {
    testWidgets(
      'Format nomor salah ditolak, dan AC-01: 5 kali salah OTP mengunci nomor 1 jam dengan pesan waktu coba lagi',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            enableMockNetworkLatencyProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authRepositoryProvider).logout();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HorasApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Guard merutekan pengguna belum login ke AUT-02 Pengenalan
        expect(find.text(AppStrings.aut02Slide1Title), findsOneWidget);

        // Buka AUT-03 Masuk
        await tester.tap(find.text(AppStrings.aut02BtnLogin));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.aut03Title), findsWidgets);

        // Input nomor tidak valid (kurang digit)
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '123');
        await tester.ensureVisible(find.text(AppStrings.aut03SendOtpBtn));
        await tester.tap(find.text(AppStrings.aut03SendOtpBtn));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Format nomor HP harus menggunakan kode negara'),
          findsOneWidget,
        );

        // Input nomor valid -> menuju AUT-05 Verifikasi OTP
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '81277778888');
        await tester.ensureVisible(find.text(AppStrings.aut03SendOtpBtn));
        await tester.tap(find.text(AppStrings.aut03SendOtpBtn));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.aut05Title), findsWidgets);

        // AC-01: Masukkan OTP salah 5 kali -> terkunci 1 jam + sebutkan waktu coba lagi
        final controller = container.read(authFlowControllerProvider.notifier);
        for (var i = 1; i <= 5; i++) {
          await controller.verifyOtpCode('000000');
          await tester.pump();
        }

        expect(
          find.textContaining('Nomor ini dikunci selama 1 jam'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Kamu dapat mencoba lagi pada pukul'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AC-02: Tahun lahir dengan usia di bawah 17 tahun ditolak dengan pesan sopan & data tidak disimpan; serta onboarding dilanjutkan setelah ditutup',
      (tester) async {
        final sharedStore = MockStore(
          appConfig: const AppConfig(
            env: AppEnvironment.dev,
            useMockBackend: true,
            allowDraftRules: true,
          ),
          enableNetworkLatency: false,
        );

        final container1 = ProviderContainer(
          overrides: [mockStoreProvider.overrideWithValue(sharedStore)],
        );
        addTearDown(container1.dispose);

        final authRepo = container1.read(authRepositoryProvider);
        await authRepo.logout();
        await authRepo.sendOtp(phoneE164: '+6281233334444');
        await authRepo.verifyOtp(
          phoneE164: '+6281233334444',
          otpCode: '123456',
          deviceName: 'Test Device',
          platform: 'Android',
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container1,
            child: const HorasApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Guard mengarahkan ke AUT-06 Langkah 1
        expect(find.text(AppStrings.aut06Step1Title), findsOneWidget);

        // Isi Langkah 1: Kotak 1 (Username/Nama) & Kotak 2 (Marga) terpisah
        final step1Fields = find.byType(TextField);
        expect(step1Fields, findsNWidgets(2));
        await tester.ensureVisible(step1Fields.first);
        await tester.enterText(step1Fields.first, 'Togu');
        await tester.ensureVisible(step1Fields.last);
        await tester.enterText(step1Fields.last, 'Simanjuntak');
        await tester.ensureVisible(find.text(AppStrings.aut06BtnNextStep));
        await tester.tap(find.text(AppStrings.aut06BtnNextStep));
        await tester.pumpAndSettle();

        // Tiba di Langkah 2: Jenis Kelamin & Tahun Lahir
        expect(find.text(AppStrings.aut06Step2Title), findsOneWidget);

        // AC-02: Coba usia < 17 (mis. tahun sekarang - 15) -> ditolak sopan & tetap di Langkah 2
        final currentYear = authRepo.currentTime.year;
        final under17Year = currentYear - 15;
        final controller = container1.read(authFlowControllerProvider.notifier);
        final okUnder17 = await controller.completeOnboardingStep2(
          gender: UserGender.male,
          birthYear: under17Year,
        );
        await tester.pumpAndSettle();

        expect(okUnder17, isFalse);
        expect(
          find.text(AppStrings.aut06Under17PoliteRejection),
          findsOneWidget,
        );
        // Pastikan tahun lahir < 17 tidak tersimpan ke draf maupun profil
        expect(authRepo.getOnboardingDraft().currentStep, 2);
        expect(authRepo.getOnboardingDraft().birthYear, isNot(under17Year));

        // Pilih tahun lahir valid (usia >= 17) -> lanjut ke Langkah 3 (Domisili & Minat)
        final validYear = currentYear - 22;
        final okValid = await controller.completeOnboardingStep2(
          gender: UserGender.male,
          birthYear: validYear,
        );
        await tester.pumpAndSettle();
        expect(okValid, isTrue);
        expect(find.text(AppStrings.aut06Step4Title), findsOneWidget);

        // Simulasikan aplikasi ditutup dan dibuka kembali dengan container baru:
        // onboarding otomatis dilanjutkan di Langkah 3!
        final container2 = ProviderContainer(
          overrides: [mockStoreProvider.overrideWithValue(sharedStore)],
        );
        addTearDown(container2.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container2,
            child: const HorasApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.aut06StepIndicator(3)), findsOneWidget);
        expect(find.text(AppStrings.aut06Step4Title), findsOneWidget);
      },
    );

    testWidgets(
      'Widget test Alur A1 penuh: Daftar -> Persetujuan -> OTP dev 123456 -> Onboarding 4 langkah -> Manfaat Izin -> Tiba di Sekitar (SEK-01)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            enableMockNetworkLatencyProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);

        final authRepo = container.read(authRepositoryProvider);
        await authRepo.logout();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HorasApp(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. AUT-02 Pengenalan -> ketuk Lewati lalu ke Daftar (AUT-04)
        expect(find.text(AppStrings.aut02Slide1Title), findsOneWidget);
        await tester.tap(find.text(AppStrings.aut02BtnSkip));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(AppStrings.aut03ToRegisterAction));
        await tester.tap(find.text(AppStrings.aut03ToRegisterAction));
        await tester.pumpAndSettle();

        // 2. AUT-04 Daftar: isi nomor HP + centang 2 persetujuan + usia 17+
        expect(find.text(AppStrings.aut04Title), findsWidgets);
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '81299887766');
        await tester.pumpAndSettle();

        final checkboxes = find.byType(Checkbox);
        expect(checkboxes, findsNWidgets(3));
        for (var i = 0; i < 3; i++) {
          await tester.ensureVisible(checkboxes.at(i));
          await tester.pumpAndSettle();
          await tester.tap(checkboxes.at(i));
          await tester.pumpAndSettle();
        }

        await tester.ensureVisible(find.text(AppStrings.aut04ContinueToOtpBtn));
        await tester.tap(find.text(AppStrings.aut04ContinueToOtpBtn));
        await tester.pumpAndSettle();

        // Pastikan persetujuan tersimpan dengan versi dan waktu
        expect(authRepo.savedLegalConsent, isNotNull);
        expect(authRepo.savedLegalConsent!.version, '1.0.0-draft');

        // 3. AUT-05 Verifikasi OTP (Pinput) dengan kode dev 123456
        expect(find.text(AppStrings.aut05Title), findsWidgets);
        expect(find.byType(Pinput), findsOneWidget);
        await tester.enterText(find.byType(Pinput), '123456');
        await tester.pumpAndSettle();

        // 4. AUT-06 Onboarding Langkah 1 (Username & Marga di 2 kotak terpisah)
        expect(find.text(AppStrings.aut06Step1Title), findsOneWidget);
        final step1Fields = find.byType(TextField);
        expect(step1Fields, findsNWidgets(2));
        await tester.ensureVisible(step1Fields.first);
        await tester.enterText(step1Fields.first, 'Bona');
        await tester.ensureVisible(step1Fields.last);
        await tester.enterText(step1Fields.last, 'Simanjuntak');
        await tester.ensureVisible(find.text(AppStrings.aut06BtnNextStep));
        await tester.tap(find.text(AppStrings.aut06BtnNextStep));
        await tester.pumpAndSettle();

        // Langkah 2 (Jenis Kelamin & Tahun Lahir)
        expect(find.text(AppStrings.aut06Step2Title), findsOneWidget);
        await tester.ensureVisible(find.text(AppStrings.aut06BtnNextStep));
        await tester.tap(find.text(AppStrings.aut06BtnNextStep));
        await tester.pumpAndSettle();

        // Langkah 3 (Domisili & Minat - langsung setelah Langkah 2, tanpa Sub-Suku & Cari Pilih Marga)
        expect(find.text(AppStrings.aut06Step4Title), findsOneWidget);
        await tester.ensureVisible(find.text(AppStrings.aut06BtnFinishSteps));
        await tester.tap(find.text(AppStrings.aut06BtnFinishSteps));
        await tester.pumpAndSettle();

        // 5. Layar Penjelas Manfaat Izin (AUT-R10)
        expect(find.text(AppStrings.autPermissionTitle), findsWidgets);
        await tester.ensureVisible(
          find.text(AppStrings.autPermissionContinueToNearbyBtn),
        );
        await tester.tap(
          find.text(AppStrings.autPermissionContinueToNearbyBtn),
        );
        await tester.pumpAndSettle();

        // 6. Tiba di tab Sekitar (SEK-01) menyelesaikan Alur A1!
        expect(find.byType(Sek01NearbyPage), findsOneWidget);
      },
    );

    test('Akun baru yang selesai onboarding tetap tersimpan di database lokal dan dapat login kembali setelah keluar/restart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final store1 = MockStore(
        appConfig: const AppConfig(
          env: AppEnvironment.dev,
          useMockBackend: true,
          allowDraftRules: true,
        ),
        prefs: prefs,
        enableNetworkLatency: false,
      );
      final authRepo1 = MockAuthRepository(store1);

      await authRepo1.logout();
      const newPhone = '+6281998877665';
      await authRepo1.sendOtp(phoneE164: newPhone);
      final regRes = await authRepo1.verifyOtp(
        phoneE164: newPhone,
        otpCode: '123456',
        deviceName: 'Pixel Uji',
        platform: 'Android',
      );
      expect(regRes.isOk, isTrue);

      final onbRes = await authRepo1.completeOnboarding(
        displayName: 'Tumpal Hutabarat',
        gender: UserGender.male,
        birthYear: 1995,
        marga: 'Hutabarat',
        subEthnic: SubEthnic.toba,
        city: 'Medan',
        subdistrict: 'Medan Baru',
      );
      expect((onbRes as Ok<Profil>).value.onboardingCompleted, isTrue);

      // Keluar akun lalu buat instance MockStore baru (simulasi aplikasi dibuka ulang)
      await authRepo1.logout();
      final store2 = MockStore(
        appConfig: const AppConfig(
          env: AppEnvironment.dev,
          useMockBackend: true,
          allowDraftRules: true,
        ),
        prefs: prefs,
        enableNetworkLatency: false,
      );
      expect(store2.currentUserId, isNull);

      final authRepo2 = MockAuthRepository(store2);
      await authRepo2.sendOtp(phoneE164: newPhone);
      final reLoginRes = await authRepo2.verifyOtp(
        phoneE164: newPhone,
        otpCode: '123456',
        deviceName: 'Pixel Uji',
        platform: 'Android',
      );
      final loggedBack = (reLoginRes as Ok<Profil>).value;
      expect(loggedBack.onboardingCompleted, isTrue);
      expect(loggedBack.displayName, 'Tumpal Hutabarat');
      expect(loggedBack.marga, 'Hutabarat');
    });

    test('Daftar dengan Email / Akun Google: wajib isi Username & Marga di Langkah 1, tersimpan di database, dan bisa login lagi pakai email tadi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final store1 = MockStore(
        appConfig: const AppConfig(
          env: AppEnvironment.dev,
          useMockBackend: true,
          allowDraftRules: true,
        ),
        prefs: prefs,
        enableNetworkLatency: false,
      );
      final authRepo1 = MockAuthRepository(store1);

      await authRepo1.logout();
      const googleEmail = 'budi.batak@gmail.com';
      final regRes = await authRepo1.signInWithEmailOrGoogle(
        email: googleEmail,
      );
      expect(regRes.isOk, isTrue);
      final newProfile = (regRes as Ok<Profil>).value;
      expect(newProfile.onboardingCompleted, isFalse);
      expect(newProfile.email, googleEmail);

      // Selesaikan onboarding dengan Username & Marga baru yang belum ada sebelumnya
      final onbRes = await authRepo1.completeOnboarding(
        displayName: 'budi_tampubolon',
        gender: UserGender.male,
        birthYear: 1997,
        marga: 'SibagariangBaru',
        subEthnic: SubEthnic.toba,
        city: 'Medan',
        subdistrict: 'Medan Baru',
      );
      expect((onbRes as Ok<Profil>).value.onboardingCompleted, isTrue);

      // Pastikan marga yang diinput otomatis masuk ke database marga
      expect(store1.margas.any((m) => m.name == 'SibagariangBaru'), isTrue);

      // Logout lalu buat MockStore baru (simulasi aplikasi dibuka ulang)
      await authRepo1.logout();
      final store2 = MockStore(
        appConfig: const AppConfig(
          env: AppEnvironment.dev,
          useMockBackend: true,
          allowDraftRules: true,
        ),
        prefs: prefs,
        enableNetworkLatency: false,
      );
      final authRepo2 = MockAuthRepository(store2);

      // Login lagi menggunakan email tadi -> langsung ditemukan di database beserta marganya!
      final reLoginRes = await authRepo2.signInWithEmailOrGoogle(
        email: googleEmail,
      );
      final restored = (reLoginRes as Ok<Profil>).value;
      expect(restored.onboardingCompleted, isTrue);
      expect(restored.email, googleEmail);
      expect(restored.displayName, 'budi_tampubolon');
      expect(restored.marga, 'SibagariangBaru');
      expect(store2.margas.any((m) => m.name == 'SibagariangBaru'), isTrue);
    });
  });
}
