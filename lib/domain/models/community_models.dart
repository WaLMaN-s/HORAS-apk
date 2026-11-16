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
