import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide Block;
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/features/messages/presentation/chat_thread_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// PSN-03 Chat Pribadi (`PSN-R1`, `PSN-R3`, `PSN-R4`, `PSN-R6`..`PSN-R9`, `AC-16`).
class Psn03PrivateChatPage extends ConsumerStatefulWidget {
  const Psn03PrivateChatPage({
    this.conversationId,
    this.targetUserId,
    super.key,
  });

  final String? conversationId;
  final String? targetUserId;

  @override
  ConsumerState<Psn03PrivateChatPage> createState() =>
      _Psn03PrivateChatPageState();
}

class _Psn03PrivateChatPageState extends ConsumerState<Psn03PrivateChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<Message>>? _msgSub;
  StreamSubscription<List<Conversation>>? _convSub;

  Conversation? _conv;
  List<Message> _messages = const <Message>[];
  final List<FailedOutgoingMessage> _failedMessages = <FailedOutgoingMessage>[];
  bool _sendReadReceipts = true;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isBlockedClosed = false;
  AppError? _error;

  Message? _replyTo;
  String? _pendingPhotoSeed;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    Future<void>.microtask(_initChat);
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final distFromBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    final shouldShow = distFromBottom > 240;
    if (shouldShow != _showScrollToBottom && mounted) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _convSub?.cancel();
    _textController.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat({bool showLoader = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoader) _isLoading = true;
      _error = null;
      _isBlockedClosed = false;
    });

    final chatRepo = ref.read(chatRepositoryProvider);
    final privacyRes = await ref
        .read(privacyRepositoryProvider)
        .getMyPrivacySettings();
    if (!mounted) return;
    if (privacyRes is Ok<PrivacySettings>) {
      _sendReadReceipts = privacyRes.value.sendReadReceipts;
    }

    final Result<Conversation> convRes;
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      convRes = await chatRepo.getConversationById(widget.conversationId!);
    } else if (widget.targetUserId != null && widget.targetUserId!.isNotEmpty) {
      convRes = await chatRepo.openDirectConversationWithUser(
        widget.targetUserId!,
      );
    } else {
      setState(() => _isLoading = false);
      return;
    }

    if (!mounted) return;
    if (convRes is Err<Conversation>) {
      final err = convRes.failure;
      final isBlockErr = err.message.toLowerCase().contains('diblokir');
      setState(() {
        _isLoading = false;
        _isBlockedClosed = isBlockErr;
        _error = isBlockErr ? null : err;
      });
      return;
    }

    final conv = (convRes as Ok<Conversation>).value;
    final msgsRes = await chatRepo.getMessages(conv.id);
    if (!mounted) return;

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
      final stillVisible = convs.where((c) => c.id == conv.id).firstOrNull;
      if (stillVisible == null) {
        setState(() => _isBlockedClosed = true);
      } else {
        setState(() => _conv = stillVisible);
      }
    });

    setState(() {
      _conv = conv;
      _messages = msgsRes is Ok<List<Message>>
          ? msgsRes.value
          : const <Message>[];
      _isLoading = false;
    });
  }

  PersonSummary? get _otherUser {
    final uid = ref.read(authRepositoryProvider).currentUserId;
    final conv = _conv;
    if (conv == null) return null;
    return conv.participants.where((p) => p.id != uid).firstOrNull;
  }

  bool get _isCounterpartDeleted =>
      _otherUser?.displayName == AppStrings.psn03DeletedUserLabel;

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

  Future<void> _showMessageActions(Message msg) async {
    final uid = ref.read(authRepositoryProvider).currentUserId;
    final isMine = msg.sender.id == uid;
    final now = ref.read(authRepositoryProvider).currentTime;
    final within1Hour =
        now.difference(msg.createdAt) <= const Duration(hours: 1);

    await AppBottomSheet.show<void>(
      context,
      title: msg.sender.displayName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!msg.isDeletedForEveryone)
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text(AppStrings.psn03ReplyAction),
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _replyTo = msg);
              },
            ),
          if (!msg.isDeletedForEveryone && msg.text.trim().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text(AppStrings.psn03CopyMessageAction),
              onTap: () async {
                Navigator.of(context).pop();
                await Clipboard.setData(ClipboardData(text: msg.text));
                if (mounted) {
                  AppToast.show(
                    context,
                    message: AppStrings.psn03CopiedMessageToast,
                    variant: AppToastVariant.info,
                  );
                }
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
          if (isMine && !msg.isDeletedForEveryone)
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: within1Hour
                    ? context.colors.danger
                    : context.colors.textMuted,
              ),
              title: Text(
                AppStrings.psn03DeleteForEveryoneAction,
                style: within1Hour
                    ? null
                    : TextStyle(color: context.colors.textMuted),
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
                    .getMessages(_conv!.id);
                if (mounted && refreshed is Ok<List<Message>>) {
                  setState(() => _messages = refreshed.value);
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmBlock() async {
    final other = _otherUser;
    if (other == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.sek04BlockConfirmTitle,
      message: AppStrings.sek04BlockConfirmBody,
      confirmLabel: AppStrings.psn03MenuBlock,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final res = await ref.read(blockRepositoryProvider).blockUser(other.id);
    if (!mounted) return;
    if (res is Err<Block>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    setState(() => _isBlockedClosed = true);
    AppToast.show(
      context,
      message: AppStrings.psn03ChatBlockedBanner,
      variant: AppToastVariant.info,
    );
  }

  List<String> _buildQuickGreetings(PersonSummary? other) {
    final result = <String>[];
    final partuturan = other?.partuturan;
    if (partuturan != null &&
        !partuturan.modeNetral &&
        partuturan.confidence != PartuturanConfidence.rendah &&
        partuturan.istilah != null &&
        partuturan.istilah!.isNotEmpty) {
      result.add(AppStrings.psn03QuickGreetingRelation(partuturan.istilah!));
    }
    result.add(AppStrings.psn03QuickGreetingDefault);
    result.add(AppStrings.psn03QuickGreetingThanks);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authRepositoryProvider).currentUserId ?? '';
    final now = ref.read(authRepositoryProvider).currentTime;
    final colors = context.colors;
    final typo = context.typo;
    final other = _otherUser;

    Widget body;
    if (_isLoading) {
      body = const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    } else if (_isBlockedClosed) {
      body = Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: colors.danger.withValues(alpha: 0.12),
            child: Text(
              AppStrings.psn03ChatBlockedBanner,
              style: typo.caption.copyWith(color: colors.danger),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StateView.contentUnavailable(onBack: () => context.pop()),
          ),
        ],
      );
    } else if (_error != null) {
      body = StateView.fromError(_error!, onRetry: _initChat);
    } else if (_conv == null) {
      body = StateView.empty(
        message: AppStrings.stateEmptyDefaultTitle,
        actionLabel: AppStrings.semanticsBack,
        onAction: () => context.pop(),
      );
    } else {
      final conv = _conv!;
      final composerEnabled = !_isCounterpartDeleted && !conv.isReadOnly;

      body = Column(
        children: <Widget>[
          if (_isCounterpartDeleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: colors.chipInactive,
              child: Text(
                AppStrings.psn03DeletedUserBanner,
                style: typo.caption.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          if (!_sendReadReceipts)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              color: colors.chipInactive,
              child: Text(
                AppStrings.psn03ReadReceiptsOffHint,
                style: typo.micro.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: Stack(
              children: <Widget>[
                ListView.builder(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                      isGroup: false,
                      now: now,
                      showReadStatus: _sendReadReceipts,
                      isGroupedWithPrevious: isGroupedPrev,
                      isGroupedWithNext: isGroupedNext,
                      repliedMessage: replied,
                      onLongPress: () => _showMessageActions(msg),
                      onSwipeReply: composerEnabled && !msg.isDeletedForEveryone
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
                if (_showScrollToBottom)
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: Semantics(
                      button: true,
                      label: AppStrings.psn03ScrollToBottomTooltip,
                      child: Material(
                        color: colors.surface,
                        elevation: 3,
                        shape: CircleBorder(
                          side: BorderSide(color: colors.border),
                        ),
                        child: IconButton(
                          tooltip: AppStrings.psn03ScrollToBottomTooltip,
                          onPressed: _scrollToBottom,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ChatComposerBar(
            controller: _textController,
            enabled: composerEnabled,
            isSending: _isSending,
            replyToMessage: _replyTo,
            onCancelReply: () => setState(() => _replyTo = null),
            pendingPhotoSeed: _pendingPhotoSeed,
            onClearPhoto: () => setState(() => _pendingPhotoSeed = null),
            quickGreetings: composerEnabled && other != null
                ? _buildQuickGreetings(other)
                : const <String>[],
            onQuickGreetingTap: (greeting) =>
                _sendMessage(overrideText: greeting),
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
        title: other == null
            ? const Text(AppStrings.psn03Title)
            : InkWell(
                onTap: _isCounterpartDeleted
                    ? null
                    : () => context
                          .push(
                            '${AppPages.sek04.routePath}?userId=${other.id}',
                          )
                          .ignore(),
                child: Row(
                  children: <Widget>[
                    AppAvatar(
                      name: other.displayName,
                      seed: other.avatarSeed,
                      size: AppSizes.avatarSm,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _isCounterpartDeleted
                                ? AppStrings.psn03DeletedUserLabel
                                : other.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typo.bodyStrong,
                          ),
                          if (!_isCounterpartDeleted &&
                              other.partuturan != null &&
                              !other.partuturan!.modeNetral)
                            PartuturanBadge(
                              result: other.partuturan!,
                              onTap: () => context
                                  .push(
                                    '${AppPages.tar05.routePath}?userId=${other.id}',
                                  )
                                  .ignore(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        // PSN-R9: TIDAK ADA tombol telepon/video.
        actions: <Widget>[
          if (_conv != null && !_isBlockedClosed)
            IconButton(
              tooltip: AppStrings.psn03MenuInfo,
              onPressed: () async {
                final outcome = await context.push(
                  '${AppPages.psn05.routePath}?conversationId=${_conv!.id}',
                );
                if (outcome == 'blocked' && mounted) {
                  setState(() => _isBlockedClosed = true);
                } else {
                  await _initChat(showLoader: false);
                }
              },
              icon: Semantics(
                label: AppStrings.psn03MenuInfo,
                child: const Icon(Icons.info_outline_rounded),
              ),
            ),
          if (other != null && !_isBlockedClosed)
            PopupMenuButton<String>(
              onSelected: (choice) {
                if (choice == 'report') {
                  context
                      .push('/report?targetType=user&targetId=${other.id}')
                      .ignore();
                } else if (choice == 'block') {
                  _confirmBlock();
                }
              },
              itemBuilder: (ctx) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Text(AppStrings.psn03MenuReport),
                ),
                const PopupMenuItem<String>(
                  value: 'block',
                  child: Text(AppStrings.psn03MenuBlock),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}
