import 'dart:async';

import 'package:clock/clock.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/data/supabase/supabase_error_mapper.dart';
import 'package:horas/data/supabase/supabase_gateway.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/repositories/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 14. Implementasi Supabase untuk [ChatRepository] dengan Supabase Realtime,
/// auto-reconnect, cache daftar percakapan offline (AC-15), unggah media lewat
/// `process-image`, dan antrean kirim ulang pesan saat offline (Tugas 4 & 5).
final class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._gw);

  final SupabaseGateway _gw;

  final StreamController<List<Conversation>> _convController =
      StreamController<List<Conversation>>.broadcast();
  final Map<String, StreamController<List<Message>>> _msgControllers =
      <String, StreamController<List<Message>>>{};

  RealtimeChannel? _chatChannel;
  Timer? _reconnectTimer;
  bool _flushingOutbox = false;

  void _ensureRealtimeConnected() {
    if (_chatChannel != null || _gw.currentUserId == null) return;
    final channel = _gw.client.channel('horas-chat-live-${_gw.currentUserId}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final cid =
                (payload.newRecord['conversation_id'] ??
                        payload.oldRecord['conversation_id'])
                    as String?;
            await _refreshConversationsStream();
            if (cid != null && _msgControllers.containsKey(cid)) {
              await _refreshMessagesStream(cid);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) async {
            await _refreshConversationsStream();
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(flushPendingOutbox());
          } else if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError) {
            _scheduleReconnect();
          }
        });
    _chatChannel = channel;
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      final old = _chatChannel;
      _chatChannel = null;
      if (old != null) {
        try {
          await _gw.client.removeChannel(old);
        } on Object {
          // Abaikan kesalahan penutupan channel lama.
        }
      }
      _ensureRealtimeConnected();
    });
  }

  Future<void> _refreshConversationsStream() async {
    final res = await getConversations();
    if (res is Ok<List<Conversation>> && !_convController.isClosed) {
      _convController.add(res.value);
    }
  }

  Future<void> _refreshMessagesStream(String conversationId) async {
    final ctrl = _msgControllers[conversationId];
    if (ctrl == null || ctrl.isClosed) return;
    final res = await getMessages(conversationId);
    if (res is Ok<List<Message>> && !ctrl.isClosed) {
      ctrl.add(res.value);
    }
  }

  /// Mengirim ulang pesan yang masuk antrean offline begitu koneksi kembali pulih.
  Future<void> flushPendingOutbox() async {
    if (_flushingOutbox || _gw.currentUserId == null) return;
    final outbox = _gw.cache.readMessageOutbox();
    if (outbox.isEmpty) return;

    _flushingOutbox = true;
    final remaining = <Map<String, Object?>>[];
    try {
      for (final item in outbox) {
        final convId = item['conversationId'] as String?;
        final text = (item['text'] as String?) ?? '';
        final photoSeed = item['photoSeed'] as String?;
        final replyTo = item['replyToMessageId'] as String?;
        if (convId == null || convId.isEmpty) continue;
        final res = await sendMessage(
          conversationId: convId,
          text: text,
          photoSeed: photoSeed,
          replyToMessageId: replyTo,
          enqueueOnOffline: false,
        );
        if (res is Err<Message> && res.failure is OfflineError) {
          remaining.add(item);
        }
      }
      await _gw.cache.replaceMessageOutbox(remaining);
    } finally {
      _flushingOutbox = false;
    }
  }

  Future<List<Message>> _hydrateMessages(
    List<Map<String, dynamic>> rows,
  ) async {
    final uid = _gw.currentUserId;
    final senderIds = rows
        .map((r) => r['sender_id'] as String?)
        .whereType<String>()
        .toSet();
    final people = await _gw.getBatchPersonSummaries(senderIds);

    final out = <Message>[];
    for (final r in rows) {
      final hidden =
          ((r['hidden_for_user_ids'] as List<Object?>?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false);
      if (uid != null && hidden.contains(uid)) continue;

      final sid = r['sender_id'] as String?;
      final sender = sid != null
          ? (people[sid] ?? SupabaseGateway.deletedPersonFallback(sid))
          : SupabaseGateway.deletedPersonFallback();
      final attPath = r['attachment_path'] as String?;
      final resolvedAtt = attPath != null
          ? await _gw.resolveStorageUrl('chat-media', attPath)
          : null;

      out.add(
        Message(
          id: r['id'] as String,
          conversationId: r['conversation_id'] as String,
          sender: sender,
          text: (r['text'] as String?) ?? '',
          photoSeed: resolvedAtt,
          replyToMessageId: r['reply_to_message_id'] as String?,
          deliveryStatus: MessageDeliveryStatus.delivered,
          isDeletedForEveryone: (r['deleted_for_everyone'] as bool?) ?? false,
          deletedForUserIds: hidden,
          hasScamWarning: (r['has_scam_warning'] as bool?) ?? false,
          isAnnouncement: (r['is_pinned_announcement'] as bool?) ?? false,
          createdAt:
              SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
        ),
      );
    }
    return out;
  }

  Future<List<Conversation>> _hydrateConversations(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) {
      _gw.cachedUnreadMessages = 0;
      return const <Conversation>[];
    }
    final uid = _gw.currentUserId;
    final convIds = rows.map((r) => r['id'] as String).toList();

    final cpRows = await _gw.client
        .from('conversation_participants')
        .select()
        .inFilter('conversation_id', convIds);

    final userIds = cpRows.map((c) => c['user_id'] as String).toSet();
    final people = await _gw.getBatchPersonSummaries(userIds);

    final participantsByConv = <String, List<PersonSummary>>{};
    final myMetaByConv = <String, Map<String, dynamic>>{};
    var totalUnread = 0;

    for (final cp in cpRows) {
      final cid = cp['conversation_id'] as String;
      final pid = cp['user_id'] as String;
      participantsByConv
          .putIfAbsent(cid, () => <PersonSummary>[])
          .add(people[pid] ?? SupabaseGateway.deletedPersonFallback(pid));
      if (pid == uid) {
        myMetaByConv[cid] = cp;
        totalUnread += (cp['unread_count'] as int?) ?? 0;
      }
    }
    _gw.cachedUnreadMessages = totalUnread;

    return rows
        .map((r) {
          final cid = r['id'] as String;
          final myMeta = myMetaByConv[cid];
          final type = SupabaseGateway.parseConversationType(
            r['type'] as String?,
          );
          final participants =
              participantsByConv[cid] ?? const <PersonSummary>[];
          var title = (r['title'] as String?) ?? '';
          if (title.isEmpty && type == ConversationType.direct) {
            final other = participants.where((p) => p.id != uid).toList();
            title = other.isNotEmpty ? other.first.displayName : 'Percakapan';
          }
          final preview = (r['last_message_preview'] as String?) ?? '';
          final updated =
              SupabaseGateway.parseDate(r['last_message_at']) ??
              _gw.currentTime;
          final lastMsg = preview.isNotEmpty
              ? Message(
                  id: 'last-$cid',
                  conversationId: cid,
                  sender: participants.isNotEmpty
                      ? participants.first
                      : SupabaseGateway.deletedPersonFallback(),
                  text: preview,
                  createdAt: updated,
                )
              : null;

          return Conversation(
            id: cid,
            type: type,
            title: title,
            participants: participants,
            communityId: r['community_id'] as String?,
            sessionId: r['session_id'] as String?,
            isReadOnly: (r['is_read_only'] as bool?) ?? false,
            mutedUntil: myMeta != null
                ? SupabaseGateway.parseDate(myMeta['muted_until'])
                : null,
            lastMessage: lastMsg,
            unreadCount: myMeta != null
                ? ((myMeta['unread_count'] as int?) ?? 0)
                : 0,
            updatedAt: updated,
          );
        })
        .toList(growable: false);
  }

  Conversation _conversationFromCache(Map<String, Object?> j) {
    ConversationType parseType(String? r) => ConversationType.values.firstWhere(
      (e) => e.name == r,
      orElse: () => ConversationType.direct,
    );
    final rawParts =
        ((j['participants'] as List<Object?>?) ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>()
            .map(
              (m) => PersonSummary.fromJson(
                m.map((k, v) => MapEntry(k.toString(), v)),
              ),
            )
            .toList(growable: false);
    final rawLast = j['lastMessage'] as Map<Object?, Object?>?;
    final updated =
        DateTime.tryParse((j['updatedAt'] as String?) ?? '') ?? clock.now();
    Message? lastMsg;
    if (rawLast != null) {
      lastMsg = Message(
        id: (rawLast['id'] as String?) ?? 'cached',
        conversationId: (j['id'] as String?) ?? '',
        sender: rawParts.isNotEmpty
            ? rawParts.first
            : SupabaseGateway.deletedPersonFallback(),
        text: (rawLast['text'] as String?) ?? '',
        createdAt: updated,
      );
    }
    return Conversation(
      id: (j['id'] as String?) ?? '',
      type: parseType(j['type'] as String?),
      title: (j['title'] as String?) ?? '',
      participants: rawParts,
      communityId: j['communityId'] as String?,
      sessionId: j['sessionId'] as String?,
      isReadOnly: (j['isReadOnly'] as bool?) ?? false,
      unreadCount: (j['unreadCount'] as int?) ?? 0,
      lastMessage: lastMsg,
      updatedAt: updated,
    );
  }

  @override
  Stream<List<Conversation>> watchConversations() {
    _ensureRealtimeConnected();
    unawaited(_refreshConversationsStream());
    return _convController.stream;
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    _ensureRealtimeConnected();
    final ctrl = _msgControllers.putIfAbsent(
      conversationId,
      () => StreamController<List<Message>>.broadcast(),
    );
    unawaited(_refreshMessagesStream(conversationId));
    return ctrl.stream;
  }

  @override
  Future<Result<List<Conversation>>> getConversations() async {
    try {
      final rows = await _gw.client
          .from('conversations')
          .select()
          .order('last_message_at', ascending: false);
      final convs = await _hydrateConversations(rows);
      await _gw.cache.saveConversations(
        convs.map((c) => c.toJson()).toList(growable: false),
      );
      _gw.cache.markLiveSync();
      return Ok<List<Conversation>>(convs);
    } on Object catch (e, st) {
      if (SupabaseErrorMapper.isOfflineFailure(e)) {
        final cached = _gw.cache.readConversations();
        if (cached.rows.isNotEmpty) {
          _gw.cache.markServingCache(cached.cachedAt);
          return Ok<List<Conversation>>(
            cached.rows.map(_conversationFromCache).toList(growable: false),
          );
        }
      }
      return Err<List<Conversation>>(SupabaseErrorMapper.map(e, st));
    }
  }

  @override
  Future<Result<Conversation>> getConversationById(String conversationId) =>
      _gw.guard(() async {
        final row = await _gw.client
            .from('conversations')
            .select()
            .eq('id', conversationId)
            .single();
        final list = await _hydrateConversations(<Map<String, dynamic>>[row]);
        return list.first;
      });

  @override
  Future<Result<Conversation>> openDirectConversationWithUser(
    String targetUserId,
  ) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final myConvs = await getConversations();
    if (myConvs is Ok<List<Conversation>>) {
      for (final c in myConvs.value) {
        if (c.type == ConversationType.direct &&
            c.participants.any((p) => p.id == targetUserId)) {
          return c;
        }
      }
    }
    throw const PermissionDeniedError(
      message: 'Mulai dengan mengirim pesan pertama.',
      permissionName: 'message',
    );
  });

  @override
  Future<Result<List<Message>>> getMessages(String conversationId) =>
      _gw.guard(() async {
        final rows = await _gw.client
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true);
        return _hydrateMessages(rows);
      });

  @override
  Future<Result<void>> markConversationRead(String conversationId) =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return;
        await _gw.client
            .from('conversation_participants')
            .update(<String, Object?>{
              'unread_count': 0,
              'last_read_at': _gw.currentTime.toIso8601String(),
            })
            .eq('conversation_id', conversationId)
            .eq('user_id', uid);
        await _refreshConversationsStream();
      });

  @override
  Future<Result<List<MessageRequest>>> getMessageRequests() => _gw.guard(
    () async {
      final uid = _gw.currentUserId;
      if (uid == null) return const <MessageRequest>[];
      final rows = await _gw.client
          .from('message_requests')
          .select()
          .eq('recipient_id', uid)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      if (rows.isEmpty) return const <MessageRequest>[];

      final senders = await _gw.getBatchPersonSummaries(
        rows.map((r) => r['sender_id'] as String),
      );
      final msgIds = rows
          .map((r) => r['first_message_id'] as String?)
          .whereType<String>()
          .toList();
      final msgsById = <String, Message>{};
      if (msgIds.isNotEmpty) {
        final msgRows = await _gw.client
            .from('messages')
            .select()
            .inFilter('id', msgIds);
        final hydrated = await _hydrateMessages(msgRows);
        for (final m in hydrated) {
          msgsById[m.id] = m;
        }
      }

      return rows
          .map((r) {
            final sid = r['sender_id'] as String;
            final cid = r['conversation_id'] as String;
            final mid = r['first_message_id'] as String?;
            final sender = senders[sid]!;
            return MessageRequest(
              id: r['id'] as String,
              conversationId: cid,
              sender: sender,
              receiverId: uid,
              firstMessage:
                  (mid != null ? msgsById[mid] : null) ??
                  Message(
                    id: mid ?? 'first-$cid',
                    conversationId: cid,
                    sender: sender,
                    text: '',
                    createdAt:
                        SupabaseGateway.parseDate(r['created_at']) ??
                        _gw.currentTime,
                  ),
              sharedContextDescription: 'Berbagi komunitas atau sesi bersama',
              status: MessageRequestStatus.pending,
              createdAt:
                  SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            );
          })
          .toList(growable: false);
    },
  );

  @override
  Future<Result<Message>> sendMessage({
    required String conversationId,
    required String text,
    String? photoSeed,
    String? replyToMessageId,
    String? voiceNoteSeed,
    int? voiceNoteDurationSeconds,
    String? stickerSeed,
    bool enqueueOnOffline = true,
  }) async {
    try {
      String? attachmentPath;
      int? attachmentBytes;
      if (photoSeed != null && photoSeed.isNotEmpty) {
        final uploaded = await _gw.mediaUploader.uploadWithRetryAndResume(
          bucket: 'chat-media',
          sourcePathOrSeed: photoSeed,
          conversationId: conversationId,
        );
        attachmentPath = uploaded.storagePath;
        attachmentBytes = uploaded.sizeBytes;
      }

      final row = await _gw.client.rpc<Map<String, dynamic>>(
        'send_message',
        params: <String, Object?>{
          'p_conversation_id': conversationId,
          'p_text': text,
          'p_attachment_path': attachmentPath,
          'p_attachment_bytes': attachmentBytes,
          'p_reply_to': replyToMessageId,
        },
      );
      if (photoSeed != null && photoSeed.isNotEmpty) {
        await _gw.mediaUploader.markBatchFinished('chat-media', <String>[
          photoSeed,
        ]);
      }
      final hydrated = await _hydrateMessages(<Map<String, dynamic>>[row]);
      unawaited(_refreshMessagesStream(conversationId));
      unawaited(_refreshConversationsStream());
      return Ok<Message>(hydrated.first);
    } on Object catch (e, st) {
      if (enqueueOnOffline && SupabaseErrorMapper.isOfflineFailure(e)) {
        await _gw.cache.enqueueOfflineMessage(<String, Object?>{
          'conversationId': conversationId,
          'text': text,
          'photoSeed': photoSeed,
          'replyToMessageId': replyToMessageId,
          'queuedAt': _gw.currentTime.toIso8601String(),
        });
      }
      return Err<Message>(SupabaseErrorMapper.map(e, st));
    }
  }

  @override
  Future<Result<Message>> sendFirstMessageToUser({
    required String targetUserId,
    required String text,
  }) => _gw.guard(() async {
    final res = await _gw.client.rpc<Map<String, dynamic>>(
      'send_first_message',
      params: <String, Object?>{'p_recipient_id': targetUserId, 'p_text': text},
    );
    final rawMsg = Map<String, dynamic>.from(res['message'] as Map);
    final hydrated = await _hydrateMessages(<Map<String, dynamic>>[rawMsg]);
    return hydrated.first;
  });

  @override
  Future<Result<void>> respondMessageRequest({
    required String requestId,
    required MessageRequestStatus decision,
  }) => _gw.guard(() async {
    if (decision == MessageRequestStatus.blocked) {
      final row = await _gw.client
          .from('message_requests')
          .select('sender_id')
          .eq('id', requestId)
          .single();
      await _gw.client.rpc<Object?>(
        'respond_message_request',
        params: <String, Object?>{'p_request_id': requestId, 'p_accept': false},
      );
      await _gw.client.rpc<Object?>(
        'block_user',
        params: <String, Object?>{'p_target_id': row['sender_id']},
      );
      return;
    }
    await _gw.client.rpc<Object?>(
      'respond_message_request',
      params: <String, Object?>{
        'p_request_id': requestId,
        'p_accept': decision == MessageRequestStatus.accepted,
      },
    );
  });

  @override
  Future<Result<void>> deleteMessageForMe(String messageId) =>
      _gw.guard(() async {
        await _gw.client.rpc<Object?>(
          'delete_message_for_me',
          params: <String, Object?>{'p_message_id': messageId},
        );
      });

  @override
  Future<Result<void>> deleteMessageForEveryone(String messageId) =>
      _gw.guard(() async {
        await _gw.client.rpc<Object?>(
          'delete_message_for_everyone',
          params: <String, Object?>{'p_message_id': messageId},
        );
      });

  @override
  Future<Result<Conversation>> muteConversation({
    required String conversationId,
    required MuteDurationOption duration,
  }) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final until = _gw.currentTime.add(duration.duration).toIso8601String();
    await _gw.client
        .from('conversation_participants')
        .update(<String, Object?>{'muted_until': until})
        .eq('conversation_id', conversationId)
        .eq('user_id', uid);
    final conv = await getConversationById(conversationId);
    if (conv is Err<Conversation>) throw conv.failure;
    return (conv as Ok<Conversation>).value;
  });

  @override
  Future<Result<Conversation>> unmuteConversation(String conversationId) =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) {
          throw const PermissionDeniedError(
            message: 'Login diperlukan.',
            permissionName: 'auth',
          );
        }
        await _gw.client
            .from('conversation_participants')
            .update(<String, Object?>{'muted_until': null})
            .eq('conversation_id', conversationId)
            .eq('user_id', uid);
        final conv = await getConversationById(conversationId);
        if (conv is Err<Conversation>) throw conv.failure;
        return (conv as Ok<Conversation>).value;
      });

  @override
  Future<Result<void>> leaveGroupConversation(String conversationId) =>
      _gw.guard(() async {
        await _gw.client.rpc<Object?>(
          'leave_group_conversation',
          params: <String, Object?>{'p_conversation_id': conversationId},
        );
      });

  @override
  Future<Result<void>> removeGroupMember({
    required String conversationId,
    required String targetUserId,
  }) => _gw.guard(() async {
    await _gw.client.rpc<Object?>(
      'remove_group_member',
      params: <String, Object?>{
        'p_conversation_id': conversationId,
        'p_target_user_id': targetUserId,
      },
    );
  });

  @override
  Future<Result<Message>> sendPinnedAnnouncement({
    required String conversationId,
    required String text,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'send_pinned_announcement_message',
      params: <String, Object?>{
        'p_conversation_id': conversationId,
        'p_text': text,
      },
    );
    final hydrated = await _hydrateMessages(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });

  @override
  Future<bool> isGroupAdmin(String conversationId) async {
    final uid = _gw.currentUserId;
    if (uid == null) return false;
    final res = await getConversationById(conversationId);
    if (res is! Ok<Conversation>) return false;
    final c = res.value;
    if (c.communityId != null) {
      final row = await _gw.client
          .from('community_memberships')
          .select('role')
          .eq('community_id', c.communityId!)
          .eq('user_id', uid)
          .maybeSingle();
      return row != null &&
          (row['role'] == 'owner' || row['role'] == 'manager');
    }
    if (c.sessionId != null) {
      final row = await _gw.client
          .from('play_sessions')
          .select('host_id')
          .eq('id', c.sessionId!)
          .maybeSingle();
      return row != null && row['host_id'] == uid;
    }
    return false;
  }

  @override
  Future<Result<Conversation>> createCommunityGroupChat({
    required Community community,
    required PersonSummary owner,
  }) => getConversationById(community.conversationId ?? '');

  @override
  Future<Result<void>> addParticipantToCommunityChat({
    required String communityId,
    required PersonSummary user,
  }) async => const Ok<void>(null);

  @override
  Future<Result<void>> removeParticipantFromCommunityChat({
    required String communityId,
    required String userId,
  }) async => const Ok<void>(null);

  @override
  Future<Result<Conversation>> createSessionGroupChat({
    required PlaySession session,
    required PersonSummary host,
  }) => getConversationById(session.conversationId ?? '');

  @override
  Future<Result<void>> addParticipantToSessionChat({
    required String sessionId,
    required PersonSummary user,
  }) async => const Ok<void>(null);

  @override
  Future<Result<void>> removeParticipantFromSessionChat({
    required String sessionId,
    required String userId,
  }) async => const Ok<void>(null);

  @override
  Future<Result<void>> markConversationReadOnly(String conversationId) =>
      _gw.guard(() async {
        await _gw.client
            .from('conversations')
            .update(<String, Object?>{'is_read_only': true})
            .eq('id', conversationId);
      });

  @override
  Future<Result<Conversation>> createCustomGroupChat({
    required String title,
    required List<String> memberUserIds,
    String? photoSeed,
  }) => _gw.guard(() async {
    final me = _gw.currentSessionProfile;
    final row = await _gw.client
        .from('conversations')
        .insert(<String, Object?>{
          'type': 'userGroup',
          'title': title,
          'photo_seed': photoSeed,
          'is_read_only': false,
        })
        .select()
        .single();
    final convId = row['id'] as String;
    final allMembers = <String>{if (me != null) me.id, ...memberUserIds};
    for (final uid in allMembers) {
      await _gw.client.from('conversation_participants').insert(
        <String, Object?>{'conversation_id': convId, 'user_id': uid},
      );
    }
    final convRes = await getConversationById(convId);
    return (convRes as Ok<Conversation>).value;
  });

  void dispose() {
    _reconnectTimer?.cancel();
    if (_chatChannel != null) {
      unawaited(_gw.client.removeChannel(_chatChannel!));
    }
    unawaited(_convController.close());
    for (final c in _msgControllers.values) {
      unawaited(c.close());
    }
  }
}

/// 15. Implementasi Supabase untuk [NotificationRepository] (Realtime + auto-reconnect).
final class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._gw);

  final SupabaseGateway _gw;
  final StreamController<List<AppNotification>> _notifController =
      StreamController<List<AppNotification>>.broadcast();
  RealtimeChannel? _notifChannel;
  Timer? _reconnectTimer;

  void _ensureRealtimeConnected() {
    final uid = _gw.currentUserId;
    if (_notifChannel != null || uid == null) return;
    final channel = _gw.client.channel('horas-notif-live-$uid');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) async {
            final res = await getNotifications();
            if (res is Ok<List<AppNotification>> &&
                !_notifController.isClosed) {
              _notifController.add(res.value);
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError) {
            _scheduleReconnect();
          }
        });
    _notifChannel = channel;
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      final old = _notifChannel;
      _notifChannel = null;
      if (old != null) {
        try {
          await _gw.client.removeChannel(old);
        } on Object {
          // Abaikan error saat channel sudah tertutup.
        }
      }
      _ensureRealtimeConnected();
    });
  }

  AppNotification _notifFromRow(Map<String, dynamic> r) {
    final route = (r['action_route'] as String?) ?? '/beranda';
    return AppNotification(
      id: r['id'] as String,
      recipientId: r['user_id'] as String,
      type: SupabaseGateway.parseNotificationType(r['type'] as String?, route),
      title: (r['title'] as String?) ?? '',
      body: (r['body'] as String?) ?? '',
      deepLink: route,
      isRead: (r['is_read'] as bool?) ?? false,
      createdAt: SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
    );
  }

  @override
  Stream<List<AppNotification>> watchNotifications() {
    _ensureRealtimeConnected();
    unawaited(
      getNotifications().then((res) {
        if (res is Ok<List<AppNotification>> && !_notifController.isClosed) {
          _notifController.add(res.value);
        }
      }),
    );
    return _notifController.stream;
  }

  @override
  Future<Result<List<AppNotification>>> getNotifications() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const <AppNotification>[];
        final rows = await _gw.client
            .from('notifications')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false);
        final items = rows.map(_notifFromRow).toList(growable: false);
        _gw.cachedUnreadNotifications = items.where((n) => !n.isRead).length;
        return items;
      });

  @override
  Future<Result<AppNotification>> push({
    required String recipientId,
    required NotificationType type,
    required String title,
    required String body,
    required String deepLink,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'push_notification',
      params: <String, Object?>{
        'p_recipient_id': recipientId,
        'p_type': SupabaseGateway.notificationTypeToSql(type),
        'p_title': title,
        'p_body': body,
        'p_action_route': deepLink,
      },
    );
    return _notifFromRow(row);
  });

  @override
  Future<Result<void>> markAsRead(String notificationId) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return;
    await _gw.client
        .from('notifications')
        .update(<String, Object?>{'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', uid);
    await getNotifications();
  });

  @override
  Future<Result<void>> markAllAsRead() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return;
    await _gw.client
        .from('notifications')
        .update(<String, Object?>{'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
    _gw.cachedUnreadNotifications = 0;
  });

  @override
  Future<Result<NotificationPreferences>> getNotificationPreferences() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const NotificationPreferences();
        final row = await _gw.client
            .from('notification_preferences')
            .select()
            .eq('user_id', uid)
            .maybeSingle();
        if (row == null) return const NotificationPreferences();
        final disabled = <NotificationType>{};
        if (row['sosial_enabled'] == false) {
          disabled.addAll(const <NotificationType>[
            NotificationType.connectionRequestReceived,
            NotificationType.connectionAccepted,
            NotificationType.postLikedOrCommented,
            NotificationType.newFollower,
            NotificationType.partuturanClaimReceived,
          ]);
        }
        if (row['komunitas_enabled'] == false) {
          disabled.addAll(const <NotificationType>[
            NotificationType.communityJoinRequest,
            NotificationType.communityJoinApproved,
            NotificationType.communityAnnouncement,
            NotificationType.eventReminder,
          ]);
        }
        if (row['main_olahraga_enabled'] == false) {
          disabled.addAll(const <NotificationType>[
            NotificationType.sessionJoinOrWaitlistPromoted,
            NotificationType.sessionReminder,
          ]);
        }
        if (row['pesan_enabled'] == false) {
          disabled.addAll(const <NotificationType>[
            NotificationType.newMessage,
            NotificationType.messageRequestReceived,
          ]);
        }
        return NotificationPreferences(
          disabledTypes: Set<NotificationType>.unmodifiable(disabled),
          quietHoursEnabled: (row['quiet_hours_start'] as int?) == 22,
        );
      });

  @override
  Future<Result<NotificationPreferences>> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return preferences;
    await _gw.client.from('notification_preferences').upsert(<String, Object?>{
      'user_id': uid,
      'sosial_enabled': preferences.isEnabled(
        NotificationType.connectionAccepted,
      ),
      'komunitas_enabled': preferences.isEnabled(
        NotificationType.communityAnnouncement,
      ),
      'main_olahraga_enabled': preferences.isEnabled(
        NotificationType.sessionReminder,
      ),
      'pesan_enabled': preferences.isEnabled(NotificationType.newMessage),
      'quiet_hours_start': preferences.quietHoursEnabled ? 22 : 0,
      'quiet_hours_end': preferences.quietHoursEnabled ? 6 : 0,
    }, onConflict: 'user_id');
    return preferences;
  });

  void dispose() {
    _reconnectTimer?.cancel();
    if (_notifChannel != null) {
      unawaited(_gw.client.removeChannel(_notifChannel!));
    }
    unawaited(_notifController.close());
  }
}

/// 23. Implementasi live Supabase untuk [NavigationBadgeRepository].
final class LiveSupabaseNavigationBadgeRepository
    implements NavigationBadgeRepository {
  const LiveSupabaseNavigationBadgeRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  UnreadCounts currentUnreadCounts() {
    return (
      unreadMessages: _gw.cachedUnreadMessages,
      unreadNotifications: _gw.cachedUnreadNotifications,
    );
  }
}
