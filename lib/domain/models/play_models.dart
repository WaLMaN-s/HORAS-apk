import 'package:horas/domain/models/user_models.dart';

/// Cabang olahraga sesi Main (MAN-R1).
enum SportType {
  badminton('Badminton'),
  futsal('Futsal'),
  volleyball('Voli'),
  basketball('Basket'),
  tableTennis('Tenis Meja'),
  jogging('Jogging'),
  other('Lainnya');

  const SportType(this.label);

  final String label;
}

/// Level kemampuan pemain di sesi Main (MAN-R1).
enum SkillLevel {
  beginner('Pemula'),
  intermediate('Menengah'),
  advanced('Mahir'),
  all('Semua Level');

  const SkillLevel(this.label);

  final String label;
}

/// Visibilitas sesi Main (MAN-R2).
enum SessionVisibility { publicInArea, communityOnly, inviteOnly }

/// Mode gabung sesi Main (MAN-R2).
enum SessionJoinMode { instant, hostApproval }

/// Status siklus hidup sesi Main (MAN-R9).
enum SessionStatus { upcoming, completed, cancelled }

/// Sesi olahraga / aktivitas bersama di modul Main (MAN-R1 .. MAN-R11).
final class PlaySession {
  const PlaySession({
    required this.id,
    required this.host,
    required this.sportType,
    required this.title,
    required this.city,
    required this.startTime,
    required this.endTime,
    required this.maxSlots,
    required this.skillLevel,
    required this.feePerPersonRupiah,
    required this.visibility,
    required this.joinMode,
    required this.createdAt,
    this.courtId,
    this.courtName,
    this.manualLocationSummary,
    this.manualLocationFullDetail,
    this.notes = '',
    this.communityId,
    this.status = SessionStatus.upcoming,
    this.participantCount = 1,
    this.waitlistCount = 0,
    this.isJoinedByMe = false,
    this.isUpdated = false,
    this.scheduleUpdatedAt,
    this.conversationId,
    this.isRecurring = false,
    this.recurringInterval,
  });

  final String id;
  final PersonSummary host;
  final SportType sportType;
  final String title;
  final String? courtId;
  final String? courtName;
  final String? manualLocationSummary;

  /// MAN-R8: Lokasi manual baru ditampilkan lengkap kepada peserta yang sudah bergabung.
  final String? manualLocationFullDetail;
  final String city;
  final DateTime startTime;
  final DateTime endTime;
  final int maxSlots;
  final SkillLevel skillLevel;
  final int feePerPersonRupiah;
  final String notes;
  final SessionVisibility visibility;
  final String? communityId;
  final SessionJoinMode joinMode;
  final SessionStatus status;
  final int participantCount;
  final int waitlistCount;
  final bool isJoinedByMe;
  final bool isUpdated;
  final DateTime? scheduleUpdatedAt;
  final String? conversationId;
  final bool isRecurring;
  final String? recurringInterval;
  final DateTime createdAt;

  /// Lokasi yang aman ditampilkan sesuai apakah pelihat sudah bergabung (MAN-R8).
  String get visibleVenueText {
    if (courtName != null && courtName!.isNotEmpty) {
      return courtName!;
    }
    if (isJoinedByMe &&
        manualLocationFullDetail != null &&
        manualLocationFullDetail!.isNotEmpty) {
      return manualLocationFullDetail!;
    }
    return manualLocationSummary ?? city;
  }

  PlaySession copyWith({
    PersonSummary? host,
    String? title,
    String? courtId,
    String? courtName,
    String? manualLocationSummary,
    String? manualLocationFullDetail,
    DateTime? startTime,
    DateTime? endTime,
    int? maxSlots,
    SkillLevel? skillLevel,
    int? feePerPersonRupiah,
    String? notes,
    SessionStatus? status,
    int? participantCount,
    int? waitlistCount,
    bool? isJoinedByMe,
    bool? isUpdated,
    DateTime? scheduleUpdatedAt,
    String? conversationId,
  }) {
    return PlaySession(
      id: id,
      host: host ?? this.host,
      sportType: sportType,
      title: title ?? this.title,
      courtId: courtId ?? this.courtId,
      courtName: courtName ?? this.courtName,
      manualLocationSummary:
          manualLocationSummary ?? this.manualLocationSummary,
      manualLocationFullDetail:
          manualLocationFullDetail ?? this.manualLocationFullDetail,
      city: city,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      maxSlots: maxSlots ?? this.maxSlots,
      skillLevel: skillLevel ?? this.skillLevel,
      feePerPersonRupiah: feePerPersonRupiah ?? this.feePerPersonRupiah,
      notes: notes ?? this.notes,
      visibility: visibility,
      communityId: communityId,
      joinMode: joinMode,
      status: status ?? this.status,
      participantCount: participantCount ?? this.participantCount,
      waitlistCount: waitlistCount ?? this.waitlistCount,
      isJoinedByMe: isJoinedByMe ?? this.isJoinedByMe,
      isUpdated: isUpdated ?? this.isUpdated,
      scheduleUpdatedAt: scheduleUpdatedAt ?? this.scheduleUpdatedAt,
      conversationId: conversationId ?? this.conversationId,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'host': host.toJson(),
    'sportType': sportType.name,
    'title': title,
    'courtId': courtId,
    'courtName': courtName,
    'manualLocationSummary': manualLocationSummary,
    'city': city,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'maxSlots': maxSlots,
    'skillLevel': skillLevel.name,
    'feePerPersonRupiah': feePerPersonRupiah,
    'notes': notes,
    'visibility': visibility.name,
    'communityId': communityId,
    'joinMode': joinMode.name,
    'status': status.name,
    'participantCount': participantCount,
    'waitlistCount': waitlistCount,
    'isJoinedByMe': isJoinedByMe,
    'isUpdated': isUpdated,
    'scheduleUpdatedAt': scheduleUpdatedAt?.toIso8601String(),
    'conversationId': conversationId,
    'isRecurring': isRecurring,
    'recurringInterval': recurringInterval,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Status keikutsertaan peserta di sesi Main (MAN-R2, MAN-R3).
enum ParticipantStatus { joined, pendingHostApproval, removed }

/// Peserta sesi Main beserta badge partuturan (MAN-R6).
final class Participant {
  const Participant({
    required this.id,
    required this.sessionId,
    required this.user,
    required this.status,
    required this.joinedAt,
    this.attended,
    this.promotedFromWaitlistAt,
  });

  final String id;
  final String sessionId;
  final PersonSummary user;
  final ParticipantStatus status;
  final bool? attended;
  final DateTime joinedAt;

  /// MAN-R3: jika naik dari daftar tunggu, boleh keluar tanpa catatan keandalan dalam 1 jam.
  final DateTime? promotedFromWaitlistAt;

  Participant copyWith({
    PersonSummary? user,
    ParticipantStatus? status,
    bool? attended,
    DateTime? promotedFromWaitlistAt,
  }) {
    return Participant(
      id: id,
      sessionId: sessionId,
      user: user ?? this.user,
      status: status ?? this.status,
      attended: attended ?? this.attended,
      joinedAt: joinedAt,
      promotedFromWaitlistAt:
          promotedFromWaitlistAt ?? this.promotedFromWaitlistAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sessionId': sessionId,
    'user': user.toJson(),
    'status': status.name,
    'attended': attended,
    'joinedAt': joinedAt.toIso8601String(),
    'promotedFromWaitlistAt': promotedFromWaitlistAt?.toIso8601String(),
  };
}

/// Entri daftar tunggu FIFO saat slot sesi penuh (MAN-R3, AC-08).
final class WaitlistEntry {
  const WaitlistEntry({
    required this.id,
    required this.sessionId,
    required this.user,
    required this.position,
    required this.enqueuedAt,
  });

  final String id;
  final String sessionId;
  final PersonSummary user;
  final int position;
  final DateTime enqueuedAt;

  WaitlistEntry copyWith({int? position}) {
    return WaitlistEntry(
      id: id,
      sessionId: sessionId,
      user: user,
      position: position ?? this.position,
      enqueuedAt: enqueuedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sessionId': sessionId,
    'user': user.toJson(),
    'position': position,
    'enqueuedAt': enqueuedAt.toIso8601String(),
  };
}

/// Alasan penambahan catatan keandalan (MAN-R4, AC-09).
enum ReliabilityMarkReason { lateLeaveUnder3Hours, noShowMarkedByHost }

/// Catatan keandalan peserta (terlihat oleh host, bukan publik — MAN-R4).
final class ReliabilityMark {
  const ReliabilityMark({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String sessionId;
  final ReliabilityMarkReason reason;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'sessionId': sessionId,
    'reason': reason.name,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Status moderasi lapangan olahraga (MAN-R10).
enum CourtModerationStatus { approved, pendingModeration, flaggedForReview }

/// Lapangan olahraga di modul Main (MAN-R10).
final class Court {
  const Court({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.supportedSports,
    required this.estimatedPriceText,
    required this.openingHours,
    this.imageSeed = 'court-default',
    this.wrongInfoReportCount = 0,
    this.status = CourtModerationStatus.approved,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final List<SportType> supportedSports;

  /// MAN-R10: perkiraan harga berlabel perkiraan.
  final String estimatedPriceText;
  final String openingHours;
  final String imageSeed;
  final int wrongInfoReportCount;
  final CourtModerationStatus status;
  final double? latitude;
  final double? longitude;

  Court copyWith({int? wrongInfoReportCount, CourtModerationStatus? status}) {
    return Court(
      id: id,
      name: name,
      address: address,
      city: city,
      supportedSports: supportedSports,
      estimatedPriceText: estimatedPriceText,
      openingHours: openingHours,
      imageSeed: imageSeed,
      wrongInfoReportCount: wrongInfoReportCount ?? this.wrongInfoReportCount,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'address': address,
    'city': city,
    'supportedSports': supportedSports
        .map((s) => s.name)
        .toList(growable: false),
    'estimatedPriceText': estimatedPriceText,
    'openingHours': openingHours,
    'imageSeed': imageSeed,
    'wrongInfoReportCount': wrongInfoReportCount,
    'status': status.name,
    'latitude': latitude,
    'longitude': longitude,
  };
}

/// Catatan patungan per peserta (pembayaran terjadi di luar aplikasi — MAN-R7).
final class PaymentShare {
  const PaymentShare({
    required this.id,
    required this.sessionId,
    required this.participant,
    required this.amountRupiah,
    required this.updatedAt,
    this.participantMarkedPaid = false,
    this.hostConfirmedPaid = false,
  });

  final String id;
  final String sessionId;
  final PersonSummary participant;
  final int amountRupiah;
  final bool participantMarkedPaid;
  final bool hostConfirmedPaid;
  final DateTime updatedAt;

  PaymentShare copyWith({
    int? amountRupiah,
    bool? participantMarkedPaid,
    bool? hostConfirmedPaid,
    DateTime? updatedAt,
  }) {
    return PaymentShare(
      id: id,
      sessionId: sessionId,
      participant: participant,
      amountRupiah: amountRupiah ?? this.amountRupiah,
      participantMarkedPaid:
          participantMarkedPaid ?? this.participantMarkedPaid,
      hostConfirmedPaid: hostConfirmedPaid ?? this.hostConfirmedPaid,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sessionId': sessionId,
    'participant': participant.toJson(),
    'amountRupiah': amountRupiah,
    'participantMarkedPaid': participantMarkedPaid,
    'hostConfirmedPaid': hostConfirmedPaid,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
