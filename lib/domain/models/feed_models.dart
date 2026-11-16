import 'package:horas/domain/models/user_models.dart';

/// Visibilitas postingan Beranda (BER-R3).
enum PostVisibility { publicPost, followersOnly, specificCommunities }

/// Status moderasi postingan (BER-R10, BER-R11).
enum PostModerationStatus { published, underReview, removed }

/// Media foto dalam postingan dengan jaminan EXIF lokasi telah dihapus (BER-R4, AC-10).
final class PostMedia {
  const PostMedia({
    required this.id,
    required this.postId,
    required this.seed,
    required this.orderIndex,
    this.aspectRatio = 1.0,
    this.exifLocationStripped = true,
    this.metadata = const <String, String>{},
  });

  final String id;
  final String postId;
  final String seed;
  final int orderIndex;
  final double aspectRatio;
  final bool exifLocationStripped;
  final Map<String, String> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'postId': postId,
    'seed': seed,
    'orderIndex': orderIndex,
    'aspectRatio': aspectRatio,
    'exifLocationStripped': exifLocationStripped,
    'metadata': metadata,
  };
}

/// Postingan di Beranda (BER-R1 .. BER-R11).
final class Post {
  const Post({
    required this.id,
    required this.author,
    required this.text,
    required this.media,
    required this.visibility,
    required this.createdAt,
    this.communityIds = const <String>[],
    this.cityTag,
    this.isEdited = false,
    this.commentsDisabled = false,
    this.moderationStatus = PostModerationStatus.published,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
    this.isSavedByMe = false,
    this.updatedAt,
  });

  final String id;
  final PersonSummary author;
  final String text;
  final List<PostMedia> media;
  final PostVisibility visibility;
  final List<String> communityIds;

  /// Tag lokasi opsional hanya level kota (BER-R4).
  final String? cityTag;
  final bool isEdited;
  final bool commentsDisabled;
  final PostModerationStatus moderationStatus;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final bool isSavedByMe;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Post copyWith({
    PersonSummary? author,
    String? text,
    List<PostMedia>? media,
    PostVisibility? visibility,
    List<String>? communityIds,
    String? cityTag,
    bool? isEdited,
    bool? commentsDisabled,
    PostModerationStatus? moderationStatus,
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
    bool? isSavedByMe,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id,
      author: author ?? this.author,
      text: text ?? this.text,
      media: media ?? this.media,
      visibility: visibility ?? this.visibility,
      communityIds: communityIds ?? this.communityIds,
      cityTag: cityTag ?? this.cityTag,
      isEdited: isEdited ?? this.isEdited,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'author': author.toJson(),
    'text': text,
    'media': media.map((m) => m.toJson()).toList(growable: false),
    'visibility': visibility.name,
    'communityIds': communityIds,
    'cityTag': cityTag,
    'isEdited': isEdited,
    'commentsDisabled': commentsDisabled,
    'moderationStatus': moderationStatus.name,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'isLikedByMe': isLikedByMe,
    'isSavedByMe': isSavedByMe,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

/// Komentar postingan dengan dukungan balasan satu tingkat (BER-R5).
final class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.text,
    required this.createdAt,
    this.parentCommentId,
  });

  final String id;
  final String postId;
  final String? parentCommentId;
  final PersonSummary author;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'postId': postId,
    'parentCommentId': parentCommentId,
    'author': author.toJson(),
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Suka pada postingan (BER-R6).
final class Like {
  const Like({
    required this.id,
    required this.postId,
    required this.user,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final PersonSummary user;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'postId': postId,
    'user': user.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Postingan yang disimpan pengguna (BER-R9, AKN-04).
final class SavedPost {
  const SavedPost({
    required this.id,
    required this.userId,
    required this.post,
    required this.savedAt,
  });

  final String id;
  final String userId;
  final Post post;
  final DateTime savedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'post': post.toJson(),
    'savedAt': savedAt.toIso8601String(),
  };
}
