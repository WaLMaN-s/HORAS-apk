/// Tabel batas angka dan kuota sistem sesuai PRD 6 & 7.2.
abstract final class AppLimits {
  // Autentikasi (AUT-R1..R9, PRD 7.2)
  static const int otpDigits = 6;
  static const Duration otpValidity = Duration(minutes: 5);
  static const Duration otpResendCooldown = Duration(seconds: 60);
  static const int otpMaxWrongAttempts = 5;
  static const int otpMaxRequestsPerHour = 5;
  static const Duration otpLockoutDuration = Duration(hours: 1);
  static const int maxActiveDevices = 3;
  static const int minAgeYears = 17;
  static const int displayNameMinChars = 2;
  static const int displayNameMaxChars = 40;

  // Beranda (BER-R2, BER-R5, BER-R10, PRD 7.2)
  static const int maxPostsPer24Hours = 20;
  static const int postTextMaxChars = 2000;
  static const int postMaxPhotos = 10;
  static const int postPhotoMaxBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxCommentsPerHour = 60;
  static const int commentMaxChars = 1000;
  static const int newAccountExternalLinkHoldDays = 7;

  // Sekitar & Komunitas (SEK-R1..R11, PRD 7.2)
  static const int nearbyPageSize = 20;
  static const int maxDailyFollows = 200;
  static const int maxDailyConnectionRequests = 10;
  static const int connectionIntroMaxChars = 200;
  static const int connectionRequestExpiryDays = 30;
  static const int connectionCooldownAfterRejectDays = 30;
  static const int minAccountAgeDaysToCreateCommunity = 7;
  static const int maxCommunitiesCreatedPerAccount = 5;
  static const int maxCommunityManagers = 10;
  static const int maxPinnedAnnouncements = 3;
  static const int communityNameMinChars = 3;
  static const int communityNameMaxChars = 60;
  static const int communityDescMaxChars = 500;
  static const int communityJoinRequestExpiryDays = 14;

  // Main (MAN-R1..R11, PRD 7.2)
  static const int maxActiveSessionsPerHost = 5;
  static const int sessionMinSlots = 2;
  static const int sessionMaxSlots = 50;
  static const int sessionMaxFeeRupiah = 1000000;
  static const int sessionRoundingStepRupiah = 500;
  static const int sessionNoteMaxChars = 300;
  static const int reliabilityMarksThreshold = 3;
  static const int reliabilityWindowDays = 30;
  static const int reliabilityRestrictionDays = 7;
  static const int quietHoursStartHour = 22;
  static const int quietHoursEndHour = 6;

  // Pesan (PSN-R3..R9, PRD 7.2)
  static const int messageTextMaxChars = 2000;
  static const int messagePhotoMaxBytes = 5 * 1024 * 1024; // 5 MB
  static const Duration deleteForEveryoneWindow = Duration(hours: 1);
  static const int maxDailyFirstMessagesToNewPeople = 20;

  // Akun & Sistem (AKN-R1..R8, SIS-R1..R4, PRD 7.2)
  static const int bioMaxChars = 150;
  static const int displayNameChangeCooldownDays = 30;
  static const int dataExportCooldownDays = 7;
  static const int accountDeletionGraceDays = 30;
  static const int maxDailyReports = 20;
  static const int reportNoteMaxChars = 500;
  static const int sanctionAppealWindowDays = 14;
  static const int strikesThresholdForSuspension = 3;
  static const int strikesWindowDays = 90;
}
