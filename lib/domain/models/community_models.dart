import 'package:horas/domain/models/user_models.dart';

/// Jenis komunitas di Sekitar (SEK-R7).
enum CommunityType {
  punguanMarga('Punguan Marga'),
  city('Kota'),
  campusOrProfession('Kampus/Profesi'),
  interest('Minat'),
  church('Gereja');

  const CommunityType(this.label);

  final String label;
}

/// Jenis akses komunitas (SEK-R7, AC-13).
enum CommunityAccessType { open, approvalRequired, closed }

/// Peran anggota di dalam komunitas (PRD 2.2, SEK-R8).
enum CommunityRole { owner, manager, member }

/// Entitas Komunitas (SEK-R7 .. SEK-R11).
final class Community {
  const Community({
    required this.id,
    required this.name,
    required this.type,
    required this.accessType,
    required this.city,
    required this.description,
    required this.avatarSeed,
    required this.ownerId,
    required this.createdAt,
    required this.lastManagerActiveAt,
    this.margaName,
    this.managerIds = const <String>[],
    this.memberCount = 1,
    this.isVerified = false,
    this.conversationId,
  });

  final String id;
  final String name;
  final CommunityType type;
  final CommunityAccessType accessType;
  final String city;
  final String? margaName;
  final String description;
  final String avatarSeed;
  final String ownerId;
  final List<String> managerIds;
  final int memberCount;

  /// SEK-R9: Komunitas Punguan marga berlencana Belum diverifikasi sampai SIS-06 disetujui.
  final bool isVerified;
  final String? conversationId;
  final DateTime createdAt;
  final DateTime lastManagerActiveAt;

  /// SEK-R8: Komunitas tanpa pengurus aktif 90 hari ditandai untuk ditinjau.
  bool isFlaggedInactive(DateTime now) =>
      now.difference(lastManagerActiveAt).inDays >= 90;

  Community copyWith({
    String? name,
    CommunityType? type,
    CommunityAccessType? accessType,
    String? city,
    String? margaName,
    String? description,
    String? avatarSeed,
    String? ownerId,
    List<String>? managerIds,
    int? memberCount,
    bool? isVerified,
    String? conversationId,
    DateTime? lastManagerActiveAt,
  }) {
    return Community(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      accessType: accessType ?? this.accessType,
      city: city ?? this.city,
      margaName: margaName ?? this.margaName,
      description: description ?? this.description,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      ownerId: ownerId ?? this.ownerId,
      managerIds: managerIds ?? this.managerIds,
      memberCount: memberCount ?? this.memberCount,
      isVerified: isVerified ?? this.isVerified,
      conversationId: conversationId ?? this.conversationId,
      createdAt: createdAt,
      lastManagerActiveAt: lastManagerActiveAt ?? this.lastManagerActiveAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'type': type.name,
    'accessType': accessType.name,
    'city': city,
    'margaName': margaName,
    'description': description,
    'avatarSeed': avatarSeed,
    'ownerId': ownerId,
    'managerIds': managerIds,
    'memberCount': memberCount,
    'isVerified': isVerified,
    'conversationId': conversationId,
    'createdAt': createdAt.toIso8601String(),
    'lastManagerActiveAt': lastManagerActiveAt.toIso8601String(),
  };
}

/// Keanggotaan komunitas beserta peran dan badge partuturan terhadap pelihat (SEK-R10).
final class Membership {
  const Membership({
    required this.id,
    required this.communityId,
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  final String id;
  final String communityId;
  final PersonSummary user;
  final CommunityRole role;
  final DateTime joinedAt;

  Membership copyWith({PersonSummary? user, CommunityRole? role}) {
    return Membership(
      id: id,
      communityId: communityId,
      user: user ?? this.user,
      role: role ?? this.role,
      joinedAt: joinedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'communityId': communityId,
    'user': user.toJson(),
    'role': role.name,
    'joinedAt': joinedAt.toIso8601String(),
  };
}

/// Status permintaan bergabung ke komunitas (SEK-R11).
enum JoinRequestStatus { pending, approved, rejected, expired }

/// Permintaan gabung ke komunitas berakses Dengan persetujuan (kedaluwarsa 14 hari — SEK-R11).
final class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.communityId,
    required this.applicant,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String communityId;
  final PersonSummary applicant;
  final JoinRequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  JoinRequest copyWith({JoinRequestStatus? status}) {
    return JoinRequest(
      id: id,
      communityId: communityId,
      applicant: applicant,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'communityId': communityId,
    'applicant': applicant.toJson(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };
}

/// Pengumuman komunitas (maksimal 3 disematkan — SEK-R10).
final class Announcement {
  const Announcement({
    required this.id,
    required this.communityId,
    required this.author,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isPinned = false,
  });

  final String id;
  final String communityId;
  final PersonSummary author;
  final String title;
  final String body;
  final bool isPinned;
  final DateTime createdAt;

  Announcement copyWith({bool? isPinned}) {
    return Announcement(
      id: id,
      communityId: communityId,
      author: author,
      title: title,
      body: body,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'communityId': communityId,
    'author': author.toJson(),
    'title': title,
    'body': body,
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Status RSVP kehadiran kegiatan komunitas/gereja (SEK-09, SEK-R12).
enum EventRsvpStatus { none, hadir, mungkin, tidak }

/// Kegiatan komunitas atau gereja di Fase 2 (SEK-09, SEK-R12).
final class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.communityId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    this.communityName = '',
    this.mapLink,
    this.capacity,
    this.myRsvp = EventRsvpStatus.none,
    this.attendeeCount = 0,
    this.isCancelled = false,
  });

  final String id;
  final String communityId;
  final String communityName;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String locationName;
  final String? mapLink;
  final int? capacity;
  final EventRsvpStatus myRsvp;
  final int attendeeCount;
  final bool isCancelled;

  bool get isPast => DateTime.now().isAfter(endTime);

  CommunityEvent copyWith({
    EventRsvpStatus? myRsvp,
    int? attendeeCount,
    bool? isCancelled,
  }) {
    return CommunityEvent(
      id: id,
      communityId: communityId,
      communityName: communityName,
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      locationName: locationName,
      mapLink: mapLink,
      capacity: capacity,
      myRsvp: myRsvp ?? this.myRsvp,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'communityId': communityId,
    'communityName': communityName,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'locationName': locationName,
    'mapLink': mapLink,
    'capacity': capacity,
    'myRsvp': myRsvp.name,
    'attendeeCount': attendeeCount,
    'isCancelled': isCancelled,
  };

  factory CommunityEvent.fromJson(Map<String, Object?> json) {
    EventRsvpStatus parseRsvp(String? raw) {
      for (final s in EventRsvpStatus.values) {
        if (s.name == raw) return s;
      }
      return EventRsvpStatus.none;
    }

    return CommunityEvent(
      id: (json['id'] as String?) ?? '',
      communityId: (json['communityId'] as String?) ?? '',
      communityName: (json['communityName'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      startTime:
          DateTime.tryParse((json['startTime'] as String?) ?? '') ??
          DateTime.now(),
      endTime:
          DateTime.tryParse((json['endTime'] as String?) ?? '') ??
          DateTime.now().add(const Duration(hours: 2)),
      locationName: (json['locationName'] as String?) ?? '',
      mapLink: json['mapLink'] as String?,
      capacity: json['capacity'] as int?,
      myRsvp: parseRsvp(json['myRsvp'] as String?),
      attendeeCount: (json['attendeeCount'] as int?) ?? 0,
      isCancelled: (json['isCancelled'] as bool?) ?? false,
    );
  }
}

/// Peserta yang merespons RSVP kegiatan (SEK-09, SEK-R12).
final class EventAttendee {
  const EventAttendee({
    required this.id,
    required this.eventId,
    required this.user,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String eventId;
  final PersonSummary user;
  final EventRsvpStatus status;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'eventId': eventId,
    'user': user.toJson(),
    'status': status.name,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Denominasi gereja Batak (SEK-10, SEK-11, SEK-R13).
enum ChurchDenomination {
  hkbp('HKBP'),
  gkpi('GKPI'),
  hki('HKI'),
  gkps('GKPS'),
  gbkp('GBKP'),
  lainnya('Lainnya');

  const ChurchDenomination(this.label);
  final String label;
}

/// Jadwal ibadah gereja (hari, jam, bahasa pengantar).
final class ChurchServiceSchedule {
  const ChurchServiceSchedule({
    required this.dayOfWeek,
    required this.time,
    required this.language,
  });

  final String dayOfWeek;
  final String time;
  final String language;

  Map<String, Object?> toJson() => <String, Object?>{
    'dayOfWeek': dayOfWeek,
    'time': time,
    'language': language,
  };

  factory ChurchServiceSchedule.fromJson(Map<String, Object?> json) {
    return ChurchServiceSchedule(
      dayOfWeek: (json['dayOfWeek'] as String?) ?? 'Minggu',
      time: (json['time'] as String?) ?? '09.00 WIB',
      language: (json['language'] as String?) ?? 'Batak Toba',
    );
  }
}

/// Direktori dan entitas gereja di Sekitar (SEK-10, SEK-11, SEK-R13).
final class Church {
  const Church({
    required this.id,
    required this.name,
    required this.denomination,
    required this.address,
    required this.city,
    required this.serviceSchedules,
    this.contactPhone = '',
    this.contactEmail = '',
    this.isVerified = false,
    this.memberCount = 0,
    this.isUserHomeChurch = false,
    this.isHomeChurchVisible = false,
  });

  final String id;
  final String name;
  final ChurchDenomination denomination;
  final String address;
  final String city;
  final List<ChurchServiceSchedule> serviceSchedules;
  final String contactPhone;
  final String contactEmail;
  final bool isVerified;
  final int memberCount;
  final bool isUserHomeChurch;
  final bool isHomeChurchVisible;

  /// SEK-R13: Jumlah jemaat di HORAS hanya tampil bila minimal 5 orang.
  bool get canDisplayMemberCount => memberCount >= 5;

  Church copyWith({
    bool? isVerified,
    int? memberCount,
    bool? isUserHomeChurch,
    bool? isHomeChurchVisible,
  }) {
    return Church(
      id: id,
      name: name,
      denomination: denomination,
      address: address,
      city: city,
      serviceSchedules: serviceSchedules,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      isVerified: isVerified ?? this.isVerified,
      memberCount: memberCount ?? this.memberCount,
      isUserHomeChurch: isUserHomeChurch ?? this.isUserHomeChurch,
      isHomeChurchVisible: isHomeChurchVisible ?? this.isHomeChurchVisible,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'denomination': denomination.name,
    'address': address,
    'city': city,
    'serviceSchedules': serviceSchedules.map((s) => s.toJson()).toList(),
    'contactPhone': contactPhone,
    'contactEmail': contactEmail,
    'isVerified': isVerified,
    'memberCount': memberCount,
    'isUserHomeChurch': isUserHomeChurch,
    'isHomeChurchVisible': isHomeChurchVisible,
  };

  factory Church.fromJson(Map<String, Object?> json) {
    ChurchDenomination parseDenom(String? raw) {
      for (final d in ChurchDenomination.values) {
        if (d.name == raw) return d;
      }
      return ChurchDenomination.hkbp;
    }

    final rawSched = json['serviceSchedules'];
    final schedules = <ChurchServiceSchedule>[];
    if (rawSched is List<Object?>) {
      for (final s in rawSched) {
        if (s is Map<String, Object?>) {
          schedules.add(ChurchServiceSchedule.fromJson(s));
        }
      }
    }

    return Church(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      denomination: parseDenom(json['denomination'] as String?),
      address: (json['address'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      serviceSchedules: schedules,
      contactPhone: (json['contactPhone'] as String?) ?? '',
      contactEmail: (json['contactEmail'] as String?) ?? '',
      isVerified: (json['isVerified'] as bool?) ?? false,
      memberCount: (json['memberCount'] as int?) ?? 0,
      isUserHomeChurch: (json['isUserHomeChurch'] as bool?) ?? false,
      isHomeChurchVisible: (json['isHomeChurchVisible'] as bool?) ?? false,
    );
  }
}
