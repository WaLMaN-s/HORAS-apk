/// Jenis peristiwa notifikasi sesuai tabel PRD bagian 9.
enum NotificationType {
  connectionRequestReceived(canDisable: true),
  connectionAccepted(canDisable: true),
  newMessage(canDisable: true),
  messageRequestReceived(canDisable: true),
  postLikedOrCommented(canDisable: true),
  newFollower(canDisable: true),
  communityJoinRequest(canDisable: true),
  communityJoinApproved(canDisable: true),
  communityAnnouncement(canDisable: true),
  eventReminder(canDisable: true),
  sessionJoinOrWaitlistPromoted(canDisable: true),
  sessionUpdatedOrCancelled(canDisable: false),
  sessionReminder(canDisable: true),
  partuturanClaimReceived(canDisable: true),
  reportOutcome(canDisable: true),
  moderationAction(canDisable: false),
  accountSecurity(canDisable: false);

  const NotificationType({required this.canDisable});

  final bool canDisable;
}

/// Entitas Notifikasi dalam aplikasi (SIS-01, PRD bagian 9).
final class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String recipientId;
  final NotificationType type;
  final String title;
  final String body;
  final String deepLink;
  final bool isRead;
  final DateTime createdAt;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      deepLink: deepLink,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'recipientId': recipientId,
    'type': type.name,
    'title': title,
    'body': body,
    'deepLink': deepLink,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Jenis target laporan moderasi (SIS-R2).
enum ReportTargetType {
  user,
  post,
  comment,
  message,
  community,
  session,
  church,
  court,
}

/// Kategori laporan moderasi (SIS-R2).
enum ReportCategory {
  harassment('Pelecehan'),
  saraHateSpeech('SARA / Ujaran Kebencian'),
  spamScam('Spam / Penipuan'),
  inappropriateContent('Konten Tidak Pantas'),
  fakeIdentity('Identitas Palsu'),
  wrongPartuturanRule('Aturan Partuturan Salah'),
  other('Lainnya');

  const ReportCategory(this.label);

  final String label;
}

/// Status penanganan laporan (SIS-R3).
enum ReportStatus {
  received('Diterima'),
  inReview('Ditinjau'),
  completed('Selesai');

  const ReportStatus(this.label);

  final String label;
}

/// Hasil umum laporan yang telah selesai (SIS-R3).
enum ReportOutcome {
  actionTaken('Tindakan diambil'),
  noViolation('Tidak melanggar');

  const ReportOutcome(this.label);

  final String label;
}

/// Laporan pelanggaran oleh pengguna (SIS-02, SIS-03, SIS-R2, SIS-R3).
final class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.category,
    required this.status,
    required this.createdAt,
    this.note = '',
    this.outcome,
    this.resolvedAt,
  });

  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final ReportCategory category;
  final String note;
  final ReportStatus status;
  final ReportOutcome? outcome;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  Report copyWith({
    ReportStatus? status,
    ReportOutcome? outcome,
    DateTime? resolvedAt,
  }) {
    return Report(
      id: id,
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      category: category,
      note: note,
      status: status ?? this.status,
      outcome: outcome ?? this.outcome,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'reporterId': reporterId,
    'targetType': targetType.name,
    'targetId': targetId,
    'category': category.name,
    'note': note,
    'status': status.name,
    'outcome': outcome?.name,
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };
}

/// Catatan pelanggaran (strike) pada akun (3 strike dalam 90 hari = suspend — SIS-R4).
final class Strike {
  const Strike({
    required this.id,
    required this.userId,
    required this.reason,
    required this.createdAt,
    this.reportId,
  });

  final String id;
  final String userId;
  final String reason;
  final String? reportId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'reason': reason,
    'reportId': reportId,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Status pengajuan banding atas sanksi moderasi (SIS-R4).
enum AppealStatus { submitted, accepted, rejected }

/// Pengajuan banding sanksi moderasi dalam 14 hari (SIS-05, SIS-R4).
final class Appeal {
  const Appeal({
    required this.id,
    required this.userId,
    required this.sanctionCreatedAt,
    required this.reasonText,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final DateTime sanctionCreatedAt;
  final String reasonText;
  final AppealStatus status;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'sanctionCreatedAt': sanctionCreatedAt.toIso8601String(),
    'reasonText': reasonText,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Status pengajuan verifikasi komunitas (SIS-R6).
enum VerificationStatus {
  submitted('Diajukan'),
  needsAdditionalData('Perlu data tambahan'),
  approved('Disetujui'),
  rejected('Ditolak');

  const VerificationStatus(this.label);

  final String label;
}

/// Pengajuan verifikasi komunitas punguan (SIS-06, SIS-07, SIS-R6).
final class VerificationRequest {
  const VerificationRequest({
    required this.id,
    required this.requesterId,
    required this.communityId,
    required this.communityName,
    required this.evidenceDescription,
    required this.contactInfo,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  final String id;
  final String requesterId;
  final String communityId;
  final String communityName;
  final String evidenceDescription;
  final String contactInfo;
  final VerificationStatus status;
  final String? rejectionReason;
  final DateTime createdAt;

  VerificationRequest copyWith({
    VerificationStatus? status,
    String? rejectionReason,
  }) {
    return VerificationRequest(
      id: id,
      requesterId: requesterId,
      communityId: communityId,
      communityName: communityName,
      evidenceDescription: evidenceDescription,
      contactInfo: contactInfo,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'requesterId': requesterId,
    'communityId': communityId,
    'communityName': communityName,
    'evidenceDescription': evidenceDescription,
    'contactInfo': contactInfo,
    'status': status.name,
    'rejectionReason': rejectionReason,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Status pekerjaan unduh arsip data pribadi (AKN-R7).
enum DataExportStatus { processing, ready, expired }

/// Pekerjaan unduh data pribadi (maksimal sekali per 7 hari — AKN-13, AKN-R7).
final class DataExportJob {
  const DataExportJob({
    required this.id,
    required this.userId,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    this.downloadUrl,
  });

  final String id;
  final String userId;
  final DataExportStatus status;
  final String? downloadUrl;
  final DateTime requestedAt;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'status': status.name,
    'downloadUrl': downloadUrl,
    'requestedAt': requestedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };
}

/// Permintaan penghapusan akun dengan masa tunggu 30 hari (AKN-14, AKN-R8, AC-12).
final class AccountDeletion {
  const AccountDeletion({
    required this.id,
    required this.userId,
    required this.requestedAt,
    required this.scheduledPermanentDeletionAt,
    this.isCancelled = false,
    this.isPermanentlyDeleted = false,
  });

  final String id;
  final String userId;
  final DateTime requestedAt;
  final DateTime scheduledPermanentDeletionAt;
  final bool isCancelled;
  final bool isPermanentlyDeleted;

  AccountDeletion copyWith({bool? isCancelled, bool? isPermanentlyDeleted}) {
    return AccountDeletion(
      id: id,
      userId: userId,
      requestedAt: requestedAt,
      scheduledPermanentDeletionAt: scheduledPermanentDeletionAt,
      isCancelled: isCancelled ?? this.isCancelled,
      isPermanentlyDeleted: isPermanentlyDeleted ?? this.isPermanentlyDeleted,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'requestedAt': requestedAt.toIso8601String(),
    'scheduledPermanentDeletionAt': scheduledPermanentDeletionAt
        .toIso8601String(),
    'isCancelled': isCancelled,
    'isPermanentlyDeleted': isPermanentlyDeleted,
  };
}

/// Artikel pusat bantuan dan FAQ (SIS-04, SIS-R5).
final class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String id;
  final String category;
  final String question;
  final String answer;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'category': category,
    'question': question,
    'answer': answer,
  };
}

/// Preferensi notifikasi per jenis dan jam tenang 22.00-06.00 (AKN-10, AKN-R5, PRD 9).
///
/// Jenis dengan `canDisable == false` (keamanan akun, tindakan moderasi,
/// sesi diubah/dibatalkan) tidak dapat dinonaktifkan.
final class NotificationPreferences {
  const NotificationPreferences({
    this.disabledTypes = const <NotificationType>{},
    this.quietHoursEnabled = true,
  });

  final Set<NotificationType> disabledTypes;
  final bool quietHoursEnabled;

  bool isEnabled(NotificationType type) {
    if (!type.canDisable) return true;
    return !disabledTypes.contains(type);
  }

  NotificationPreferences setTypeEnabled(NotificationType type, bool enabled) {
    if (!type.canDisable) {
      // AKN-10 & PRD 9: Keamanan akun & tindakan moderasi terkunci aktif.
      return this;
    }
    final next = Set<NotificationType>.from(disabledTypes);
    if (enabled) {
      next.remove(type);
    } else {
      next.add(type);
    }
    return NotificationPreferences(
      disabledTypes: Set<NotificationType>.unmodifiable(next),
      quietHoursEnabled: quietHoursEnabled,
    );
  }

  NotificationPreferences copyWith({bool? quietHoursEnabled}) {
    return NotificationPreferences(
      disabledTypes: disabledTypes,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    );
  }
}

/// Entri riwayat masuk 30 hari terakhir (AKN-09, AKN-R4).
final class LoginHistoryEntry {
  const LoginHistoryEntry({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.platform,
    required this.city,
    required this.loggedInAt,
  });

  final String id;
  final String userId;
  final String deviceName;
  final String platform;
  final String city;
  final DateTime loggedInAt;
}

/// Tiket dukungan pelanggan dengan kategori dan lampiran opsional (SIS-05, SIS-R5).
final class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.category,
    required this.message,
    required this.createdAt,
    this.email,
    this.attachmentSeed,
  });

  final String id;
  final String userId;
  final String category;
  final String message;
  final String? email;
  final String? attachmentSeed;
  final DateTime createdAt;
}
