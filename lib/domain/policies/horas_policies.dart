import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/app_limits.dart';

/// Kumpulan fungsi kebijakan murni berbasis waktu (`DateTime now` / `Clock`)
/// sesuai PRD bagian 6 dan 7.2 (Prompt 2 Bagian E).
///
/// Pelanggaran kuota/batas menghasilkan [RateLimitedError] beserta waktu `retryAt`
/// kapan pengguna dapat mencoba lagi, bukan hukuman permanen.
abstract final class HorasPolicies {
  // ── 1. Kebijakan OTP (AUT-R1, AUT-R2, AC-01) ───────────────────────────────

  static Result<void> validatePhoneE164(String phone) {
    final trimmed = phone.trim();
    final regex = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!regex.hasMatch(trimmed)) {
      return const Err<void>(
        ValidationError(
          message:
              'Format nomor HP harus menggunakan kode negara (mis. +62812...).',
          field: 'phone',
        ),
      );
    }
    return const Ok<void>(null);
  }

  static Result<void> validateEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(trimmed)) {
      return const Err<void>(
        ValidationError(
          message: 'Format alamat email tidak valid (mis. nama@gmail.com).',
          field: 'email',
        ),
      );
    }
    return const Ok<void>(null);
  }

  static Result<void> checkOtpSendAllowed({
    required List<DateTime> recentRequestTimes,
    required DateTime now,
    DateTime? lockedUntil,
  }) {
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      return Err<void>(
        RateLimitedError(
          message: 'Nomor ini dikunci sementara selama 1 jam karena batas percobaan OTP terlampaui.',
          retryAt: lockedUntil,
          retryAfter: lockedUntil.difference(now),
        ),
      );
    }

    if (recentRequestTimes.isNotEmpty) {
      final latest = recentRequestTimes.reduce((a, b) => a.isAfter(b) ? a : b);
      final resendReadyAt = latest.add(AppLimits.otpResendCooldown);
      if (now.isBefore(resendReadyAt)) {
        return Err<void>(
          RateLimitedError(
            message: 'Tunggu 60 detik sebelum meminta kode OTP baru.',
            retryAt: resendReadyAt,
            retryAfter: resendReadyAt.difference(now),
          ),
        );
      }
    }

    final windowStart = now.subtract(const Duration(hours: 1));
    final inLastHour =
        recentRequestTimes.where((t) => t.isAfter(windowStart)).toList()
          ..sort();
    if (inLastHour.length >= AppLimits.otpMaxRequestsPerHour) {
      final retryAt = inLastHour.first.add(const Duration(hours: 1));
      return Err<void>(
        RateLimitedError(
          message:
              'Maksimal ${AppLimits.otpMaxRequestsPerHour} permintaan OTP per jam.',
          retryAt: retryAt,
          retryAfter: retryAt.difference(now),
        ),
      );
    }

    return const Ok<void>(null);
  }

  /// Mengevaluasi input kode OTP dan mengembalikan `(Result, wrongAttemptsBaru, lockedUntilBaru)`.
  static ({Result<void> result, int wrongAttempts, DateTime? lockedUntil})
  evaluateOtpVerification({
    required String inputCode,
    required String expectedCode,
    required DateTime issuedAt,
    required int currentWrongAttempts,
    required DateTime now,
    DateTime? currentLockedUntil,
  }) {
    if (currentLockedUntil != null && now.isBefore(currentLockedUntil)) {
      return (
        result: Err<void>(
          RateLimitedError(
            message: 'Nomor terkunci selama 1 jam karena 5 kali salah memasukkan OTP.',
            retryAt: currentLockedUntil,
            retryAfter: currentLockedUntil.difference(now),
          ),
        ),
        wrongAttempts: currentWrongAttempts,
        lockedUntil: currentLockedUntil,
      );
    }

    final expiresAt = issuedAt.add(AppLimits.otpValidity);
    if (now.isAfter(expiresAt)) {
      return (
        result: const Err<void>(
          ValidationError(
            message: 'Kode OTP sudah kedaluwarsa (berlaku 5 menit).',
            field: 'otp',
          ),
        ),
        wrongAttempts: currentWrongAttempts,
        lockedUntil: null,
      );
    }

    if (inputCode.trim() != expectedCode.trim()) {
      final nextWrong = currentWrongAttempts + 1;
      if (nextWrong >= AppLimits.otpMaxWrongAttempts) {
        final lockUntil = now.add(AppLimits.otpLockoutDuration);
        return (
          result: Err<void>(
            RateLimitedError(
              message:
                  'OTP salah dimasukkan ${AppLimits.otpMaxWrongAttempts} kali. Nomor dikunci 1 jam hingga ${lockUntil.toIso8601String()}.',
              retryAt: lockUntil,
              retryAfter: AppLimits.otpLockoutDuration,
            ),
          ),
          wrongAttempts: nextWrong,
          lockedUntil: lockUntil,
        );
      }
      return (
        result: Err<void>(
          ValidationError(
            message:
                'Kode OTP belum sesuai (percobaan $nextWrong dari ${AppLimits.otpMaxWrongAttempts}).',
            field: 'otp',
          ),
        ),
        wrongAttempts: nextWrong,
        lockedUntil: null,
      );
    }

    return (result: const Ok<void>(null), wrongAttempts: 0, lockedUntil: null);
  }

  // ── 2. Kebijakan Usia 17+ & Perangkat Maksimal 3 (AUT-R5, AUT-R9, AC-02) ──

  static Result<void> validateOnboardingAge({
    required int birthYear,
    required DateTime now,
  }) {
    final age = now.year - birthYear;
    if (age < AppLimits.minAgeYears) {
      return const Err<void>(
        ValidationError(
          message: 'Maaf, pengguna HORAS harus berusia minimal 17 tahun sesuai ketentuan.',
          field: 'birthYear',
        ),
      );
    }
    if (age > 110) {
      return const Err<void>(
        ValidationError(
          message: 'Tahun lahir tidak valid.',
          field: 'birthYear',
        ),
      );
    }
    return const Ok<void>(null);
  }

  static Result<void> validateDisplayName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.length < AppLimits.displayNameMinChars ||
        trimmed.length > AppLimits.displayNameMaxChars) {
      return const Err<void>(
        ValidationError(
          message: 'Nama tampil harus terdiri dari 2 sampai 40 karakter.',
          field: 'displayName',
        ),
      );
    }
    return const Ok<void>(null);
  }

  /// AUT-R9: Maksimal 3 perangkat aktif; login di perangkat ke-4 mengeluarkan perangkat tertua.
  static ({List<Device> activeDevices, List<Device> evictedDevices})
  resolveDevicesOnNewLogin({
    required List<Device> existingDevices,
    required Device newDevice,
  }) {
    final sorted = List<Device>.of(existingDevices)
      ..removeWhere((d) => d.id == newDevice.id)
      ..sort((a, b) => a.loggedInAt.compareTo(b.loggedInAt));

    final evicted = <Device>[];
    while (sorted.length >= AppLimits.maxActiveDevices) {
      evicted.add(sorted.removeAt(0));
    }
    sorted.add(newDevice);
    return (activeDevices: sorted, evictedDevices: evicted);
  }

  // ── 3. Kebijakan Kenalan / Terhubung (SEK-R5, AC-05) ───────────────────────

  static DateTime connectionRequestExpiresAt(DateTime createdAt) => createdAt
      .add(const Duration(days: AppLimits.connectionRequestExpiryDays));

  static Result<void> validateConnectionRequest({
    required String introMessage,
    required List<DateTime> requestsSentLast24h,
    required DateTime now,
    DateTime? lastRejectedOrExpiredWithTargetAt,
  }) {
    if (introMessage.trim().length > AppLimits.connectionIntroMaxChars) {
      return const Err<void>(
        ValidationError(
          message: 'Pesan pengantar Kenalan maksimal 200 karakter.',
          field: 'introMessage',
        ),
      );
    }

    if (lastRejectedOrExpiredWithTargetAt != null) {
      final cooldownUntil = lastRejectedOrExpiredWithTargetAt.add(
        const Duration(days: AppLimits.connectionCooldownAfterRejectDays),
      );
      if (now.isBefore(cooldownUntil)) {
        return Err<void>(
          RateLimitedError(
            message: 'Permintaan Kenalan ke pengguna ini baru dapat dikirim kembali setelah 30 hari.',
            retryAt: cooldownUntil,
            retryAfter: cooldownUntil.difference(now),
          ),
        );
      }
    }

    return _checkRollingWindowQuota(
      timestamps: requestsSentLast24h,
      window: const Duration(hours: 24),
      maxAllowed: AppLimits.maxDailyConnectionRequests,
      now: now,
      quotaLabel:
          'Maksimal ${AppLimits.maxDailyConnectionRequests} permintaan Kenalan baru per hari.',
    );
  }

  // ── 4. Kuota Harian/Jam: Ikuti, Pesan Pertama, Postingan, Komentar, Nama ───

  static Result<void> checkDailyFollowQuota({
    required List<DateTime> followsLast24h,
    required DateTime now,
  }) {
    return _checkRollingWindowQuota(
      timestamps: followsLast24h,
      window: const Duration(hours: 24),
      maxAllowed: AppLimits.maxDailyFollows,
      now: now,
      quotaLabel: 'Maksimal ${AppLimits.maxDailyFollows} ikuti baru per hari.',
    );
  }

  static Result<void> checkDailyFirstMessageQuota({
    required List<DateTime> firstMessagesLast24h,
    required DateTime now,
  }) {
    return _checkRollingWindowQuota(
      timestamps: firstMessagesLast24h,
      window: const Duration(hours: 24),
      maxAllowed: AppLimits.maxDailyFirstMessagesToNewPeople,
      now: now,
      quotaLabel:
          'Maksimal ${AppLimits.maxDailyFirstMessagesToNewPeople} pesan pertama ke orang baru per hari.',
    );
  }

  static Result<PostModerationStatus> validatePostCreation({
    required String text,
    required int photoCount,
    required List<int> photoSizesBytes,
    required List<DateTime> postsLast24h,
    required DateTime accountCreatedAt,
    required DateTime now,
  }) {
    final quotaCheck = _checkRollingWindowQuota(
      timestamps: postsLast24h,
      window: const Duration(hours: 24),
      maxAllowed: AppLimits.maxPostsPer24Hours,
      now: now,
      quotaLabel:
          'Maksimal ${AppLimits.maxPostsPer24Hours} postingan per 24 jam.',
    );
    if (quotaCheck is Err<void>) {
      return Err<PostModerationStatus>(quotaCheck.failure);
    }

    final cleanText = text.trim();
    if (cleanText.isEmpty && photoCount == 0) {
      return const Err<PostModerationStatus>(
        ValidationError(
          message: 'Postingan harus berisi minimal teks atau satu foto.',
          field: 'text',
        ),
      );
    }
    if (cleanText.length > AppLimits.postTextMaxChars) {
      return const Err<PostModerationStatus>(
        ValidationError(
          message: 'Teks postingan maksimal 2.000 karakter.',
          field: 'text',
        ),
      );
    }
    if (photoCount > AppLimits.postMaxPhotos) {
      return const Err<PostModerationStatus>(
        ValidationError(
          message: 'Maksimal 10 foto dalam satu postingan.',
          field: 'media',
        ),
      );
    }
    for (final size in photoSizesBytes) {
      if (size > AppLimits.postPhotoMaxBytes) {
        return const Err<PostModerationStatus>(
          ValidationError(
            message: 'Ukuran per foto maksimal 10 MB sebelum kompres.',
            field: 'media',
          ),
        );
      }
    }

    // BER-R10 & BER-R11: tautan eksternal dari akun berusia < 7 hari, atau filter kata/spam
    // menahan postingan untuk ditinjau (terlihat oleh pembuatnya sebagai Sedang ditinjau).
    final hasExternalLink = RegExp(
      r'(https?://|www\.)\S+',
      caseSensitive: false,
    ).hasMatch(cleanText);
    final isNewAccount =
        now.difference(accountCreatedAt).inDays <
        AppLimits.newAccountExternalLinkHoldDays;

    final lowerText = cleanText.toLowerCase();
    final hasFilteredWords = RegExp(
      r'\b(slot\s*gacor|judi\s*online|pinjol\s*ilegal|taruhan\s*bola|promo\s*togel|kasar_sara)\b',
    ).hasMatch(lowerText);
    final linkCount = RegExp(
      r'(https?://|www\.)\S+',
      caseSensitive: false,
    ).allMatches(cleanText).length;
    final hasSpamPattern =
        linkCount >= 3 || RegExp(r'(.)\1{9,}').hasMatch(cleanText);

    if ((hasExternalLink && isNewAccount) ||
        hasFilteredWords ||
        hasSpamPattern) {
      return const Ok<PostModerationStatus>(PostModerationStatus.underReview);
    }
    return const Ok<PostModerationStatus>(PostModerationStatus.published);
  }

  static Result<void> validateCommentCreation({
    required String text,
    required List<DateTime> commentsLastHour,
    required DateTime now,
  }) {
    final quotaCheck = _checkRollingWindowQuota(
      timestamps: commentsLastHour,
      window: const Duration(hours: 1),
      maxAllowed: AppLimits.maxCommentsPerHour,
      now: now,
      quotaLabel: 'Maksimal ${AppLimits.maxCommentsPerHour} komentar per jam.',
    );
    if (quotaCheck.isErr) {
      return quotaCheck;
    }

    final clean = text.trim();
    if (clean.isEmpty) {
      return const Err<void>(
        ValidationError(message: 'Komentar tidak boleh kosong.', field: 'text'),
      );
    }
    if (clean.length > AppLimits.commentMaxChars) {
      return const Err<void>(
        ValidationError(
          message: 'Komentar maksimal 1.000 karakter.',
          field: 'text',
        ),
      );
    }
    return const Ok<void>(null);
  }

  static Result<void> validateBio(String bio) {
    if (bio.trim().length > AppLimits.bioMaxChars) {
      return const Err<void>(
        ValidationError(
          message: 'Bio profil maksimal 150 karakter.',
          field: 'bio',
        ),
      );
    }
    return const Ok<void>(null);
  }

  static Result<void> checkDisplayNameChangeAllowed({
    required DateTime now,
    DateTime? lastChangedAt,
  }) {
    if (lastChangedAt == null) {
      return const Ok<void>(null);
    }
    final nextAllowedAt = lastChangedAt.add(
      const Duration(days: AppLimits.displayNameChangeCooldownDays),
    );
    if (now.isBefore(nextAllowedAt)) {
      return Err<void>(
        RateLimitedError(
          message: 'Nama tampil hanya dapat diubah sekali setiap 30 hari.',
          retryAt: nextAllowedAt,
          retryAfter: nextAllowedAt.difference(now),
        ),
      );
    }
    return const Ok<void>(null);
  }

  // ── 5. Kebijakan Komunitas (SEK-R7, SEK-R8, SEK-R10, SEK-R11) ──────────────

  static DateTime communityJoinRequestExpiresAt(DateTime createdAt) => createdAt
      .add(const Duration(days: AppLimits.communityJoinRequestExpiryDays));

  static Result<void> validateCommunityCreation({
    required String name,
    required String description,
    required DateTime accountCreatedAt,
    required int ownedCommunitiesCount,
    required DateTime now,
  }) {
    final eligibleAt = accountCreatedAt.add(
      const Duration(days: AppLimits.minAccountAgeDaysToCreateCommunity),
    );
    if (now.isBefore(eligibleAt)) {
      return Err<void>(
        RateLimitedError(
          message: 'Pembuatan komunitas membutuhkan usia akun minimal 7 hari.',
          retryAt: eligibleAt,
          retryAfter: eligibleAt.difference(now),
        ),
      );
    }

    if (ownedCommunitiesCount >= AppLimits.maxCommunitiesCreatedPerAccount) {
      return Err<void>(
        RateLimitedError(
          message:
              'Maksimal ${AppLimits.maxCommunitiesCreatedPerAccount} komunitas dapat dibuat per akun.',
          retryAt: now.add(const Duration(days: 1)),
          retryAfter: const Duration(days: 1),
        ),
      );
    }

    final cleanName = name.trim();
    if (cleanName.length < AppLimits.communityNameMinChars ||
        cleanName.length > AppLimits.communityNameMaxChars) {
      return const Err<void>(
        ValidationError(
          message: 'Nama komunitas harus terdiri dari 3 sampai 60 karakter.',
          field: 'name',
        ),
      );
    }

    if (description.trim().length > AppLimits.communityDescMaxChars) {
      return const Err<void>(
        ValidationError(
          message: 'Deskripsi komunitas maksimal 500 karakter.',
          field: 'description',
        ),
      );
    }
    return const Ok<void>(null);
  }

  static Result<void> checkCommunityManagerLimit(int currentManagerCount) {
    if (currentManagerCount >= AppLimits.maxCommunityManagers) {
      return const Err<void>(
        ValidationError(
          message: 'Maksimal 10 Pengurus dalam satu komunitas.',
          field: 'managers',
        ),
      );
    }
    return const Ok<void>(null);
  }

  static Result<void> checkPinnedAnnouncementLimit(int currentPinnedCount) {
    if (currentPinnedCount >= AppLimits.maxPinnedAnnouncements) {
      return const Err<void>(
        ValidationError(
          message: 'Maksimal 3 pengumuman dapat disematkan.',
          field: 'isPinned',
        ),
      );
    }
    return const Ok<void>(null);
  }

  // ── 6. Kebijakan Sesi Main & Patungan (MAN-R1, MAN-R5, MAN-R7) ─────────────

  static Result<void> validateSessionCreation({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required int maxSlots,
    required int feePerPersonRupiah,
    required String notes,
    required int activeHostedSessionsCount,
    required DateTime now,
  }) {
    if (activeHostedSessionsCount >= AppLimits.maxActiveSessionsPerHost) {
      return Err<void>(
        RateLimitedError(
          message:
              'Host maksimal memiliki ${AppLimits.maxActiveSessionsPerHost} sesi aktif sekaligus.',
          retryAt: now.add(const Duration(hours: 2)),
          retryAfter: const Duration(hours: 2),
        ),
      );
    }

    final minStart = now.add(const Duration(hours: 1));
    final maxStart = now.add(const Duration(days: 60));
    if (startTime.isBefore(minStart) || startTime.isAfter(maxStart)) {
      return const Err<void>(
        ValidationError(
          message: 'Waktu mulai sesi harus minimal 1 jam dari sekarang dan maksimal 60 hari ke depan.',
          field: 'startTime',
        ),
      );
    }

    if (!endTime.isAfter(startTime)) {
      return const Err<void>(
        ValidationError(
          message: 'Waktu selesai sesi harus setelah waktu mulai.',
          field: 'endTime',
        ),
      );
    }

    if (maxSlots < AppLimits.sessionMinSlots ||
        maxSlots > AppLimits.sessionMaxSlots) {
      return const Err<void>(
        ValidationError(
          message: 'Jumlah slot peserta harus antara 2 sampai 50 orang.',
          field: 'maxSlots',
        ),
      );
    }

    if (feePerPersonRupiah < 0 ||
        feePerPersonRupiah > AppLimits.sessionMaxFeeRupiah) {
      return const Err<void>(
        ValidationError(
          message: 'Biaya per orang harus antara Rp0 sampai Rp1.000.000.',
          field: 'feePerPersonRupiah',
        ),
      );
    }

    if (notes.trim().length > AppLimits.sessionNoteMaxChars) {
      return const Err<void>(
        ValidationError(
          message: 'Catatan sesi maksimal 300 karakter.',
          field: 'notes',
        ),
      );
    }

    // MAN-R7: Larangan mutlak taruhan uang atau judi
    final combinedLower = '$title $notes'.toLowerCase();
    final gamblingPattern = RegExp(
      r'\b(taruhan|judi|betting|voor|pur-puran|uang\s+taruhan)\b',
    );
    if (gamblingPattern.hasMatch(combinedLower)) {
      return const Err<void>(
        ValidationError(
          message: 'Taruhan uang atau judi dalam bentuk apa pun dilarang keras di HORAS.',
          field: 'notes',
        ),
      );
    }

    return const Ok<void>(null);
  }

  /// MAN-R7: Menghitung patungan per orang dan membulatkan ke atas ke kelipatan Rp500.
  static int calculatePatunganPerPerson({
    required int totalRupiah,
    required int participantCount,
  }) {
    if (totalRupiah <= 0 || participantCount <= 0) {
      return 0;
    }
    final rawPerPerson =
        (totalRupiah + participantCount - 1) ~/ participantCount;
    const step = AppLimits.sessionRoundingStepRupiah;
    return ((rawPerPerson + step - 1) ~/ step) * step;
  }

  // ── 7. Kebijakan Catatan Keandalan (MAN-R3, MAN-R4, AC-09) ─────────────────

  static bool shouldRecordLateLeaveMark({
    required DateTime sessionStartTime,
    required DateTime leaveTime,
    DateTime? promotedFromWaitlistAt,
    DateTime? scheduleUpdatedAt,
  }) {
    // MAN-R5: Jika host mengedit waktu/lapangan, peserta boleh keluar tanpa catatan keandalan.
    if (scheduleUpdatedAt != null && !leaveTime.isBefore(scheduleUpdatedAt)) {
      return false;
    }
    // MAN-R3: peserta yang baru naik dari daftar tunggu dapat keluar tanpa catatan dalam 1 jam.
    if (promotedFromWaitlistAt != null &&
        leaveTime.difference(promotedFromWaitlistAt) <=
            const Duration(hours: 1)) {
      return false;
    }
    final diff = sessionStartTime.difference(leaveTime);
    return !diff.isNegative && diff < const Duration(hours: 3);
  }

  /// MAN-R11 & AKN-R5: Menggeser pengingat yang jatuh di jam tenang (22.00-06.00) ke pukul 06.00.
  static DateTime adjustReminderForQuietHours(DateTime candidate) {
    if (candidate.hour >= AppLimits.quietHoursStartHour) {
      return DateTime(
        candidate.year,
        candidate.month,
        candidate.day + 1,
        AppLimits.quietHoursEndHour,
        0,
      );
    }
    if (candidate.hour < AppLimits.quietHoursEndHour) {
      return DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        AppLimits.quietHoursEndHour,
        0,
      );
    }
    return candidate;
  }

  /// AKN-10 & PRD 9: Menentukan apakah notifikasi non-keamanan sedang berada
  /// di jam tenang (22.00-06.00). `NotificationType.accountSecurity` selalu aktif.
  static bool shouldDelayPushForQuietHours({
    required NotificationType type,
    required DateTime now,
    required NotificationPreferences prefs,
  }) {
    if (!prefs.quietHoursEnabled || type == NotificationType.accountSecurity) {
      return false;
    }
    return now.hour >= AppLimits.quietHoursStartHour ||
        now.hour < AppLimits.quietHoursEndHour;
  }

  /// MAN-R11: Menghitung jadwal pengingat H-1 pukul 19.00 dan 2 jam sebelum mulai
  /// dengan menghormati jam tenang 22.00-06.00.
  static ({DateTime? reminderHMinus1, DateTime? reminder2HoursBefore})
  computeSessionReminders({
    required DateTime sessionStartTime,
    required DateTime now,
  }) {
    final rawH1 = DateTime(
      sessionStartTime.year,
      sessionStartTime.month,
      sessionStartTime.day - 1,
      19,
      0,
    );
    final h1 = adjustReminderForQuietHours(rawH1);

    final raw2h = sessionStartTime.subtract(const Duration(hours: 2));
    final h2 = adjustReminderForQuietHours(raw2h);

    return (
      reminderHMinus1: h1.isAfter(now) ? h1 : null,
      reminder2HoursBefore: h2.isAfter(now) ? h2 : null,
    );
  }

  static Result<void> checkSessionJoinReliability({
    required List<ReliabilityMark> userMarks,
    required DateTime now,
  }) {
    final windowStart = now.subtract(
      const Duration(days: AppLimits.reliabilityWindowDays),
    );
    final recentMarks =
        userMarks.where((m) => m.createdAt.isAfter(windowStart)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (recentMarks.length >= AppLimits.reliabilityMarksThreshold) {
      final latestMark = recentMarks.first;
      final restrictedUntil = latestMark.createdAt.add(
        const Duration(days: AppLimits.reliabilityRestrictionDays),
      );
      if (now.isBefore(restrictedUntil)) {
        return Err<void>(
          RateLimitedError(
            message:
                'Belum bisa bergabung selama 7 hari karena 3 catatan ketidakhadiran/keluar mendadak dalam 30 hari terakhir. Dapat mencoba lagi mulai ${restrictedUntil.toIso8601String()}.',
            retryAt: restrictedUntil,
            retryAfter: restrictedUntil.difference(now),
          ),
        );
      }
    }
    return const Ok<void>(null);
  }

  // ── 8. Kebijakan Pesan & Peringatan Penipuan (PSN-R3, PSN-R4, PSN-R8, AC-16)

  static bool detectFirstMessageScamWarning({
    required String text,
    required bool isSenderConnected,
  }) {
    if (isSenderConnected) {
      return false;
    }
    final lower = text.toLowerCase();
    final hasLink = RegExp(r'(https?://|www\.|bit\.ly|t\.me)').hasMatch(lower);
    final hasMoneyRequest = RegExp(
      r'\b(transfer|pinjam|rekening|dana|gopay|ovo|kirim\s+uang|minta\s+pulsa)\b',
    ).hasMatch(lower);
    return hasLink || hasMoneyRequest;
  }

  static Result<void> checkDeleteMessageForEveryoneAllowed({
    required DateTime messageCreatedAt,
    required DateTime now,
  }) {
    if (now.difference(messageCreatedAt) > AppLimits.deleteForEveryoneWindow) {
      return const Err<void>(
        ValidationError(
          message: 'Hapus untuk semua hanya dapat dilakukan dalam 1 jam setelah pesan dikirim.',
          field: 'messageId',
        ),
      );
    }
    return const Ok<void>(null);
  }

  // ── 9. Kebijakan Laporan, Sanksi, Unduh Data, Hapus Akun (SIS & AKN) ───────

  static Result<void> validateReportSubmission({
    required String note,
    required List<DateTime> reportsLast24h,
    required bool hasActiveReportOnSameTarget,
    required DateTime now,
  }) {
    if (hasActiveReportOnSameTarget) {
      return const Err<void>(
        ValidationError(
          message: 'Kamu sudah memiliki laporan aktif untuk target ini yang sedang ditinjau.',
          field: 'targetId',
        ),
      );
    }
    if (note.trim().length > AppLimits.reportNoteMaxChars) {
      return const Err<void>(
        ValidationError(
          message: 'Catatan laporan maksimal 500 karakter.',
          field: 'note',
        ),
      );
    }
    return _checkRollingWindowQuota(
      timestamps: reportsLast24h,
      window: const Duration(hours: 24),
      maxAllowed: AppLimits.maxDailyReports,
      now: now,
      quotaLabel: 'Maksimal ${AppLimits.maxDailyReports} laporan per hari.',
    );
  }

  static bool shouldSuspendForStrikes({
    required List<Strike> strikes,
    required DateTime now,
  }) {
    final windowStart = now.subtract(
      const Duration(days: AppLimits.strikesWindowDays),
    );
    final recentCount = strikes
        .where((s) => s.createdAt.isAfter(windowStart))
        .length;
    return recentCount >= AppLimits.strikesThresholdForSuspension;
  }

  static Result<void> validateSanctionAppeal({
    required DateTime sanctionCreatedAt,
    required DateTime now,
  }) {
    final deadline = sanctionCreatedAt.add(
      const Duration(days: AppLimits.sanctionAppealWindowDays),
    );
    if (now.isAfter(deadline)) {
      return const Err<void>(
        ValidationError(
          message: 'Pengajuan banding hanya dapat dikirim dalam 14 hari sejak sanksi diterapkan.',
          field: 'sanctionCreatedAt',
        ),
      );
    }
    return const Ok<void>(null);
  }

  static Result<void> checkDataExportAllowed({
    required DateTime now,
    DateTime? lastExportRequestedAt,
  }) {
    if (lastExportRequestedAt == null) {
      return const Ok<void>(null);
    }
    final nextAllowedAt = lastExportRequestedAt.add(
      const Duration(days: AppLimits.dataExportCooldownDays),
    );
    if (now.isBefore(nextAllowedAt)) {
      return Err<void>(
        RateLimitedError(
          message: 'Unduh arsip data pribadi maksimal sekali setiap 7 hari.',
          retryAt: nextAllowedAt,
          retryAfter: nextAllowedAt.difference(now),
        ),
      );
    }
    return const Ok<void>(null);
  }

  static AccountDeletion createAccountDeletionSchedule({
    required String id,
    required String userId,
    required DateTime now,
  }) {
    return AccountDeletion(
      id: id,
      userId: userId,
      requestedAt: now,
      scheduledPermanentDeletionAt: now.add(
        const Duration(days: AppLimits.accountDeletionGraceDays),
      ),
    );
  }

  /// AC-12: Login dalam 30 hari membatalkan penghapusan; lewat 30 hari dihapus permanen.
  static AccountDeletion evaluateAccountDeletionOnTime({
    required AccountDeletion deletion,
    required DateTime now,
    required bool userLoggedIn,
  }) {
    if (deletion.isCancelled || deletion.isPermanentlyDeleted) {
      return deletion;
    }
    if (!now.isBefore(deletion.scheduledPermanentDeletionAt)) {
      return deletion.copyWith(isPermanentlyDeleted: true);
    }
    if (userLoggedIn) {
      return deletion.copyWith(isCancelled: true);
    }
    return deletion;
  }

  static Result<void> _checkRollingWindowQuota({
    required List<DateTime> timestamps,
    required Duration window,
    required int maxAllowed,
    required DateTime now,
    required String quotaLabel,
  }) {
    final windowStart = now.subtract(window);
    final active = timestamps.where((t) => t.isAfter(windowStart)).toList()
      ..sort();
    if (active.length >= maxAllowed) {
      final retryAt = active.first.add(window);
      return Err<void>(
        RateLimitedError(
          message: quotaLabel,
          retryAt: retryAt,
          retryAfter: retryAt.difference(now),
        ),
      );
    }
    return const Ok<void>(null);
  }
}
