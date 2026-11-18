import 'package:horas/domain/models/sub_ethnic.dart';
import 'package:horas/domain/models/user_models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';

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
    this.isVideo = false,
    this.durationSeconds = 0,
  });

  final String id;
  final String postId;
  final String seed;
  final int orderIndex;
  final double aspectRatio;
  final bool exifLocationStripped;
  final Map<String, String> metadata;
  final bool isVideo;
  final int durationSeconds;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'postId': postId,
    'seed': seed,
    'orderIndex': orderIndex,
    'aspectRatio': aspectRatio,
    'exifLocationStripped': exifLocationStripped,
    'metadata': metadata,
    'isVideo': isVideo,
    'durationSeconds': durationSeconds,
  };

  factory PostMedia.fromJson(Map<String, Object?> json) {
    final rawMeta = json['metadata'];
    final safeMeta = <String, String>{};
    if (rawMeta is Map<Object?, Object?>) {
      for (final e in rawMeta.entries) {
        safeMeta[e.key.toString()] = e.value.toString();
      }
    }
    return PostMedia(
      id: (json['id'] as String?) ?? '',
      postId: (json['postId'] as String?) ?? '',
      seed: (json['seed'] as String?) ?? '',
      orderIndex: (json['orderIndex'] as int?) ?? 0,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1.0,
      exifLocationStripped: (json['exifLocationStripped'] as bool?) ?? true,
      metadata: safeMeta,
      isVideo: (json['isVideo'] as bool?) ?? false,
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
    );
  }
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

  factory Post.fromJson(Map<String, Object?> json) {
    PostVisibility parseVis(String? raw) {
      for (final v in PostVisibility.values) {
        if (v.name == raw) return v;
      }
      return PostVisibility.publicPost;
    }

    PostModerationStatus parseMod(String? raw) {
      for (final m in PostModerationStatus.values) {
        if (m.name == raw) return m;
      }
      return PostModerationStatus.published;
    }

    return Post(
      id: (json['id'] as String?) ?? '',
      author: json['author'] is Map<String, Object?>
          ? PersonSummary.fromJson(json['author'] as Map<String, Object?>)
          : const PersonSummary(
              id: '',
              displayName: '',
              gender: UserGender.male,
              marga: '',
              subEthnic: SubEthnic.toba,
              city: '',
              proximity: AreaProximity.diKotamu,
              avatarSeed: '',
            ),
      text: (json['text'] as String?) ?? '',
      media: ((json['media'] as List<Object?>?) ?? const <Object?>[])
          .whereType<Map<String, Object?>>()
          .map(PostMedia.fromJson)
          .toList(growable: false),
      visibility: parseVis(json['visibility'] as String?),
      communityIds:
          ((json['communityIds'] as List<Object?>?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      cityTag: json['cityTag'] as String?,
      isEdited: (json['isEdited'] as bool?) ?? false,
      commentsDisabled: (json['commentsDisabled'] as bool?) ?? false,
      moderationStatus: parseMod(json['moderationStatus'] as String?),
      likeCount: (json['likeCount'] as int?) ?? 0,
      commentCount: (json['commentCount'] as int?) ?? 0,
      isLikedByMe: (json['isLikedByMe'] as bool?) ?? false,
      isSavedByMe: (json['isSavedByMe'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.utc(2026, 11, 16),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  List<String> get hashtags {
    final exp = RegExp(r'#([A-Za-z0-9_]+)');
    return exp
        .allMatches(text)
        .map((m) => m.group(1) ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

/// Draf postingan yang tersimpan bila unggahan gagal (Alur A6, BER-04).
final class PostDraft {
  const PostDraft({
    this.text = '',
    this.mediaSeeds = const <String>[],
    this.mediaSizesBytes = const <int>[],
    this.mediaAspectRatios = const <double>[],
    this.visibility = PostVisibility.publicPost,
    this.communityIds = const <String>[],
    this.cityTag,
  });

  final String text;
  final List<String> mediaSeeds;
  final List<int> mediaSizesBytes;
  final List<double> mediaAspectRatios;
  final PostVisibility visibility;
  final List<String> communityIds;
  final String? cityTag;

  bool get isEmpty => text.trim().isEmpty && mediaSeeds.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'text': text,
    'mediaSeeds': mediaSeeds,
    'mediaSizesBytes': mediaSizesBytes,
    'mediaAspectRatios': mediaAspectRatios,
    'visibility': visibility.name,
    'communityIds': communityIds,
    'cityTag': cityTag,
  };

  factory PostDraft.fromJson(Map<String, Object?> json) {
    PostVisibility parseVis(String? raw) {
      for (final v in PostVisibility.values) {
        if (v.name == raw) return v;
      }
      return PostVisibility.publicPost;
    }

    return PostDraft(
      text: (json['text'] as String?) ?? '',
      mediaSeeds: ((json['mediaSeeds'] as List<Object?>?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      mediaSizesBytes:
          ((json['mediaSizesBytes'] as List<Object?>?) ?? const <Object?>[])
              .whereType<int>()
              .toList(growable: false),
      mediaAspectRatios:
          ((json['mediaAspectRatios'] as List<Object?>?) ?? const <Object?>[])
              .whereType<num>()
              .map((e) => e.toDouble())
              .toList(growable: false),
      visibility: parseVis(json['visibility'] as String?),
      communityIds:
          ((json['communityIds'] as List<Object?>?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      cityTag: json['cityTag'] as String?,
    );
  }
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

/// Cerita singkat 24 jam di Beranda (BER-02, BER-03, BER-R12).
final class Story {
  const Story({
    required this.id,
    required this.author,
    required this.mediaSeed,
    required this.createdAt,
    required this.expiresAt,
    this.caption = '',
    this.isVideo = false,
    this.durationSeconds = 5,
    this.viewerCount = 0,
    this.isViewedByMe = false,
  });

  final String id;
  final PersonSummary author;
  final String mediaSeed;
  final String caption;
  final bool isVideo;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewerCount;
  final bool isViewedByMe;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Story copyWith({int? viewerCount, bool? isViewedByMe}) {
    return Story(
      id: id,
      author: author,
      mediaSeed: mediaSeed,
      caption: caption,
      isVideo: isVideo,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      expiresAt: expiresAt,
      viewerCount: viewerCount ?? this.viewerCount,
      isViewedByMe: isViewedByMe ?? this.isViewedByMe,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'author': author.toJson(),
    'mediaSeed': mediaSeed,
    'caption': caption,
    'isVideo': isVideo,
    'durationSeconds': durationSeconds,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'viewerCount': viewerCount,
    'isViewedByMe': isViewedByMe,
  };

  factory Story.fromJson(Map<String, Object?> json) {
    final authorMap = json['author'];
    final fallbackAuthorId = (json['author_id'] as String?) ?? '';
    return Story(
      id: (json['id'] as String?) ?? '',
      author: authorMap is Map
          ? PersonSummary.fromJson(
              authorMap.map((k, v) => MapEntry(k.toString(), v)),
            )
          : PersonSummary(
              id: fallbackAuthorId,
              displayName: '',
              gender: UserGender.male,
              marga: '',
              subEthnic: SubEthnic.toba,
              city: '',
              proximity: AreaProximity.diKotamu,
              avatarSeed: '',
            ),
      mediaSeed:
          (json['mediaSeed'] as String?) ??
          (json['media_seed'] as String?) ??
          '',
      caption: (json['caption'] as String?) ?? '',
      isVideo:
          (json['isVideo'] as bool?) ?? (json['is_video'] as bool?) ?? false,
      durationSeconds:
          (json['durationSeconds'] as int?) ??
          (json['duration_seconds'] as int?) ??
          5,
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] as String?) ??
                (json['created_at'] as String?) ??
                '',
          ) ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(
            (json['expiresAt'] as String?) ??
                (json['expires_at'] as String?) ??
                '',
          ) ??
          DateTime.now().add(const Duration(hours: 24)),
      viewerCount:
          (json['viewerCount'] as int?) ?? (json['viewer_count'] as int?) ?? 0,
      isViewedByMe:
          (json['isViewedByMe'] as bool?) ??
          (json['is_viewed_by_me'] as bool?) ??
          false,
    );
  }
}

/// Riwayat penonton story yang hanya dapat dilihat pembuat (BER-R12).
final class StoryViewer {
  const StoryViewer({
    required this.id,
    required this.storyId,
    required this.viewer,
    required this.viewedAt,
  });

  final String id;
  final String storyId;
  final PersonSummary viewer;
  final DateTime viewedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'storyId': storyId,
    'viewer': viewer.toJson(),
    'viewedAt': viewedAt.toIso8601String(),
  };

  factory StoryViewer.fromJson(Map<String, Object?> json) {
    final viewerMap = json['viewer'];
    return StoryViewer(
      id: (json['id'] as String?) ?? '',
      storyId:
          (json['storyId'] as String?) ?? (json['story_id'] as String?) ?? '',
      viewer: viewerMap is Map
          ? PersonSummary.fromJson(
              viewerMap.map((k, v) => MapEntry(k.toString(), v)),
            )
          : PersonSummary(
              id: (json['viewer_id'] as String?) ?? '',
              displayName: '',
              gender: UserGender.male,
              marga: '',
              subEthnic: SubEthnic.toba,
              city: '',
              proximity: AreaProximity.diKotamu,
              avatarSeed: '',
            ),
      viewedAt:
          DateTime.tryParse(
            (json['viewedAt'] as String?) ??
                (json['viewed_at'] as String?) ??
                '',
          ) ??
          DateTime.now(),
    );
  }
}
