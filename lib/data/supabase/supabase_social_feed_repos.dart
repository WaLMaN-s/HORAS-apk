import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/data/supabase/supabase_error_mapper.dart';
import 'package:horas/data/supabase/supabase_gateway.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/repositories/repositories.dart';

/// 4. Implementasi Supabase untuk [FollowRepository].
final class SupabaseFollowRepository implements FollowRepository {
  SupabaseFollowRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<Follow>> followUser(String targetUserId) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'follow_user',
      params: <String, Object?>{'p_target_id': targetUserId},
    );
    _gw.invalidatePersonCache(targetUserId);
    return Follow(
      id: row['id'] as String,
      followerId: row['follower_id'] as String,
      followeeId: row['followee_id'] as String,
      createdAt:
          SupabaseGateway.parseDate(row['created_at']) ?? _gw.currentTime,
    );
  });

  @override
  Future<Result<void>> unfollowUser(String targetUserId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return;
    await _gw.client
        .from('follows')
        .delete()
        .eq('follower_id', uid)
        .eq('followee_id', targetUserId);
    _gw.invalidatePersonCache(targetUserId);
  });

  @override
  Future<Result<Follow?>> getFollowStatus(String targetUserId) =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return null;
        final row = await _gw.client
            .from('follows')
            .select()
            .eq('follower_id', uid)
            .eq('followee_id', targetUserId)
            .maybeSingle();
        if (row == null) return null;
        return Follow(
          id: row['id'] as String,
          followerId: row['follower_id'] as String,
          followeeId: row['followee_id'] as String,
          createdAt:
              SupabaseGateway.parseDate(row['created_at']) ?? _gw.currentTime,
        );
      });

  @override
  Future<Result<List<PersonSummary>>> getFollowers(String userId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('follows')
            .select('follower_id')
            .eq('followee_id', userId)
            .order('created_at', ascending: false);
        final ids = rows.map((r) => r['follower_id'] as String).toList();
        final map = await _gw.getBatchPersonSummaries(ids);
        return ids.map((id) => map[id]!).toList(growable: false);
      });

  @override
  Future<Result<List<PersonSummary>>> getFollowing(String userId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('follows')
            .select('followee_id')
            .eq('follower_id', userId)
            .order('created_at', ascending: false);
        final ids = rows.map((r) => r['followee_id'] as String).toList();
        final map = await _gw.getBatchPersonSummaries(ids);
        return ids.map((id) => map[id]!).toList(growable: false);
      });
}

/// 5. Implementasi Supabase untuk [ConnectionRepository] (AC-05).
final class SupabaseConnectionRepository implements ConnectionRepository {
  SupabaseConnectionRepository(this._gw);

  final SupabaseGateway _gw;

  ConnectionRequestStatus _parseReqStatus(String? raw) => switch (raw) {
    'accepted' => ConnectionRequestStatus.accepted,
    'rejected' => ConnectionRequestStatus.rejected,
    'expired' => ConnectionRequestStatus.expired,
    _ => ConnectionRequestStatus.pending,
  };

  Future<List<ConnectionRequest>> _hydrateRequests(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = <String>{};
    for (final r in rows) {
      ids.add(r['requester_id'] as String);
      ids.add(r['recipient_id'] as String);
    }
    final people = await _gw.getBatchPersonSummaries(ids);
    return rows
        .map(
          (r) => ConnectionRequest(
            id: r['id'] as String,
            sender: people[r['requester_id'] as String]!,
            receiver: people[r['recipient_id'] as String]!,
            introMessage: (r['intro_message'] as String?) ?? '',
            status: _parseReqStatus(r['status'] as String?),
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            expiresAt:
                SupabaseGateway.parseDate(r['expires_at']) ?? _gw.currentTime,
            respondedAt: SupabaseGateway.parseDate(r['responded_at']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Result<ConnectionRequest>> sendConnectionRequest({
    required String targetUserId,
    required String introMessage,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'send_connection_request',
      params: <String, Object?>{
        'p_recipient_id': targetUserId,
        'p_intro_message': introMessage,
      },
    );
    final hydrated = await _hydrateRequests(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });

  @override
  Future<Result<void>> respondToConnectionRequest({
    required String requestId,
    required bool accept,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'respond_connection_request',
      params: <String, Object?>{'p_request_id': requestId, 'p_accept': accept},
    );
    _gw.invalidatePersonCache();
  });

  @override
  Future<Result<void>> removeConnection(String targetUserId) =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return;
        final a = uid.compareTo(targetUserId) < 0 ? uid : targetUserId;
        final b = uid.compareTo(targetUserId) < 0 ? targetUserId : uid;
        await _gw.client
            .from('connections')
            .delete()
            .eq('user_a', a)
            .eq('user_b', b);
        _gw.invalidatePersonCache(targetUserId);
      });

  @override
  Future<Result<List<Connection>>> getConnections() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return const <Connection>[];
    final rows = await _gw.client
        .from('connections')
        .select()
        .or('user_a.eq.$uid,user_b.eq.$uid')
        .order('connected_at', ascending: false);

    final friendIds = rows
        .map((r) => (r['user_a'] == uid ? r['user_b'] : r['user_a']) as String)
        .toList();
    final people = await _gw.getBatchPersonSummaries(friendIds);

    return rows
        .map((r) {
          final friendId =
              (r['user_a'] == uid ? r['user_b'] : r['user_a']) as String;
          return Connection(
            id: r['id'] as String,
            userId: uid,
            friend: people[friendId]!,
            connectedAt:
                SupabaseGateway.parseDate(r['connected_at']) ?? _gw.currentTime,
          );
        })
        .toList(growable: false);
  });

  @override
  Future<Result<List<ConnectionRequest>>> getIncomingRequests() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const <ConnectionRequest>[];
        final rows = await _gw.client
            .from('connection_requests')
            .select()
            .eq('recipient_id', uid)
            .eq('status', 'pending')
            .order('created_at', ascending: false);
        return _hydrateRequests(rows);
      });

  @override
  Future<Result<List<ConnectionRequest>>> getOutgoingRequests() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const <ConnectionRequest>[];
        final rows = await _gw.client
            .from('connection_requests')
            .select()
            .eq('requester_id', uid)
            .eq('status', 'pending')
            .order('created_at', ascending: false);
        return _hydrateRequests(rows);
      });
}

/// 6. Implementasi Supabase untuk [BlockRepository] (AC-11).
final class SupabaseBlockRepository implements BlockRepository {
  SupabaseBlockRepository(this._gw);

  final SupabaseGateway _gw;
  final Set<String> _blockedPeerIds = <String>{};

  @override
  Future<Result<Block>> blockUser(String targetUserId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final summaries = await _gw.getBatchPersonSummaries(<String>[targetUserId]);
    await _gw.client.rpc<Object?>(
      'block_user',
      params: <String, Object?>{'p_target_id': targetUserId},
    );
    _blockedPeerIds.add(targetUserId);
    _gw.invalidatePersonCache(targetUserId);
    return Block(
      id: 'blk-$targetUserId',
      blockerId: uid,
      blockedUser: summaries[targetUserId]!,
      createdAt: _gw.currentTime,
    );
  });

  @override
  Future<Result<void>> unblockUser(String targetUserId) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'unblock_user',
      params: <String, Object?>{'p_target_id': targetUserId},
    );
    _blockedPeerIds.remove(targetUserId);
    _gw.invalidatePersonCache(targetUserId);
  });

  @override
  Future<Result<List<Block>>> getBlockedUsers() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return const <Block>[];
    final rows = await _gw.client
        .from('blocks')
        .select()
        .eq('blocker_id', uid)
        .order('created_at', ascending: false);

    _blockedPeerIds
      ..clear()
      ..addAll(rows.map((r) => r['blocked_id'] as String));

    return rows
        .map(
          (r) => Block(
            id: r['id'] as String,
            blockerId: uid,
            blockedUser: PersonSummary(
              id: r['blocked_id'] as String,
              displayName: 'Pengguna diblokir',
              gender: UserGender.male,
              marga: '',
              subEthnic: SubEthnic.toba,
              city: '',
              proximity: AreaProximity.diKotamu,
              avatarSeed: 'blocked-${r['blocked_id']}',
            ),
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
          ),
        )
        .toList(growable: false);
  });

  @override
  bool isBlockedBetween(String userAId, String userBId) {
    final uid = _gw.currentUserId;
    if (uid == null) return false;
    if (userAId == uid) return _blockedPeerIds.contains(userBId);
    if (userBId == uid) return _blockedPeerIds.contains(userAId);
    return false;
  }
}

/// 7. Implementasi Supabase untuk [PostRepository] (Cache offline halaman-1 AC-15,
/// kompres + retry backoff + EXIF strip `process-image`, dan simpan draf bila gagal).
final class SupabasePostRepository implements PostRepository {
  SupabasePostRepository(this._gw);

  final SupabaseGateway _gw;
  static const String _kPostDraft = 'horas_sb_post_draft_v1';

  Future<List<Post>> _hydratePosts(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const <Post>[];
    final uid = _gw.currentUserId;
    final postIds = rows.map((r) => r['id'] as String).toList();
    final authorIds = rows.map((r) => r['author_id'] as String).toSet();

    final authors = await _gw.getBatchPersonSummaries(authorIds);
    final mediaRows = await _gw.client
        .from('post_media')
        .select()
        .inFilter('post_id', postIds)
        .order('sort_order', ascending: true);

    final likedPostIds = <String>{};
    final savedPostIds = <String>{};
    if (uid != null) {
      final likesRows = await _gw.client
          .from('likes')
          .select('post_id')
          .eq('user_id', uid)
          .inFilter('post_id', postIds);
      likedPostIds.addAll(likesRows.map((e) => e['post_id'] as String));

      final savedRows = await _gw.client
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', uid)
          .inFilter('post_id', postIds);
      savedPostIds.addAll(savedRows.map((e) => e['post_id'] as String));
    }

    final mediaByPost = <String, List<PostMedia>>{};
    for (final m in mediaRows) {
      final pid = m['post_id'] as String;
      final storagePath = (m['storage_path'] as String?) ?? '';
      final urlOrSeed = await _gw.resolveStorageUrl('posts', storagePath);
      final metaRaw = m['metadata'];
      final meta = <String, String>{};
      if (metaRaw is Map) {
        for (final e in metaRaw.entries) {
          meta[e.key.toString()] = e.value.toString();
        }
      }
      mediaByPost
          .putIfAbsent(pid, () => <PostMedia>[])
          .add(
            PostMedia(
              id: m['id'] as String,
              postId: pid,
              seed: urlOrSeed,
              orderIndex: (m['sort_order'] as int?) ?? 0,
              aspectRatio: (m['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
              exifLocationStripped: (m['exif_stripped'] as bool?) ?? true,
              metadata: meta,
              isVideo: (m['is_video'] as bool?) ?? urlOrSeed.contains('video'),
              durationSeconds: (m['duration_seconds'] as int?) ?? 0,
            ),
          );
    }

    return rows
        .map((r) {
          final pid = r['id'] as String;
          final commIds =
              ((r['community_ids'] as List<Object?>?) ?? const <Object?>[])
                  .whereType<String>()
                  .toList(growable: false);
          final singleComm = r['community_id'] as String?;
          return Post(
            id: pid,
            author: authors[r['author_id'] as String]!,
            text: (r['text'] as String?) ?? '',
            media: mediaByPost[pid] ?? const <PostMedia>[],
            visibility: SupabaseGateway.parsePostVisibility(
              r['visibility'] as String?,
            ),
            communityIds: commIds.isNotEmpty
                ? commIds
                : (singleComm != null
                      ? <String>[singleComm]
                      : const <String>[]),
            cityTag: r['city_tag'] as String?,
            isEdited: (r['is_edited'] as bool?) ?? false,
            commentsDisabled: (r['comments_disabled'] as bool?) ?? false,
            moderationStatus: SupabaseGateway.parsePostModeration(
              r['moderation_status'] as String?,
            ),
            likeCount: (r['like_count'] as int?) ?? 0,
            commentCount: (r['comment_count'] as int?) ?? 0,
            isLikedByMe: likedPostIds.contains(pid),
            isSavedByMe: savedPostIds.contains(pid),
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            updatedAt: SupabaseGateway.parseDate(r['updated_at']),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Result<List<Post>>> getFeed({int page = 1, int pageSize = 8}) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;
    try {
      final rows = await _gw.client
          .from('posts')
          .select()
          .neq('moderation_status', 'removed')
          .order('created_at', ascending: false)
          .range(from, to);
      final posts = await _hydratePosts(rows);
      if (page == 1) {
        await _gw.cache.saveFeedPage1(
          posts.map((p) => p.toJson()).toList(growable: false),
        );
      }
      _gw.cache.markLiveSync();
      return Ok<List<Post>>(posts);
    } on Object catch (e, st) {
      if (page == 1 && SupabaseErrorMapper.isOfflineFailure(e)) {
        final cached = getCachedFeedPage1();
        if (cached.isNotEmpty) {
          _gw.cache.markServingCache(_gw.cache.readFeedPage1().cachedAt);
          return Ok<List<Post>>(cached);
        }
      }
      return Err<List<Post>>(SupabaseErrorMapper.map(e, st));
    }
  }

  @override
  List<Post> getCachedFeedPage1() {
    final cached = _gw.cache.readFeedPage1();
    return cached.rows.map(Post.fromJson).toList(growable: false);
  }

  @override
  PostDraft? getSavedPostDraft() {
    final raw = _gw.prefs?.getString(_kPostDraft);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PostDraft.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> savePostDraft(PostDraft draft) async {
    await _gw.prefs?.setString(_kPostDraft, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clearPostDraft() async {
    await _gw.prefs?.remove(_kPostDraft);
  }

  @override
  Future<Result<Post>> getPostById(String postId) => _gw.guard(() async {
    final row = await _gw.client
        .from('posts')
        .select()
        .eq('id', postId)
        .single();
    final posts = await _hydratePosts(<Map<String, dynamic>>[row]);
    return posts.first;
  });

  @override
  Future<Result<List<Post>>> getUserPosts(String userId) => _gw.guard(() async {
    final rows = await _gw.client
        .from('posts')
        .select()
        .eq('author_id', userId)
        .neq('moderation_status', 'removed')
        .order('created_at', ascending: false);
    return _hydratePosts(rows);
  });

  @override
  Future<Result<List<SavedPost>>> getSavedPosts() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return const <SavedPost>[];
    final rows = await _gw.client
        .from('saved_posts')
        .select('id:post_id, saved_at:created_at, post:posts(*)')
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    final rawPosts = <Map<String, dynamic>>[];
    for (final r in rows) {
      if (r['post'] is Map) {
        rawPosts.add(Map<String, dynamic>.from(r['post'] as Map));
      }
    }
    final hydrated = await _hydratePosts(rawPosts);
    final byId = <String, Post>{for (final p in hydrated) p.id: p};
    final out = <SavedPost>[];
    for (final r in rows) {
      final pid = r['id'] as String;
      final post = byId[pid];
      if (post != null) {
        out.add(
          SavedPost(
            id: 'save-$pid',
            userId: uid,
            post: post,
            savedAt:
                SupabaseGateway.parseDate(r['saved_at']) ?? _gw.currentTime,
          ),
        );
      }
    }
    return out;
  });

  @override
  Future<Result<Post>> createPost({
    required String text,
    required PostVisibility visibility,
    List<String> mediaSeeds = const <String>[],
    List<int> mediaSizesBytes = const <int>[],
    List<double> mediaAspectRatios = const <double>[],
    List<Map<String, String>> rawExifPerMedia = const <Map<String, String>>[],
    List<String> communityIds = const <String>[],
    String? cityTag,
  }) async {
    final draft = PostDraft(
      text: text,
      mediaSeeds: mediaSeeds,
      mediaSizesBytes: mediaSizesBytes,
      mediaAspectRatios: mediaAspectRatios,
      visibility: visibility,
      communityIds: communityIds,
      cityTag: cityTag,
    );

    try {
      final uploadedPayload = <Map<String, Object?>>[];
      for (var i = 0; i < mediaSeeds.length; i++) {
        final seed = mediaSeeds[i];
        final uploaded = await _gw.mediaUploader.uploadWithRetryAndResume(
          bucket: 'posts',
          sourcePathOrSeed: seed,
        );
        final declaredSize = i < mediaSizesBytes.length
            ? mediaSizesBytes[i]
            : uploaded.sizeBytes;
        uploadedPayload.add(<String, Object?>{
          'storagePath': uploaded.storagePath,
          'mimeType': 'image/jpeg',
          'sizeBytes': declaredSize > 0 ? declaredSize : uploaded.sizeBytes,
          'aspectRatio': i < mediaAspectRatios.length
              ? mediaAspectRatios[i]
              : 1.0,
          'exifStripped': true,
          // Pastikan GPS/EXIF tidak pernah dikirim ke tabel `post_media`
          'metadata': const <String, String>{},
        });
      }

      final row = await _gw.client.rpc<Map<String, dynamic>>(
        'create_post',
        params: <String, Object?>{
          'p_text': text,
          'p_visibility': SupabaseGateway.postVisibilityToSql(visibility),
          'p_community_id': communityIds.isNotEmpty ? communityIds.first : null,
          'p_media': uploadedPayload,
          'p_community_ids': communityIds,
          'p_city_tag': cityTag,
        },
      );

      await _gw.mediaUploader.markBatchFinished('posts', mediaSeeds);
      await clearPostDraft();
      final hydrated = await _hydratePosts(<Map<String, dynamic>>[row]);
      return Ok<Post>(hydrated.first);
    } on Object catch (e, st) {
      await savePostDraft(draft);
      return Err<Post>(SupabaseErrorMapper.map(e, st));
    }
  }

  @override
  Future<Result<Post>> editPostText({
    required String postId,
    required String newText,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'edit_post_text',
      params: <String, Object?>{'p_post_id': postId, 'p_new_text': newText},
    );
    final posts = await _hydratePosts(<Map<String, dynamic>>[row]);
    return posts.first;
  });

  @override
  Future<Result<void>> deletePost(String postId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return;
    await _gw.client
        .from('posts')
        .delete()
        .eq('id', postId)
        .eq('author_id', uid);
  });

  @override
  Future<Result<Post>> toggleLike(String postId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final existing = await _gw.client
        .from('likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .maybeSingle();
    if (existing != null) {
      await _gw.client
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    } else {
      await _gw.client.from('likes').insert(<String, Object?>{
        'post_id': postId,
        'user_id': uid,
      });
    }
    final res = await getPostById(postId);
    if (res is Err<Post>) throw res.failure;
    return (res as Ok<Post>).value;
  });

  @override
  Future<Result<List<Like>>> getPostLikes(String postId) => _gw.guard(() async {
    final rows = await _gw.client
        .from('likes')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: false);
    final ids = rows.map((r) => r['user_id'] as String).toList();
    final people = await _gw.getBatchPersonSummaries(ids);
    return rows
        .map(
          (r) => Like(
            id: r['id'] as String,
            postId: postId,
            user: people[r['user_id'] as String]!,
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<Post>> toggleSavePost(String postId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final existing = await _gw.client
        .from('saved_posts')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .maybeSingle();
    if (existing != null) {
      await _gw.client
          .from('saved_posts')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    } else {
      await _gw.client.from('saved_posts').insert(<String, Object?>{
        'post_id': postId,
        'user_id': uid,
      });
    }
    final res = await getPostById(postId);
    if (res is Err<Post>) throw res.failure;
    return (res as Ok<Post>).value;
  });
}

/// 8. Implementasi Supabase untuk [CommentRepository].
final class SupabaseCommentRepository implements CommentRepository {
  SupabaseCommentRepository(this._gw, this._postRepo);

  final SupabaseGateway _gw;
  final SupabasePostRepository _postRepo;

  @override
  Future<Result<List<Comment>>> getComments(String postId) => _gw.guard(
    () async {
      final rows = await _gw.client
          .from('comments')
          .select()
          .eq('post_id', postId)
          .eq('is_removed', false)
          .order('created_at', ascending: true);
      final ids = rows.map((r) => r['author_id'] as String).toSet();
      final people = await _gw.getBatchPersonSummaries(ids);
      return rows
          .map(
            (r) => Comment(
              id: r['id'] as String,
              postId: postId,
              parentCommentId: r['parent_comment_id'] as String?,
              author: people[r['author_id'] as String]!,
              text: (r['text'] as String?) ?? '',
              createdAt:
                  SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            ),
          )
          .toList(growable: false);
    },
  );

  @override
  Future<Result<Comment>> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'add_comment',
      params: <String, Object?>{
        'p_post_id': postId,
        'p_text': text,
        'p_parent_comment_id': parentCommentId,
      },
    );
    final authorMap = await _gw.getBatchPersonSummaries(<String>[
      row['author_id'] as String,
    ]);
    return Comment(
      id: row['id'] as String,
      postId: postId,
      parentCommentId: row['parent_comment_id'] as String?,
      author: authorMap[row['author_id'] as String]!,
      text: (row['text'] as String?) ?? '',
      createdAt:
          SupabaseGateway.parseDate(row['created_at']) ?? _gw.currentTime,
    );
  });

  @override
  Future<Result<void>> deleteComment(String commentId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return;
    await _gw.client
        .from('comments')
        .delete()
        .eq('id', commentId)
        .eq('author_id', uid);
  });

  @override
  Future<Result<Post>> setCommentsDisabled({
    required String postId,
    required bool disabled,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'set_post_comments_disabled',
      params: <String, Object?>{'p_post_id': postId, 'p_disabled': disabled},
    );
    final postRes = await _postRepo.getPostById(postId);
    if (postRes is Err<Post>) throw postRes.failure;
    return (postRes as Ok<Post>).value;
  });
}

/// 9. Implementasi Supabase untuk [SearchRepository].
final class SupabaseSearchRepository implements SearchRepository {
  SupabaseSearchRepository(this._gw);

  final SupabaseGateway _gw;
  static const String _kSearchHistory = 'horas_sb_search_history_v1';

  @override
  List<String> getSearchHistory() =>
      _gw.prefs?.getStringList(_kSearchHistory) ?? const <String>[];

  @override
  Future<void> addSearchHistory(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final list = List<String>.of(getSearchHistory())
      ..removeWhere((e) => e.toLowerCase() == clean.toLowerCase())
      ..insert(0, clean);
    await _gw.prefs?.setStringList(
      _kSearchHistory,
      list.take(15).toList(growable: false),
    );
  }

  @override
  Future<void> removeSearchHistory(String query) async {
    final list = List<String>.of(getSearchHistory())
      ..removeWhere((e) => e == query);
    await _gw.prefs?.setStringList(_kSearchHistory, list);
  }

  @override
  Future<void> clearSearchHistory() async {
    await _gw.prefs?.remove(_kSearchHistory);
  }

  @override
  List<String> getSearchSuggestions() => const <String>[
    'Simanjuntak',
    'Sitorus',
    'Badminton Medan',
    'Punguan Marga',
    'Tebet',
  ];

  @override
  Future<Result<List<PersonSummary>>> searchPeople({
    required String query,
    String? city,
    String? marga,
  }) => _gw.guard(() async {
    final res = await _gw.client.rpc<List<Object?>>(
      'search_people',
      params: <String, Object?>{
        'p_query': query,
        'p_city': city,
        'p_marga': marga,
      },
    );
    return res
        .whereType<Map<Object?, Object?>>()
        .map(
          (m) => PersonSummary.fromJson(
            m.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<List<Community>>> searchCommunities({
    required String query,
    String? city,
    CommunityType? type,
  }) => _gw.guard(() async {
    final clean = query.trim();
    var q = _gw.client.from('communities').select();
    if (clean.isNotEmpty) {
      q = q.or(
        'name.ilike.%$clean%,city.ilike.%$clean%,marga_name.ilike.%$clean%',
      );
    }
    if (city != null && city.trim().isNotEmpty) {
      q = q.ilike('city', city.trim());
    }
    if (type != null) {
      q = q.eq('type', SupabaseGateway.communityTypeToSql(type));
    }
    final rows = await q.order('member_count', ascending: false);
    return rows
        .map(
          (r) => Community(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? '',
            type: SupabaseGateway.parseCommunityType(r['type'] as String?),
            accessType: SupabaseGateway.parseCommunityAccess(
              r['access_type'] as String?,
            ),
            city: (r['city'] as String?) ?? '',
            description: (r['description'] as String?) ?? '',
            avatarSeed: (r['avatar_seed'] as String?) ?? '',
            ownerId: (r['owner_id'] as String?) ?? '',
            margaName: r['marga_name'] as String?,
            memberCount: (r['member_count'] as int?) ?? 0,
            isVerified: (r['is_verified'] as bool?) ?? false,
            conversationId: r['conversation_id'] as String?,
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? clock.now(),
            lastManagerActiveAt:
                SupabaseGateway.parseDate(r['last_manager_active_at']) ??
                clock.now(),
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<List<Church>>> searchChurches({
    required String query,
    String? city,
  }) => _gw.guard(() async {
    final clean = query.trim();
    var q = _gw.client.from('churches').select();
    if (clean.isNotEmpty) {
      q = q.or(
        'name.ilike.%$clean%,city.ilike.%$clean%,address.ilike.%$clean%',
      );
    }
    if (city != null && city.trim().isNotEmpty) {
      q = q.ilike('city', city.trim());
    }
    final rows = await q.order('name');
    return rows.map((r) => Church.fromJson(r)).toList(growable: false);
  });

  @override
  Future<Result<List<Post>>> searchPublicPosts({required String query}) =>
      _gw.guard(() async {
        final clean = query.trim();
        var q = _gw.client
            .from('posts')
            .select()
            .eq('visibility', 'publicPost');
        if (clean.isNotEmpty) {
          q = q.ilike('text', '%$clean%');
        }
        final rows = await q.order('created_at', ascending: false).limit(20);
        return rows.map((r) => Post.fromJson(r)).toList(growable: false);
      });
}

/// 10. Implementasi Supabase untuk [NearbyRepository] (SEK-01..SEK-03, AC-07).
final class SupabaseNearbyRepository implements NearbyRepository {
  SupabaseNearbyRepository(this._gw);

  final SupabaseGateway _gw;
  String? _selectedCity;
  bool _locationPermissionDenied = false;

  @override
  String get currentSelectedCity =>
      _selectedCity ?? _gw.currentSessionProfile?.city ?? 'Medan';

  @override
  void setCurrentSelectedCity(String city) {
    _selectedCity = city;
  }

  @override
  bool get locationPermissionDenied => _locationPermissionDenied;

  @override
  void setLocationPermissionDenied(bool denied) {
    _locationPermissionDenied = denied;
  }

  @override
  Future<Result<List<WilayahCity>>> getAvailableCities() => _gw.guard(() async {
    final rows = await _gw.client
        .from('wilayah')
        .select()
        .order('name', ascending: true);
    return rows
        .map(
          (r) => WilayahCity(
            id: (r['id'] as String).trim(),
            name: r['name'] as String,
            province: r['province'] as String,
            subdistricts:
                ((r['subdistricts'] as List<Object?>?) ?? const <Object?>[])
                    .whereType<String>()
                    .toList(growable: false),
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<List<PersonSummary>>> getNearbyPeople({
    String? city,
    String? marga,
    String? hobby,
    String? campusOrOffice,
    int page = 1,
  }) => _gw.guard(() async {
    const pageSize = 20;
    final res = await _gw.client.rpc<List<Object?>>(
      'get_nearby_people',
      params: <String, Object?>{
        'p_city': city ?? currentSelectedCity,
        'p_limit': 100,
        'p_offset': 0,
      },
    );
    var people = res
        .whereType<Map<Object?, Object?>>()
        .map(
          (m) => PersonSummary.fromJson(
            m.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList(growable: false);

    if (marga != null && marga.trim().isNotEmpty) {
      final m = marga.trim().toLowerCase();
      people = people.where((p) => p.marga.toLowerCase() == m).toList();
    }
    if (hobby != null && hobby.trim().isNotEmpty) {
      final h = hobby.trim().toLowerCase();
      people = people
          .where((p) => p.hobbies.any((item) => item.toLowerCase().contains(h)))
          .toList();
    }
    if (campusOrOffice != null && campusOrOffice.trim().isNotEmpty) {
      final c = campusOrOffice.trim().toLowerCase();
      people = people
          .where((p) => (p.campusOrOffice ?? '').toLowerCase().contains(c))
          .toList();
    }

    final start = (page - 1) * pageSize;
    if (start >= people.length) return const <PersonSummary>[];
    final end = (start + pageSize).clamp(0, people.length);
    return people.sublist(start, end);
  });
}
