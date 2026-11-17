import 'package:horas/domain/models/user_models.dart';

/// Jenis percakapan di modul Pesan (PSN-R1, PSN-R5).
enum ConversationType { direct, communityGroup, sessionGroup, userGroup }

/// Durasi bisukan percakapan (PSN-R6).
enum MuteDurationOption {
  oneHour(Duration(hours: 1)),
  eightHours(Duration(hours: 8)),
  oneWeek(Duration(days: 7)),
  forever(Duration(days: 36500));

  const MuteDurationOption(this.duration);

  final Duration duration;
}

/// Status pengiriman dan keterbacaan pesan (PSN-R3).
enum MessageDeliveryStatus { sent, delivered, read }

/// Pesan di dalam percakapan pribadi atau grup (PSN-R3, PSN-R4, PSN-R8).
final class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.photoSeed,
    this.replyToMessageId,
    this.deliveryStatus = MessageDeliveryStatus.sent,
    this.isDeletedForEveryone = false,
    this.deletedForUserIds = const <String>[],
    this.hasScamWarning = false,
    this.isReported = false,
    this.isAnnouncement = false,
    this.moderatedRetainedUntil,
    this.voiceNoteSeed,
    this.voiceNoteDurationSeconds,
    this.stickerSeed,
  });

  final String id;
  final String conversationId;
  final PersonSummary sender;
  final String text;
  final String? photoSeed;
  final String? replyToMessageId;
  final MessageDeliveryStatus deliveryStatus;
  final bool isDeletedForEveryone;
  final List<String> deletedForUserIds;

  /// PSN-R8, AC-16: pesan pertama dari non-terhubung berisi tautan / permintaan uang.
  final bool hasScamWarning;
  final bool isReported;

  /// PSN-R5: pesan pengumuman admin grup yang disematkan.
  final bool isAnnouncement;

  /// PSN-R3 Fase 2: pesan suara (voice note).
  final String? voiceNoteSeed;
  final int? voiceNoteDurationSeconds;

  /// PSN-R3 Fase 2: stiker Batak.
  final String? stickerSeed;

  /// PSN-R4: pesan yang dilaporkan tetap tersimpan 30 hari untuk moderasi walau dihapus.
  final DateTime? moderatedRetainedUntil;
  final DateTime createdAt;

  Message copyWith({
    String? text,
    MessageDeliveryStatus? deliveryStatus,
    bool? isDeletedForEveryone,
    List<String>? deletedForUserIds,
    bool? isReported,
    bool? isAnnouncement,
    DateTime? moderatedRetainedUntil,
    String? voiceNoteSeed,
    int? voiceNoteDurationSeconds,
    String? stickerSeed,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      sender: sender,
      text: text ?? this.text,
      photoSeed: photoSeed,
      replyToMessageId: replyToMessageId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
      hasScamWarning: hasScamWarning,
      isReported: isReported ?? this.isReported,
      isAnnouncement: isAnnouncement ?? this.isAnnouncement,
      moderatedRetainedUntil:
          moderatedRetainedUntil ?? this.moderatedRetainedUntil,
      voiceNoteSeed: voiceNoteSeed ?? this.voiceNoteSeed,
      voiceNoteDurationSeconds:
          voiceNoteDurationSeconds ?? this.voiceNoteDurationSeconds,
      stickerSeed: stickerSeed ?? this.stickerSeed,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'conversationId': conversationId,
    'sender': sender.toJson(),
    'text': text,
    'photoSeed': photoSeed,
    'replyToMessageId': replyToMessageId,
    'deliveryStatus': deliveryStatus.name,
    'isDeletedForEveryone': isDeletedForEveryone,
    'deletedForUserIds': deletedForUserIds,
    'hasScamWarning': hasScamWarning,
    'isReported': isReported,
    'isAnnouncement': isAnnouncement,
    'moderatedRetainedUntil': moderatedRetainedUntil?.toIso8601String(),
    'voiceNoteSeed': voiceNoteSeed,
    'voiceNoteDurationSeconds': voiceNoteDurationSeconds,
    'stickerSeed': stickerSeed,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Percakapan pribadi atau grup (PSN-01, PSN-03, PSN-04, MAN-R9).
final class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    required this.participants,
    required this.updatedAt,
    this.communityId,
    this.sessionId,
    this.isReadOnly = false,
    this.mutedUntil,
    this.pinnedAnnouncement,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final ConversationType type;
  final String title;
  final List<PersonSummary> participants;
  final String? communityId;
  final String? sessionId;

  /// MAN-R9: chat grup sesi menjadi baca-saja 24 jam setelah sesi selesai.
  final bool isReadOnly;
  final DateTime? mutedUntil;
  final String? pinnedAnnouncement;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  Conversation copyWith({
    String? title,
    List<PersonSummary>? participants,
    bool? isReadOnly,
    DateTime? mutedUntil,
    bool clearMutedUntil = false,
    String? pinnedAnnouncement,
    Message? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id,
      type: type,
      title: title ?? this.title,
      participants: participants ?? this.participants,
      communityId: communityId,
      sessionId: sessionId,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      mutedUntil: clearMutedUntil ? null : (mutedUntil ?? this.mutedUntil),
      pinnedAnnouncement: pinnedAnnouncement ?? this.pinnedAnnouncement,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.name,
    'title': title,
    'participants': participants.map((p) => p.toJson()).toList(growable: false),
    'communityId': communityId,
    'sessionId': sessionId,
    'isReadOnly': isReadOnly,
    'mutedUntil': mutedUntil?.toIso8601String(),
    'pinnedAnnouncement': pinnedAnnouncement,
    'lastMessage': lastMessage?.toJson(),
    'unreadCount': unreadCount,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Status permintaan pesan dari konteks bersama (PSN-R2).
enum MessageRequestStatus { pending, accepted, deleted, blocked }

/// Permintaan pesan pertama dari orang yang belum terhubung namun berbagi komunitas/sesi (PSN-02, PSN-R2).
final class MessageRequest {
  const MessageRequest({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.receiverId,
    required this.firstMessage,
    required this.sharedContextDescription,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final PersonSummary sender;
  final String receiverId;
  final Message firstMessage;
  final String sharedContextDescription;
  final MessageRequestStatus status;
  final DateTime createdAt;

  MessageRequest copyWith({MessageRequestStatus? status}) {
    return MessageRequest(
      id: id,
      conversationId: conversationId,
      sender: sender,
      receiverId: receiverId,
      firstMessage: firstMessage,
      sharedContextDescription: sharedContextDescription,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'conversationId': conversationId,
    'sender': sender.toJson(),
    'receiverId': receiverId,
    'firstMessage': firstMessage.toJson(),
    'sharedContextDescription': sharedContextDescription,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };
}
