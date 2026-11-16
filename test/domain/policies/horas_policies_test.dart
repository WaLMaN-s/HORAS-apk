import 'package:flutter_test/flutter_test.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/horas_policies.dart';

void main() {
  final baseNow = DateTime.utc(2026, 11, 16, 12, 0);

  group('Bagian E - Kebijakan & Batas Angka PRD 7.2', () {
    test('OTP (AUT-R2, AC-01): 5 permintaan/jam, jeda 60 detik, berlaku 5 menit, 5 salah = kunci 1 jam', () {
      // Jeda 60 detik sebelum kirim ulang
      final cooldownRes = HorasPolicies.checkOtpSendAllowed(
        recentRequestTimes: <DateTime>[
          baseNow.subtract(const Duration(seconds: 30)),
        ],
        now: baseNow,
      );
      expect(cooldownRes.isErr, isTrue);
      expect(
        (cooldownRes as Err<void>).failure,
        isA<RateLimitedError>().having(
          (e) => e.retryAt,
          'retryAt',
          baseNow.add(const Duration(seconds: 30)),
        ),
      );

      // 5 permintaan dalam 1 jam -> RateLimited
      final fiveRequests = <DateTime>[
        baseNow.subtract(const Duration(minutes: 50)),
        baseNow.subtract(const Duration(minutes: 40)),
        baseNow.subtract(const Duration(minutes: 30)),
        baseNow.subtract(const Duration(minutes: 20)),
        baseNow.subtract(const Duration(minutes: 10)),
      ];
      final hourlyRes = HorasPolicies.checkOtpSendAllowed(
        recentRequestTimes: fiveRequests,
        now: baseNow,
      );
      expect(hourlyRes.isErr, isTrue);
      expect((hourlyRes as Err<void>).failure, isA<RateLimitedError>());

      // Kedaluwarsa lewat 5 menit
      final expiredEval = HorasPolicies.evaluateOtpVerification(
        inputCode: '123456',
        expectedCode: '123456',
        issuedAt: baseNow.subtract(const Duration(minutes: 6)),
        currentWrongAttempts: 0,
        now: baseNow,
      );
      expect(expiredEval.result.isErr, isTrue);

      // AC-01: 5 kali salah memasukkan OTP -> terkunci 1 jam
      var wrong = 0;
      DateTime? lockUntil;
      for (var i = 1; i <= 5; i++) {
        final step = HorasPolicies.evaluateOtpVerification(
          inputCode: '000000',
          expectedCode: '123456',
          issuedAt: baseNow,
          currentWrongAttempts: wrong,
          now: baseNow,
          currentLockedUntil: lockUntil,
        );
        wrong = step.wrongAttempts;
        lockUntil = step.lockedUntil;
        if (i < 5) {
          expect(step.result.isErr, isTrue);
          expect(lockUntil, isNull);
        } else {
          expect(lockUntil, baseNow.add(const Duration(hours: 1)));
          expect((step.result as Err<void>).failure, isA<RateLimitedError>());
        }
      }
    });

    test(
      'Usia minimal 17 (AUT-R5, AC-02) dan perangkat aktif maksimal 3 (AUT-R9)',
      () {
        final under17 = HorasPolicies.validateOnboardingAge(
          birthYear: baseNow.year - 16,
          now: baseNow,
        );
        expect(under17.isErr, isTrue);

        final age17 = HorasPolicies.validateOnboardingAge(
          birthYear: baseNow.year - 17,
          now: baseNow,
        );
        expect(age17.isOk, isTrue);

        // AUT-R9: Perangkat ke-4 mengeluarkan perangkat tertua
        final existing = <Device>[
          Device(
            id: 'd1',
            userId: 'u-01',
            deviceName: 'Oldest Phone',
            platform: 'Android',
            loggedInAt: baseNow.subtract(const Duration(days: 10)),
            lastActiveAt: baseNow,
          ),
          Device(
            id: 'd2',
            userId: 'u-01',
            deviceName: 'Phone 2',
            platform: 'Android',
            loggedInAt: baseNow.subtract(const Duration(days: 5)),
            lastActiveAt: baseNow,
          ),
          Device(
            id: 'd3',
            userId: 'u-01',
            deviceName: 'Phone 3',
            platform: 'iOS',
            loggedInAt: baseNow.subtract(const Duration(days: 2)),
            lastActiveAt: baseNow,
          ),
        ];
        final d4 = Device(
          id: 'd4',
          userId: 'u-01',
          deviceName: 'New Phone 4',
          platform: 'Android',
          loggedInAt: baseNow,
          lastActiveAt: baseNow,
        );
        final resolved = HorasPolicies.resolveDevicesOnNewLogin(
          existingDevices: existing,
          newDevice: d4,
        );
        expect(resolved.activeDevices.length, 3);
        expect(resolved.evictedDevices.single.id, 'd1');
      },
    );

    test('Kenalan (SEK-R5, AC-05): 10/hari, pengantar 200 karakter, kedaluwarsa 30 hari, tunggu 30 hari setelah ditolak', () {
      expect(
        HorasPolicies.connectionRequestExpiresAt(baseNow),
        baseNow.add(const Duration(days: 30)),
      );

      // Cooldown 30 hari setelah ditolak
      final rejected10DaysAgo = baseNow.subtract(const Duration(days: 10));
      final cooldownCheck = HorasPolicies.validateConnectionRequest(
        introMessage: 'Horas!',
        requestsSentLast24h: const <DateTime>[],
        now: baseNow,
        lastRejectedOrExpiredWithTargetAt: rejected10DaysAgo,
      );
      expect(cooldownCheck.isErr, isTrue);
      expect((cooldownCheck as Err<void>).failure, isA<RateLimitedError>());

      // Batas 10 permintaan per hari
      final tenToday = List<DateTime>.generate(
        10,
        (i) => baseNow.subtract(Duration(hours: i + 1)),
      );
      final quotaCheck = HorasPolicies.validateConnectionRequest(
        introMessage: 'Horas!',
        requestsSentLast24h: tenToday,
        now: baseNow,
      );
      expect(quotaCheck.isErr, isTrue);
      expect((quotaCheck as Err<void>).failure, isA<RateLimitedError>());
    });

    test('Kuota Ikuti 200/hari, Pesan pertama 20/hari, Postingan 20/24j, Komentar 60/jam, Ganti nama 30 hari', () {
      final follows200 = List<DateTime>.generate(
        200,
        (i) => baseNow.subtract(Duration(minutes: i + 1)),
      );
      expect(
        HorasPolicies.checkDailyFollowQuota(
          followsLast24h: follows200,
          now: baseNow,
        ).isErr,
        isTrue,
      );

      final firstMsgs20 = List<DateTime>.generate(
        20,
        (i) => baseNow.subtract(Duration(minutes: i + 1)),
      );
      expect(
        HorasPolicies.checkDailyFirstMessageQuota(
          firstMessagesLast24h: firstMsgs20,
          now: baseNow,
        ).isErr,
        isTrue,
      );

      final posts20 = List<DateTime>.generate(
        20,
        (i) => baseNow.subtract(Duration(minutes: i + 1)),
      );
      expect(
        HorasPolicies.validatePostCreation(
          text: 'Horas',
          photoCount: 0,
          photoSizesBytes: const <int>[],
          postsLast24h: posts20,
          accountCreatedAt: baseNow.subtract(const Duration(days: 30)),
          now: baseNow,
        ).isErr,
        isTrue,
      );

      // BER-R10: Tautan eksternal dari akun < 7 hari ditahan (underReview)
      final newAccPost = HorasPolicies.validatePostCreation(
        text: 'Cek https://example.com',
        photoCount: 0,
        photoSizesBytes: const <int>[],
        postsLast24h: const <DateTime>[],
        accountCreatedAt: baseNow.subtract(const Duration(days: 3)),
        now: baseNow,
      );
      expect(
        (newAccPost as Ok<PostModerationStatus>).value,
        PostModerationStatus.underReview,
      );

      final comments60 = List<DateTime>.generate(
        60,
        (i) => baseNow.subtract(Duration(seconds: (i + 1) * 30)),
      );
      expect(
        HorasPolicies.validateCommentCreation(
          text: 'Mantap!',
          commentsLastHour: comments60,
          now: baseNow,
        ).isErr,
        isTrue,
      );

      // Ganti nama tampil sekali per 30 hari
      expect(
        HorasPolicies.checkDisplayNameChangeAllowed(
          now: baseNow,
          lastChangedAt: baseNow.subtract(const Duration(days: 15)),
        ).isErr,
        isTrue,
      );
    });

    test('Komunitas: akun minimal 7 hari, maksimal 5 komunitas, 10 Pengurus, 3 sematan, kedaluwarsa gabung 14 hari', () {
      expect(
        HorasPolicies.communityJoinRequestExpiresAt(baseNow),
        baseNow.add(const Duration(days: 14)),
      );

      // Akun < 7 hari ditolak
      expect(
        HorasPolicies.validateCommunityCreation(
          name: 'Punguan Baru',
          description: 'Deskripsi',
          accountCreatedAt: baseNow.subtract(const Duration(days: 3)),
          ownedCommunitiesCount: 0,
          now: baseNow,
        ).isErr,
        isTrue,
      );

      // Sudah punya 5 komunitas -> RateLimited
      expect(
        HorasPolicies.validateCommunityCreation(
          name: 'Punguan Keenam',
          description: 'Deskripsi',
          accountCreatedAt: baseNow.subtract(const Duration(days: 30)),
          ownedCommunitiesCount: 5,
          now: baseNow,
        ).isErr,
        isTrue,
      );

      expect(HorasPolicies.checkCommunityManagerLimit(10).isErr, isTrue);
      expect(HorasPolicies.checkPinnedAnnouncementLimit(3).isErr, isTrue);
    });

    test('Sesi Main & Patungan: 5 sesi aktif, 1 jam - 60 hari, slot 2-50, biaya <= 1jt, bulatkan ke atas Rp500, anti-taruhan', () {
      expect(
        HorasPolicies.validateSessionCreation(
          title: 'Badminton',
          startTime: baseNow.add(const Duration(hours: 2)),
          endTime: baseNow.add(const Duration(hours: 4)),
          maxSlots: 8,
          feePerPersonRupiah: 35000,
          notes: '',
          activeHostedSessionsCount: 5,
          now: baseNow,
        ).isErr,
        isTrue,
      );

      // Larangan taruhan (MAN-R7)
      expect(
        HorasPolicies.validateSessionCreation(
          title: 'Futsal Taruhan Uang',
          startTime: baseNow.add(const Duration(hours: 2)),
          endTime: baseNow.add(const Duration(hours: 4)),
          maxSlots: 10,
          feePerPersonRupiah: 50000,
          notes: '',
          activeHostedSessionsCount: 0,
          now: baseNow,
        ).isErr,
        isTrue,
      );

      // Patungan dibulatkan ke atas Rp500 (MAN-R7)
      // Rp100.000 / 3 = 33.334 -> dibulatkan ke atas Rp33.500
      expect(
        HorasPolicies.calculatePatunganPerPerson(
          totalRupiah: 100000,
          participantCount: 3,
        ),
        33500,
      );
    });

    test('Catatan keandalan (MAN-R4, AC-09): keluar < 3 jam menambah catatan, 3 dalam 30 hari = 7 hari tidak bisa gabung', () {
      final sessionStart = baseNow.add(const Duration(hours: 2));
      expect(
        HorasPolicies.shouldRecordLateLeaveMark(
          sessionStartTime: sessionStart,
          leaveTime: baseNow,
        ),
        isTrue,
      );

      // Tiga catatan dalam 30 hari terakhir -> dibatasi 7 hari
      final marks = <ReliabilityMark>[
        ReliabilityMark(
          id: 'm1',
          userId: 'u-01',
          sessionId: 's1',
          reason: ReliabilityMarkReason.lateLeaveUnder3Hours,
          createdAt: baseNow.subtract(const Duration(days: 10)),
        ),
        ReliabilityMark(
          id: 'm2',
          userId: 'u-01',
          sessionId: 's2',
          reason: ReliabilityMarkReason.noShowMarkedByHost,
          createdAt: baseNow.subtract(const Duration(days: 5)),
        ),
        ReliabilityMark(
          id: 'm3',
          userId: 'u-01',
          sessionId: 's3',
          reason: ReliabilityMarkReason.lateLeaveUnder3Hours,
          createdAt: baseNow.subtract(const Duration(days: 1)),
        ),
      ];
      final check = HorasPolicies.checkSessionJoinReliability(
        userMarks: marks,
        now: baseNow,
      );
      expect(check.isErr, isTrue);
      expect(
        (check as Err<void>).failure,
        isA<RateLimitedError>().having(
          (e) => e.retryAt,
          'retryAt',
          baseNow
              .subtract(const Duration(days: 1))
              .add(const Duration(days: 7)),
        ),
      );
    });

    test('Laporan 20/hari, Unduh data sekali/7 hari, 3 strike dalam 90 hari = suspend, Banding 14 hari, Hapus akun 30 hari (AC-12)', () {
      final reports20 = List<DateTime>.generate(
        20,
        (i) => baseNow.subtract(Duration(minutes: i + 1)),
      );
      expect(
        HorasPolicies.validateReportSubmission(
          note: 'Spam',
          reportsLast24h: reports20,
          hasActiveReportOnSameTarget: false,
          now: baseNow,
        ).isErr,
        isTrue,
      );

      expect(
        HorasPolicies.checkDataExportAllowed(
          now: baseNow,
          lastExportRequestedAt: baseNow.subtract(const Duration(days: 3)),
        ).isErr,
        isTrue,
      );

      final strikes3 = List<Strike>.generate(
        3,
        (i) => Strike(
          id: 'st-$i',
          userId: 'u-01',
          reason: 'Violation',
          createdAt: baseNow.subtract(Duration(days: i * 10)),
        ),
      );
      expect(
        HorasPolicies.shouldSuspendForStrikes(strikes: strikes3, now: baseNow),
        isTrue,
      );

      // Banding lewat 14 hari ditolak
      expect(
        HorasPolicies.validateSanctionAppeal(
          sanctionCreatedAt: baseNow.subtract(const Duration(days: 15)),
          now: baseNow,
        ).isErr,
        isTrue,
      );

      // AC-12: Hapus akun dibatalkan bila login dalam 30 hari; permanen pada hari ke-30
      final schedule = HorasPolicies.createAccountDeletionSchedule(
        id: 'del-1',
        userId: 'u-01',
        now: baseNow,
      );
      final loginDay10 = HorasPolicies.evaluateAccountDeletionOnTime(
        deletion: schedule,
        now: baseNow.add(const Duration(days: 10)),
        userLoggedIn: true,
      );
      expect(loginDay10.isCancelled, isTrue);

      final day30Expired = HorasPolicies.evaluateAccountDeletionOnTime(
        deletion: schedule,
        now: baseNow.add(const Duration(days: 30)),
        userLoggedIn: false,
      );
      expect(day30Expired.isPermanentlyDeleted, isTrue);
    });
  });
}
