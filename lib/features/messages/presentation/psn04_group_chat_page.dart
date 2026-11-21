import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/features/messages/presentation/chat_thread_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// PSN-04 Chat Grup (`PSN-R5`, `PSN-R6`, `MAN-R9`).
class Psn04GroupChatPage extends ConsumerStatefulWidget {
  const Psn04GroupChatPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<Psn04GroupChatPage> createState() => _Psn04GroupChatPageState();
}

class _Psn04GroupChatPageState extends ConsumerState<Psn04GroupChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<Message>>? _msgSub;
  StreamSubscription<List<Conversation>>? _convSub;

  Conversation? _conv;
  List<Message> _messages = const <Message>[];
  final List<FailedOutgoingMessage> _failedMessages = <FailedOutgoingMessage>[];
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _sendReadReceipts = true;
  AppError? _error;

  Message? _replyTo;
  String? _pendingPhotoSeed;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_initGroup);
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _convSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initGroup({bool showLoader = true}) async {
    if (!mounted) return;
    if (widget.conversationId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      if (showLoader) _isLoading = true;
      _error = null;
    });

    final chatRepo = ref.read(chatRepositoryProvider);
    final privacyRes = await ref
        .read(privacyRepositoryProvider)
        .getMyPrivacySettings();
    if (!mounted) return;
    if (privacyRes is Ok<PrivacySettings>) {
      _sendReadReceipts = privacyRes.value.sendReadReceipts;
    }

    final convRes = await chatRepo.getConversationById(widget.conversationId);
    if (!mounted) return;
    if (convRes is Err<Conversation>) {
      setState(() {
        _isLoading = false;
        _error = convRes.failure;
      });
      return;
    }

    final conv = (convRes as Ok<Conversation>).value;
    final msgsRes = await chatRepo.getMessages(conv.id);
    final isAdmin = await chatRepo.isGroupAdmin(conv.id);
    await chatRepo.markConversationRead(conv.id);
    if (!mounted) return;

    await _msgSub?.cancel();
    if (!mounted) return;
    _msgSub = chatRepo.watchMessages(conv.id).listen((updated) {
      if (!mounted) return;
      setState(() => _messages = updated);
    });

    await _convSub?.cancel();
    if (!mounted) return;
    _convSub = chatRepo.watchConversations().listen((convs) {
      if (!mounted) return;
      final match = convs.where((c) => c.id == conv.id).firstOrNull;
      setState(() => _conv = match);
    });

    setState(() {
      _conv = conv;
      _messages = msgsRes is Ok<List<Message>>
          ? msgsRes.value
          : const <Message>[];
      _isAdmin = isAdmin;
      _isLoading = false;
    });
  }

  Future<void> _sendMessage({
    String? overrideText,
    String? overridePhoto,
    String? overrideReplyId,
    String? retryTempId,
    String? voiceNoteSeed,
    int? voiceNoteDurationSeconds,
    String? stickerSeed,
  }) async {
    final conv = _conv;
    if (conv == null) return;
    final text = (overrideText ?? _textController.text).trim();
    final photo = overridePhoto ?? _pendingPhotoSeed;
    final replyId = overrideReplyId ?? _replyTo?.id;
    if (text.isEmpty &&
        photo == null &&
        voiceNoteSeed == null &&
        stickerSeed == null) {
      return;
    }

    if (overrideText == null && voiceNoteSeed == null && stickerSeed == null) {
      _textController.clear();
      setState(() {
        _pendingPhotoSeed = null;
        _replyTo = null;
        _isSending = true;
      });
    } else {
      setState(() {
        if (retryTempId != null) {
          _failedMessages.removeWhere((f) => f.tempId == retryTempId);
        }
        _isSending = true;
      });
    }

    final res = await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          conversationId: conv.id,
          text: text.isEmpty
              ? (voiceNoteSeed != null ? 'Pesan Suara' : (stickerSeed ?? ''))
              : text,
          photoSeed: photo,
          replyToMessageId: replyId,
          voiceNoteSeed: voiceNoteSeed,
          voiceNoteDurationSeconds: voiceNoteDurationSeconds,
          stickerSeed: stickerSeed,
        );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (res is Err<Message>) {
      setState(() {
        _failedMessages.add(
          FailedOutgoingMessage(
            tempId: 'fail-${DateTime.now().microsecondsSinceEpoch}',
            text: text,
            photoSeed: photo,
            replyToMessageId: replyId,
            errorMessage: res.failure.message,
          ),
        );
      });
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    final sentMsg = (res as Ok<Message>).value;
    if (!_messages.any((m) => m.id == sentMsg.id)) {
      setState(() => _messages = <Message>[..._messages, sentMsg]);
    }
  }

  Future<void> _pickPhoto() async {
    final seed = await pickAndCompressChatPhoto(context);
    if (seed == null || !mounted) return;
    setState(() => _pendingPhotoSeed = seed);
  }

  Future<void> _openAnnouncementSheet() async {
    final conv = _conv;
    if (conv == null || conv.isReadOnly) return;
    final ctrl = TextEditingController();
    final submit = await AppBottomSheet.show<bool>(
      context,
      title: AppStrings.psn04SendAnnouncementBtn,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextField(
            controller: ctrl,
            hintText: AppStrings.psn04AnnouncementHint,
            maxLines: 3,
            maxLength: AppLimits.messageTextMaxChars,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: AppStrings.psn04SendAnnouncementBtn,
            isExpanded: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (submit != true || text.isEmpty || !mounted) return;

    final res = await ref
        .read(chatRepositoryProvider)
        .sendPinnedAnnouncement(conversationId: conv.id, text: text);
    if (!mounted) return;
    if (res is Err<Message>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    await _initGroup();
  }

  Future<void> _showGroupMessageActions(Message msg) async {
    final uid = ref.read(authRepositoryProvider).currentUserId;
    final isMine = msg.sender.id == uid;
    final conv = _conv;
    if (conv == null) return;

    await AppBottomSheet.show<void>(
      context,
      title: msg.sender.displayName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!conv.isReadOnly && !msg.isDeletedForEveryone)
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text(AppStrings.psn03ReplyAction),
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _replyTo = msg);
              },
            ),
          if (!isMine && !msg.isDeletedForEveryone)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text(AppStrings.psn03ReportMessageAction),
              onTap: () async {
                Navigator.of(context).pop();
                final res = await ref
                    .read(reportRepositoryProvider)
                    .submitReport(
                      targetType: ReportTargetType.message,
                      targetId: msg.id,
                      category: ReportCategory.inappropriateContent,
                      note: msg.text,
                    );
                if (!mounted) return;
                if (res is Ok<Report>) {
                  AppToast.show(
                    context,
                    message: AppStrings.psn03ReportedMessageToast,
                    variant: AppToastVariant.success,
                  );
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text(AppStrings.psn03DeleteForMeAction),
            onTap: () async {
              Navigator.of(context).pop();
              await ref.read(chatRepositoryProvider).deleteMessageForMe(msg.id);
              if (!mounted) return;
              setState(
                () => _messages = _messages
                    .where((m) => m.id != msg.id)
                    .toList(growable: false),
              );
            },
          ),
          if ((isMine || _isAdmin) && !msg.isDeletedForEveryone)
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: context.colors.danger,
              ),
              title: Text(
                _isAdmin && !isMine
                    ? AppStrings.psn04AdminDeleteMessageAction
                    : AppStrings.psn03DeleteForEveryoneAction,
              ),
              onTap: () async {
                Navigator.of(context).pop();
                final res = await ref
                    .read(chatRepositoryProvider)
                    .deleteMessageForEveryone(msg.id);
                if (!mounted) return;
                if (res is Err<void>) {
                  AppToast.show(
                    context,
                    message: res.failure.message,
                    variant: AppToastVariant.error,
                  );
                  return;
                }
                final refreshed = await ref
                    .read(chatRepositoryProvider)
                    .getMessages(conv.id);
                if (mounted && refreshed is Ok<List<Message>>) {
                  setState(() => _messages = refreshed.value);
                }
              },
            ),
          if (_isAdmin && !isMine)
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: context.colors.danger,
              ),
              title: const Text(AppStrings.psn04AdminKickMemberAction),
              onTap: () async {
                Navigator.of(context).pop();
                final ok = await ConfirmDialog.show(
                  context,
                  title: AppStrings.psn04AdminKickConfirmTitle,
                  message: AppStrings.psn04AdminKickConfirmBody,
                  confirmLabel: AppStrings.psn04AdminKickMemberAction,
                  isDestructive: true,
                );
                if (ok != true || !mounted) return;
                await ref
                    .read(chatRepositoryProvider)
                    .removeGroupMember(
                      conversationId: conv.id,
                      targetUserId: msg.sender.id,
                    );
                await _initGroup();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authRepositoryProvider).currentUserId ?? '';
    final now = ref.read(authRepositoryProvider).currentTime;
    final colors = context.colors;
    final typo = context.typo;

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _initGroup);
    } else if (_conv == null) {
      body = StateView.contentUnavailable(onBack: () => context.pop());
    } else {
      final conv = _conv!;
      body = Column(
        children: <Widget>[
          if (conv.pinnedAnnouncement != null &&
              conv.pinnedAnnouncement!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.confidenceAmberSurface,
                border: Border(
                  bottom: BorderSide(color: colors.confidenceAmber),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.campaign_outlined,
                    color: colors.confidenceAmber,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${AppStrings.psn04PinnedAnnouncementTitle}: ${conv.pinnedAnnouncement!}',
                      style: typo.caption.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
          if (conv.isReadOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: colors.chipInactive,
              child: Text(
                AppStrings.psn03ReadOnlySessionBanner,
                style: typo.caption.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: _messages.length + _failedMessages.length,
              itemBuilder: (context, idx) {
                if (idx >= _messages.length) {
                  final failed = _failedMessages[idx - _messages.length];
                  return FailedMessageTile(
                    item: failed,
                    onRetry: () => _sendMessage(
                      overrideText: failed.text,
                      overridePhoto: failed.photoSeed,
                      overrideReplyId: failed.replyToMessageId,
                      retryTempId: failed.tempId,
                    ),
                  );
                }
                final msg = _messages[idx];
                final prev = idx > 0 ? _messages[idx - 1] : null;
                final next = idx + 1 < _messages.length
                    ? _messages[idx + 1]
                    : null;
                final showDateHeader =
                    prev == null ||
                    ChatDateSeparator.isDifferentDay(
                      prev.createdAt,
                      msg.createdAt,
                    );
                final isGroupedPrev =
                    !showDateHeader &&
                    prev.sender.id == msg.sender.id &&
                    msg.createdAt.difference(prev.createdAt).inMinutes < 5;
                final isGroupedNext =
                    next != null &&
                    !ChatDateSeparator.isDifferentDay(
                      msg.createdAt,
                      next.createdAt,
                    ) &&
                    next.sender.id == msg.sender.id &&
                    next.createdAt.difference(msg.createdAt).inMinutes < 5;
                final replied = msg.replyToMessageId == null
                    ? null
                    : _messages
                          .where((m) => m.id == msg.replyToMessageId)
                          .firstOrNull;
                final bubble = ChatMessageBubble(
                  message: msg,
                  isMine: msg.sender.id == uid,
                  isGroup: true,
                  now: now,
                  showReadStatus: _sendReadReceipts,
                  isGroupedWithPrevious: isGroupedPrev,
                  isGroupedWithNext: isGroupedNext,
                  repliedMessage: replied,
                  onLongPress: () => _showGroupMessageActions(msg),
                  onSwipeReply: !conv.isReadOnly && !msg.isDeletedForEveryone
                      ? () => setState(() => _replyTo = msg)
                      : null,
                  onPhotoTap: (seed) => context
                      .push('${AppPages.psn06.routePath}?seed=$seed')
                      .ignore(),
                );
                if (!showDateHeader) return bubble;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ChatDateSeparator(date: msg.createdAt, now: now),
                    bubble,
                  ],
                );
              },
            ),
          ),
          if (!conv.isReadOnly)
            ChatComposerBar(
              controller: _textController,
              enabled: true,
              isSending: _isSending,
              replyToMessage: _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
              pendingPhotoSeed: _pendingPhotoSeed,
              onClearPhoto: () => setState(() => _pendingPhotoSeed = null),
              onPickPhoto: _pickPhoto,
              onSend: _sendMessage,
              onSendVoiceNote: () => _sendMessage(
                voiceNoteSeed: 'vn-${DateTime.now().millisecondsSinceEpoch}',
                voiceNoteDurationSeconds: 5,
              ),
              onSendSticker: (stk) =>
                  _sendMessage(overrideText: stk, stickerSeed: stk),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _conv?.title ?? AppStrings.psn04Title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_conv != null)
              Text(
                '${_conv!.participants.length} anggota',
                style: typo.micro.copyWith(color: colors.textMuted),
              ),
          ],
        ),
        actions: <Widget>[
          if (_isAdmin && _conv != null && !_conv!.isReadOnly)
            IconButton(
              tooltip: AppStrings.psn04SendAnnouncementBtn,
              onPressed: _openAnnouncementSheet,
              icon: Semantics(
                label: AppStrings.psn04SendAnnouncementBtn,
                child: const Icon(Icons.campaign_outlined),
              ),
            ),
          if (_conv != null)
            IconButton(
              tooltip: AppStrings.psn03MenuInfo,
              onPressed: () async {
                final outcome = await context.push(
                  '${AppPages.psn05.routePath}?conversationId=${_conv!.id}',
                );
                if (!context.mounted) return;
                if (outcome == 'left') {
                  context.pop();
                } else {
                  await _initGroup(showLoader: false);
                }
              },
              icon: Semantics(
                label: AppStrings.psn03MenuInfo,
                child: const Icon(Icons.info_outline_rounded),
              ),
            ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}
