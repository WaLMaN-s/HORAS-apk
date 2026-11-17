import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/data/supabase/supabase_error_mapper.dart';
import 'package:horas/data/supabase/supabase_gateway.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/policies/horas_policies.dart';
import 'package:horas/domain/repositories/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// 1. Implementasi Supabase untuk [AuthRepository] (Tugas 3: OTP guard, token di
/// `flutter_secure_storage`, max 3 perangkat, pemulihan akun, & logout).
final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._gw);

  final SupabaseGateway _gw;

  static const String _kLegalConsent = 'horas_sb_legal_consent_v1';
  static const String _kOnboardingDraft = 'horas_sb_onboarding_draft_v1';
  static const String _kDeviceKey = 'horas_sb_device_key_v1';
  static const String _kLatestRecovery = 'horas_sb_latest_recovery_v1';

  final Map<String, OtpPhoneStatus> _otpStatusByPhone =
      <String, OtpPhoneStatus>{};

  @override
  String? get currentUserId => _gw.currentUserId;

  @override
  Profil? get currentSessionProfile => _gw.currentSessionProfile;

  @override
  DateTime get currentTime => _gw.currentTime;

  @override
  bool get isDevOtpHintEnabled => !_gw.appConfig.isProd;

  @override
  bool get hadDeletionRecentlyCancelled => _gw.hadDeletionRecentlyCancelled;

  @override
  void clearDeletionCancelledNotice() {
    _gw.hadDeletionRecentlyCancelled = false;
  }

  /// Memulihkan sesi dari `flutter_secure_storage` atau cache profil saat offline (AC-15).
  Future<Profil?> restoreSessionProfile() async {
    final user = _gw.client.auth.currentUser;
    if (user == null) {
      _gw.currentSessionProfile = null;
      return null;
    }
    try {
      final profRow = await _gw.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      final privRow = await _gw.client
          .from('user_privacy_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      final profile = _gw.profileFromRow(profRow, privacyRow: privRow);
      _gw.currentSessionProfile = profile;
      await _gw.cache.saveMyProfileJson(profile.toJson());
      _gw.cache.markLiveSync();
      return profile;
    } on Object {
      final cachedJson = _gw.cache.readMyProfileJson();
      if (cachedJson != null) {
        final cachedProfile = Profil.fromJson(cachedJson);
        _gw.currentSessionProfile = cachedProfile;
        _gw.cache.markServingCache();
        return cachedProfile;
      }
      return null;
    }
  }

  @override
  LegalConsentRecord? get savedLegalConsent {
    final raw = _gw.prefs?.getString(_kLegalConsent);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LegalConsentRecord.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveLegalConsent(LegalConsentRecord consent) async {
    await _gw.prefs?.setString(_kLegalConsent, jsonEncode(consent.toJson()));
  }

  @override
  OnboardingDraft getOnboardingDraft() {
    final raw = _gw.prefs?.getString(_kOnboardingDraft);
    if (raw == null || raw.isEmpty) return const OnboardingDraft();
    try {
      return OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return const OnboardingDraft();
    }
  }

  @override
  Future<void> saveOnboardingDraft(OnboardingDraft draft) async {
    await _gw.prefs?.setString(_kOnboardingDraft, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clearOnboardingDraft() async {
    await _gw.prefs?.remove(_kOnboardingDraft);
  }

  @override
  OtpPhoneStatus getOtpStatusForPhone(String phoneE164) {
    return _otpStatusByPhone[phoneE164.trim()] ??
        (
          remainingAttempts: 5,
          lockedUntil: null,
          issuedAt: null,
          resendReadyAt: null,
        );
  }

  String _getOrCreateDeviceKey() {
    final existing = _gw.prefs?.getString(_kDeviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    _gw.prefs?.setString(_kDeviceKey, generated);
    return generated;
  }

  @override
  Future<Result<void>> sendOtp({required String phoneE164}) async {
    final check = HorasPolicies.validatePhoneE164(phoneE164);
    if (check is Err<void>) return check;
    final phone = phoneE164.trim();

    try {
      final res = await _gw.client.functions.invoke(
        'auth-otp-guard',
        body: <String, Object?>{'action': 'request_otp', 'phoneE164': phone},
      );
      final data = res.data;
      if (res.status >= 400 || (data is Map && data['ok'] == false)) {
        final err = SupabaseErrorMapper.map(
          FunctionException(status: res.status, details: data),
        );
        if (err is RateLimitedError) {
          _otpStatusByPhone[phone] = (
            remainingAttempts: 5,
            lockedUntil: err.retryAt.difference(clock.now()).inMinutes > 5
                ? err.retryAt
                : null,
            issuedAt: clock.now(),
            resendReadyAt: err.retryAt,
          );
        }
        return Err<void>(err);
      }

      final now = clock.now().toUtc();
      final resendAt = (data is Map && data['resendAvailableAt'] is String)
          ? DateTime.tryParse(data['resendAvailableAt'] as String)
          : now.add(const Duration(seconds: 60));
      _otpStatusByPhone[phone] = (
        remainingAttempts: 5,
        lockedUntil: null,
        issuedAt: now,
        resendReadyAt: resendAt,
      );
      return const Ok<void>(null);
    } on Object catch (e, st) {
      final mapped = SupabaseErrorMapper.map(e, st);
      if (mapped is RateLimitedError) {
        _otpStatusByPhone[phone] = (
          remainingAttempts: 5,
          lockedUntil: mapped.retryAt.difference(clock.now()).inMinutes > 5
              ? mapped.retryAt
              : null,
          issuedAt: clock.now(),
          resendReadyAt: mapped.retryAt,
        );
      }
      return Err<void>(mapped);
    }
  }

  @override
  Future<Result<Profil>> verifyOtp({
    required String phoneE164,
    required String otpCode,
    required String deviceName,
    required String platform,
  }) async {
    final phoneCheck = HorasPolicies.validatePhoneE164(phoneE164);
    if (phoneCheck is Err<void>) {
      return Err<Profil>((phoneCheck).failure);
    }
    final phone = phoneE164.trim();
    final deviceKey = _getOrCreateDeviceKey();

    try {
      final res = await _gw.client.functions.invoke(
        'auth-otp-guard',
        body: <String, Object?>{
          'action': 'verify_otp',
          'phoneE164': phone,
          'otpCode': otpCode.trim(),
          'deviceKey': deviceKey,
          'deviceName': deviceName,
          'platform': platform,
        },
      );
      final data = res.data;
      if (res.status >= 400 || data is! Map || data['ok'] != true) {
        if (data is Map && data['remainingAttempts'] is int) {
          final prev = getOtpStatusForPhone(phone);
          _otpStatusByPhone[phone] = (
            remainingAttempts: data['remainingAttempts'] as int,
            lockedUntil: prev.lockedUntil,
            issuedAt: prev.issuedAt,
            resendReadyAt: prev.resendReadyAt,
          );
        }
        return Err<Profil>(
          SupabaseErrorMapper.map(
            FunctionException(status: res.status, details: data),
          ),
        );
      }

      final sessionMap = data['session'] as Map?;
      final refreshToken = sessionMap?['refresh_token'] as String?;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _gw.client.auth.setSession(refreshToken);
      }

      _gw.hadDeletionRecentlyCancelled = data['deletionCancelled'] == true;
      _otpStatusByPhone.remove(phone);

      final profile = await restoreSessionProfile();
      if (profile == null) {
        return Err<Profil>(
          SupabaseErrorMapper.map(
            const UnavailableError(message: 'Profil belum siap.'),
          ),
        );
      }
      return Ok<Profil>(profile);
    } on Object catch (e, st) {
      final mapped = SupabaseErrorMapper.map(e, st);
      if (mapped is RateLimitedError) {
        _otpStatusByPhone[phone] = (
          remainingAttempts: 0,
          lockedUntil: mapped.retryAt,
          issuedAt: clock.now(),
          resendReadyAt: mapped.retryAt,
        );
      }
      return Err<Profil>(mapped);
    }
  }

  @override
  Future<Result<Profil>> signInWithEmailOrGoogle({
    required String email,
    String deviceName = 'Perangkat Android HORAS',
    String platform = 'Android',
  }) async {
    final emailCheck = HorasPolicies.validateEmail(email);
    if (emailCheck is Err<void>) {
      return Err<Profil>(emailCheck.failure);
    }
    final cleanEmail = email.trim().toLowerCase();
    final deviceKey = _getOrCreateDeviceKey();

    try {
      final res = await _gw.client.functions.invoke(
        'auth-otp-guard',
        body: <String, Object?>{
          'action': 'sign_in_email_or_google',
          'email': cleanEmail,
          'deviceKey': deviceKey,
          'deviceName': deviceName,
          'platform': platform,
        },
      );
      final data = res.data;
      if (res.status >= 400 || data is! Map || data['ok'] != true) {
        return Err<Profil>(
          SupabaseErrorMapper.map(
            FunctionException(status: res.status, details: data),
          ),
        );
      }

      final sessionMap = data['session'] as Map?;
      final refreshToken = sessionMap?['refresh_token'] as String?;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _gw.client.auth.setSession(refreshToken);
      }

      _gw.hadDeletionRecentlyCancelled = data['deletionCancelled'] == true;
      final profile = await restoreSessionProfile();
      if (profile == null) {
        return Err<Profil>(
          SupabaseErrorMapper.map(
            const UnavailableError(message: 'Profil belum siap.'),
          ),
        );
      }
      return Ok<Profil>(profile);
    } on Object catch (e, st) {
      return Err<Profil>(SupabaseErrorMapper.map(e, st));
    }
  }

  @override
  Future<Result<Profil>> completeOnboarding({
    required String displayName,
    required UserGender gender,
    required int birthYear,
    required String marga,
    required SubEthnic subEthnic,
    required String city,
    required String subdistrict,
    String? motherMarga,
    List<String> hobbies = const <String>[],
    String? campusOrOffice,
  }) => _gw.guard(() async {
    final consent =
        savedLegalConsent ??
        LegalConsentRecord(
          version: '1.0.0',
          acceptedPrivacyAndTermsAt: _gw.currentTime,
          acceptedCommunityGuidelinesAt: _gw.currentTime,
          confirmedAge17PlusAt: _gw.currentTime,
        );
    final draft = getOnboardingDraft();
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'complete_onboarding',
      params: <String, Object?>{
        'p_display_name': displayName,
        'p_gender': gender.jsonCode,
        'p_birth_year': birthYear,
        'p_marga': marga,
        'p_sub_ethnic': subEthnic.name,
        'p_mother_marga': motherMarga,
        'p_city': city,
        'p_subdistrict': subdistrict,
        'p_hobbies': hobbies,
        'p_campus_or_office': campusOrOffice,
        'p_is_custom_marga': draft.isCustomMarga,
        'p_legal_consent': consent.toJson(),
      },
    );

    if (draft.photoSeedOrPath != null && draft.photoSeedOrPath!.isNotEmpty) {
      try {
        final uploaded = await _gw.mediaUploader.uploadWithRetryAndResume(
          bucket: 'avatars',
          sourcePathOrSeed: draft.photoSeedOrPath!,
        );
        await _gw.client
            .from('profiles')
            .update(<String, Object?>{'avatar_path': uploaded.storagePath})
            .eq('id', row['id'] as String);
      } on Object {
        // Tetap lanjut onboarding bila foto profil ditunda saat koneksi lemah.
      }
    }

    await clearOnboardingDraft();
    final restored = await restoreSessionProfile();
    return restored ?? _gw.profileFromRow(row);
  });

  @override
  Future<Result<List<Device>>> getActiveDevices() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return const <Device>[];
    final currentKey = _gw.prefs?.getString(_kDeviceKey);
    final rows = await _gw.client
        .from('user_devices')
        .select()
        .eq('user_id', uid)
        .isFilter('revoked_at', null)
        .order('logged_in_at', ascending: true);

    return rows
        .map(
          (r) => Device(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            deviceName: (r['device_name'] as String?) ?? 'Perangkat HORAS',
            platform: (r['platform'] as String?) ?? 'android',
            loggedInAt:
                SupabaseGateway.parseDate(r['logged_in_at']) ?? _gw.currentTime,
            lastActiveAt:
                SupabaseGateway.parseDate(r['last_active_at']) ??
                _gw.currentTime,
            isCurrent: currentKey != null && r['device_key'] == currentKey,
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<void>> revokeDevice(String deviceId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return;
    await _gw.client
        .from('user_devices')
        .delete()
        .eq('id', deviceId)
        .eq('user_id', uid);
  });

  @override
  Future<Result<List<LoginHistoryEntry>>> getLoginHistory30Days() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const <LoginHistoryEntry>[];
        final since = _gw.currentTime
            .subtract(const Duration(days: 30))
            .toIso8601String();
        final rows = await _gw.client
            .from('login_history')
            .select()
            .eq('user_id', uid)
            .gte('logged_in_at', since)
            .order('logged_in_at', ascending: false);

        return rows
            .map(
              (r) => LoginHistoryEntry(
                id: r['id'] as String,
                userId: r['user_id'] as String,
                deviceName: (r['device_name'] as String?) ?? '',
                platform: (r['platform'] as String?) ?? 'android',
                city: (r['city_label'] as String?) ?? '',
                loggedInAt:
                    SupabaseGateway.parseDate(r['logged_in_at']) ??
                    _gw.currentTime,
              ),
            )
            .toList(growable: false);
      });

  @override
  Future<Result<void>> requestAccountRecovery({
    required String oldPhoneE164,
    required String newPhoneE164,
    required String proofNote,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'submit_account_recovery',
      params: <String, Object?>{
        'p_old_phone_e164': oldPhoneE164,
        'p_new_phone_e164': newPhoneE164,
        'p_approximate_registration_period': '-',
        'p_marga': _gw.currentSessionProfile?.marga ?? '-',
        'p_known_friends_text': proofNote,
      },
    );
  });

  @override
  Future<Result<void>> changePhoneWithDualOtp({
    required String oldPhoneE164,
    required String oldOtpCode,
    required String newPhoneE164,
    required String newOtpCode,
  }) => _gw.guard(() async {
    final vOld = HorasPolicies.validatePhoneE164(oldPhoneE164);
    if (vOld is Err<void>) throw vOld.failure;
    final vNew = HorasPolicies.validatePhoneE164(newPhoneE164);
    if (vNew is Err<void>) throw vNew.failure;

    await _gw.client.auth.updateUser(
      UserAttributes(phone: newPhoneE164.trim()),
    );
    await _gw.client.auth.verifyOTP(
      phone: newPhoneE164.trim(),
      token: newOtpCode.trim(),
      type: OtpType.phoneChange,
    );
    await restoreSessionProfile();
  });

  @override
  Future<Result<AccountRecoverySubmission>> submitLostPhoneRecovery({
    required String oldPhoneE164,
    required String newPhoneE164,
    required String approximateRegistrationPeriod,
    required String marga,
    required String knownFriendsText,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'submit_account_recovery',
      params: <String, Object?>{
        'p_old_phone_e164': oldPhoneE164,
        'p_new_phone_e164': newPhoneE164,
        'p_approximate_registration_period': approximateRegistrationPeriod,
        'p_marga': marga,
        'p_known_friends_text': knownFriendsText,
      },
    );
    final sub = AccountRecoverySubmission(
      id: row['id'] as String,
      oldPhoneE164: (row['old_phone_e164'] as String?) ?? oldPhoneE164,
      newPhoneE164: (row['new_phone_e164'] as String?) ?? newPhoneE164,
      approximateRegistrationPeriod:
          (row['approximate_registration_period'] as String?) ??
          approximateRegistrationPeriod,
      marga: (row['marga'] as String?) ?? marga,
      knownFriendsText:
          (row['known_friends_text'] as String?) ?? knownFriendsText,
      statusLabel: 'Menunggu verifikasi tim dukungan',
      submittedAt:
          SupabaseGateway.parseDate(row['submitted_at']) ?? _gw.currentTime,
    );
    await _gw.prefs?.setString(
      _kLatestRecovery,
      jsonEncode(<String, Object?>{
        'id': sub.id,
        'oldPhoneE164': sub.oldPhoneE164,
        'newPhoneE164': sub.newPhoneE164,
        'approximateRegistrationPeriod': sub.approximateRegistrationPeriod,
        'marga': sub.marga,
        'knownFriendsText': sub.knownFriendsText,
        'statusLabel': sub.statusLabel,
        'submittedAt': sub.submittedAt.toIso8601String(),
      }),
    );
    return sub;
  });

  @override
  AccountRecoverySubmission? get latestRecoverySubmission {
    final raw = _gw.prefs?.getString(_kLatestRecovery);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      return AccountRecoverySubmission(
        id: m['id'] as String,
        oldPhoneE164: m['oldPhoneE164'] as String,
        newPhoneE164: m['newPhoneE164'] as String,
        approximateRegistrationPeriod:
            m['approximateRegistrationPeriod'] as String,
        marga: m['marga'] as String,
        knownFriendsText: m['knownFriendsText'] as String,
        statusLabel: m['statusLabel'] as String,
        submittedAt: DateTime.parse(m['submittedAt'] as String),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<Result<void>> logout() => _gw.guard(() async {
    await _gw.client.auth.signOut();
    _gw.currentSessionProfile = null;
    _gw.invalidatePersonCache();
    await _gw.cache.clearAllUserCaches();
  });
}

/// 2. Implementasi Supabase untuk [ProfileRepository].
final class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._gw, this._authRepo);

  final SupabaseGateway _gw;
  final SupabaseAuthRepository _authRepo;

  @override
  Future<Result<Profil>> getMyProfile() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      return const Err<Profil>(
        PermissionDeniedError(
          message: 'Login diperlukan.',
          permissionName: 'auth',
        ),
      );
    }
    try {
      final profRow = await _gw.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();
      final privRow = await _gw.client
          .from('user_privacy_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      final profile = _gw.profileFromRow(profRow, privacyRow: privRow);
      _gw.currentSessionProfile = profile;
      await _gw.cache.saveMyProfileJson(profile.toJson());
      _gw.cache.markLiveSync();
      return Ok<Profil>(profile);
    } on Object catch (e, st) {
      if (SupabaseErrorMapper.isOfflineFailure(e)) {
        final cached = _gw.cache.readMyProfileJson();
        if (cached != null) {
          _gw.cache.markServingCache();
          return Ok<Profil>(Profil.fromJson(cached));
        }
      }
      return Err<Profil>(SupabaseErrorMapper.map(e, st));
    }
  }

  @override
  Future<Result<Profil>> updateMyProfile({
    String? displayName,
    String? avatarSeed,
    String? bio,
    String? city,
    String? subdistrict,
    String? motherMarga,
    List<String>? hobbies,
    String? campusOrOffice,
    String? websiteUrl,
    String? homeChurchName,
  }) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }

    final updates = <String, Object?>{};
    if (displayName != null) updates['display_name'] = displayName.trim();
    if (bio != null) updates['bio'] = bio.trim();
    if (city != null) updates['city'] = city.trim();
    if (subdistrict != null) updates['subdistrict'] = subdistrict.trim();
    if (motherMarga != null) {
      updates['mother_marga'] = motherMarga.trim().isEmpty
          ? null
          : motherMarga.trim();
    }
    if (hobbies != null) updates['hobbies'] = hobbies;
    if (campusOrOffice != null) {
      updates['campus_or_office'] = campusOrOffice.trim();
    }
    if (websiteUrl != null) updates['website_url'] = websiteUrl.trim();
    if (homeChurchName != null) updates['home_church'] = homeChurchName.trim();
    if (avatarSeed != null && avatarSeed.isNotEmpty) {
      final uploaded = await _gw.mediaUploader.uploadWithRetryAndResume(
        bucket: 'avatars',
        sourcePathOrSeed: avatarSeed,
      );
      if (uploaded.publicUrl != null) {
        updates['avatar_path'] = uploaded.publicUrl;
      } else {
        updates['avatar_seed'] = uploaded.storagePath;
      }
      await _gw.mediaUploader.markBatchFinished('avatars', <String>[
        avatarSeed,
      ]);
    }

    if (updates.isNotEmpty) {
      await _gw.client.from('profiles').update(updates).eq('id', uid);
      _gw.invalidatePersonCache(uid);
    }

    final refreshed = await _authRepo.restoreSessionProfile();
    if (refreshed == null) {
      throw const UnavailableError(message: 'Profil tidak ditemukan.');
    }
    return refreshed;
  });

  @override
  Future<Result<PersonSummary>> getPersonSummary(String userId) =>
      _gw.guard(() async {
        final raw = await _gw.client.rpc<Map<String, dynamic>>(
          'get_person_summary',
          params: <String, Object?>{'p_target_id': userId},
        );
        return PersonSummary.fromJson(raw.map((k, v) => MapEntry(k, v)));
      });

  @override
  Future<Result<List<MargaEntry>>> getStandardMargaList({
    SubEthnic? subEthnic,
  }) => _gw.guard(() async {
    var q = _gw.client.from('marga').select();
    if (subEthnic != null) {
      q = q.eq('sub_ethnic', subEthnic.name);
    }
    final rows = await q.order('name', ascending: true);
    return rows
        .map(
          (r) => MargaEntry(
            name: r['name'] as String,
            subEthnic: SupabaseGateway.parseSubEthnic(
              r['sub_ethnic'] as String?,
            ),
            isVerified: (r['is_verified'] as bool?) ?? true,
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<MargaEntry>> submitCustomMarga({
    required String margaName,
    required SubEthnic subEthnic,
  }) => _gw.guard(() async {
    final r = await _gw.client.rpc<Map<String, dynamic>>(
      'submit_custom_marga',
      params: <String, Object?>{
        'p_name': margaName,
        'p_sub_ethnic': subEthnic.name,
      },
    );
    return MargaEntry(
      name: r['name'] as String,
      subEthnic: SupabaseGateway.parseSubEthnic(r['sub_ethnic'] as String?),
      isVerified: (r['is_verified'] as bool?) ?? false,
    );
  });
}

/// 3. Implementasi Supabase untuk [PrivacyRepository].
final class SupabasePrivacyRepository implements PrivacyRepository {
  SupabasePrivacyRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<PrivacySettings>> getMyPrivacySettings() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final row = await _gw.client
        .from('user_privacy_settings')
        .select()
        .eq('user_id', uid)
        .single();
    return _gw.privacyFromRow(row);
  });

  @override
  Future<Result<PrivacySettings>> updateMyPrivacySettings(
    PrivacySettings settings,
  ) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final payload = _gw.privacyToRow(uid, settings);
    final row = await _gw.client
        .from('user_privacy_settings')
        .upsert(payload, onConflict: 'user_id')
        .select()
        .single();
    final updated = _gw.privacyFromRow(row);
    if (_gw.currentSessionProfile != null) {
      _gw.currentSessionProfile = _gw.currentSessionProfile!.copyWith(
        privacySettings: updated,
      );
    }
    return updated;
  });
}
