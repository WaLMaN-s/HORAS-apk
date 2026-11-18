import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/domain/models/sub_ethnic.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';

/// Rentang kedekatan area aman privasi — TIDAK PERNAH jarak presisi km (SEK-R2, AC-07).
enum AreaProximity {
  diKotamu('DiKotamu', AppStrings.areaSameCity),
  diKecamatanmu('DiKecamatanmu', AppStrings.areaSameSubdistrict);

  const AreaProximity(this.jsonCode, this.displayLabel);

  final String jsonCode;
  final String displayLabel;

  static AreaProximity fromJson(String? raw) {
    return raw == 'DiKecamatanmu'
        ? AreaProximity.diKecamatanmu
        : AreaProximity.diKotamu;
  }
}

/// Status akun pengguna (AUT, SIS-R4).
enum AccountStatus { active, restricted, suspended, permanentlyBanned }

/// Pengaturan privasi lengkap sesuai PRD 7.1 beserta nilai bawaan ketat.
final class PrivacySettings {
  const PrivacySettings({
    this.motherMarga = FieldVisibility.connectedOnly,
    this.showAgeGroup = false,
    this.subdistrict = FieldVisibility.connectedOnly,
    this.joinedCommunities = FieldVisibility.connectedOnly,
    this.homeChurch = FieldVisibility.onlyMe,
    this.tarombo = FieldVisibility.onlyMe,
    this.discoverableInNearbyAndSearch = true,
    this.whoCanSendConnectionRequest = ConnectionRequestAllowance.everyone,
    this.allowMessagesFromSharedContext = true,
    this.sendReadReceipts = true,
    this.accountType = AccountVisibilityType.publicAccount,
  });

  final FieldVisibility motherMarga;
  final bool showAgeGroup;
  final FieldVisibility subdistrict;
  final FieldVisibility joinedCommunities;
  final FieldVisibility homeChurch;
  final FieldVisibility tarombo;
  final bool discoverableInNearbyAndSearch;
  final ConnectionRequestAllowance whoCanSendConnectionRequest;
  final bool allowMessagesFromSharedContext;
  final bool sendReadReceipts;
  final AccountVisibilityType accountType;

  PrivacySettings copyWith({
    FieldVisibility? motherMarga,
    bool? showAgeGroup,
    FieldVisibility? subdistrict,
    FieldVisibility? joinedCommunities,
    FieldVisibility? homeChurch,
    FieldVisibility? tarombo,
    bool? discoverableInNearbyAndSearch,
    ConnectionRequestAllowance? whoCanSendConnectionRequest,
    bool? allowMessagesFromSharedContext,
    bool? sendReadReceipts,
    AccountVisibilityType? accountType,
  }) {
    return PrivacySettings(
      motherMarga: motherMarga ?? this.motherMarga,
      showAgeGroup: showAgeGroup ?? this.showAgeGroup,
      subdistrict: subdistrict ?? this.subdistrict,
      joinedCommunities: joinedCommunities ?? this.joinedCommunities,
      homeChurch: homeChurch ?? this.homeChurch,
      tarombo: tarombo ?? this.tarombo,
      discoverableInNearbyAndSearch:
          discoverableInNearbyAndSearch ?? this.discoverableInNearbyAndSearch,
      whoCanSendConnectionRequest:
          whoCanSendConnectionRequest ?? this.whoCanSendConnectionRequest,
      allowMessagesFromSharedContext:
          allowMessagesFromSharedContext ?? this.allowMessagesFromSharedContext,
      sendReadReceipts: sendReadReceipts ?? this.sendReadReceipts,
      accountType: accountType ?? this.accountType,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'motherMarga': motherMarga.name,
    'showAgeGroup': showAgeGroup,
    'subdistrict': subdistrict.name,
    'joinedCommunities': joinedCommunities.name,
    'homeChurch': homeChurch.name,
    'tarombo': tarombo.name,
    'discoverableInNearbyAndSearch': discoverableInNearbyAndSearch,
    'whoCanSendConnectionRequest': whoCanSendConnectionRequest.name,
    'allowMessagesFromSharedContext': allowMessagesFromSharedContext,
    'sendReadReceipts': sendReadReceipts,
    'accountType': accountType.name,
  };

  factory PrivacySettings.fromJson(Map<String, Object?> json) {
    FieldVisibility parseVis(String? raw, FieldVisibility fallback) {
      for (final v in FieldVisibility.values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    ConnectionRequestAllowance parseAllowance(String? raw) {
      for (final a in ConnectionRequestAllowance.values) {
        if (a.name == raw) return a;
      }
      return ConnectionRequestAllowance.everyone;
    }

    return PrivacySettings(
      motherMarga: parseVis(
        json['motherMarga'] as String?,
        FieldVisibility.connectedOnly,
      ),
      showAgeGroup: (json['showAgeGroup'] as bool?) ?? false,
      subdistrict: parseVis(
        json['subdistrict'] as String?,
        FieldVisibility.connectedOnly,
      ),
      joinedCommunities: parseVis(
        json['joinedCommunities'] as String?,
        FieldVisibility.connectedOnly,
      ),
      homeChurch: parseVis(
        json['homeChurch'] as String?,
        FieldVisibility.onlyMe,
      ),
      tarombo: parseVis(json['tarombo'] as String?, FieldVisibility.onlyMe),
      discoverableInNearbyAndSearch:
          (json['discoverableInNearbyAndSearch'] as bool?) ?? true,
      whoCanSendConnectionRequest: parseAllowance(
        json['whoCanSendConnectionRequest'] as String?,
      ),
      allowMessagesFromSharedContext:
          (json['allowMessagesFromSharedContext'] as bool?) ?? true,
      sendReadReceipts: (json['sendReadReceipts'] as bool?) ?? true,
      accountType:
          (json['accountType'] as String?) ==
              AccountVisibilityType.privateAccount.name
          ? AccountVisibilityType.privateAccount
          : AccountVisibilityType.publicAccount,
    );
  }
}

/// Profil milik sendiri (AKN-01, AUT-R5).
///
/// Hanya digunakan untuk sesi pengguna yang sedang login; TIDAK PERNAH dikirim
/// sebagai DTO profil orang lain.
final class Profil {
  const Profil({
    required this.id,
    required this.phoneE164,
    required this.displayName,
    required this.gender,
    required this.birthYear,
    required this.marga,
    required this.subEthnic,
    required this.city,
    required this.subdistrict,
    required this.avatarSeed,
    required this.createdAt,
    this.email,
    this.motherMarga,
    this.bio = '',
    this.hobbies = const <String>[],
    this.campusOrOffice,
    this.websiteUrl,
    this.homeChurchName,
    this.sundut,
    this.isMargaVerified = true,
    this.onboardingStep = 4,
    this.onboardingCompleted = true,
    this.followersCount = 0,
    this.followingCount = 0,
    this.connectionsCount = 0,
    this.lastDisplayNameChangedAt,
    this.accountStatus = AccountStatus.active,
    this.privacySettings = const PrivacySettings(),
  });

  final String id;
  final String phoneE164;
  final String? email;
  final String displayName;
  final UserGender gender;
  final int birthYear;
  final String marga;
  final SubEthnic subEthnic;
  final String? motherMarga;
  final String city;
  final String subdistrict;
  final String avatarSeed;
  final String bio;
  final List<String> hobbies;
  final String? campusOrOffice;
  final String? websiteUrl;
  final String? homeChurchName;
  final int? sundut;
  final bool isMargaVerified;
  final int onboardingStep;
  final bool onboardingCompleted;
  final int followersCount;
  final int followingCount;
  final int connectionsCount;
  final DateTime createdAt;
  final DateTime? lastDisplayNameChangedAt;
  final AccountStatus accountStatus;
  final PrivacySettings privacySettings;

  Profil copyWith({
    String? phoneE164,
    String? email,
    String? displayName,
    UserGender? gender,
    int? birthYear,
    String? marga,
    SubEthnic? subEthnic,
    String? motherMarga,
    String? city,
    String? subdistrict,
    String? avatarSeed,
    String? bio,
    List<String>? hobbies,
    String? campusOrOffice,
    String? websiteUrl,
    String? homeChurchName,
    int? sundut,
    bool? isMargaVerified,
    int? onboardingStep,
    bool? onboardingCompleted,
    int? followersCount,
    int? followingCount,
    int? connectionsCount,
    DateTime? createdAt,
    DateTime? lastDisplayNameChangedAt,
    AccountStatus? accountStatus,
    PrivacySettings? privacySettings,
  }) {
    return Profil(
      id: id,
      phoneE164: phoneE164 ?? this.phoneE164,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      marga: marga ?? this.marga,
      subEthnic: subEthnic ?? this.subEthnic,
      motherMarga: motherMarga ?? this.motherMarga,
      city: city ?? this.city,
      subdistrict: subdistrict ?? this.subdistrict,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      bio: bio ?? this.bio,
      hobbies: hobbies ?? this.hobbies,
      campusOrOffice: campusOrOffice ?? this.campusOrOffice,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      homeChurchName: homeChurchName ?? this.homeChurchName,
      sundut: sundut ?? this.sundut,
      isMargaVerified: isMargaVerified ?? this.isMargaVerified,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      connectionsCount: connectionsCount ?? this.connectionsCount,
      createdAt: createdAt ?? this.createdAt,
      lastDisplayNameChangedAt:
          lastDisplayNameChangedAt ?? this.lastDisplayNameChangedAt,
      accountStatus: accountStatus ?? this.accountStatus,
      privacySettings: privacySettings ?? this.privacySettings,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'phoneE164': phoneE164,
    'email': email,
    'displayName': displayName,
    'gender': gender.jsonCode,
    'birthYear': birthYear,
    'marga': marga,
    'subEthnic': subEthnic.name,
    'motherMarga': motherMarga,
    'city': city,
    'subdistrict': subdistrict,
    'avatarSeed': avatarSeed,
    'bio': bio,
    'hobbies': hobbies,
    'campusOrOffice': campusOrOffice,
    'websiteUrl': websiteUrl,
    'homeChurchName': homeChurchName,
    'sundut': sundut,
    'isMargaVerified': isMargaVerified,
    'onboardingStep': onboardingStep,
    'onboardingCompleted': onboardingCompleted,
    'followersCount': followersCount,
    'followingCount': followingCount,
    'connectionsCount': connectionsCount,
    'createdAt': createdAt.toIso8601String(),
    'lastDisplayNameChangedAt': lastDisplayNameChangedAt?.toIso8601String(),
    'accountStatus': accountStatus.name,
    'privacySettings': privacySettings.toJson(),
  };

  factory Profil.fromJson(Map<String, Object?> json) {
    SubEthnic parseSubEthnic(String? raw) {
      for (final s in SubEthnic.values) {
        if (s.name == raw) return s;
      }
      return SubEthnic.toba;
    }

    AccountStatus parseStatus(String? raw) {
      for (final s in AccountStatus.values) {
        if (s.name == raw) return s;
      }
      return AccountStatus.active;
    }

    return Profil(
      id: (json['id'] as String?) ?? '',
      phoneE164: (json['phoneE164'] as String?) ?? '+628120000000',
      email: json['email'] as String?,
      displayName: (json['displayName'] as String?) ?? '',
      gender: UserGender.fromJson(json['gender'] as String?),
      birthYear: (json['birthYear'] as int?) ?? 1995,
      marga: (json['marga'] as String?) ?? 'Simanjuntak',
      subEthnic: parseSubEthnic(json['subEthnic'] as String?),
      motherMarga: json['motherMarga'] as String?,
      city: (json['city'] as String?) ?? 'Medan',
      subdistrict: (json['subdistrict'] as String?) ?? 'Medan Baru',
      avatarSeed: PersonSummary.resolveAvatarSeed(
        (json['avatarSeed'] as String?) ?? (json['avatar_seed'] as String?),
        (json['avatarPath'] as String?) ?? (json['avatar_path'] as String?),
      ),
      bio: (json['bio'] as String?) ?? '',
      hobbies: ((json['hobbies'] as List<Object?>?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      campusOrOffice: json['campusOrOffice'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      homeChurchName: json['homeChurchName'] as String?,
      sundut: json['sundut'] as int?,
      isMargaVerified: (json['isMargaVerified'] as bool?) ?? true,
      onboardingStep: (json['onboardingStep'] as int?) ?? 4,
      onboardingCompleted: (json['onboardingCompleted'] as bool?) ?? true,
      followersCount: (json['followersCount'] as int?) ?? 0,
      followingCount: (json['followingCount'] as int?) ?? 0,
      connectionsCount: (json['connectionsCount'] as int?) ?? 0,
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.utc(2026, 1, 1),
      lastDisplayNameChangedAt: json['lastDisplayNameChangedAt'] != null
          ? DateTime.tryParse(json['lastDisplayNameChangedAt'] as String)
          : null,
      accountStatus: parseStatus(json['accountStatus'] as String?),
      privacySettings: json['privacySettings'] is Map<String, Object?>
          ? PrivacySettings.fromJson(
              json['privacySettings'] as Map<String, Object?>,
            )
          : const PrivacySettings(),
    );
  }
}

/// DTO profil orang lain yang telah disaring privasi (SEK-R2, SEK-R4, AC-07).
///
/// LARANGAN MUTLAK PRD:
/// TIDAK PERNAH memiliki field nomor HP, tahun lahir, usia pasti, koordinat,
/// atau jarak presisi (km). Jarak hanya berupa [AreaProximity] (`DiKotamu`, `DiKecamatanmu`).
final class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.displayName,
    required this.gender,
    required this.marga,
    required this.subEthnic,
    required this.city,
    required this.proximity,
    required this.avatarSeed,
    this.sharedCommunitiesCount = 0,
    this.isSameMarga = false,
    this.partuturan,
    this.visibleMotherMarga,
    this.visibleSubdistrict,
    this.visibleAgeGroup,
    this.visibleHomeChurch,
    this.bio = '',
    this.hobbies = const <String>[],
    this.campusOrOffice,
    this.websiteUrl,
    this.isPrivateAccount = false,
    this.isFollowing = false,
    this.isConnected = false,
    this.canMessage = false,
  });

  final String id;
  final String displayName;
  final UserGender gender;
  final String marga;
  final SubEthnic subEthnic;
  final String city;
  final AreaProximity proximity;
  final String avatarSeed;
  final int sharedCommunitiesCount;
  final bool isSameMarga;
  final PartuturanResult? partuturan;

  /// Hanya terisi apabila pengaturan privasi pemilik mengizinkannya untuk pelihat (PRD 7.1).
  final String? visibleMotherMarga;
  final String? visibleSubdistrict;

  /// Kelompok rentang usia (contoh: `'25-34'`), bukan usia pasti atau tahun lahir (PRD 7.1).
  final String? visibleAgeGroup;
  final String? visibleHomeChurch;
  final String bio;
  final List<String> hobbies;
  final String? campusOrOffice;
  final String? websiteUrl;
  final bool isPrivateAccount;
  final bool isFollowing;
  final bool isConnected;
  final bool canMessage;

  PersonSummary copyWith({
    String? displayName,
    UserGender? gender,
    String? marga,
    SubEthnic? subEthnic,
    String? city,
    AreaProximity? proximity,
    String? avatarSeed,
    int? sharedCommunitiesCount,
    bool? isSameMarga,
    PartuturanResult? partuturan,
    String? visibleMotherMarga,
    String? visibleSubdistrict,
    String? visibleAgeGroup,
    String? visibleHomeChurch,
    String? bio,
    List<String>? hobbies,
    String? campusOrOffice,
    String? websiteUrl,
    bool? isPrivateAccount,
    bool? isFollowing,
    bool? isConnected,
    bool? canMessage,
  }) {
    return PersonSummary(
      id: id,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      marga: marga ?? this.marga,
      subEthnic: subEthnic ?? this.subEthnic,
      city: city ?? this.city,
      proximity: proximity ?? this.proximity,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      sharedCommunitiesCount:
          sharedCommunitiesCount ?? this.sharedCommunitiesCount,
      isSameMarga: isSameMarga ?? this.isSameMarga,
      partuturan: partuturan ?? this.partuturan,
      visibleMotherMarga: visibleMotherMarga ?? this.visibleMotherMarga,
      visibleSubdistrict: visibleSubdistrict ?? this.visibleSubdistrict,
      visibleAgeGroup: visibleAgeGroup ?? this.visibleAgeGroup,
      visibleHomeChurch: visibleHomeChurch ?? this.visibleHomeChurch,
      bio: bio ?? this.bio,
      hobbies: hobbies ?? this.hobbies,
      campusOrOffice: campusOrOffice ?? this.campusOrOffice,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
      isFollowing: isFollowing ?? this.isFollowing,
      isConnected: isConnected ?? this.isConnected,
      canMessage: canMessage ?? this.canMessage,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'displayName': displayName,
    'gender': gender.jsonCode,
    'marga': marga,
    'subEthnic': subEthnic.name,
    'city': city,
    'proximity': proximity.jsonCode,
    'avatarSeed': avatarSeed,
    'sharedCommunitiesCount': sharedCommunitiesCount,
    'isSameMarga': isSameMarga,
    'partuturan': partuturan?.toJson(),
    'visibleMotherMarga': visibleMotherMarga,
    'visibleSubdistrict': visibleSubdistrict,
    'visibleAgeGroup': visibleAgeGroup,
    'visibleHomeChurch': visibleHomeChurch,
    'bio': bio,
    'hobbies': hobbies,
    'campusOrOffice': campusOrOffice,
    'websiteUrl': websiteUrl,
    'isPrivateAccount': isPrivateAccount,
    'isFollowing': isFollowing,
    'isConnected': isConnected,
    'canMessage': canMessage,
  };

  static String resolveAvatarSeed(String? seed, String? path) {
    bool isReal(String? v) =>
        v != null &&
        (v.startsWith('data:image/') ||
            v.startsWith('http://') ||
            v.startsWith('https://'));
    if (isReal(seed)) return seed!;
    if (isReal(path)) return path!;
    if (seed != null && seed.trim().isNotEmpty && seed != 'avatar') {
      return seed;
    }
    if (path != null && path.trim().isNotEmpty) {
      return path;
    }
    return (seed != null && seed.trim().isNotEmpty) ? seed : 'avatar';
  }

  factory PersonSummary.fromJson(Map<String, Object?> json) {
    SubEthnic parseSubEthnic(String? raw) {
      for (final s in SubEthnic.values) {
        if (s.name == raw) return s;
      }
      return SubEthnic.toba;
    }

    final rawSeed =
        (json['avatarSeed'] as String?) ?? (json['avatar_seed'] as String?);
    final rawPath =
        (json['avatarPath'] as String?) ?? (json['avatar_path'] as String?);

    return PersonSummary(
      id: (json['id'] as String?) ?? '',
      displayName:
          (json['displayName'] as String?) ??
          (json['display_name'] as String?) ??
          '',
      gender: UserGender.fromJson(json['gender'] as String?),
      marga: (json['marga'] as String?) ?? '',
      subEthnic: parseSubEthnic(
        (json['subEthnic'] as String?) ?? (json['sub_ethnic'] as String?),
      ),
      city: (json['city'] as String?) ?? '',
      proximity: AreaProximity.fromJson(json['proximity'] as String?),
      avatarSeed: resolveAvatarSeed(rawSeed, rawPath),
      sharedCommunitiesCount: (json['sharedCommunitiesCount'] as int?) ?? 0,
      isSameMarga: (json['isSameMarga'] as bool?) ?? false,
      partuturan: json['partuturan'] is Map<String, Object?>
          ? PartuturanResult.fromJson(
              json['partuturan'] as Map<String, Object?>,
            )
          : null,
      visibleMotherMarga: json['visibleMotherMarga'] as String?,
      visibleSubdistrict: json['visibleSubdistrict'] as String?,
      visibleAgeGroup: json['visibleAgeGroup'] as String?,
      visibleHomeChurch: json['visibleHomeChurch'] as String?,
      bio: (json['bio'] as String?) ?? '',
      hobbies: ((json['hobbies'] as List<Object?>?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      campusOrOffice: json['campusOrOffice'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      isPrivateAccount: (json['isPrivateAccount'] as bool?) ?? false,
      isFollowing: (json['isFollowing'] as bool?) ?? false,
      isConnected: (json['isConnected'] as bool?) ?? false,
      canMessage: (json['canMessage'] as bool?) ?? false,
    );
  }
}

/// Perangkat aktif pengguna (AUT-R9, AKN-R4).
final class Device {
  const Device({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.platform,
    required this.loggedInAt,
    required this.lastActiveAt,
    this.isCurrent = false,
  });

  final String id;
  final String userId;
  final String deviceName;
  final String platform;
  final DateTime loggedInAt;
  final DateTime lastActiveAt;
  final bool isCurrent;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'deviceName': deviceName,
    'platform': platform,
    'loggedInAt': loggedInAt.toIso8601String(),
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'isCurrent': isCurrent,
  };
}

/// Hubungan satu arah Ikuti (PRD 6.3).
final class Follow {
  const Follow({
    required this.id,
    required this.followerId,
    required this.followeeId,
    required this.createdAt,
    this.isPendingApproval = false,
  });

  final String id;
  final String followerId;
  final String followeeId;
  final DateTime createdAt;
  final bool isPendingApproval;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'followerId': followerId,
    'followeeId': followeeId,
    'createdAt': createdAt.toIso8601String(),
    'isPendingApproval': isPendingApproval,
  };
}

/// Status permintaan Kenalan (SEK-R5).
enum ConnectionRequestStatus { pending, accepted, rejected, expired }

/// Permintaan Kenalan dua arah (SEK-R5, AC-05).
final class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.introMessage,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  final String id;
  final PersonSummary sender;
  final PersonSummary receiver;
  final String introMessage;
  final ConnectionRequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  ConnectionRequest copyWith({
    ConnectionRequestStatus? status,
    DateTime? respondedAt,
  }) {
    return ConnectionRequest(
      id: id,
      sender: sender,
      receiver: receiver,
      introMessage: introMessage,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sender': sender.toJson(),
    'receiver': receiver.toJson(),
    'introMessage': introMessage,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
  };
}

/// Hubungan Terhubung / Kenalan aktif (PRD 6.3).
final class Connection {
  const Connection({
    required this.id,
    required this.userId,
    required this.friend,
    required this.connectedAt,
  });

  final String id;
  final String userId;
  final PersonSummary friend;
  final DateTime connectedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'friend': friend.toJson(),
    'connectedAt': connectedAt.toIso8601String(),
  };
}

/// Pemblokiran pengguna (AKN-R6, AC-11).
final class Block {
  const Block({
    required this.id,
    required this.blockerId,
    required this.blockedUser,
    required this.createdAt,
  });

  final String id;
  final String blockerId;
  final PersonSummary blockedUser;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'blockerId': blockerId,
    'blockedUser': blockedUser.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Entri master marga baku (AUT-R6).
final class MargaEntry {
  const MargaEntry({
    required this.name,
    required this.subEthnic,
    this.isVerified = true,
  });

  final String name;
  final SubEthnic subEthnic;
  final bool isVerified;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'subEthnic': subEthnic.name,
    'isVerified': isVerified,
  };
}

/// Data kota dan daftar kecamatan dari `assets/data/wilayah.json`.
final class WilayahCity {
  const WilayahCity({
    required this.id,
    required this.name,
    required this.province,
    required this.subdistricts,
  });

  final String id;
  final String name;
  final String province;
  final List<String> subdistricts;

  factory WilayahCity.fromJson(Map<String, Object?> json) {
    return WilayahCity(
      id: ((json['id'] as String?) ?? '').trim(),
      name: (json['name'] as String?) ?? '',
      province: (json['province'] as String?) ?? '',
      subdistricts:
          ((json['subdistricts'] as List<Object?>?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'province': province,
    'subdistricts': subdistricts,
  };
}

/// Catatan persetujuan dokumen hukum dan pernyataan usia 17+ beserta versi & waktu (AUT-04, AUT-R4).
final class LegalConsentRecord {
  const LegalConsentRecord({
    required this.version,
    required this.acceptedPrivacyAndTermsAt,
    required this.acceptedCommunityGuidelinesAt,
    required this.confirmedAge17PlusAt,
  });

  final String version;
  final DateTime acceptedPrivacyAndTermsAt;
  final DateTime acceptedCommunityGuidelinesAt;
  final DateTime confirmedAge17PlusAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'acceptedPrivacyAndTermsAt': acceptedPrivacyAndTermsAt.toIso8601String(),
    'acceptedCommunityGuidelinesAt': acceptedCommunityGuidelinesAt
        .toIso8601String(),
    'confirmedAge17PlusAt': confirmedAge17PlusAt.toIso8601String(),
  };

  factory LegalConsentRecord.fromJson(Map<String, Object?> json) {
    final fallback = DateTime.utc(2026, 11, 16);
    return LegalConsentRecord(
      version: (json['version'] as String?) ?? '1.0.0-draft',
      acceptedPrivacyAndTermsAt:
          DateTime.tryParse(
            (json['acceptedPrivacyAndTermsAt'] as String?) ?? '',
          ) ??
          fallback,
      acceptedCommunityGuidelinesAt:
          DateTime.tryParse(
            (json['acceptedCommunityGuidelinesAt'] as String?) ?? '',
          ) ??
          fallback,
      confirmedAge17PlusAt:
          DateTime.tryParse((json['confirmedAge17PlusAt'] as String?) ?? '') ??
          fallback,
    );
  }
}

/// Draf progres Onboarding 4 langkah yang disimpan per langkah agar dapat dilanjutkan
/// apabila aplikasi ditutup di tengah jalan (AUT-06, AUT-R5).
final class OnboardingDraft {
  const OnboardingDraft({
    this.currentStep = 1,
    this.displayName = '',
    this.photoSeedOrPath,
    this.gender = UserGender.male,
    this.birthYear = 1998,
    this.marga = '',
    this.isCustomMarga = false,
    this.subEthnic = SubEthnic.toba,
    this.motherMarga = '',
    this.city = 'Medan',
    this.subdistrict = 'Medan Baru',
    this.hobbies = const <String>[],
    this.campusOrOffice = '',
    this.showPermissionExplainer = false,
  });

  final int currentStep;
  final String displayName;
  final String? photoSeedOrPath;
  final UserGender gender;
  final int birthYear;
  final String marga;
  final bool isCustomMarga;
  final SubEthnic subEthnic;
  final String motherMarga;
  final String city;
  final String subdistrict;
  final List<String> hobbies;
  final String campusOrOffice;
  final bool showPermissionExplainer;

  OnboardingDraft copyWith({
    int? currentStep,
    String? displayName,
    String? photoSeedOrPath,
    UserGender? gender,
    int? birthYear,
    String? marga,
    bool? isCustomMarga,
    SubEthnic? subEthnic,
    String? motherMarga,
    String? city,
    String? subdistrict,
    List<String>? hobbies,
    String? campusOrOffice,
    bool? showPermissionExplainer,
  }) {
    return OnboardingDraft(
      currentStep: currentStep ?? this.currentStep,
      displayName: displayName ?? this.displayName,
      photoSeedOrPath: photoSeedOrPath ?? this.photoSeedOrPath,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      marga: marga ?? this.marga,
      isCustomMarga: isCustomMarga ?? this.isCustomMarga,
      subEthnic: subEthnic ?? this.subEthnic,
      motherMarga: motherMarga ?? this.motherMarga,
      city: city ?? this.city,
      subdistrict: subdistrict ?? this.subdistrict,
      hobbies: hobbies ?? this.hobbies,
      campusOrOffice: campusOrOffice ?? this.campusOrOffice,
      showPermissionExplainer:
          showPermissionExplainer ?? this.showPermissionExplainer,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'currentStep': currentStep,
    'displayName': displayName,
    'photoSeedOrPath': photoSeedOrPath,
    'gender': gender.jsonCode,
    'birthYear': birthYear,
    'marga': marga,
    'isCustomMarga': isCustomMarga,
    'subEthnic': subEthnic.name,
    'motherMarga': motherMarga,
    'city': city,
    'subdistrict': subdistrict,
    'hobbies': hobbies,
    'campusOrOffice': campusOrOffice,
    'showPermissionExplainer': showPermissionExplainer,
  };

  factory OnboardingDraft.fromJson(Map<String, Object?> json) {
    SubEthnic parseSubEthnic(String? raw) {
      for (final s in SubEthnic.values) {
        if (s.name == raw) return s;
      }
      return SubEthnic.toba;
    }

    return OnboardingDraft(
      currentStep: ((json['currentStep'] as int?) ?? 1).clamp(1, 4),
      displayName: (json['displayName'] as String?) ?? '',
      photoSeedOrPath: json['photoSeedOrPath'] as String?,
      gender: UserGender.fromJson(json['gender'] as String?),
      birthYear: (json['birthYear'] as int?) ?? 1998,
      marga: (json['marga'] as String?) ?? '',
      isCustomMarga: (json['isCustomMarga'] as bool?) ?? false,
      subEthnic: parseSubEthnic(json['subEthnic'] as String?),
      motherMarga: (json['motherMarga'] as String?) ?? '',
      city: (json['city'] as String?) ?? 'Medan',
      subdistrict: (json['subdistrict'] as String?) ?? 'Medan Baru',
      hobbies: ((json['hobbies'] as List<Object?>?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      campusOrOffice: (json['campusOrOffice'] as String?) ?? '',
      showPermissionExplainer:
          (json['showPermissionExplainer'] as bool?) ?? false,
    );
  }
}

/// Pengajuan pemulihan akun saat nomor lama hilang (AUT-07, AUT-R8b).
final class AccountRecoverySubmission {
  const AccountRecoverySubmission({
    required this.id,
    required this.oldPhoneE164,
    required this.newPhoneE164,
    required this.approximateRegistrationPeriod,
    required this.marga,
    required this.knownFriendsText,
    required this.statusLabel,
    required this.submittedAt,
  });

  final String id;
  final String oldPhoneE164;
  final String newPhoneE164;
  final String approximateRegistrationPeriod;
  final String marga;
  final String knownFriendsText;
  final String statusLabel;
  final DateTime submittedAt;
}
