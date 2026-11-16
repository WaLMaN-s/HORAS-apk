import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/policies/coarse_location_matcher.dart';
import 'package:horas/domain/policies/horas_policies.dart';

/// Kode telepon negara untuk Indonesia dan diaspora Batak (AUT-R1).
final class CountryDialOption {
  const CountryDialOption({required this.dialCode, required this.countryName});

  final String dialCode;
  final String countryName;
}

const List<CountryDialOption> kSupportedCountryDialOptions =
    <CountryDialOption>[
      CountryDialOption(dialCode: '+62', countryName: 'Indonesia (+62)'),
      CountryDialOption(dialCode: '+65', countryName: 'Singapura (+65)'),
      CountryDialOption(dialCode: '+60', countryName: 'Malaysia (+60)'),
      CountryDialOption(dialCode: '+61', countryName: 'Australia (+61)'),
      CountryDialOption(dialCode: '+1', countryName: 'AS / Kanada (+1)'),
      CountryDialOption(dialCode: '+49', countryName: 'Jerman (+49)'),
      CountryDialOption(dialCode: '+31', countryName: 'Belanda (+31)'),
      CountryDialOption(dialCode: '+44', countryName: 'Inggris (+44)'),
      CountryDialOption(dialCode: '+81', countryName: 'Jepang (+81)'),
    ];

/// State alur Autentikasi & Onboarding (AUT-01 .. AUT-07).
final class AuthFlowState {
  const AuthFlowState({
    this.countryDialCode = '+62',
    this.nationalPhone = '',
    this.pendingPhoneE164 = '',
    this.privacyAndTermsAccepted = false,
    this.communityGuidelinesAccepted = false,
    this.age17PlusConfirmed = false,
    this.isLoading = false,
    this.error,
    this.onboardingDraft = const OnboardingDraft(),
    this.under17PoliteRejectionMessage,
    this.notificationsGranted = false,
    this.coarseLocationMatchedCity,
    this.permissionDeniedNotice = false,
    this.dualOtpSent = false,
    this.phoneChangeSucceeded = false,
    this.recoverySubmission,
  });

  final String countryDialCode;
  final String nationalPhone;
  final String pendingPhoneE164;
  final bool privacyAndTermsAccepted;
  final bool communityGuidelinesAccepted;
  final bool age17PlusConfirmed;
  final bool isLoading;
  final AppError? error;
  final OnboardingDraft onboardingDraft;
  final String? under17PoliteRejectionMessage;
  final bool notificationsGranted;
  final String? coarseLocationMatchedCity;
  final bool permissionDeniedNotice;
  final bool dualOtpSent;
  final bool phoneChangeSucceeded;
  final AccountRecoverySubmission? recoverySubmission;

  bool get allRegistrationConsentsChecked =>
      privacyAndTermsAccepted &&
      communityGuidelinesAccepted &&
      age17PlusConfirmed;

  /// Menormalkan kode negara + input nomor nasional menjadi format E.164 (`+62812...`).
  String formatE164([String? customNational]) {
    final raw = (customNational ?? nationalPhone).trim();
    if (raw.startsWith('+')) {
      return raw.replaceAll(RegExp(r'\s+'), '');
    }
    var digits = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (countryDialCode == '+62' && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '$countryDialCode$digits';
  }

  AuthFlowState copyWith({
    String? countryDialCode,
    String? nationalPhone,
    String? pendingPhoneE164,
    bool? privacyAndTermsAccepted,
    bool? communityGuidelinesAccepted,
    bool? age17PlusConfirmed,
    bool? isLoading,
    AppError? error,
    bool clearError = false,
    OnboardingDraft? onboardingDraft,
    String? under17PoliteRejectionMessage,
    bool clearUnder17Message = false,
    bool? notificationsGranted,
    String? coarseLocationMatchedCity,
    bool? permissionDeniedNotice,
    bool? dualOtpSent,
    bool? phoneChangeSucceeded,
    AccountRecoverySubmission? recoverySubmission,
  }) {
    return AuthFlowState(
      countryDialCode: countryDialCode ?? this.countryDialCode,
      nationalPhone: nationalPhone ?? this.nationalPhone,
      pendingPhoneE164: pendingPhoneE164 ?? this.pendingPhoneE164,
      privacyAndTermsAccepted:
          privacyAndTermsAccepted ?? this.privacyAndTermsAccepted,
      communityGuidelinesAccepted:
          communityGuidelinesAccepted ?? this.communityGuidelinesAccepted,
      age17PlusConfirmed: age17PlusConfirmed ?? this.age17PlusConfirmed,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      onboardingDraft: onboardingDraft ?? this.onboardingDraft,
      under17PoliteRejectionMessage: clearUnder17Message
          ? null
          : (under17PoliteRejectionMessage ??
                this.under17PoliteRejectionMessage),
      notificationsGranted: notificationsGranted ?? this.notificationsGranted,
      coarseLocationMatchedCity:
          coarseLocationMatchedCity ?? this.coarseLocationMatchedCity,
      permissionDeniedNotice:
          permissionDeniedNotice ?? this.permissionDeniedNotice,
      dualOtpSent: dualOtpSent ?? this.dualOtpSent,
      phoneChangeSucceeded: phoneChangeSucceeded ?? this.phoneChangeSucceeded,
      recoverySubmission: recoverySubmission ?? this.recoverySubmission,
    );
  }
}

/// Controller Riverpod untuk modul Autentikasi (`AUT-01` .. `AUT-07`).
class AuthFlowController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() {
    final authRepo = ref.watch(authRepositoryProvider);
    final savedDraft = authRepo.getOnboardingDraft();
    return AuthFlowState(
      onboardingDraft: savedDraft,
      recoverySubmission: authRepo.latestRecoverySubmission,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true, clearUnder17Message: true);
  }

  void setCountryDialCode(String dialCode) {
    state = state.copyWith(countryDialCode: dialCode, clearError: true);
  }

  void setNationalPhone(String value) {
    state = state.copyWith(nationalPhone: value, clearError: true);
  }

  void setPrivacyConsent(bool value) {
    state = state.copyWith(privacyAndTermsAccepted: value, clearError: true);
  }

  void setGuidelinesConsent(bool value) {
    state = state.copyWith(
      communityGuidelinesAccepted: value,
      clearError: true,
    );
  }

  void setAge17Confirmed(bool value) {
    state = state.copyWith(age17PlusConfirmed: value, clearError: true);
  }

  /// AUT-03: Meminta OTP untuk masuk dengan nomor HP.
  Future<bool> sendOtpForLogin([String? phoneOverride]) async {
    final authRepo = ref.read(authRepositoryProvider);
    final phoneE164 = state.formatE164(phoneOverride);
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      pendingPhoneE164: phoneE164,
    );

    final res = await authRepo.sendOtp(phoneE164: phoneE164);
    return res.fold(
      onOk: (_) {
        state = state.copyWith(isLoading: false, pendingPhoneE164: phoneE164);
        return true;
      },
      onErr: (err) {
        state = state.copyWith(isLoading: false, error: err);
        return false;
      },
    );
  }

  /// AUT-04: Memvalidasi 2 persetujuan + usia 17+, menyimpan versi & waktu, lalu meminta OTP.
  Future<bool> submitRegistrationConsentsAndSendOtp([
    String? phoneOverride,
  ]) async {
    if (!state.allRegistrationConsentsChecked) {
      state = state.copyWith(
        error: const ValidationError(
          message: AppStrings.aut04ErrorMustAcceptAll,
          field: 'consents',
        ),
      );
      return false;
    }

    final authRepo = ref.read(authRepositoryProvider);
    final now = authRepo.currentTime;
    await authRepo.saveLegalConsent(
      LegalConsentRecord(
        version: '1.0.0-draft',
        acceptedPrivacyAndTermsAt: now,
        acceptedCommunityGuidelinesAt: now,
        confirmedAge17PlusAt: now,
      ),
    );

    return sendOtpForLogin(phoneOverride);
  }

  /// AUT-05: Memverifikasi kode OTP 6 digit.
  Future<Profil?> verifyOtpCode(
    String otpCode, {
    String deviceName = 'Perangkat Android HORAS',
    String platform = 'Android',
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    final targetPhone = state.pendingPhoneE164.isNotEmpty
        ? state.pendingPhoneE164
        : state.formatE164();

    state = state.copyWith(isLoading: true, clearError: true);
    final res = await authRepo.verifyOtp(
      phoneE164: targetPhone,
      otpCode: otpCode,
      deviceName: deviceName,
      platform: platform,
    );

    return res.fold(
      onOk: (profil) {
        final savedDraft = authRepo.getOnboardingDraft();
        state = state.copyWith(isLoading: false, onboardingDraft: savedDraft);
        return profil;
      },
      onErr: (err) {
        state = state.copyWith(isLoading: false, error: err);
        return null;
      },
    );
  }

  /// Menyimpan perubahan draf onboarding setiap langkah agar tidak hilang bila aplikasi ditutup (AUT-R5).
  Future<void> updateOnboardingDraft(
    OnboardingDraft Function(OnboardingDraft current) updater,
  ) async {
    final nextDraft = updater(state.onboardingDraft);
    state = state.copyWith(
      onboardingDraft: nextDraft,
      clearError: true,
      clearUnder17Message: true,
    );
    await ref.read(authRepositoryProvider).saveOnboardingDraft(nextDraft);
  }

  /// Langkah 1 -> Langkah 2: Validasi nama tampil 2–40 karakter.
  Future<bool> completeOnboardingStep1({
    required String displayName,
    String? photoSeedOrPath,
  }) async {
    final check = HorasPolicies.validateDisplayName(displayName);
    if (check is Err<void>) {
      state = state.copyWith(error: check.failure);
      return false;
    }
    await updateOnboardingDraft(
      (d) => d.copyWith(
        currentStep: 2,
        displayName: displayName.trim(),
        photoSeedOrPath: photoSeedOrPath ?? d.photoSeedOrPath,
      ),
    );
    return true;
  }

  /// Langkah 2 -> Langkah 3: Validasi jenis kelamin & tahun lahir (usia < 17 ditolak sopan & TIDAK disimpan — AC-02).
  Future<bool> completeOnboardingStep2({
    required UserGender gender,
    required int birthYear,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    final ageCheck = HorasPolicies.validateOnboardingAge(
      birthYear: birthYear,
      now: authRepo.currentTime,
    );
    if (ageCheck is Err<void>) {
      // AC-02: Pendaftaran ditolak dengan pesan sopan dan data TIDAK disimpan ke draf/profil.
      state = state.copyWith(
        under17PoliteRejectionMessage: AppStrings.aut06Under17PoliteRejection,
        error: ageCheck.failure,
      );
      return false;
    }

    await updateOnboardingDraft(
      (d) => d.copyWith(currentStep: 3, gender: gender, birthYear: birthYear),
    );
    return true;
  }

  /// Langkah 3 -> Langkah 4: Validasi marga & sub-suku (opsi Marga belum ada — AUT-R6).
  Future<bool> completeOnboardingStep3({
    required SubEthnic subEthnic,
    required String marga,
    required bool isCustomMarga,
    String? motherMarga,
  }) async {
    final cleanMarga = marga.trim();
    if (cleanMarga.length < 2) {
      state = state.copyWith(
        error: const ValidationError(
          message: 'Pilih atau masukkan nama marga terlebih dahulu.',
          field: 'marga',
        ),
      );
      return false;
    }

    if (isCustomMarga) {
      await ref
          .read(profileRepositoryProvider)
          .submitCustomMarga(margaName: cleanMarga, subEthnic: subEthnic);
    }

    await updateOnboardingDraft(
      (d) => d.copyWith(
        currentStep: 4,
        subEthnic: subEthnic,
        marga: cleanMarga,
        isCustomMarga: isCustomMarga,
        motherMarga: (motherMarga ?? '').trim(),
      ),
    );
    return true;
  }

  /// Langkah 4 -> Layar Penjelas Manfaat Izin (AUT-R10).
  Future<bool> completeOnboardingStep4({
    required String city,
    required String subdistrict,
    required List<String> hobbies,
    String? campusOrOffice,
  }) async {
    if (city.trim().isEmpty || subdistrict.trim().isEmpty) {
      state = state.copyWith(
        error: const ValidationError(
          message: 'Pilih kota dan kecamatan domisili terlebih dahulu.',
          field: 'city',
        ),
      );
      return false;
    }

    final draft = state.onboardingDraft.copyWith(
      city: city.trim(),
      subdistrict: subdistrict.trim(),
      hobbies: hobbies,
      campusOrOffice: (campusOrOffice ?? '').trim(),
    );

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      onboardingDraft: draft,
    );

    final authRepo = ref.read(authRepositoryProvider);
    final res = await authRepo.completeOnboarding(
      displayName: draft.displayName.isEmpty
          ? 'Anggota HORAS'
          : draft.displayName,
      gender: draft.gender,
      birthYear: draft.birthYear,
      marga: draft.marga.isEmpty ? 'Simanjuntak' : draft.marga,
      subEthnic: draft.subEthnic,
      city: draft.city,
      subdistrict: draft.subdistrict,
      motherMarga: draft.motherMarga.isEmpty ? null : draft.motherMarga,
      hobbies: draft.hobbies,
      campusOrOffice: draft.campusOrOffice.isEmpty
          ? null
          : draft.campusOrOffice,
    );

    return res.fold(
      onOk: (_) async {
        await updateOnboardingDraft(
          (d) => draft.copyWith(showPermissionExplainer: true),
        );
        state = state.copyWith(isLoading: false);
        return true;
      },
      onErr: (err) {
        state = state.copyWith(isLoading: false, error: err);
        return false;
      },
    );
  }

  Future<void> goBackOnboardingStep() async {
    final current = state.onboardingDraft.currentStep;
    if (current > 1) {
      await updateOnboardingDraft((d) => d.copyWith(currentStep: current - 1));
    }
  }

  /// AUT-R10: Mengaktifkan izin notifikasi.
  void grantNotificationPermission({required bool granted}) {
    state = state.copyWith(
      notificationsGranted: granted,
      permissionDeniedNotice: !granted,
    );
  }

  /// AUT-R10: Mencocokkan lokasi kasar (`ACCESS_COARSE_LOCATION`) ke kota terdekat
  /// dari `wilayah.json` di perangkat, lalu langsung membuang koordinatnya.
  Future<void> matchCoarseLocationAndDiscardCoordinates({
    required double coarseLat,
    required double coarseLon,
    required bool permissionGranted,
  }) async {
    if (!permissionGranted) {
      state = state.copyWith(permissionDeniedNotice: true);
      return;
    }
    final nearbyRepo = ref.read(nearbyRepositoryProvider);
    final citiesRes = await nearbyRepo.getAvailableCities();
    final cityNames = citiesRes.fold(
      onOk: (list) => list.map((c) => c.name).toList(),
      onErr: (_) => const <String>[],
    );

    // Koordinat dipakai hanya di fungsi lokal ini dan langsung dibuang
    final matchedCity = CoarseLocationCityMatcher.matchNearestCityName(
      coarseLat: coarseLat,
      coarseLon: coarseLon,
      availableCityNames: cityNames,
    );

    nearbyRepo.setCurrentSelectedCity(matchedCity);
    await ref
        .read(profileRepositoryProvider)
        .updateMyProfile(city: matchedCity);
    state = state.copyWith(
      coarseLocationMatchedCity: matchedCity,
      permissionDeniedNotice: false,
    );
  }

  Future<void> finishPermissionExplainer() async {
    await ref.read(authRepositoryProvider).clearOnboardingDraft();
    state = state.copyWith(onboardingDraft: const OnboardingDraft());
  }

  // ── AUT-07 Pemulihan Akun (AUT-R8a & AUT-R8b) ───────────────────────────────

  Future<bool> sendDualOtpForPhoneChange({
    required String oldPhoneE164,
    required String newPhoneE164,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    state = state.copyWith(isLoading: true, clearError: true);
    final res1 = await authRepo.sendOtp(phoneE164: oldPhoneE164);
    if (res1 is Err<void>) {
      state = state.copyWith(isLoading: false, error: res1.failure);
      return false;
    }
    final res2 = await authRepo.sendOtp(phoneE164: newPhoneE164);
    if (res2 is Err<void>) {
      state = state.copyWith(isLoading: false, error: res2.failure);
      return false;
    }
    state = state.copyWith(isLoading: false, dualOtpSent: true);
    return true;
  }

  Future<bool> verifyDualOtpAndChangePhone({
    required String oldPhoneE164,
    required String oldOtpCode,
    required String newPhoneE164,
    required String newOtpCode,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    state = state.copyWith(isLoading: true, clearError: true);
    final res = await authRepo.changePhoneWithDualOtp(
      oldPhoneE164: oldPhoneE164,
      oldOtpCode: oldOtpCode,
      newPhoneE164: newPhoneE164,
      newOtpCode: newOtpCode,
    );
    return res.fold(
      onOk: (_) {
        state = state.copyWith(isLoading: false, phoneChangeSucceeded: true);
        return true;
      },
      onErr: (err) {
        state = state.copyWith(isLoading: false, error: err);
        return false;
      },
    );
  }

  Future<bool> submitLostPhoneProof({
    required String oldPhoneE164,
    required String newPhoneE164,
    required String approximateRegistrationPeriod,
    required String marga,
    required String knownFriendsText,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    state = state.copyWith(isLoading: true, clearError: true);
    final res = await authRepo.submitLostPhoneRecovery(
      oldPhoneE164: oldPhoneE164,
      newPhoneE164: newPhoneE164,
      approximateRegistrationPeriod: approximateRegistrationPeriod,
      marga: marga,
      knownFriendsText: knownFriendsText,
    );
    return res.fold(
      onOk: (submission) {
        state = state.copyWith(
          isLoading: false,
          recoverySubmission: submission,
        );
        return true;
      },
      onErr: (err) {
        state = state.copyWith(isLoading: false, error: err);
        return false;
      },
    );
  }
}

/// Provider global untuk [AuthFlowController].
final authFlowControllerProvider =
    NotifierProvider<AuthFlowController, AuthFlowState>(AuthFlowController.new);
