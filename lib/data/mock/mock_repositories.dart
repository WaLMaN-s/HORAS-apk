import 'dart:async';

import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/data/mock/mock_seed_data.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/partuturan/partuturan_engine.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/domain/policies/horas_policies.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:horas/domain/repositories/repositories.dart';

// ── 1. MockAuthRepository ───────────────────────────────────────────────────

final class MockAuthRepository implements AuthRepository {
  const MockAuthRepository(this._store);

  final MockStore _store;

  @override
  String? get currentUserId => _store.currentUserId;

  @override
  Future<Result<void>> sendOtp({required String phoneE164}) async {
    final net = await _store.simulateNetworkCall(checkAccountStatus: false);
    if (net.isErr) return net;

    final validPhone = HorasPolicies.validatePhoneE164(phoneE164);
    if (validPhone.isErr) return validPhone;

    final cleanPhone = phoneE164.trim();
    final existingRequests =
        _store.otpRequestTimesByPhone[cleanPhone] ?? const <DateTime>[];
    final lockedUntil = _store.otpLockedUntilByPhone[cleanPhone];

    final allowed = HorasPolicies.checkOtpSendAllowed(
      recentRequestTimes: existingRequests,
      now: _store.now,
      lockedUntil: lockedUntil,
    );
    if (allowed.isErr) return allowed;

    // AUT-R3: Nomor yang pernah diblokir permanen tidak dapat mendaftar.
    final banned = _store.usersById.values.any(
      (u) =>
          u.phoneE164 == cleanPhone &&
          u.accountStatus == AccountStatus.permanentlyBanned,
    );
    if (banned) {
      return const Err<void>(
        SuspendedError(
          message:
              'Nomor ini telah diblokir secara permanen dari layanan HORAS.',
          canAppeal: false,
        ),
      );
    }

    final updatedTimes = <DateTime>[...existingRequests, _store.now];
    _store.otpRequestTimesByPhone[cleanPhone] = updatedTimes;

    // Bagian C: OTP dev 123456 hanya bila AppConfig.env != prod.
    final otpCode = _store.appConfig.isProd ? '984321' : '123456';
    _store.issuedOtpCodeByPhone[cleanPhone] = otpCode;
    _store.issuedOtpTimeByPhone[cleanPhone] = _store.now;
    _store.otpWrongAttemptsByPhone[cleanPhone] = 0;

    return const Ok<void>(null);
  }

  @override
  Future<Result<Profil>> verifyOtp({
    required String phoneE164,
    required String otpCode,
    required String deviceName,
    required String platform,
  }) async {
    final net = await _store.simulateNetworkCall(checkAccountStatus: false);
    if (net is Err<void>) return Err<Profil>(net.failure);

    final cleanPhone = phoneE164.trim();
    final expected =
        _store.issuedOtpCodeByPhone[cleanPhone] ??
        (_store.appConfig.isProd ? '984321' : '123456');
    final issuedAt = _store.issuedOtpTimeByPhone[cleanPhone] ?? _store.now;
    final currentWrong = _store.otpWrongAttemptsByPhone[cleanPhone] ?? 0;
    final currentLock = _store.otpLockedUntilByPhone[cleanPhone];

    final eval = HorasPolicies.evaluateOtpVerification(
      inputCode: otpCode,
      expectedCode: expected,
      issuedAt: issuedAt,
      currentWrongAttempts: currentWrong,
      now: _store.now,
      currentLockedUntil: currentLock,
    );

    _store.otpWrongAttemptsByPhone[cleanPhone] = eval.wrongAttempts;
    if (eval.lockedUntil != null) {
      _store.otpLockedUntilByPhone[cleanPhone] = eval.lockedUntil!;
    } else {
      _store.otpLockedUntilByPhone.remove(cleanPhone);
    }

    if (eval.result is Err<void>) {
      return Err<Profil>((eval.result as Err<void>).failure);
    }

    // Cari pengguna dengan nomor HP ini atau buat akun baru yang belum selesai onboarding
    var user = _store.usersById.values
        .where((u) => u.phoneE164 == cleanPhone)
        .firstOrNull;
    if (user == null) {
      final newId = _store.nextId('u');
      user = Profil(
        id: newId,
        phoneE164: cleanPhone,
        displayName: 'Anggota Baru',
        gender: UserGender.male,
        birthYear: 1998,
        marga: 'Simanjuntak',
        subEthnic: SubEthnic.toba,
        city: 'Medan',
        subdistrict: 'Medan Baru',
        avatarSeed: 'avatar-$newId',
        createdAt: _store.now,
        onboardingStep: 1,
        onboardingCompleted: false,
      );
      _store.usersById[newId] = user;
    }

    // AC-12: Login dalam 30 hari membatalkan penghapusan akun; lewat 30 hari sudah terhapus.
    final pendingDeletion = _store.accountDeletionsByUser[user.id];
    if (pendingDeletion != null) {
      final evaluated = HorasPolicies.evaluateAccountDeletionOnTime(
        deletion: pendingDeletion,
        now: _store.now,
        userLoggedIn: true,
      );
      _store.accountDeletionsByUser[user.id] = evaluated;
      if (evaluated.isPermanentlyDeleted) {
        _store.usersById.remove(user.id);
        return const Err<Profil>(
          UnavailableError(
            message:
                'Akun ini telah dihapus permanen setelah masa tunggu 30 hari.',
          ),
        );
      }
    }

    // AUT-R9: Maksimal 3 perangkat aktif; login ke-4 mengeluarkan yang tertua + notifikasi keamanan
    final existingDevices = _store.devicesByUserId[user.id] ?? const <Device>[];
    final newDevice = Device(
      id: _store.nextId('dev'),
      userId: user.id,
      deviceName: deviceName,
      platform: platform,
      loggedInAt: _store.now,
      lastActiveAt: _store.now,
      isCurrent: true,
    );
    final resolved = HorasPolicies.resolveDevicesOnNewLogin(
      existingDevices: existingDevices,
      newDevice: newDevice,
    );
    _store.devicesByUserId[user.id] = resolved.activeDevices;

    if (resolved.evictedDevices.isNotEmpty) {
      _store.pushNotificationInternal(
        recipientId: user.id,
        type: NotificationType.accountSecurity,
        title: 'Perangkat Baru Masuk',
        body:
            'Login di $deviceName mengeluarkan perangkat tertua (${resolved.evictedDevices.first.deviceName}).',
        deepLink: 'horas://app/akun/keamanan',
      );
    }

    _store.currentUserId = user.id;
    await _store.persistSessionAndProfile();
    _store.notifyListeners();
    return Ok<Profil>(user);
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
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Profil>(net.failure);

    final nameCheck = HorasPolicies.validateDisplayName(displayName);
    if (nameCheck is Err<void>) return Err<Profil>(nameCheck.failure);

    // AUT-R5 & AC-02: usia minimal 17 tahun; jika di bawah 17 ditolak & data tidak disimpan.
    final ageCheck = HorasPolicies.validateOnboardingAge(
      birthYear: birthYear,
      now: _store.now,
    );
    if (ageCheck is Err<void>) {
      return Err<Profil>(ageCheck.failure);
    }

    final me = _store.activeProfile;
    if (me == null) {
      return const Err<Profil>(
        UnavailableError(message: 'Sesi pengguna tidak ditemukan.'),
      );
    }

    final isStandardMarga = _store.margas.any(
      (m) => m.name.toLowerCase() == marga.trim().toLowerCase() && m.isVerified,
    );

    final updated = me.copyWith(
      displayName: displayName.trim(),
      gender: gender,
      birthYear: birthYear,
      marga: marga.trim(),
      subEthnic: subEthnic,
      motherMarga: motherMarga?.trim(),
      city: city.trim(),
      subdistrict: subdistrict.trim(),
      hobbies: hobbies,
      campusOrOffice: campusOrOffice?.trim(),
      isMargaVerified: isStandardMarga,
      onboardingStep: 4,
      onboardingCompleted: true,
    );

    _store.usersById[updated.id] = updated;
    _store.currentSelectedCity = updated.city;
    await _store.persistSessionAndProfile();
    _store.notifyListeners();
    return Ok<Profil>(updated);
  }

  @override
  Future<Result<List<Device>>> getActiveDevices() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Device>>(net.failure);
    final uid = _store.currentUserId;
    if (uid == null) return const Ok<List<Device>>(<Device>[]);
    return Ok<List<Device>>(
      List<Device>.unmodifiable(
        _store.devicesByUserId[uid] ?? const <Device>[],
      ),
    );
  }

  @override
  Future<Result<void>> revokeDevice(String deviceId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    final uid = _store.currentUserId;
    if (uid != null) {
      _store.devicesByUserId[uid]?.removeWhere((d) => d.id == deviceId);
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> requestAccountRecovery({
    required String oldPhoneE164,
    required String newPhoneE164,
    required String proofNote,
  }) async {
    final net = await _store.simulateNetworkCall(checkAccountStatus: false);
    if (net.isErr) return net;
    final phoneCheck = HorasPolicies.validatePhoneE164(newPhoneE164);
    if (phoneCheck.isErr) return phoneCheck;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> logout() async {
    _store.currentUserId = null;
    await _store.persistSessionAndProfile();
    _store.notifyListeners();
    return const Ok<void>(null);
  }
}

// ── 2. MockProfileRepository ────────────────────────────────────────────────

final class MockProfileRepository implements ProfileRepository {
  const MockProfileRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<Profil>> getMyProfile() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Profil>(net.failure);

    final me = _store.activeProfile;
    if (me == null) {
      return const Err<Profil>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    return Ok<Profil>(me);
  }

  @override
  Future<Result<Profil>> updateMyProfile({
    String? displayName,
    String? bio,
    String? city,
    String? subdistrict,
    String? motherMarga,
    List<String>? hobbies,
    String? campusOrOffice,
    String? websiteUrl,
    String? homeChurchName,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Profil>(net.failure);

    final me = _store.activeProfile;
    if (me == null) {
      return const Err<Profil>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    DateTime? nextLastNameChange = me.lastDisplayNameChangedAt;
    if (displayName != null && displayName.trim() != me.displayName) {
      final validName = HorasPolicies.validateDisplayName(displayName);
      if (validName is Err<void>) return Err<Profil>(validName.failure);

      final cooldownCheck = HorasPolicies.checkDisplayNameChangeAllowed(
        now: _store.now,
        lastChangedAt: me.lastDisplayNameChangedAt,
      );
      if (cooldownCheck is Err<void>) return Err<Profil>(cooldownCheck.failure);
      nextLastNameChange = _store.now;
    }

    if (bio != null) {
      final validBio = HorasPolicies.validateBio(bio);
      if (validBio is Err<void>) return Err<Profil>(validBio.failure);
    }

    final updated = me.copyWith(
      displayName: displayName?.trim(),
      bio: bio?.trim(),
      city: city?.trim(),
      subdistrict: subdistrict?.trim(),
      motherMarga: motherMarga?.trim(),
      hobbies: hobbies,
      campusOrOffice: campusOrOffice?.trim(),
      websiteUrl: websiteUrl?.trim(),
      homeChurchName: homeChurchName?.trim(),
      lastDisplayNameChangedAt: nextLastNameChange,
    );

    _store.usersById[updated.id] = updated;
    await _store.persistSessionAndProfile();
    _store.notifyListeners();
    return Ok<Profil>(updated);
  }

  @override
  Future<Result<PersonSummary>> getPersonSummary(String userId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PersonSummary>(net.failure);

    final viewer = _store.activeProfile;
    final target = _store.usersById[userId];
    if (target == null ||
        (viewer != null && _store.isBlockedBetween(viewer.id, target.id))) {
      // PRD 5.2 & AC-11: Pesan netral tanpa membocorkan alasan
      return const Err<PersonSummary>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    return Ok<PersonSummary>(_store.toPersonSummary(target, viewer: viewer));
  }

  @override
  Future<Result<List<MargaEntry>>> getStandardMargaList({
    SubEthnic? subEthnic,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<MargaEntry>>(net.failure);

    final filtered = subEthnic == null
        ? _store.margas
        : _store.margas.where((m) => m.subEthnic == subEthnic).toList();
    return Ok<List<MargaEntry>>(List<MargaEntry>.unmodifiable(filtered));
  }

  @override
  Future<Result<MargaEntry>> submitCustomMarga({
    required String margaName,
    required SubEthnic subEthnic,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<MargaEntry>(net.failure);

    // AUT-R6: Marga belum ada masuk antrean verifikasi admin & tampil tanpa badge sementara.
    final entry = MargaEntry(
      name: margaName.trim(),
      subEthnic: subEthnic,
      isVerified: false,
    );
    _store.margas.add(entry);
    final me = _store.activeProfile;
    if (me != null) {
      _store.usersById[me.id] = me.copyWith(
        marga: entry.name,
        isMargaVerified: false,
      );
    }
    return Ok<MargaEntry>(entry);
  }
}

// ── 3. MockPrivacyRepository ────────────────────────────────────────────────

final class MockPrivacyRepository implements PrivacyRepository {
  const MockPrivacyRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<PrivacySettings>> getMyPrivacySettings() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PrivacySettings>(net.failure);
    return Ok<PrivacySettings>(
      _store.activeProfile?.privacySettings ?? const PrivacySettings(),
    );
  }

  @override
  Future<Result<PrivacySettings>> updateMyPrivacySettings(
    PrivacySettings settings,
  ) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PrivacySettings>(net.failure);

    final me = _store.activeProfile;
    if (me != null) {
      _store.usersById[me.id] = me.copyWith(privacySettings: settings);
      await _store.persistSessionAndProfile();
    }
    return Ok<PrivacySettings>(settings);
  }
}

// ── 4. MockFollowRepository ─────────────────────────────────────────────────

final class MockFollowRepository implements FollowRepository {
  const MockFollowRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<Follow>> followUser(String targetUserId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Follow>(net.failure);

    final me = _store.activeProfile;
    final target = _store.usersById[targetUserId];
    if (me == null ||
        target == null ||
        _store.isBlockedBetween(me.id, target.id)) {
      return const Err<Follow>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final myRecentFollows = _store.follows
        .where((f) => f.followerId == me.id)
        .map((f) => f.createdAt)
        .toList();
    final quota = HorasPolicies.checkDailyFollowQuota(
      followsLast24h: myRecentFollows,
      now: _store.now,
    );
    if (quota is Err<void>) return Err<Follow>(quota.failure);

    final isPrivate =
        target.privacySettings.accountType ==
        AccountVisibilityType.privateAccount;
    final follow = Follow(
      id: _store.nextId('fol'),
      followerId: me.id,
      followeeId: target.id,
      createdAt: _store.now,
      isPendingApproval: isPrivate,
    );
    _store.follows.removeWhere(
      (f) => f.followerId == me.id && f.followeeId == target.id,
    );
    _store.follows.add(follow);

    // PRD 9: Notifikasi pengikut baru / permintaan ikuti
    _store.pushNotificationInternal(
      recipientId: target.id,
      type: NotificationType.newFollower,
      title: isPrivate ? 'Permintaan Mengikuti Baru' : 'Pengikut Baru',
      body: '${me.displayName} mulai mengikuti akunmu.',
      deepLink: isPrivate
          ? 'horas://app/akun/kenalan'
          : 'horas://app/akun/pengikut',
    );
    return Ok<Follow>(follow);
  }

  @override
  Future<Result<void>> unfollowUser(String targetUserId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    final uid = _store.currentUserId;
    if (uid != null) {
      _store.follows.removeWhere(
        (f) => f.followerId == uid && f.followeeId == targetUserId,
      );
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<PersonSummary>>> getFollowers(String userId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PersonSummary>>(net.failure);
    if (_store.isEmptyState) {
      return const Ok<List<PersonSummary>>(<PersonSummary>[]);
    }

    final viewer = _store.activeProfile;
    final list = _store.follows
        .where((f) => f.followeeId == userId && !f.isPendingApproval)
        .map((f) => _store.usersById[f.followerId])
        .whereType<Profil>()
        .where(
          (u) => viewer == null || !_store.isBlockedBetween(viewer.id, u.id),
        )
        .map((u) => _store.toPersonSummary(u, viewer: viewer))
        .toList(growable: false);
    return Ok<List<PersonSummary>>(list);
  }

  @override
  Future<Result<List<PersonSummary>>> getFollowing(String userId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PersonSummary>>(net.failure);
    if (_store.isEmptyState) {
      return const Ok<List<PersonSummary>>(<PersonSummary>[]);
    }

    final viewer = _store.activeProfile;
    final list = _store.follows
        .where((f) => f.followerId == userId && !f.isPendingApproval)
        .map((f) => _store.usersById[f.followeeId])
        .whereType<Profil>()
        .where(
          (u) => viewer == null || !_store.isBlockedBetween(viewer.id, u.id),
        )
        .map((u) => _store.toPersonSummary(u, viewer: viewer))
        .toList(growable: false);
    return Ok<List<PersonSummary>>(list);
  }
}

// ── 5. MockConnectionRepository ─────────────────────────────────────────────

final class MockConnectionRepository implements ConnectionRepository {
  const MockConnectionRepository(this._store);

  final MockStore _store;

  void _expireOldRequests() {
    for (var i = 0; i < _store.connectionRequests.length; i++) {
      final req = _store.connectionRequests[i];
      if (req.status == ConnectionRequestStatus.pending &&
          _store.now.isAfter(req.expiresAt)) {
        _store.connectionRequests[i] = req.copyWith(
          status: ConnectionRequestStatus.expired,
          respondedAt: req.expiresAt,
        );
      }
    }
  }

  @override
  Future<Result<ConnectionRequest>> sendConnectionRequest({
    required String targetUserId,
    required String introMessage,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<ConnectionRequest>(net.failure);

    _expireOldRequests();

    final me = _store.activeProfile;
    final target = _store.usersById[targetUserId];
    if (me == null ||
        target == null ||
        _store.isBlockedBetween(me.id, target.id)) {
      return const Err<ConnectionRequest>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    // PRD 7.1: Cek siapa yang dapat mengirim Kenalan ke target
    final allowance = target.privacySettings.whoCanSendConnectionRequest;
    if (allowance == ConnectionRequestAllowance.noOne ||
        (allowance == ConnectionRequestAllowance.sameCommunity &&
            !_store.sharesCommunityOrSession(me.id, target.id))) {
      return const Err<ConnectionRequest>(
        ValidationError(
          message: 'Pengguna ini membatasi penerimaan permintaan Kenalan.',
          field: 'targetUserId',
        ),
      );
    }

    // AC-05 & SEK-R5: Cek apakah pernah ditolak atau kedaluwarsa dalam 30 hari terakhir
    DateTime? lastRejectOrExpireAt;
    for (final req in _store.connectionRequests) {
      if (req.sender.id == me.id &&
          req.receiver.id == target.id &&
          (req.status == ConnectionRequestStatus.rejected ||
              req.status == ConnectionRequestStatus.expired)) {
        final t = req.respondedAt ?? req.expiresAt;
        if (lastRejectOrExpireAt == null || t.isAfter(lastRejectOrExpireAt)) {
          lastRejectOrExpireAt = t;
        }
      }
    }

    final mySentTimes = _store.connectionRequests
        .where((r) => r.sender.id == me.id)
        .map((r) => r.createdAt)
        .toList();

    final check = HorasPolicies.validateConnectionRequest(
      introMessage: introMessage,
      requestsSentLast24h: mySentTimes,
      now: _store.now,
      lastRejectedOrExpiredWithTargetAt: lastRejectOrExpireAt,
    );
    if (check is Err<void>) return Err<ConnectionRequest>(check.failure);

    final req = ConnectionRequest(
      id: _store.nextId('creq'),
      sender: _store.toPersonSummary(me, viewer: target),
      receiver: _store.toPersonSummary(target, viewer: me),
      introMessage: introMessage.trim(),
      status: ConnectionRequestStatus.pending,
      createdAt: _store.now,
      expiresAt: HorasPolicies.connectionRequestExpiresAt(_store.now),
    );
    _store.connectionRequests.add(req);

    // PRD 9: Notifikasi permintaan Kenalan masuk ke penerima
    _store.pushNotificationInternal(
      recipientId: target.id,
      type: NotificationType.connectionRequestReceived,
      title: 'Permintaan Kenalan Masuk',
      body: '${me.displayName} (${me.marga}) mengajak berkenalan.',
      deepLink: 'horas://app/akun/kenalan',
    );
    return Ok<ConnectionRequest>(req);
  }

  @override
  Future<Result<void>> respondToConnectionRequest({
    required String requestId,
    required bool accept,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;

    _expireOldRequests();
    final idx = _store.connectionRequests.indexWhere((r) => r.id == requestId);
    if (idx < 0) {
      return const Err<void>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final req = _store.connectionRequests[idx];
    final updated = req.copyWith(
      status: accept
          ? ConnectionRequestStatus.accepted
          : ConnectionRequestStatus.rejected,
      respondedAt: _store.now,
    );
    _store.connectionRequests[idx] = updated;

    if (accept) {
      _store.connections.add(
        Connection(
          id: _store.nextId('conn'),
          userId: req.receiver.id,
          friend: req.sender,
          connectedAt: _store.now,
        ),
      );
      // PRD 9: Kenalan diterima mengirim notifikasi ke pengirim.
      // SEK-R5 & AC-05: Jika ditolak, pengirim TIDAK diberi tahu.
      _store.pushNotificationInternal(
        recipientId: req.sender.id,
        type: NotificationType.connectionAccepted,
        title: 'Permintaan Kenalan Diterima',
        body:
            '${req.receiver.displayName} menerima ajakan kenalanmu. Sekarang kalian Terhubung!',
        deepLink: 'horas://app/sekitar/profil',
      );
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> removeConnection(String targetUserId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    final uid = _store.currentUserId;
    if (uid != null) {
      // PRD 6.3: Hapus koneksi tanpa pemberitahuan
      _store.connections.removeWhere(
        (c) =>
            (c.userId == uid && c.friend.id == targetUserId) ||
            (c.userId == targetUserId && c.friend.id == uid),
      );
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Connection>>> getConnections() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Connection>>(net.failure);
    if (_store.isEmptyState) return const Ok<List<Connection>>(<Connection>[]);

    final me = _store.activeProfile;
    if (me == null) return const Ok<List<Connection>>(<Connection>[]);

    final result = <Connection>[];
    for (final c in _store.connections) {
      if (c.userId == me.id && !_store.isBlockedBetween(me.id, c.friend.id)) {
        result.add(c);
      } else if (c.friend.id == me.id &&
          !_store.isBlockedBetween(me.id, c.userId)) {
        final other = _store.usersById[c.userId];
        if (other != null) {
          result.add(
            Connection(
              id: c.id,
              userId: me.id,
              friend: _store.toPersonSummary(other, viewer: me),
              connectedAt: c.connectedAt,
            ),
          );
        }
      }
    }
    return Ok<List<Connection>>(result);
  }

  @override
  Future<Result<List<ConnectionRequest>>> getIncomingRequests() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) {
      return Err<List<ConnectionRequest>>(net.failure);
    }
    _expireOldRequests();
    if (_store.isEmptyState) {
      return const Ok<List<ConnectionRequest>>(<ConnectionRequest>[]);
    }
    final uid = _store.currentUserId;
    final list = _store.connectionRequests
        .where(
          (r) =>
              r.receiver.id == uid &&
              r.status == ConnectionRequestStatus.pending &&
              (uid == null || !_store.isBlockedBetween(uid, r.sender.id)),
        )
        .toList(growable: false);
    return Ok<List<ConnectionRequest>>(list);
  }

  @override
  Future<Result<List<ConnectionRequest>>> getOutgoingRequests() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) {
      return Err<List<ConnectionRequest>>(net.failure);
    }
    _expireOldRequests();
    if (_store.isEmptyState) {
      return const Ok<List<ConnectionRequest>>(<ConnectionRequest>[]);
    }
    final uid = _store.currentUserId;
    final list = _store.connectionRequests
        .where(
          (r) =>
              r.sender.id == uid &&
              r.status == ConnectionRequestStatus.pending &&
              (uid == null || !_store.isBlockedBetween(uid, r.receiver.id)),
        )
        .toList(growable: false);
    return Ok<List<ConnectionRequest>>(list);
  }
}

// ── 6. MockBlockRepository ──────────────────────────────────────────────────

final class MockBlockRepository implements BlockRepository {
  const MockBlockRepository(this._store);

  final MockStore _store;

  @override
  bool isBlockedBetween(String userAId, String userBId) =>
      _store.isBlockedBetween(userAId, userBId);

  @override
  Future<Result<Block>> blockUser(String targetUserId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Block>(net.failure);

    final me = _store.activeProfile;
    final target = _store.usersById[targetUserId];
    if (me == null || target == null) {
      return const Err<Block>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final block = Block(
      id: _store.nextId('blk'),
      blockerId: me.id,
      blockedUser: _store.toPersonSummary(target, viewer: me),
      createdAt: _store.now,
    );
    _store.blocks.removeWhere(
      (b) => b.blockerId == me.id && b.blockedUser.id == targetUserId,
    );
    _store.blocks.add(block);

    // AKN-R6 & AC-11: koneksi dan ikuti dihapus dua arah saat blokir
    _store.follows.removeWhere(
      (f) =>
          (f.followerId == me.id && f.followeeId == targetUserId) ||
          (f.followerId == targetUserId && f.followeeId == me.id),
    );
    _store.connections.removeWhere(
      (c) =>
          (c.userId == me.id && c.friend.id == targetUserId) ||
          (c.userId == targetUserId && c.friend.id == me.id),
    );
    _store.connectionRequests.removeWhere(
      (r) =>
          (r.sender.id == me.id && r.receiver.id == targetUserId) ||
          (r.sender.id == targetUserId && r.receiver.id == me.id),
    );
    _store.notifyListeners();
    return Ok<Block>(block);
  }

  @override
  Future<Result<void>> unblockUser(String targetUserId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    final uid = _store.currentUserId;
    if (uid != null) {
      // AKN-R6: Buka blokir tidak memulihkan hubungan sebelumnya secara otomatis
      _store.blocks.removeWhere(
        (b) => b.blockerId == uid && b.blockedUser.id == targetUserId,
      );
      _store.notifyListeners();
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Block>>> getBlockedUsers() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Block>>(net.failure);
    final uid = _store.currentUserId;
    final list = _store.blocks
        .where((b) => b.blockerId == uid)
        .toList(growable: false);
    return Ok<List<Block>>(list);
  }
}

// ── 7. MockPostRepository ───────────────────────────────────────────────────

final class MockPostRepository implements PostRepository {
  const MockPostRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<List<Post>>> getFeed() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Post>>(net.failure);
    if (_store.isEmptyState) return const Ok<List<Post>>(<Post>[]);

    final me = _store.activeProfile;
    if (me == null) return const Ok<List<Post>>(<Post>[]);

    final followedUserIds = _store.follows
        .where((f) => f.followerId == me.id && !f.isPendingApproval)
        .map((f) => f.followeeId)
        .toSet();
    final joinedCommIds = _store.communityIdsForUser(me.id);

    // BER-R1: Feed kronologis menurun dari akun yang diikuti, komunitas diikuti, dan diri sendiri.
    final visible = _store.posts.where((p) {
      if (_store.isBlockedBetween(me.id, p.author.id)) return false;
      if (p.moderationStatus == PostModerationStatus.removed) return false;
      if (p.moderationStatus == PostModerationStatus.underReview &&
          p.author.id != me.id) {
        return false; // BER-R11: sedang ditinjau hanya terlihat oleh pembuatnya
      }
      final isMine = p.author.id == me.id;
      final isFollowedAuthor = followedUserIds.contains(p.author.id);
      final isFromJoinedCommunity = p.communityIds.any(joinedCommIds.contains);
      return isMine || isFollowedAuthor || isFromJoinedCommunity;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Ok<List<Post>>(visible);
  }

  @override
  Future<Result<Post>> getPostById(String postId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Post>(net.failure);

    final me = _store.activeProfile;
    final post = _store.posts.where((p) => p.id == postId).firstOrNull;
    if (post == null ||
        post.moderationStatus == PostModerationStatus.removed ||
        (me != null && _store.isBlockedBetween(me.id, post.author.id))) {
      return const Err<Post>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    return Ok<Post>(post);
  }

  @override
  Future<Result<List<Post>>> getUserPosts(String userId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Post>>(net.failure);
    if (_store.isEmptyState) return const Ok<List<Post>>(<Post>[]);

    final me = _store.activeProfile;
    if (me != null && _store.isBlockedBetween(me.id, userId)) {
      return const Err<List<Post>>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final list = _store.posts.where((p) => p.author.id == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Ok<List<Post>>(list);
  }

  @override
  Future<Result<List<SavedPost>>> getSavedPosts() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<SavedPost>>(net.failure);
    if (_store.isEmptyState) return const Ok<List<SavedPost>>(<SavedPost>[]);

    final uid = _store.currentUserId;
    final list = _store.savedPosts
        .where(
          (s) =>
              s.userId == uid &&
              (uid == null || !_store.isBlockedBetween(uid, s.post.author.id)),
        )
        .toList(growable: false);
    return Ok<List<SavedPost>>(list);
  }

  @override
  Future<Result<Post>> createPost({
    required String text,
    required PostVisibility visibility,
    List<String> mediaSeeds = const <String>[],
    List<int> mediaSizesBytes = const <int>[],
    List<Map<String, String>> rawExifPerMedia = const <Map<String, String>>[],
    List<String> communityIds = const <String>[],
    String? cityTag,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Post>(net.failure);

    final me = _store.activeProfile;
    if (me == null) {
      return const Err<Post>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final myRecentPosts = _store.posts
        .where((p) => p.author.id == me.id)
        .map((p) => p.createdAt)
        .toList();

    final validation = HorasPolicies.validatePostCreation(
      text: text,
      photoCount: mediaSeeds.length,
      photoSizesBytes: mediaSizesBytes,
      postsLast24h: myRecentPosts,
      accountCreatedAt: me.createdAt,
      now: _store.now,
    );
    if (validation is Err<PostModerationStatus>) {
      return Err<Post>(validation.failure);
    }
    final modStatus = (validation as Ok<PostModerationStatus>).value;

    final postId = _store.nextId('post');

    // BER-R4 & AC-10: Hapus seluruh metadata lokasi EXIF dari setiap foto di "server"
    const forbiddenExifKeys = <String>{
      'gpslatitude',
      'gpslongitude',
      'gpsaltitude',
      'gpstimestamp',
      'location',
      'coordinates',
      'latitude',
      'longitude',
    };
    final mediaItems = <PostMedia>[];
    for (var i = 0; i < mediaSeeds.length; i++) {
      final rawExif = i < rawExifPerMedia.length
          ? rawExifPerMedia[i]
          : const <String, String>{};
      final sanitizedMetadata = <String, String>{
        for (final entry in rawExif.entries)
          if (!forbiddenExifKeys.contains(entry.key.toLowerCase()))
            entry.key: entry.value,
      };
      mediaItems.add(
        PostMedia(
          id: '$postId-m$i',
          postId: postId,
          seed: mediaSeeds[i],
          orderIndex: i,
          exifLocationStripped: true,
          metadata: Map<String, String>.unmodifiable(sanitizedMetadata),
        ),
      );
    }

    final post = Post(
      id: postId,
      author: _store.toPersonSummary(me),
      text: text.trim(),
      media: mediaItems,
      visibility: visibility,
      communityIds: communityIds,
      cityTag: cityTag?.trim(),
      moderationStatus: modStatus,
      createdAt: _store.now,
    );
    _store.posts.insert(0, post);
    return Ok<Post>(post);
  }

  @override
  Future<Result<Post>> editPostText({
    required String postId,
    required String newText,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Post>(net.failure);

    final idx = _store.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) {
      return const Err<Post>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final clean = newText.trim();
    if (clean.length > AppLimits.postTextMaxChars) {
      return const Err<Post>(
        ValidationError(
          message: 'Teks postingan maksimal 2.000 karakter.',
          field: 'text',
        ),
      );
    }
    // BER-R7: Edit hanya teks, dengan label Diedit.
    final updated = _store.posts[idx].copyWith(
      text: clean,
      isEdited: true,
      updatedAt: _store.now,
    );
    _store.posts[idx] = updated;
    return Ok<Post>(updated);
  }

  @override
  Future<Result<void>> deletePost(String postId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;

    // BER-R8: Hapus postingan bersifat langsung; komentar ikut terhapus.
    _store.posts.removeWhere((p) => p.id == postId);
    _store.comments.removeWhere((c) => c.postId == postId);
    _store.likes.removeWhere((l) => l.postId == postId);
    _store.savedPosts.removeWhere((s) => s.post.id == postId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<Post>> toggleLike(String postId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Post>(net.failure);

    final me = _store.activeProfile;
    final idx = _store.posts.indexWhere((p) => p.id == postId);
    if (me == null || idx < 0) {
      return const Err<Post>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final post = _store.posts[idx];
    final existingIdx = _store.likes.indexWhere(
      (l) => l.postId == postId && l.user.id == me.id,
    );
    final bool nowLiked;
    if (existingIdx >= 0) {
      _store.likes.removeAt(existingIdx);
      nowLiked = false;
    } else {
      // BER-R6: Satu suka per pengguna per postingan
      _store.likes.add(
        Like(
          id: _store.nextId('like'),
          postId: postId,
          user: _store.toPersonSummary(me),
          createdAt: _store.now,
        ),
      );
      nowLiked = true;
      if (post.author.id != me.id) {
        _store.pushNotificationInternal(
          recipientId: post.author.id,
          type: NotificationType.postLikedOrCommented,
          title: 'Suka Baru pada Postinganmu',
          body: '${me.displayName} menyukai postinganmu.',
          deepLink: 'horas://app/beranda/postingan-detail',
        );
      }
    }

    final updated = post.copyWith(
      likeCount: nowLiked
          ? post.likeCount + 1
          : (post.likeCount - 1).clamp(0, 999999),
      isLikedByMe: nowLiked,
    );
    _store.posts[idx] = updated;
    return Ok<Post>(updated);
  }

  @override
  Future<Result<List<Like>>> getPostLikes(String postId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Like>>(net.failure);

    final me = _store.activeProfile;
    // BER-R6: Daftar suka tidak menampilkan akun yang saling memblokir dengan pelihat.
    final list = _store.likes
        .where(
          (l) =>
              l.postId == postId &&
              (me == null || !_store.isBlockedBetween(me.id, l.user.id)),
        )
        .toList(growable: false);
    return Ok<List<Like>>(list);
  }

  @override
  Future<Result<Post>> toggleSavePost(String postId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Post>(net.failure);

    final me = _store.activeProfile;
    final idx = _store.posts.indexWhere((p) => p.id == postId);
    if (me == null || idx < 0) {
      return const Err<Post>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final post = _store.posts[idx];
    final existingIdx = _store.savedPosts.indexWhere(
      (s) => s.post.id == postId && s.userId == me.id,
    );
    final bool nowSaved;
    if (existingIdx >= 0) {
      _store.savedPosts.removeAt(existingIdx);
      nowSaved = false;
    } else {
      _store.savedPosts.insert(
        0,
        SavedPost(
          id: _store.nextId('sav'),
          userId: me.id,
          post: post.copyWith(isSavedByMe: true),
          savedAt: _store.now,
        ),
      );
      nowSaved = true;
    }
    final updated = post.copyWith(isSavedByMe: nowSaved);
    _store.posts[idx] = updated;
    return Ok<Post>(updated);
  }
}

// ── 8. MockCommentRepository ────────────────────────────────────────────────

final class MockCommentRepository implements CommentRepository {
  const MockCommentRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<List<Comment>>> getComments(String postId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Comment>>(net.failure);
    if (_store.isEmptyState) return const Ok<List<Comment>>(<Comment>[]);

    final me = _store.activeProfile;
    final list = _store.comments
        .where(
          (c) =>
              c.postId == postId &&
              (me == null || !_store.isBlockedBetween(me.id, c.author.id)),
        )
        .toList(growable: false);
    return Ok<List<Comment>>(list);
  }

  @override
  Future<Result<Comment>> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Comment>(net.failure);

    final me = _store.activeProfile;
    final postIdx = _store.posts.indexWhere((p) => p.id == postId);
    if (me == null || postIdx < 0) {
      return const Err<Comment>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final post = _store.posts[postIdx];
    if (post.commentsDisabled) {
      return const Err<Comment>(
        ValidationError(
          message: 'Komentar pada postingan ini telah dinonaktifkan oleh pembuatnya.',
          field: 'postId',
        ),
      );
    }

    final recentTimes =
        _store.commentTimestampsByUser[me.id] ?? const <DateTime>[];
    final check = HorasPolicies.validateCommentCreation(
      text: text,
      commentsLastHour: recentTimes,
      now: _store.now,
    );
    if (check is Err<void>) return Err<Comment>(check.failure);

    _store.commentTimestampsByUser[me.id] = <DateTime>[
      ...recentTimes,
      _store.now,
    ];

    final comment = Comment(
      id: _store.nextId('cmt'),
      postId: postId,
      parentCommentId: parentCommentId,
      author: _store.toPersonSummary(me),
      text: text.trim(),
      createdAt: _store.now,
    );
    _store.comments.add(comment);
    _store.posts[postIdx] = post.copyWith(commentCount: post.commentCount + 1);

    if (post.author.id != me.id) {
      _store.pushNotificationInternal(
        recipientId: post.author.id,
        type: NotificationType.postLikedOrCommented,
        title: 'Komentar Baru',
        body: '${me.displayName} mengomentari postinganmu.',
        deepLink: 'horas://app/beranda/komentar',
      );
    }
    return Ok<Comment>(comment);
  }

  @override
  Future<Result<void>> deleteComment(String commentId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    _store.comments.removeWhere(
      (c) => c.id == commentId || c.parentCommentId == commentId,
    );
    return const Ok<void>(null);
  }

  @override
  Future<Result<Post>> setCommentsDisabled({
    required String postId,
    required bool disabled,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Post>(net.failure);
    final idx = _store.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) {
      return const Err<Post>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final updated = _store.posts[idx].copyWith(commentsDisabled: disabled);
    _store.posts[idx] = updated;
    return Ok<Post>(updated);
  }
}

// ── 9. MockSearchRepository ─────────────────────────────────────────────────

final class MockSearchRepository implements SearchRepository {
  const MockSearchRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<List<PersonSummary>>> searchPeople({
    required String query,
    String? city,
    String? marga,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PersonSummary>>(net.failure);
    if (_store.isEmptyState) {
      return const Ok<List<PersonSummary>>(<PersonSummary>[]);
    }

    final me = _store.activeProfile;
    final q = query.trim().toLowerCase();
    final results = <PersonSummary>[];

    for (final u in _store.usersById.values) {
      if (me != null && _store.isBlockedBetween(me.id, u.id)) {
        continue; // AC-11
      }
      // BER-R13: Pengguna bermode tersembunyi tidak muncul di pencarian kecuali bagi yang sudah terhubung.
      if (!u.privacySettings.discoverableInNearbyAndSearch &&
          (me == null || !_store.isConnectedBetween(me.id, u.id))) {
        continue;
      }
      if (city != null &&
          city.isNotEmpty &&
          u.city.toLowerCase() != city.toLowerCase()) {
        continue;
      }
      if (marga != null &&
          marga.isNotEmpty &&
          u.marga.toLowerCase() != marga.toLowerCase()) {
        continue;
      }
      if (q.isNotEmpty &&
          !u.displayName.toLowerCase().contains(q) &&
          !u.marga.toLowerCase().contains(q)) {
        continue;
      }
      results.add(_store.toPersonSummary(u, viewer: me));
    }
    return Ok<List<PersonSummary>>(results);
  }

  @override
  Future<Result<List<Community>>> searchCommunities({
    required String query,
    String? city,
    CommunityType? type,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Community>>(net.failure);
    if (_store.isEmptyState) return const Ok<List<Community>>(<Community>[]);

    final uid = _store.currentUserId;
    final myComms = uid != null ? _store.communityIdsForUser(uid) : <String>{};
    final q = query.trim().toLowerCase();

    final results = _store.communities
        .where((c) {
          // SEK-R7 & AC-13: Komunitas Tertutup tidak muncul di pencarian bagi non-anggota.
          if (c.accessType == CommunityAccessType.closed &&
              !myComms.contains(c.id)) {
            return false;
          }
          if (city != null &&
              city.isNotEmpty &&
              c.city.toLowerCase() != city.toLowerCase()) {
            return false;
          }
          if (type != null && c.type != type) {
            return false;
          }
          if (q.isNotEmpty &&
              !c.name.toLowerCase().contains(q) &&
              !c.city.toLowerCase().contains(q)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return Ok<List<Community>>(results);
  }
}

// ── 10. MockNearbyRepository ────────────────────────────────────────────────

final class MockNearbyRepository implements NearbyRepository {
  const MockNearbyRepository(this._store);

  final MockStore _store;

  @override
  String get currentSelectedCity => _store.currentSelectedCity;

  @override
  void setCurrentSelectedCity(String city) {
    _store.currentSelectedCity = city.trim();
  }

  @override
  Future<Result<List<WilayahCity>>> getAvailableCities() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<WilayahCity>>(net.failure);
    return Ok<List<WilayahCity>>(List<WilayahCity>.unmodifiable(_store.cities));
  }

  @override
  Future<Result<List<PersonSummary>>> getNearbyPeople({
    String? city,
    String? marga,
    String? hobby,
    String? campusOrOffice,
    int page = 1,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PersonSummary>>(net.failure);
    if (_store.isEmptyState) {
      return const Ok<List<PersonSummary>>(<PersonSummary>[]);
    }

    final me = _store.activeProfile;
    final targetCity = (city ?? _store.currentSelectedCity).trim();

    final candidates = <PersonSummary>[];
    for (final u in _store.usersById.values) {
      if (me != null && u.id == me.id) continue;
      if (me != null && _store.isBlockedBetween(me.id, u.id)) continue; // AC-11
      if (!u.privacySettings.discoverableInNearbyAndSearch) continue; // SEK-R3
      if (targetCity.isNotEmpty &&
          u.city.toLowerCase() != targetCity.toLowerCase()) {
        continue;
      }
      if (marga != null &&
          marga.isNotEmpty &&
          u.marga.toLowerCase() != marga.toLowerCase()) {
        continue;
      }
      if (hobby != null &&
          hobby.isNotEmpty &&
          !u.hobbies.any((h) => h.toLowerCase() == hobby.toLowerCase())) {
        continue;
      }
      if (campusOrOffice != null &&
          campusOrOffice.isNotEmpty &&
          !(u.campusOrOffice ?? '').toLowerCase().contains(
            campusOrOffice.toLowerCase(),
          )) {
        continue;
      }
      candidates.add(_store.toPersonSummary(u, viewer: me));
    }

    // SEK-R1: Urutan: kerabat (keyakinan tinggi/sedang), komunitas sama, hobi sama
    int kinshipRank(PersonSummary p) {
      final part = p.partuturan;
      if (part == null || part.modeNetral) return 0;
      return switch (part.confidence) {
        PartuturanConfidence.tinggi => 3,
        PartuturanConfidence.sedang => 2,
        PartuturanConfidence.rendah => 1,
      };
    }

    candidates.sort((a, b) {
      final kDiff = kinshipRank(b).compareTo(kinshipRank(a));
      if (kDiff != 0) return kDiff;
      return b.sharedCommunitiesCount.compareTo(a.sharedCommunitiesCount);
    });

    final start = ((page - 1) * AppLimits.nearbyPageSize).clamp(
      0,
      candidates.length,
    );
    final end = (start + AppLimits.nearbyPageSize).clamp(0, candidates.length);
    return Ok<List<PersonSummary>>(candidates.sublist(start, end));
  }
}

// ── 11. MockCommunityRepository ─────────────────────────────────────────────

final class MockCommunityRepository implements CommunityRepository {
  const MockCommunityRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<List<Community>>> getCommunities({
    String? city,
    CommunityType? type,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Community>>(net.failure);
    if (_store.isEmptyState) return const Ok<List<Community>>(<Community>[]);

    final uid = _store.currentUserId;
    final myComms = uid != null ? _store.communityIdsForUser(uid) : <String>{};

    final list = _store.communities
        .where((c) {
          // AC-13: Komunitas Tertutup tidak muncul bagi non-anggota.
          if (c.accessType == CommunityAccessType.closed &&
              !myComms.contains(c.id)) {
            return false;
          }
          if (city != null &&
              city.isNotEmpty &&
              c.city.toLowerCase() != city.toLowerCase()) {
            return false;
          }
          if (type != null && c.type != type) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return Ok<List<Community>>(list);
  }

  @override
  Future<Result<Community>> getCommunityById(String communityId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Community>(net.failure);

    final comm = _store.communities
        .where((c) => c.id == communityId)
        .firstOrNull;
    if (comm == null) {
      return const Err<Community>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final uid = _store.currentUserId;
    final isMember =
        uid != null && _store.communityIdsForUser(uid).contains(communityId);
    if (comm.accessType == CommunityAccessType.closed && !isMember) {
      return const Err<Community>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    return Ok<Community>(comm);
  }

  @override
  Future<Result<Community>> createCommunity({
    required String name,
    required CommunityType type,
    required CommunityAccessType accessType,
    required String city,
    required String description,
    String? margaName,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Community>(net.failure);

    final me = _store.activeProfile;
    if (me == null) {
      return const Err<Community>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final ownedCount = _store.communities
        .where((c) => c.ownerId == me.id)
        .length;

    final check = HorasPolicies.validateCommunityCreation(
      name: name,
      description: description,
      accountCreatedAt: me.createdAt,
      ownedCommunitiesCount: ownedCount,
      now: _store.now,
    );
    if (check is Err<void>) return Err<Community>(check.failure);

    // SEK-R7: Nama unik per jenis dan kota
    final duplicate = _store.communities.any(
      (c) =>
          c.type == type &&
          c.city.toLowerCase() == city.trim().toLowerCase() &&
          c.name.toLowerCase() == name.trim().toLowerCase(),
    );
    if (duplicate) {
      return const Err<Community>(
        ValidationError(
          message: 'Komunitas dengan nama, jenis, dan kota yang sama sudah terdaftar.',
          field: 'name',
        ),
      );
    }

    final commId = _store.nextId('com');
    final convId = 'conv-$commId';
    final comm = Community(
      id: commId,
      name: name.trim(),
      type: type,
      accessType: accessType,
      city: city.trim(),
      margaName: margaName?.trim(),
      description: description.trim(),
      avatarSeed: 'com-seed-$commId',
      ownerId: me.id,
      memberCount: 1,
      isVerified: false, // SEK-R9: Belum diverifikasi saat dibuat
      conversationId: convId,
      createdAt: _store.now,
      lastManagerActiveAt: _store.now,
    );
    _store.communities.add(comm);

    final meSummary = _store.toPersonSummary(me);
    _store.memberships.add(
      Membership(
        id: 'mem-$commId-${me.id}',
        communityId: commId,
        user: meSummary,
        role: CommunityRole.owner,
        joinedAt: _store.now,
      ),
    );

    // SEK-R11: Chat grup komunitas dibuat otomatis
    _store.conversations.add(
      Conversation(
        id: convId,
        type: ConversationType.communityGroup,
        title: comm.name,
        communityId: commId,
        participants: <PersonSummary>[meSummary],
        updatedAt: _store.now,
      ),
    );
    return Ok<Community>(comm);
  }

  @override
  Future<Result<JoinRequest?>> joinCommunity(String communityId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<JoinRequest?>(net.failure);

    final me = _store.activeProfile;
    final idx = _store.communities.indexWhere((c) => c.id == communityId);
    if (me == null || idx < 0) {
      return const Err<JoinRequest?>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final comm = _store.communities[idx];
    if (comm.accessType == CommunityAccessType.closed) {
      return const Err<JoinRequest?>(
        ValidationError(
          message:
              'Komunitas ini tertutup dan hanya dapat diikuti lewat undangan.',
          field: 'communityId',
        ),
      );
    }

    final meSummary = _store.toPersonSummary(me);
    if (comm.accessType == CommunityAccessType.open) {
      // SEK-R11: Gabung langsung & otomatis masuk ke chat grup komunitas
      _store.memberships.removeWhere(
        (m) => m.communityId == communityId && m.user.id == me.id,
      );
      _store.memberships.add(
        Membership(
          id: _store.nextId('mem'),
          communityId: communityId,
          user: meSummary,
          role: CommunityRole.member,
          joinedAt: _store.now,
        ),
      );
      _store.communities[idx] = comm.copyWith(
        memberCount: comm.memberCount + 1,
      );
      _addMemberToCommunityChat(comm.id, meSummary);
      return const Ok<JoinRequest?>(null);
    }

    // Dengan persetujuan: kedaluwarsa 14 hari (SEK-R11)
    final joinReq = JoinRequest(
      id: _store.nextId('jreq'),
      communityId: communityId,
      applicant: meSummary,
      status: JoinRequestStatus.pending,
      createdAt: _store.now,
      expiresAt: HorasPolicies.communityJoinRequestExpiresAt(_store.now),
    );
    _store.joinRequests.add(joinReq);

    // PRD 9: Notifikasi permintaan gabung ke Pengurus/Owner
    _store.pushNotificationInternal(
      recipientId: comm.ownerId,
      type: NotificationType.communityJoinRequest,
      title: 'Permintaan Gabung Komunitas',
      body: '${me.displayName} meminta bergabung ke ${comm.name}.',
      deepLink: 'horas://app/sekitar/komunitas-kelola',
    );
    return Ok<JoinRequest?>(joinReq);
  }

  void _addMemberToCommunityChat(String communityId, PersonSummary user) {
    final convIdx = _store.conversations.indexWhere(
      (c) => c.communityId == communityId,
    );
    if (convIdx >= 0) {
      final conv = _store.conversations[convIdx];
      if (!conv.participants.any((p) => p.id == user.id)) {
        _store.conversations[convIdx] = conv.copyWith(
          participants: <PersonSummary>[...conv.participants, user],
        );
      }
    }
  }

  @override
  Future<Result<void>> leaveCommunity(String communityId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;

    final uid = _store.currentUserId;
    final idx = _store.communities.indexWhere((c) => c.id == communityId);
    if (uid == null || idx < 0) return const Ok<void>(null);

    final comm = _store.communities[idx];
    // SEK-R8: Pemilik tidak dapat keluar sebelum menyerahkan kepemilikan.
    if (comm.ownerId == uid) {
      return const Err<void>(
        ValidationError(
          message: 'Pemilik komunitas harus menyerahkan kepemilikan kepada pengurus lain sebelum keluar.',
          field: 'ownerId',
        ),
      );
    }

    _store.memberships.removeWhere(
      (m) => m.communityId == communityId && m.user.id == uid,
    );
    _store.communities[idx] = comm.copyWith(
      memberCount: (comm.memberCount - 1).clamp(1, 999999),
    );
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Membership>>> getMembers(String communityId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Membership>>(net.failure);

    final comm = _store.communities
        .where((c) => c.id == communityId)
        .firstOrNull;
    if (comm == null) {
      return const Err<List<Membership>>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final uid = _store.currentUserId;
    final isMember =
        uid != null && _store.communityIdsForUser(uid).contains(communityId);
    // SEK-R10 & AC-13: Pada komunitas Tertutup hanya anggota yang dapat melihat daftar anggota.
    if (comm.accessType == CommunityAccessType.closed && !isMember) {
      return const Err<List<Membership>>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final me = _store.activeProfile;
    final list = _store.memberships
        .where((m) => m.communityId == communityId)
        .map((m) {
          final targetProfile = _store.usersById[m.user.id];
          if (targetProfile == null) return m;
          return m.copyWith(
            user: _store.toPersonSummary(targetProfile, viewer: me),
          );
        })
        .toList(growable: false);
    return Ok<List<Membership>>(list);
  }

  @override
  Future<Result<List<JoinRequest>>> getPendingJoinRequests(
    String communityId,
  ) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<JoinRequest>>(net.failure);

    final list = _store.joinRequests
        .where(
          (r) =>
              r.communityId == communityId &&
              r.status == JoinRequestStatus.pending &&
              _store.now.isBefore(r.expiresAt),
        )
        .toList(growable: false);
    return Ok<List<JoinRequest>>(list);
  }

  @override
  Future<Result<void>> respondJoinRequest({
    required String joinRequestId,
    required bool approve,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;

    final idx = _store.joinRequests.indexWhere((r) => r.id == joinRequestId);
    if (idx < 0) return const Ok<void>(null);

    final req = _store.joinRequests[idx];
    if (_store.now.isAfter(req.expiresAt)) {
      _store.joinRequests[idx] = req.copyWith(
        status: JoinRequestStatus.expired,
      );
      return const Err<void>(
        ValidationError(
          message: 'Permintaan gabung ini sudah kedaluwarsa (lewat 14 hari).',
          field: 'joinRequestId',
        ),
      );
    }

    _store.joinRequests[idx] = req.copyWith(
      status: approve ? JoinRequestStatus.approved : JoinRequestStatus.rejected,
    );

    if (approve) {
      _store.memberships.add(
        Membership(
          id: _store.nextId('mem'),
          communityId: req.communityId,
          user: req.applicant,
          role: CommunityRole.member,
          joinedAt: _store.now,
        ),
      );
      final cIdx = _store.communities.indexWhere(
        (c) => c.id == req.communityId,
      );
      if (cIdx >= 0) {
        final comm = _store.communities[cIdx];
        _store.communities[cIdx] = comm.copyWith(
          memberCount: comm.memberCount + 1,
          lastManagerActiveAt: _store.now,
        );
        _addMemberToCommunityChat(comm.id, req.applicant);
        // PRD 9: Persetujuan gabung komunitas
        _store.pushNotificationInternal(
          recipientId: req.applicant.id,
          type: NotificationType.communityJoinApproved,
          title: 'Permintaan Gabung Disetujui',
          body: 'Selamat datang di ${comm.name}!',
          deepLink: 'horas://app/sekitar/komunitas-detail',
        );
      }
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> setMemberRole({
    required String communityId,
    required String targetUserId,
    required CommunityRole role,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;

    final cIdx = _store.communities.indexWhere((c) => c.id == communityId);
    if (cIdx < 0) return const Ok<void>(null);
    final comm = _store.communities[cIdx];

    if (role == CommunityRole.manager &&
        !comm.managerIds.contains(targetUserId)) {
      final limitCheck = HorasPolicies.checkCommunityManagerLimit(
        comm.managerIds.length,
      );
      if (limitCheck.isErr) return limitCheck;
      _store.communities[cIdx] = comm.copyWith(
        managerIds: <String>[...comm.managerIds, targetUserId],
      );
    }

    final mIdx = _store.memberships.indexWhere(
      (m) => m.communityId == communityId && m.user.id == targetUserId,
    );
    if (mIdx >= 0) {
      _store.memberships[mIdx] = _store.memberships[mIdx].copyWith(role: role);
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<Announcement>> createAnnouncement({
    required String communityId,
    required String title,
    required String body,
    bool isPinned = false,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Announcement>(net.failure);

    final me = _store.activeProfile;
    if (me == null) {
      return const Err<Announcement>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    if (isPinned) {
      final pinnedCount = _store.announcements
          .where((a) => a.communityId == communityId && a.isPinned)
          .length;
      final pinCheck = HorasPolicies.checkPinnedAnnouncementLimit(pinnedCount);
      if (pinCheck is Err<void>) return Err<Announcement>(pinCheck.failure);
    }

    final ann = Announcement(
      id: _store.nextId('ann'),
      communityId: communityId,
      author: _store.toPersonSummary(me),
      title: title.trim(),
      body: body.trim(),
      isPinned: isPinned,
      createdAt: _store.now,
    );
    _store.announcements.insert(0, ann);

    // PRD 9: Pengumuman komunitas mengirim notifikasi ke anggota
    for (final m in _store.memberships.where(
      (m) => m.communityId == communityId && m.user.id != me.id,
    )) {
      _store.pushNotificationInternal(
        recipientId: m.user.id,
        type: NotificationType.communityAnnouncement,
        title: title.trim(),
        body: body.trim(),
        deepLink: 'horas://app/sekitar/komunitas-detail',
      );
    }
    return Ok<Announcement>(ann);
  }

  @override
  Future<Result<List<Announcement>>> getAnnouncements(
    String communityId,
  ) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Announcement>>(net.failure);
    final list = _store.announcements
        .where((a) => a.communityId == communityId)
        .toList(growable: false);
    return Ok<List<Announcement>>(list);
  }

  @override
  Future<Result<Community>> transferOwnership({
    required String communityId,
    required String newOwnerUserId,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Community>(net.failure);

    final cIdx = _store.communities.indexWhere((c) => c.id == communityId);
    if (cIdx < 0) {
      return const Err<Community>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final updated = _store.communities[cIdx].copyWith(ownerId: newOwnerUserId);
    _store.communities[cIdx] = updated;
    return Ok<Community>(updated);
  }
}

// ── 12. MockSessionRepository ───────────────────────────────────────────────

final class MockSessionRepository implements SessionRepository {
  const MockSessionRepository(this._store);

  final MockStore _store;

  void _refreshCompletedSessions() {
    for (var i = 0; i < _store.sessions.length; i++) {
      final s = _store.sessions[i];
      // MAN-R9: Sesi otomatis berstatus Selesai 2 jam setelah waktu selesai.
      if (s.status == SessionStatus.upcoming &&
          _store.now.isAfter(s.endTime.add(const Duration(hours: 2)))) {
        _store.sessions[i] = s.copyWith(status: SessionStatus.completed);
      }
      // MAN-R9: Chat sesi menjadi baca-saja 24 jam setelah selesai.
      if (s.conversationId != null &&
          _store.now.isAfter(s.endTime.add(const Duration(hours: 24)))) {
        final convIdx = _store.conversations.indexWhere(
          (c) => c.id == s.conversationId,
        );
        if (convIdx >= 0 && !_store.conversations[convIdx].isReadOnly) {
          _store.conversations[convIdx] = _store.conversations[convIdx]
              .copyWith(isReadOnly: true);
        }
      }
    }
  }

  @override
  Future<Result<List<PlaySession>>> getSessions({
    String? city,
    SportType? sportType,
    SkillLevel? skillLevel,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PlaySession>>(net.failure);
    _refreshCompletedSessions();
    if (_store.isEmptyState) {
      return const Ok<List<PlaySession>>(<PlaySession>[]);
    }

    final list = _store.sessions
        .where((s) {
          if (city != null &&
              city.isNotEmpty &&
              s.city.toLowerCase() != city.toLowerCase()) {
            return false;
          }
          if (sportType != null && s.sportType != sportType) return false;
          if (skillLevel != null && s.skillLevel != skillLevel) return false;
          return true;
        })
        .toList(growable: false);
    return Ok<List<PlaySession>>(list);
  }

  @override
  Future<Result<PlaySession>> getSessionById(String sessionId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PlaySession>(net.failure);
    _refreshCompletedSessions();

    final s = _store.sessions.where((s) => s.id == sessionId).firstOrNull;
    if (s == null) {
      return const Err<PlaySession>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    return Ok<PlaySession>(s);
  }

  @override
  Future<Result<PlaySession>> createSession({
    required SportType sportType,
    required String title,
    required String city,
    required DateTime startTime,
    required DateTime endTime,
    required int maxSlots,
    required SkillLevel skillLevel,
    required int feePerPersonRupiah,
    required SessionVisibility visibility,
    required SessionJoinMode joinMode,
    String? courtId,
    String? manualLocationSummary,
    String? manualLocationFullDetail,
    String notes = '',
    String? communityId,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PlaySession>(net.failure);
    _refreshCompletedSessions();

    final me = _store.activeProfile;
    if (me == null || !me.onboardingCompleted) {
      return const Err<PlaySession>(
        ValidationError(
          message:
              'Pembuat sesi harus menyelesaikan onboarding terlebih dahulu.',
          field: 'host',
        ),
      );
    }

    final activeHosted = _store.sessions
        .where((s) => s.host.id == me.id && s.status == SessionStatus.upcoming)
        .length;

    final check = HorasPolicies.validateSessionCreation(
      title: title,
      startTime: startTime,
      endTime: endTime,
      maxSlots: maxSlots,
      feePerPersonRupiah: feePerPersonRupiah,
      notes: notes,
      activeHostedSessionsCount: activeHosted,
      now: _store.now,
    );
    if (check is Err<void>) return Err<PlaySession>(check.failure);

    final sessionId = _store.nextId('ses');
    final convId = 'conv-$sessionId';
    final court = courtId != null
        ? _store.courts.where((c) => c.id == courtId).firstOrNull
        : null;
    final hostSummary = _store.toPersonSummary(me);

    final roundedFee = HorasPolicies.calculatePatunganPerPerson(
      totalRupiah: feePerPersonRupiah,
      participantCount: 1,
    );

    final session = PlaySession(
      id: sessionId,
      host: hostSummary,
      sportType: sportType,
      title: title.trim().isEmpty ? sportType.label : title.trim(),
      courtId: court?.id,
      courtName: court?.name,
      manualLocationSummary: manualLocationSummary?.trim(),
      manualLocationFullDetail: manualLocationFullDetail?.trim(),
      city: city.trim(),
      startTime: startTime,
      endTime: endTime,
      maxSlots: maxSlots,
      skillLevel: skillLevel,
      feePerPersonRupiah: roundedFee,
      notes: notes.trim(),
      visibility: visibility,
      communityId: communityId,
      joinMode: joinMode,
      isJoinedByMe: true,
      conversationId: convId,
      createdAt: _store.now,
    );
    _store.sessions.insert(0, session);

    _store.participants.add(
      Participant(
        id: 'part-$sessionId-${me.id}',
        sessionId: sessionId,
        user: hostSummary,
        status: ParticipantStatus.joined,
        joinedAt: _store.now,
      ),
    );
    _store.paymentShares.add(
      PaymentShare(
        id: 'pay-$sessionId-${me.id}',
        sessionId: sessionId,
        participant: hostSummary,
        amountRupiah: roundedFee,
        participantMarkedPaid: true,
        hostConfirmedPaid: true,
        updatedAt: _store.now,
      ),
    );

    // MAN-R9: Chat sesi dibuat otomatis
    _store.conversations.add(
      Conversation(
        id: convId,
        type: ConversationType.sessionGroup,
        title: session.title,
        sessionId: sessionId,
        participants: <PersonSummary>[hostSummary],
        updatedAt: _store.now,
      ),
    );

    return Ok<PlaySession>(session);
  }

  @override
  Future<Result<PlaySession>> cancelSession(String sessionId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PlaySession>(net.failure);

    final idx = _store.sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) {
      return const Err<PlaySession>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final session = _store.sessions[idx];
    final updated = session.copyWith(status: SessionStatus.cancelled);
    _store.sessions[idx] = updated;

    // PRD 9 & MAN-R5: Sesi dibatalkan memberi notifikasi wajib ke peserta
    for (final p in _store.participants.where(
      (p) => p.sessionId == sessionId && p.user.id != session.host.id,
    )) {
      _store.pushNotificationInternal(
        recipientId: p.user.id,
        type: NotificationType.sessionUpdatedOrCancelled,
        title: 'Sesi Dibatalkan',
        body: 'Sesi ${session.title} telah dibatalkan oleh host.',
        deepLink: 'horas://app/main/sesi-detail',
      );
    }
    return Ok<PlaySession>(updated);
  }

  @override
  Future<Result<({Participant? participant, WaitlistEntry? waitlist})>>
  joinSession(String sessionId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) {
      return Err<({Participant? participant, WaitlistEntry? waitlist})>(
        net.failure,
      );
    }

    final me = _store.activeProfile;
    final idx = _store.sessions.indexWhere((s) => s.id == sessionId);
    if (me == null || idx < 0) {
      return const Err<({Participant? participant, WaitlistEntry? waitlist})>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    // MAN-R4: Cek pembatasan keandalan (3 catatan dalam 30 hari = 7 hari tidak bisa gabung)
    final myMarks = _store.reliabilityMarks
        .where((m) => m.userId == me.id)
        .toList();
    final reliabilityCheck = HorasPolicies.checkSessionJoinReliability(
      userMarks: myMarks,
      now: _store.now,
    );
    if (reliabilityCheck is Err<void>) {
      return Err<({Participant? participant, WaitlistEntry? waitlist})>(
        reliabilityCheck.failure,
      );
    }

    final session = _store.sessions[idx];
    final currentJoinedCount = _store.participants
        .where(
          (p) =>
              p.sessionId == sessionId && p.status == ParticipantStatus.joined,
        )
        .length;

    final meSummary = _store.toPersonSummary(me);

    // MAN-R3 & AC-08: Slot penuh menghasilkan daftar tunggu FIFO
    if (currentJoinedCount >= session.maxSlots) {
      final currentWaitlist = _store.waitlistEntries
          .where((w) => w.sessionId == sessionId)
          .toList();
      final entry = WaitlistEntry(
        id: _store.nextId('wait'),
        sessionId: sessionId,
        user: meSummary,
        position: currentWaitlist.length + 1,
        enqueuedAt: _store.now,
      );
      _store.waitlistEntries.add(entry);
      _store.sessions[idx] = session.copyWith(
        waitlistCount: currentWaitlist.length + 1,
      );
      return Ok<({Participant? participant, WaitlistEntry? waitlist})>((
        participant: null,
        waitlist: entry,
      ));
    }

    final partStatus = session.joinMode == SessionJoinMode.instant
        ? ParticipantStatus.joined
        : ParticipantStatus.pendingHostApproval;
    final participant = Participant(
      id: _store.nextId('part'),
      sessionId: sessionId,
      user: meSummary,
      status: partStatus,
      joinedAt: _store.now,
    );
    _store.participants.add(participant);
    _store.paymentShares.add(
      PaymentShare(
        id: _store.nextId('pay'),
        sessionId: sessionId,
        participant: meSummary,
        amountRupiah: session.feePerPersonRupiah,
        updatedAt: _store.now,
      ),
    );
    _store.sessions[idx] = session.copyWith(
      participantCount: currentJoinedCount + 1,
      isJoinedByMe: true,
    );

    if (partStatus == ParticipantStatus.joined) {
      _store.pushNotificationInternal(
        recipientId: me.id,
        type: NotificationType.sessionJoinOrWaitlistPromoted,
        title: 'Terdaftar di Sesi Main',
        body: 'Kamu telah bergabung ke sesi ${session.title}.',
        deepLink: 'horas://app/main/sesi-detail',
      );
    }

    return Ok<({Participant? participant, WaitlistEntry? waitlist})>((
      participant: participant,
      waitlist: null,
    ));
  }

  @override
  Future<Result<void>> leaveSession(String sessionId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;

    final me = _store.activeProfile;
    final idx = _store.sessions.indexWhere((s) => s.id == sessionId);
    if (me == null || idx < 0) return const Ok<void>(null);

    final session = _store.sessions[idx];
    final pIdx = _store.participants.indexWhere(
      (p) => p.sessionId == sessionId && p.user.id == me.id,
    );
    if (pIdx < 0) return const Ok<void>(null);

    final leavingParticipant = _store.participants.removeAt(pIdx);
    _store.paymentShares.removeWhere(
      (ps) => ps.sessionId == sessionId && ps.participant.id == me.id,
    );

    // MAN-R4 & AC-09: Keluar mendadak (< 3 jam sebelum mulai) menambah catatan keandalan & notifikasi ke host
    if (HorasPolicies.shouldRecordLateLeaveMark(
      sessionStartTime: session.startTime,
      leaveTime: _store.now,
      promotedFromWaitlistAt: leavingParticipant.promotedFromWaitlistAt,
    )) {
      _store.reliabilityMarks.add(
        ReliabilityMark(
          id: _store.nextId('rel'),
          userId: me.id,
          sessionId: sessionId,
          reason: ReliabilityMarkReason.lateLeaveUnder3Hours,
          createdAt: _store.now,
        ),
      );
      _store.pushNotificationInternal(
        recipientId: session.host.id,
        type: NotificationType.sessionUpdatedOrCancelled,
        title: 'Peserta Keluar Mendadak',
        body:
            '${me.displayName} keluar kurang dari 3 jam sebelum sesi ${session.title} dimulai.',
        deepLink: 'horas://app/main/peserta',
      );
    }

    // MAN-R3 & AC-08: Promosikan urutan 1 di daftar tunggu FIFO secara otomatis
    final sessionWaitlist =
        _store.waitlistEntries.where((w) => w.sessionId == sessionId).toList()
          ..sort((a, b) => a.position.compareTo(b.position));

    if (sessionWaitlist.isNotEmpty) {
      final firstWait = sessionWaitlist.first;
      _store.waitlistEntries.removeWhere((w) => w.id == firstWait.id);

      // Perbarui posisi sisa daftar tunggu
      for (var i = 1; i < sessionWaitlist.length; i++) {
        final wId = sessionWaitlist[i].id;
        final wIdx = _store.waitlistEntries.indexWhere((w) => w.id == wId);
        if (wIdx >= 0) {
          _store.waitlistEntries[wIdx] = _store.waitlistEntries[wIdx].copyWith(
            position: i,
          );
        }
      }

      _store.participants.add(
        Participant(
          id: _store.nextId('part'),
          sessionId: sessionId,
          user: firstWait.user,
          status: ParticipantStatus.joined,
          joinedAt: _store.now,
          promotedFromWaitlistAt: _store.now,
        ),
      );
      _store.paymentShares.add(
        PaymentShare(
          id: _store.nextId('pay'),
          sessionId: sessionId,
          participant: firstWait.user,
          amountRupiah: session.feePerPersonRupiah,
          updatedAt: _store.now,
        ),
      );

      // AC-08: Kirim notifikasi ke pengguna yang naik dari daftar tunggu
      _store.pushNotificationInternal(
        recipientId: firstWait.user.id,
        type: NotificationType.sessionJoinOrWaitlistPromoted,
        title: 'Slot Terbuka! Kamu Masuk Sesi',
        body:
            'Kamu otomatis masuk dari daftar tunggu ke sesi ${session.title}.',
        deepLink: 'horas://app/main/sesi-detail',
      );
    }

    final remainingJoined = _store.participants
        .where(
          (p) =>
              p.sessionId == sessionId && p.status == ParticipantStatus.joined,
        )
        .length;
    final remainingWaitlist = _store.waitlistEntries
        .where((w) => w.sessionId == sessionId)
        .length;

    _store.sessions[idx] = session.copyWith(
      participantCount: remainingJoined,
      waitlistCount: remainingWaitlist,
      isJoinedByMe: false,
    );
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Participant>>> getParticipants(String sessionId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Participant>>(net.failure);

    final me = _store.activeProfile;
    // MAN-R6: Badge partuturan antar-peserta tampil di daftar peserta.
    final list = _store.participants
        .where((p) => p.sessionId == sessionId)
        .map((p) {
          final target = _store.usersById[p.user.id];
          if (target == null) return p;
          return p.copyWith(user: _store.toPersonSummary(target, viewer: me));
        })
        .toList(growable: false);
    return Ok<List<Participant>>(list);
  }

  @override
  Future<Result<List<WaitlistEntry>>> getWaitlist(String sessionId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<WaitlistEntry>>(net.failure);
    final list =
        _store.waitlistEntries.where((w) => w.sessionId == sessionId).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    return Ok<List<WaitlistEntry>>(list);
  }

  @override
  Future<Result<List<PaymentShare>>> getPaymentShares(String sessionId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PaymentShare>>(net.failure);
    final list = _store.paymentShares
        .where((ps) => ps.sessionId == sessionId)
        .toList(growable: false);
    return Ok<List<PaymentShare>>(list);
  }

  @override
  Future<Result<PaymentShare>> markPaymentPaid(String paymentShareId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PaymentShare>(net.failure);

    final idx = _store.paymentShares.indexWhere(
      (ps) => ps.id == paymentShareId,
    );
    if (idx < 0) {
      return const Err<PaymentShare>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final updated = _store.paymentShares[idx].copyWith(
      participantMarkedPaid: true,
      updatedAt: _store.now,
    );
    _store.paymentShares[idx] = updated;
    return Ok<PaymentShare>(updated);
  }

  @override
  Future<Result<PaymentShare>> confirmPaymentReceived(
    String paymentShareId,
  ) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PaymentShare>(net.failure);

    final idx = _store.paymentShares.indexWhere(
      (ps) => ps.id == paymentShareId,
    );
    if (idx < 0) {
      return const Err<PaymentShare>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final updated = _store.paymentShares[idx].copyWith(
      hostConfirmedPaid: true,
      updatedAt: _store.now,
    );
    _store.paymentShares[idx] = updated;
    return Ok<PaymentShare>(updated);
  }

  @override
  Future<Result<List<PlaySession>>> getMySessionHistory() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PlaySession>>(net.failure);
    _refreshCompletedSessions();
    final uid = _store.currentUserId;
    if (uid == null) return const Ok<List<PlaySession>>(<PlaySession>[]);
    final myJoinedSessionIds = _store.sessionIdsForUser(uid);
    final list = _store.sessions
        .where((s) => s.host.id == uid || myJoinedSessionIds.contains(s.id))
        .toList(growable: false);
    return Ok<List<PlaySession>>(list);
  }

  @override
  Future<Result<List<ReliabilityMark>>> getReliabilityMarksForHost(
    String targetUserId,
  ) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<ReliabilityMark>>(net.failure);
    // MAN-R4: Catatan keandalan terlihat oleh host, bukan publik.
    final list = _store.reliabilityMarks
        .where((m) => m.userId == targetUserId)
        .toList(growable: false);
    return Ok<List<ReliabilityMark>>(list);
  }
}

// ── 13. MockCourtRepository ─────────────────────────────────────────────────

final class MockCourtRepository implements CourtRepository {
  const MockCourtRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<List<Court>>> getCourts({
    String? city,
    SportType? sportType,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Court>>(net.failure);
    if (_store.isEmptyState) return const Ok<List<Court>>(<Court>[]);

    final list = _store.courts
        .where((c) {
          if (c.status == CourtModerationStatus.pendingModeration) return false;
          if (city != null &&
              city.isNotEmpty &&
              c.city.toLowerCase() != city.toLowerCase()) {
            return false;
          }
          if (sportType != null && !c.supportedSports.contains(sportType)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    return Ok<List<Court>>(list);
  }

  @override
  Future<Result<Court>> getCourtById(String courtId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Court>(net.failure);
    final court = _store.courts.where((c) => c.id == courtId).firstOrNull;
    if (court == null) {
      return const Err<Court>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    return Ok<Court>(court);
  }

  @override
  Future<Result<Court>> proposeCourt({
    required String name,
    required String address,
    required String city,
    required List<SportType> supportedSports,
    required String estimatedPriceText,
    required String openingHours,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Court>(net.failure);

    final court = Court(
      id: _store.nextId('court'),
      name: name.trim(),
      address: address.trim(),
      city: city.trim(),
      supportedSports: supportedSports,
      estimatedPriceText: estimatedPriceText.trim(),
      openingHours: openingHours.trim(),
      status: CourtModerationStatus.pendingModeration, // MAN-R10
    );
    _store.courts.add(court);
    return Ok<Court>(court);
  }
}

// ── 14. MockChatRepository ──────────────────────────────────────────────────

final class MockChatRepository implements ChatRepository {
  const MockChatRepository(this._store);

  final MockStore _store;

  @override
  Stream<List<Conversation>> watchConversations() =>
      _store.conversationsStreamController.stream;

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    final controller = _store.messageStreamsByConv.putIfAbsent(
      conversationId,
      StreamController<List<Message>>.broadcast,
    );
    return controller.stream;
  }

  @override
  Future<Result<List<Conversation>>> getConversations() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Conversation>>(net.failure);
    return Ok<List<Conversation>>(_store.visibleConversationsForActiveUser());
  }

  @override
  Future<Result<List<MessageRequest>>> getMessageRequests() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<MessageRequest>>(net.failure);
    if (_store.isEmptyState) {
      return const Ok<List<MessageRequest>>(<MessageRequest>[]);
    }
    final uid = _store.currentUserId;
    final list = _store.messageRequests
        .where(
          (r) =>
              r.receiverId == uid &&
              r.status == MessageRequestStatus.pending &&
              (uid == null || !_store.isBlockedBetween(uid, r.sender.id)),
        )
        .toList(growable: false);
    return Ok<List<MessageRequest>>(list);
  }

  @override
  Future<Result<Message>> sendFirstMessageToUser({
    required String targetUserId,
    required String text,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Message>(net.failure);

    final me = _store.activeProfile;
    final target = _store.usersById[targetUserId];
    if (me == null ||
        target == null ||
        _store.isBlockedBetween(me.id, target.id)) {
      return const Err<Message>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final connected = _store.isConnectedBetween(me.id, target.id);
    final sharedContext =
        _store.sharesCommunityOrSession(me.id, target.id) &&
        target.privacySettings.allowMessagesFromSharedContext;

    // PSN-R1 & AC-06: Hanya boleh kirim pesan bila Terhubung atau berbagi komunitas/sesi
    if (!connected && !sharedContext) {
      return const Err<Message>(
        ValidationError(
          message: 'Pesan pribadi hanya dapat dikirim kepada Kenalan yang sudah Terhubung atau anggota komunitas/sesi yang sama.',
          field: 'targetUserId',
        ),
      );
    }

    // PSN-R2: Pada kasus non-terhubung (konteks bersama), maksimal satu pesan teks sampai diterima.
    final existingPendingReq = _store.messageRequests.any(
      (r) =>
          r.sender.id == me.id &&
          r.receiverId == target.id &&
          r.status == MessageRequestStatus.pending,
    );
    if (!connected && existingPendingReq) {
      return const Err<Message>(
        ValidationError(
          message: 'Kamu sudah mengirim permintaan pesan. Tunggu sampai penerima menyetujuinya.',
          field: 'targetUserId',
        ),
      );
    }

    // PSN-R9: Batas pesan pertama ke maksimal 20 orang baru per hari
    final myFirstMsgTimes =
        _store.firstMessageTimestampsByUser[me.id] ?? const <DateTime>[];
    final quota = HorasPolicies.checkDailyFirstMessageQuota(
      firstMessagesLast24h: myFirstMsgTimes,
      now: _store.now,
    );
    if (quota is Err<void>) return Err<Message>(quota.failure);

    final cleanText = text.trim();
    if (cleanText.isEmpty || cleanText.length > AppLimits.messageTextMaxChars) {
      return const Err<Message>(
        ValidationError(
          message: 'Pesan teks harus antara 1 sampai 2.000 karakter.',
          field: 'text',
        ),
      );
    }

    _store.firstMessageTimestampsByUser[me.id] = <DateTime>[
      ...myFirstMsgTimes,
      _store.now,
    ];

    // PSN-R8 & AC-16: Deteksi peringatan penipuan pada pesan pertama dari non-terhubung
    final hasScamWarning = HorasPolicies.detectFirstMessageScamWarning(
      text: cleanText,
      isSenderConnected: connected,
    );

    final convId = _store.nextId('conv-dm');
    final meSummary = _store.toPersonSummary(me, viewer: target);
    final targetSummary = _store.toPersonSummary(target, viewer: me);

    final message = Message(
      id: _store.nextId('msg'),
      conversationId: convId,
      sender: meSummary,
      text: cleanText,
      hasScamWarning: hasScamWarning,
      createdAt: _store.now,
    );

    _store.messagesByConversationId[convId] = <Message>[message];

    if (connected) {
      _store.conversations.insert(
        0,
        Conversation(
          id: convId,
          type: ConversationType.direct,
          title: targetSummary.displayName,
          participants: <PersonSummary>[meSummary, targetSummary],
          lastMessage: message,
          updatedAt: _store.now,
        ),
      );
      _store.pushNotificationInternal(
        recipientId: target.id,
        type: NotificationType.newMessage,
        title: 'Pesan Baru dari ${me.displayName}',
        body: cleanText,
        deepLink: 'horas://app/pesan/pribadi',
      );
    } else {
      final req = MessageRequest(
        id: _store.nextId('mreq'),
        conversationId: convId,
        sender: meSummary,
        receiverId: target.id,
        firstMessage: message,
        sharedContextDescription: 'Berbagi komunitas atau sesi olahraga',
        status: MessageRequestStatus.pending,
        createdAt: _store.now,
      );
      _store.messageRequests.insert(0, req);
      _store.pushNotificationInternal(
        recipientId: target.id,
        type: NotificationType.messageRequestReceived,
        title: 'Permintaan Pesan Baru',
        body: '${me.displayName} mengirim permintaan pesan.',
        deepLink: 'horas://app/pesan/permintaan',
      );
    }

    _store.notifyListeners();
    return Ok<Message>(message);
  }

  @override
  Future<Result<Message>> sendMessage({
    required String conversationId,
    required String text,
    String? photoSeed,
    String? replyToMessageId,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Message>(net.failure);

    final me = _store.activeProfile;
    final convIdx = _store.conversations.indexWhere(
      (c) => c.id == conversationId,
    );
    if (me == null || convIdx < 0) {
      return const Err<Message>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final conv = _store.conversations[convIdx];
    if (conv.isReadOnly) {
      return const Err<Message>(
        ValidationError(
          message: 'Percakapan sesi ini sudah menjadi baca-saja (lewat 24 jam setelah sesi selesai).',
          field: 'conversationId',
        ),
      );
    }

    final clean = text.trim();
    if (clean.length > AppLimits.messageTextMaxChars) {
      return const Err<Message>(
        ValidationError(
          message: 'Pesan teks maksimal 2.000 karakter.',
          field: 'text',
        ),
      );
    }

    final msg = Message(
      id: _store.nextId('msg'),
      conversationId: conversationId,
      sender: _store.toPersonSummary(me),
      text: clean,
      photoSeed: photoSeed,
      replyToMessageId: replyToMessageId,
      createdAt: _store.now,
    );
    final list = _store.messagesByConversationId.putIfAbsent(
      conversationId,
      () => <Message>[],
    )..add(msg);

    _store.conversations[convIdx] = conv.copyWith(
      lastMessage: msg,
      updatedAt: _store.now,
    );

    _store.messageStreamsByConv[conversationId]?.add(
      List<Message>.unmodifiable(list),
    );

    for (final p in conv.participants.where((p) => p.id != me.id)) {
      _store.pushNotificationInternal(
        recipientId: p.id,
        type: NotificationType.newMessage,
        title: conv.type == ConversationType.direct
            ? me.displayName
            : conv.title,
        body: clean,
        deepLink: 'horas://app/pesan',
      );
    }
    _store.notifyListeners();
    return Ok<Message>(msg);
  }

  @override
  Future<Result<void>> respondMessageRequest({
    required String requestId,
    required MessageRequestStatus decision,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;

    final idx = _store.messageRequests.indexWhere((r) => r.id == requestId);
    if (idx < 0) return const Ok<void>(null);

    final req = _store.messageRequests[idx];
    _store.messageRequests[idx] = req.copyWith(status: decision);

    if (decision == MessageRequestStatus.accepted) {
      final me = _store.activeProfile;
      if (me != null) {
        _store.conversations.insert(
          0,
          Conversation(
            id: req.conversationId,
            type: ConversationType.direct,
            title: req.sender.displayName,
            participants: <PersonSummary>[
              _store.toPersonSummary(me),
              req.sender,
            ],
            lastMessage: req.firstMessage,
            updatedAt: _store.now,
          ),
        );
      }
    } else if (decision == MessageRequestStatus.blocked) {
      await MockBlockRepository(_store).blockUser(req.sender.id);
    }
    _store.notifyListeners();
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> deleteMessageForMe(String messageId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    final uid = _store.currentUserId;
    if (uid == null) return const Ok<void>(null);

    for (final list in _store.messagesByConversationId.values) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == messageId) {
          list[i] = list[i].copyWith(
            deletedForUserIds: <String>[...list[i].deletedForUserIds, uid],
          );
        }
      }
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> deleteMessageForEveryone(String messageId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;

    for (final list in _store.messagesByConversationId.values) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == messageId) {
          // PSN-R4: Hapus untuk semua dalam 1 jam setelah kirim
          final check = HorasPolicies.checkDeleteMessageForEveryoneAllowed(
            messageCreatedAt: list[i].createdAt,
            now: _store.now,
          );
          if (check.isErr) return check;
          list[i] = list[i].copyWith(isDeletedForEveryone: true);
          return const Ok<void>(null);
        }
      }
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<Conversation>> muteConversation({
    required String conversationId,
    required MuteDurationOption duration,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Conversation>(net.failure);

    final idx = _store.conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) {
      return const Err<Conversation>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    final updated = _store.conversations[idx].copyWith(
      mutedUntil: _store.now.add(duration.duration),
    );
    _store.conversations[idx] = updated;
    return Ok<Conversation>(updated);
  }
}

// ── 15. MockNotificationRepository ──────────────────────────────────────────

final class MockNotificationRepository implements NotificationRepository {
  const MockNotificationRepository(this._store);

  final MockStore _store;

  @override
  Stream<List<AppNotification>> watchNotifications() =>
      _store.notificationsStreamController.stream;

  @override
  Future<Result<List<AppNotification>>> getNotifications() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<AppNotification>>(net.failure);
    return Ok<List<AppNotification>>(
      _store.visibleNotificationsForActiveUser(),
    );
  }

  @override
  Future<Result<AppNotification>> push({
    required String recipientId,
    required NotificationType type,
    required String title,
    required String body,
    required String deepLink,
  }) async {
    final item = _store.pushNotificationInternal(
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      deepLink: deepLink,
    );
    return Ok<AppNotification>(item);
  }

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    final idx = _store.notifications.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      _store.notifications[idx] = _store.notifications[idx].copyWith(
        isRead: true,
      );
      _store.notifyListeners();
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> markAllAsRead() async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    final uid = _store.currentUserId;
    for (var i = 0; i < _store.notifications.length; i++) {
      if (_store.notifications[i].recipientId == uid) {
        _store.notifications[i] = _store.notifications[i].copyWith(
          isRead: true,
        );
      }
    }
    _store.notifyListeners();
    return const Ok<void>(null);
  }
}

// ── 16. MockReportRepository ────────────────────────────────────────────────

final class MockReportRepository implements ReportRepository {
  const MockReportRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<Report>> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String note = '',
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<Report>(net.failure);

    final uid = _store.currentUserId;
    if (uid == null) {
      return const Err<Report>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    // SIS-R2 & AC-14: Satu laporan aktif per target per pelapor; maksimal 20/hari
    final hasActiveSameTarget = _store.reports.any(
      (r) =>
          r.reporterId == uid &&
          r.targetType == targetType &&
          r.targetId == targetId &&
          r.status != ReportStatus.completed,
    );
    final myRecentReports = _store.reports
        .where((r) => r.reporterId == uid)
        .map((r) => r.createdAt)
        .toList();

    final check = HorasPolicies.validateReportSubmission(
      note: note,
      reportsLast24h: myRecentReports,
      hasActiveReportOnSameTarget: hasActiveSameTarget,
      now: _store.now,
    );
    if (check is Err<void>) return Err<Report>(check.failure);

    final report = Report(
      id: _store.nextId('rep'),
      reporterId: uid,
      targetType: targetType,
      targetId: targetId,
      category: category,
      note: note.trim(),
      status: ReportStatus.received, // AC-14: berstatus Diterima
      createdAt: _store.now,
    );
    _store.reports.insert(0, report);

    // MAN-R10: Lapangan dengan lebih dari 3 laporan salah info ditandai untuk ditinjau.
    if (targetType == ReportTargetType.court) {
      final cIdx = _store.courts.indexWhere((c) => c.id == targetId);
      if (cIdx >= 0) {
        final court = _store.courts[cIdx];
        final nextCount = court.wrongInfoReportCount + 1;
        _store.courts[cIdx] = court.copyWith(
          wrongInfoReportCount: nextCount,
          status: nextCount > 3
              ? CourtModerationStatus.flaggedForReview
              : court.status,
        );
      }
    }

    return Ok<Report>(report);
  }

  @override
  Future<Result<List<Report>>> getMyReports() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<Report>>(net.failure);
    final uid = _store.currentUserId;
    final list = _store.reports
        .where((r) => r.reporterId == uid)
        .toList(growable: false);
    return Ok<List<Report>>(list);
  }

  @override
  Future<Result<List<Strike>>> getMyStrikes() async {
    final net = await _store.simulateNetworkCall(checkAccountStatus: false);
    if (net is Err<void>) return Err<List<Strike>>(net.failure);
    final uid = _store.currentUserId;
    final list = _store.strikes
        .where((s) => s.userId == uid)
        .toList(growable: false);
    return Ok<List<Strike>>(list);
  }

  @override
  Future<Result<Appeal>> submitAppeal({
    required DateTime sanctionCreatedAt,
    required String reasonText,
  }) async {
    final net = await _store.simulateNetworkCall(checkAccountStatus: false);
    if (net is Err<void>) return Err<Appeal>(net.failure);

    final uid = _store.currentUserId;
    if (uid == null) {
      return const Err<Appeal>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final windowCheck = HorasPolicies.validateSanctionAppeal(
      sanctionCreatedAt: sanctionCreatedAt,
      now: _store.now,
    );
    if (windowCheck is Err<void>) return Err<Appeal>(windowCheck.failure);

    final appeal = Appeal(
      id: _store.nextId('apl'),
      userId: uid,
      sanctionCreatedAt: sanctionCreatedAt,
      reasonText: reasonText.trim(),
      status: AppealStatus.submitted,
      createdAt: _store.now,
    );
    _store.appeals.insert(0, appeal);
    return Ok<Appeal>(appeal);
  }
}

// ── 17. MockVerificationRepository ──────────────────────────────────────────

final class MockVerificationRepository implements VerificationRepository {
  const MockVerificationRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<VerificationRequest>> submitCommunityVerification({
    required String communityId,
    required String evidenceDescription,
    required String contactInfo,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<VerificationRequest>(net.failure);

    final uid = _store.currentUserId;
    final comm = _store.communities
        .where((c) => c.id == communityId)
        .firstOrNull;
    if (uid == null || comm == null) {
      return const Err<VerificationRequest>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final req = VerificationRequest(
      id: _store.nextId('ver'),
      requesterId: uid,
      communityId: communityId,
      communityName: comm.name,
      evidenceDescription: evidenceDescription.trim(),
      contactInfo: contactInfo.trim(),
      status: VerificationStatus.submitted,
      createdAt: _store.now,
    );
    _store.verificationRequests.insert(0, req);
    return Ok<VerificationRequest>(req);
  }

  @override
  Future<Result<List<VerificationRequest>>> getMyVerificationRequests() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) {
      return Err<List<VerificationRequest>>(net.failure);
    }
    final uid = _store.currentUserId;
    final list = _store.verificationRequests
        .where((v) => v.requesterId == uid)
        .toList(growable: false);
    return Ok<List<VerificationRequest>>(list);
  }
}

// ── 18. MockTaromboRepository ───────────────────────────────────────────────

final class MockTaromboRepository implements TaromboRepository {
  const MockTaromboRepository(this._store);

  final MockStore _store;

  @override
  bool get hasGivenConsent => _store.hasGivenTaromboConsent;

  @override
  Future<Result<void>> giveConsent() async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    _store.hasGivenTaromboConsent = true;
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<FamilyMember>>> getMyFamilyMembers() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<FamilyMember>>(net.failure);
    if (_store.isEmptyState) {
      return const Ok<List<FamilyMember>>(<FamilyMember>[]);
    }
    final uid = _store.currentUserId;
    final list = _store.familyMembers
        .where((f) => f.ownerUserId == uid)
        .toList(growable: false);
    return Ok<List<FamilyMember>>(list);
  }

  @override
  Future<Result<FamilyMember>> upsertFamilyMember({
    required FamilyRelationType relationType,
    required String fullName,
    required String marga,
    required UserGender gender,
    required LifeStatus lifeStatus,
    String? id,
    int? birthYear,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<FamilyMember>(net.failure);

    final uid = _store.currentUserId;
    if (uid == null) {
      return const Err<FamilyMember>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final member = FamilyMember(
      id: id ?? _store.nextId('fam'),
      ownerUserId: uid,
      relationType: relationType,
      fullName: fullName.trim(),
      marga: marga.trim(),
      gender: gender,
      birthYear: birthYear,
      lifeStatus: lifeStatus,
    );
    _store.familyMembers.removeWhere((f) => f.id == member.id);
    _store.familyMembers.add(member);
    return Ok<FamilyMember>(member);
  }

  @override
  Future<Result<void>> deleteAllMyTarombo() async {
    final net = await _store.simulateNetworkCall();
    if (net.isErr) return net;
    final uid = _store.currentUserId;
    // TAR-R10: Pemilik dapat menghapus seluruh data tarombonya kapan saja.
    _store.familyMembers.removeWhere((f) => f.ownerUserId == uid);
    return const Ok<void>(null);
  }

  @override
  Future<Result<int>> getCompletenessPercent() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<int>(net.failure);

    final me = _store.activeProfile;
    if (me == null) return const Ok<int>(0);

    // TAR-R11: Kelengkapan tarombo (%) dihitung dari 5 butir:
    // marga ibu, ayah, ibu, kakek dari ayah, kakek dari ibu.
    var score = 0;
    if ((me.motherMarga ?? '').trim().isNotEmpty) score += 20;
    final myMembers = _store.familyMembers
        .where((f) => f.ownerUserId == me.id)
        .map((f) => f.relationType)
        .toSet();
    if (myMembers.contains(FamilyRelationType.father)) score += 20;
    if (myMembers.contains(FamilyRelationType.mother)) score += 20;
    if (myMembers.contains(FamilyRelationType.paternalGrandfather)) score += 20;
    if (myMembers.contains(FamilyRelationType.maternalGrandfather)) score += 20;
    return Ok<int>(score);
  }

  @override
  Future<Result<List<PartuturanClaim>>> getIncomingClaims() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PartuturanClaim>>(net.failure);
    final uid = _store.currentUserId;
    final list = _store.partuturanClaims
        .where(
          (c) =>
              c.receiver.id == uid && c.status == PartuturanClaimStatus.pending,
        )
        .toList(growable: false);
    return Ok<List<PartuturanClaim>>(list);
  }

  @override
  Future<Result<List<PartuturanClaim>>> getOutgoingClaims() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<PartuturanClaim>>(net.failure);
    final uid = _store.currentUserId;
    final list = _store.partuturanClaims
        .where(
          (c) =>
              c.sender.id == uid && c.status == PartuturanClaimStatus.pending,
        )
        .toList(growable: false);
    return Ok<List<PartuturanClaim>>(list);
  }

  @override
  Future<Result<PartuturanClaim>> sendKinshipClaim({
    required String targetUserId,
    required String claimedTermForTarget,
    String? note,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PartuturanClaim>(net.failure);

    final me = _store.activeProfile;
    final target = _store.usersById[targetUserId];
    if (me == null ||
        target == null ||
        _store.isBlockedBetween(me.id, target.id)) {
      return const Err<PartuturanClaim>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    // TAR-R7: Satu klaim aktif per pasangan
    final hasActive = _store.partuturanClaims.any(
      (c) =>
          c.status == PartuturanClaimStatus.pending &&
          ((c.sender.id == me.id && c.receiver.id == target.id) ||
              (c.sender.id == target.id && c.receiver.id == me.id)),
    );
    if (hasActive) {
      return const Err<PartuturanClaim>(
        ValidationError(
          message:
              'Masih ada klaim konfirmasi hubungan aktif dengan pengguna ini.',
          field: 'targetUserId',
        ),
      );
    }

    final claim = PartuturanClaim(
      id: _store.nextId('clm'),
      sender: _store.toPersonSummary(me, viewer: target),
      receiver: _store.toPersonSummary(target, viewer: me),
      claimedTermForReceiver: claimedTermForTarget.trim(),
      note: note?.trim(),
      status: PartuturanClaimStatus.pending,
      createdAt: _store.now,
    );
    _store.partuturanClaims.add(claim);

    // PRD 9: Klaim Kami kerabat masuk
    _store.pushNotificationInternal(
      recipientId: target.id,
      type: NotificationType.partuturanClaimReceived,
      title: 'Klaim Hubungan Kerabat Baru',
      body:
          '${me.displayName} mengirim konfirmasi hubungan kerabat ($claimedTermForTarget).',
      deepLink: 'horas://app/tarombo/konfirmasi',
    );
    return Ok<PartuturanClaim>(claim);
  }

  @override
  Future<Result<PartuturanClaim>> respondKinshipClaim({
    required String claimId,
    required bool accept,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PartuturanClaim>(net.failure);

    final idx = _store.partuturanClaims.indexWhere((c) => c.id == claimId);
    if (idx < 0) {
      return const Err<PartuturanClaim>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    // TAR-R7: Bila diterima, keyakinan pasangan menjadi Tinggi. Penolakan tidak diberitahukan.
    final updated = _store.partuturanClaims[idx].copyWith(
      status: accept
          ? PartuturanClaimStatus.accepted
          : PartuturanClaimStatus.rejected,
      respondedAt: _store.now,
    );
    _store.partuturanClaims[idx] = updated;
    return Ok<PartuturanClaim>(updated);
  }
}

// ── 19. MockPartuturanRepository ────────────────────────────────────────────

final class MockPartuturanRepository implements PartuturanRepository {
  const MockPartuturanRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<PartuturanResult>> evaluateWithUser(String targetUserId) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PartuturanResult>(net.failure);

    final me = _store.activeProfile;
    final target = _store.usersById[targetUserId];
    if (me == null || target == null) {
      return const Err<PartuturanResult>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }
    return Ok<PartuturanResult>(
      _store.evaluatePartuturanForUsers(viewer: me, target: target),
    );
  }

  @override
  Future<Result<PartuturanResult>> evaluateManual({
    required String viewerMarga,
    required UserGender viewerGender,
    required SubEthnic subEthnic,
    required String targetMarga,
    required UserGender targetGender,
    required GenerationInfo generationInfo,
    String? viewerMotherMarga,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PartuturanResult>(net.failure);

    final result = _store.partuturanEngine.evaluate(
      PartuturanEvaluationInput(
        viewerMarga: viewerMarga,
        viewerGender: viewerGender,
        viewerMotherMarga: viewerMotherMarga,
        subEthnic: subEthnic,
        targetMarga: targetMarga,
        targetGender: targetGender,
        generationInfo: generationInfo,
      ),
    );
    return Ok<PartuturanResult>(result);
  }

  @override
  Future<Result<PartuturanFeedback>> submitNotThisFeedback({
    required String targetMarga,
    required String? shownTerm,
    String? suggestedTerm,
    String? note,
  }) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<PartuturanFeedback>(net.failure);

    final me = _store.activeProfile;
    if (me == null) {
      return const Err<PartuturanFeedback>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    // TAR-R8: Tombol Bukan menyimpan umpan balik sebagai sinyal tinjauan, tidak mengubah aturan otomatis.
    final feedback = PartuturanFeedback(
      id: _store.nextId('pfb'),
      userId: me.id,
      viewerMarga: me.marga,
      targetMarga: targetMarga.trim(),
      shownTerm: shownTerm,
      suggestedTerm: suggestedTerm?.trim(),
      note: note?.trim(),
      ruleVersion: '0.1.0-draft',
      createdAt: _store.now,
    );
    _store.partuturanFeedbacks.add(feedback);
    return Ok<PartuturanFeedback>(feedback);
  }

  @override
  Future<Result<Report>> reportWrongRule({
    required String ruleOrTargetId,
    required String note,
  }) {
    // TAR-R8: Tombol Laporkan aturan salah membuat Report kategori Aturan partuturan salah.
    return MockReportRepository(_store).submitReport(
      targetType: ReportTargetType.user,
      targetId: ruleOrTargetId,
      category: ReportCategory.wrongPartuturanRule,
      note: note,
    );
  }
}

// ── 20. MockSupportRepository ───────────────────────────────────────────────

final class MockSupportRepository implements SupportRepository {
  const MockSupportRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<List<HelpArticle>>> getHelpArticles({String? query}) async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<List<HelpArticle>>(net.failure);

    final q = (query ?? '').trim().toLowerCase();
    final list = MockSeedData.helpArticles
        .where((a) {
          if (q.isEmpty) return true;
          return a.question.toLowerCase().contains(q) ||
              a.answer.toLowerCase().contains(q);
        })
        .toList(growable: false);
    return Ok<List<HelpArticle>>(list);
  }

  @override
  Future<Result<void>> submitSupportTicket({
    required String category,
    required String message,
    String? email,
  }) async {
    final net = await _store.simulateNetworkCall(checkAccountStatus: false);
    if (net.isErr) return net;
    if (message.trim().isEmpty) {
      return const Err<void>(
        ValidationError(
          message: 'Pesan keluhan atau pertanyaan tidak boleh kosong.',
          field: 'message',
        ),
      );
    }
    return const Ok<void>(null);
  }
}

// ── 21. MockAccountLifecycleRepository ──────────────────────────────────────

final class MockAccountLifecycleRepository
    implements AccountLifecycleRepository {
  const MockAccountLifecycleRepository(this._store);

  final MockStore _store;

  @override
  Future<Result<DataExportJob>> requestDataExport() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<DataExportJob>(net.failure);

    final uid = _store.currentUserId;
    if (uid == null) {
      return const Err<DataExportJob>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    final latest = _store.dataExportJobs
        .where((j) => j.userId == uid)
        .fold<DateTime?>(
          null,
          (prev, elem) => prev == null || elem.requestedAt.isAfter(prev)
              ? elem.requestedAt
              : prev,
        );

    // AKN-R7: Unduh data maksimal sekali per 7 hari
    final check = HorasPolicies.checkDataExportAllowed(
      now: _store.now,
      lastExportRequestedAt: latest,
    );
    if (check is Err<void>) return Err<DataExportJob>(check.failure);

    final job = DataExportJob(
      id: _store.nextId('exp'),
      userId: uid,
      status: DataExportStatus.ready,
      downloadUrl: 'https://horas.id/export/$uid.zip',
      requestedAt: _store.now,
      expiresAt: _store.now.add(const Duration(days: 7)),
    );
    _store.dataExportJobs.insert(0, job);
    return Ok<DataExportJob>(job);
  }

  @override
  Future<Result<DataExportJob?>> getLatestDataExportJob() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<DataExportJob?>(net.failure);
    final uid = _store.currentUserId;
    final job = _store.dataExportJobs.where((j) => j.userId == uid).firstOrNull;
    return Ok<DataExportJob?>(job);
  }

  @override
  Future<Result<AccountDeletion>> requestAccountDeletion() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<AccountDeletion>(net.failure);

    final uid = _store.currentUserId;
    if (uid == null) {
      return const Err<AccountDeletion>(
        UnavailableError(message: AppStrings.stateContentUnavailableMessage),
      );
    }

    // AKN-R8: Komunitas yang dimiliki harus diserahkan dulu sebelum hapus akun
    final ownsCommunities = _store.communities.any((c) => c.ownerId == uid);
    if (ownsCommunities) {
      return const Err<AccountDeletion>(
        ValidationError(
          message: 'Serahkan kepemilikan komunitas yang kamu miliki terlebih dahulu sebelum menghapus akun.',
          field: 'communities',
        ),
      );
    }

    final schedule = HorasPolicies.createAccountDeletionSchedule(
      id: _store.nextId('del'),
      userId: uid,
      now: _store.now,
    );
    _store.accountDeletionsByUser[uid] = schedule;
    return Ok<AccountDeletion>(schedule);
  }

  @override
  Future<Result<AccountDeletion?>> cancelAccountDeletion() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<AccountDeletion?>(net.failure);
    final uid = _store.currentUserId;
    if (uid == null) return const Ok<AccountDeletion?>(null);
    final existing = _store.accountDeletionsByUser[uid];
    if (existing == null) return const Ok<AccountDeletion?>(null);

    final evaluated = HorasPolicies.evaluateAccountDeletionOnTime(
      deletion: existing,
      now: _store.now,
      userLoggedIn: true,
    );
    _store.accountDeletionsByUser[uid] = evaluated;
    return Ok<AccountDeletion?>(evaluated);
  }

  @override
  Future<Result<AccountDeletion?>> getAccountDeletionStatus() async {
    final net = await _store.simulateNetworkCall();
    if (net is Err<void>) return Err<AccountDeletion?>(net.failure);
    final uid = _store.currentUserId;
    if (uid == null) return const Ok<AccountDeletion?>(null);
    final existing = _store.accountDeletionsByUser[uid];
    if (existing == null) return const Ok<AccountDeletion?>(null);

    final evaluated = HorasPolicies.evaluateAccountDeletionOnTime(
      deletion: existing,
      now: _store.now,
      userLoggedIn: false,
    );
    _store.accountDeletionsByUser[uid] = evaluated;
    return Ok<AccountDeletion?>(evaluated);
  }
}

// ── 22. MockDebugSimulationRepository (Panel Debug Bagian D) ────────────────

final class MockDebugSimulationRepository implements DebugSimulationRepository {
  const MockDebugSimulationRepository(this._store);

  final MockStore _store;

  @override
  DebugSimulationState get state {
    final uid = _store.currentUserId ?? 'u-01';
    final me = _store.usersById[uid];
    final windowStart = _store.now.subtract(
      const Duration(days: AppLimits.strikesWindowDays),
    );
    final strikeCount = _store.strikes
        .where((s) => s.userId == uid && s.createdAt.isAfter(windowStart))
        .length;

    return DebugSimulationState(
      currentUserId: uid,
      currentNow: _store.now,
      isOffline: _store.isOffline,
      isServerError: _store.isServerError,
      isEmptyState: _store.isEmptyState,
      isSlowNetwork: _store.isSlowNetwork,
      timeOffset: _store.timeOffset,
      activeStrikesCount: strikeCount,
      isAccountSuspended: me?.accountStatus == AccountStatus.suspended,
    );
  }

  @override
  List<DebugMockUserOption> get availableMockUsers {
    return _store.usersById.values
        .map(
          (u) => (
            id: u.id,
            displayName: u.displayName,
            marga: u.marga,
            subEthnic: u.subEthnic,
            city: u.city,
          ),
        )
        .toList(growable: false);
  }

  @override
  void setOffline(bool value) {
    _store.isOffline = value;
    _store.notifyListeners();
  }

  @override
  void setServerError(bool value) {
    _store.isServerError = value;
    _store.notifyListeners();
  }

  @override
  void setEmptyState(bool value) {
    _store.isEmptyState = value;
    _store.notifyListeners();
  }

  @override
  void setSlowNetwork(bool value) {
    _store.isSlowNetwork = value;
    _store.notifyListeners();
  }

  @override
  Future<void> switchMockUser(String userId) async {
    if (_store.usersById.containsKey(userId)) {
      _store.currentUserId = userId;
      _store.currentSelectedCity = _store.usersById[userId]!.city;
      await _store.persistSessionAndProfile();
      _store.notifyListeners();
    }
  }

  @override
  void advanceClock(Duration delta) {
    _store.timeOffset += delta;
    _store.notifyListeners();
  }

  @override
  void resetClock() {
    _store.timeOffset = Duration.zero;
    _store.notifyListeners();
  }

  @override
  void simulateAddStrike({
    String reason = 'Pelanggaran Pedoman Komunitas HORAS',
  }) {
    final uid = _store.currentUserId;
    if (uid == null) return;
    _store.strikes.add(
      Strike(
        id: _store.nextId('strk'),
        userId: uid,
        reason: reason,
        createdAt: _store.now,
      ),
    );
    final myStrikes = _store.strikes.where((s) => s.userId == uid).toList();
    // SIS-R4: 3 strike dalam 90 hari = suspend otomatis
    if (HorasPolicies.shouldSuspendForStrikes(
      strikes: myStrikes,
      now: _store.now,
    )) {
      simulateSuspendCurrentAccount();
      return;
    }
    _store.pushNotificationInternal(
      recipientId: uid,
      type: NotificationType.moderationAction,
      title: 'Peringatan & Strike Akun',
      body: reason,
      deepLink: 'horas://app/sistem/pedoman',
    );
    _store.notifyListeners();
  }

  @override
  void simulateSuspendCurrentAccount() {
    final uid = _store.currentUserId;
    if (uid == null) return;
    final me = _store.usersById[uid];
    if (me != null) {
      _store.usersById[uid] = me.copyWith(
        accountStatus: AccountStatus.suspended,
      );
      _store.pushNotificationInternal(
        recipientId: uid,
        type: NotificationType.moderationAction,
        title: 'Akun Ditangguhkan Sementara',
        body: AppStrings.stateAccountRestrictedDefaultReason,
        deepLink: 'horas://app/sistem/dukungan',
      );
      _store.notifyListeners();
    }
  }

  @override
  void clearAccountSanctions() {
    final uid = _store.currentUserId;
    if (uid == null) return;
    _store.strikes.removeWhere((s) => s.userId == uid);
    final me = _store.usersById[uid];
    if (me != null) {
      _store.usersById[uid] = me.copyWith(accountStatus: AccountStatus.active);
    }
    _store.notifyListeners();
  }

  @override
  Future<void> resetAllData() => _store.resetAllData();
}

// ── 23. MockNavigationBadgeRepository (terhubung ke MockStore) ──────────────

final class StoreBackedNavigationBadgeRepository
    implements NavigationBadgeRepository {
  const StoreBackedNavigationBadgeRepository(this._store);

  final MockStore _store;

  @override
  UnreadCounts currentUnreadCounts() {
    final unreadNotifs = _store
        .visibleNotificationsForActiveUser()
        .where((n) => !n.isRead)
        .length;
    final unreadMsgs = _store.visibleConversationsForActiveUser().fold<int>(
      0,
      (sum, c) => sum + c.unreadCount,
    );
    return (unreadMessages: unreadMsgs, unreadNotifications: unreadNotifs);
  }
}
