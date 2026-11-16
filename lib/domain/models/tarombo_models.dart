import 'package:horas/domain/models/user_models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';

/// Peran anggota keluarga pada pohon silsilah ringkas 3 generasi (TAR-03, TAR-R11, TAR-R12).
enum FamilyRelationType {
  father('Ayah', 1),
  mother('Ibu', 1),
  paternalGrandfather('Kakek dari Ayah (Ompung Suhut)', 2),
  maternalGrandfather('Kakek dari Ibu (Ompung Bao)', 2),
  otherAncestor('Leluhur Lainnya', 2);

  const FamilyRelationType(this.label, this.generationsAbove);

  final String label;
  final int generationsAbove;
}

/// Status hidup / almarhum anggota tarombo (TAR-R3).
enum LifeStatus {
  alive('Hidup'),
  deceased('Almarhum/Almarhumah');

  const LifeStatus(this.label);

  final String label;
}

/// Anggota silsilah keluarga pada Tarombo milik pengguna (TAR-R3, TAR-R4).
///
/// Hanya terlihat oleh pemilik dan pihak yang disetujui; tidak dapat dicari publik.
final class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.ownerUserId,
    required this.relationType,
    required this.fullName,
    required this.marga,
    required this.gender,
    required this.lifeStatus,
    this.birthYear,
    this.linkedUserId,
  });

  final String id;
  final String ownerUserId;
  final FamilyRelationType relationType;
  final String fullName;
  final String marga;
  final UserGender gender;
  final int? birthYear;
  final LifeStatus lifeStatus;
  final String? linkedUserId;

  FamilyMember copyWith({
    String? fullName,
    String? marga,
    UserGender? gender,
    int? birthYear,
    LifeStatus? lifeStatus,
    String? linkedUserId,
  }) {
    return FamilyMember(
      id: id,
      ownerUserId: ownerUserId,
      relationType: relationType,
      fullName: fullName ?? this.fullName,
      marga: marga ?? this.marga,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      lifeStatus: lifeStatus ?? this.lifeStatus,
      linkedUserId: linkedUserId ?? this.linkedUserId,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'ownerUserId': ownerUserId,
    'relationType': relationType.name,
    'fullName': fullName,
    'marga': marga,
    'gender': gender.jsonCode,
    'birthYear': birthYear,
    'lifeStatus': lifeStatus.name,
    'linkedUserId': linkedUserId,
  };
}

/// Status klaim konfirmasi hubungan kerabat (TAR-R7).
enum PartuturanClaimStatus { pending, accepted, rejected }

/// Klaim pengakuan kerabat "Kami kerabat" antara dua pengguna (TAR-07, TAR-R7).
///
/// Bila diterima kedua pihak, tingkat keyakinan pasangan naik menjadi Tinggi.
final class PartuturanClaim {
  const PartuturanClaim({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.claimedTermForReceiver,
    required this.status,
    required this.createdAt,
    this.note,
    this.respondedAt,
  });

  final String id;
  final PersonSummary sender;
  final PersonSummary receiver;
  final String claimedTermForReceiver;
  final String? note;
  final PartuturanClaimStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  PartuturanClaim copyWith({
    PartuturanClaimStatus? status,
    DateTime? respondedAt,
  }) {
    return PartuturanClaim(
      id: id,
      sender: sender,
      receiver: receiver,
      claimedTermForReceiver: claimedTermForReceiver,
      note: note,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sender': sender.toJson(),
    'receiver': receiver.toJson(),
    'claimedTermForReceiver': claimedTermForReceiver,
    'note': note,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
  };
}

/// Umpan balik tombol "Bukan" pada hasil partuturan Sedang/Rendah (TAR-R8).
///
/// Disimpan sebagai sinyal tinjauan untuk reviewer adat, tidak mengubah aturan otomatis.
final class PartuturanFeedback {
  const PartuturanFeedback({
    required this.id,
    required this.userId,
    required this.viewerMarga,
    required this.targetMarga,
    required this.shownTerm,
    required this.ruleVersion,
    required this.createdAt,
    this.suggestedTerm,
    this.note,
  });

  final String id;
  final String userId;
  final String viewerMarga;
  final String targetMarga;
  final String? shownTerm;
  final String? suggestedTerm;
  final String? note;
  final String ruleVersion;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'viewerMarga': viewerMarga,
    'targetMarga': targetMarga,
    'shownTerm': shownTerm,
    'suggestedTerm': suggestedTerm,
    'note': note,
    'ruleVersion': ruleVersion,
    'createdAt': createdAt.toIso8601String(),
  };
}
