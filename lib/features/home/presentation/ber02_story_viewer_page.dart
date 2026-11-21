import 'dart:async';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// BER-02 Penampil Story layar penuh bergaya Instagram (`BER-R12`).
///
/// - Foto/video maks 15 detik, tayang 24 jam, hanya untuk pengikut.
/// - Tahan layar untuk jeda (*long-press pause*), geser ke bawah untuk tutup.
/// - Reaksi emoji cepat & balas story ke DM (untuk cerita orang lain).
/// - Daftar penonton hanya terlihat pembuat.
/// - TANPA tombol bagikan ulang (`BER-R12`).
class Ber02StoryViewerPage extends ConsumerStatefulWidget {
  const Ber02StoryViewerPage({
    super.key,
    this.initialUserId,
    this.initialStoryId,
  });

  final String? initialUserId;
  final String? initialStoryId;

  @override
  ConsumerState<Ber02StoryViewerPage> createState() =>
      _Ber02StoryViewerPageState();
}

class _Ber02StoryViewerPageState extends ConsumerState<Ber02StoryViewerPage> {
  static const List<String> _quickEmojis = <String>[
    '❤️',
    '🔥',
    '👏',
    '😂',
    '😮',
    '🙏',
  ];

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  bool _isLoading = true;
  AppError? _error;
  List<Story> _stories = const <Story>[];
  int _currentIndex = 0;
  Timer? _playbackTimer;
  Timer? _emojiPopTimer;
  double _progress = 0.0;
  int _currentTick = 0;
  bool _isSendingReply = false;
  bool _isPausedByHold = false;
  double _verticalDragOffset = 0.0;
  String? _poppedEmoji;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _replyFocusNode.addListener(_onReplyFocusChanged);
    Future<void>.microtask(_loadStories);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _emojiPopTimer?.cancel();
    _replyFocusNode.removeListener(_onReplyFocusChanged);
    _replyFocusNode.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _onReplyFocusChanged() {
    if (mounted) setState(() {});
    if (_replyFocusNode.hasFocus) {
      _playbackTimer?.cancel();
    } else if (!_isSendingReply && !_isPausedByHold && mounted) {
      _resumePlayback();
    }
  }

  Future<void> _loadStories() async {
    _playbackTimer?.cancel();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    _myUserId = authRepo.currentUserId;
    final storyRepo = ref.read(storyRepositoryProvider);
    final res = await storyRepo.getStories();

    if (!mounted) return;
    if (res is Err<List<Story>>) {
      setState(() {
        _isLoading = false;
        _error = res.failure;
      });
      return;
    }

    final all = (res as Ok<List<Story>>).value;
    var targetIdx = 0;
    if (widget.initialStoryId != null) {
      final idx = all.indexWhere((s) => s.id == widget.initialStoryId);
      if (idx >= 0) targetIdx = idx;
    } else if (widget.initialUserId != null) {
      final idx = all.indexWhere((s) => s.author.id == widget.initialUserId);
      if (idx >= 0) targetIdx = idx;
    }

    setState(() {
      _stories = all;
      _currentIndex = targetIdx;
      _isLoading = false;
    });

    if (all.isNotEmpty) {
      _startPlayback();
    }
  }

  void _startPlayback() {
    _playbackTimer?.cancel();
    _progress = 0.0;
    _currentTick = 0;
    if (_stories.isEmpty || _currentIndex >= _stories.length) return;

    final currentStory = _stories[_currentIndex];
    ref.read(storyRepositoryProvider).markStoryViewed(currentStory.id).ignore();
    _resumePlayback();
  }

  void _resumePlayback() {
    _playbackTimer?.cancel();
    if (_stories.isEmpty ||
        _currentIndex >= _stories.length ||
        _replyFocusNode.hasFocus ||
        _isSendingReply ||
        _isPausedByHold) {
      return;
    }

    final currentStory = _stories[_currentIndex];
    final totalSeconds = currentStory.durationSeconds.clamp(3, 15);
    const tickMs = 80;
    final totalTicks = (totalSeconds * 1000) ~/ tickMs;

    _playbackTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_replyFocusNode.hasFocus || _isSendingReply || _isPausedByHold) {
        t.cancel();
        return;
      }
      _currentTick++;
      setState(() {
        _progress = (_currentTick / totalTicks).clamp(0.0, 1.0);
      });
      if (_currentTick >= totalTicks) {
        t.cancel();
        _nextStory();
      }
    });
  }

  Future<void> _sendStoryReply(Story story, {String? overrideText}) async {
    final clean = (overrideText ?? _replyController.text).trim();
    if (clean.isEmpty || _isSendingReply) return;

    HapticFeedback.lightImpact().ignore();
    if (overrideText != null) {
      _emojiPopTimer?.cancel();
      setState(() => _poppedEmoji = overrideText);
      _emojiPopTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _poppedEmoji = null);
      });
    }

    _playbackTimer?.cancel();
    setState(() => _isSendingReply = true);

    final chatRepo = ref.read(chatRepositoryProvider);
    final convRes = await chatRepo.openDirectConversationWithUser(
      story.author.id,
    );
    if (!mounted) return;

    if (convRes is Err<Conversation>) {
      setState(() => _isSendingReply = false);
      AppToast.show(
        context,
        message: convRes.failure.message,
        variant: AppToastVariant.error,
      );
      _resumePlayback();
      return;
    }

    final conv = (convRes as Ok<Conversation>).value;
    final formatted = story.caption.trim().isNotEmpty
        ? 'Membalas story ("${story.caption.trim()}"): $clean'
        : 'Membalas story: $clean';

    final msgRes = await chatRepo.sendMessage(
      conversationId: conv.id,
      text: formatted,
    );
    if (!mounted) return;

    setState(() => _isSendingReply = false);
    if (msgRes is Err<Message>) {
      AppToast.show(
        context,
        message: msgRes.failure.message,
        variant: AppToastVariant.error,
      );
      _resumePlayback();
      return;
    }

    if (overrideText == null) {
      _replyController.clear();
      _replyFocusNode.unfocus();
    }
    AppToast.show(
      context,
      message: AppStrings.ber02ReplySentToast,
      variant: AppToastVariant.success,
    );
    _resumePlayback();
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex++;
      });
      _startPlayback();
    } else {
      if (mounted) context.pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex--;
      });
      _startPlayback();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _playbackTimer?.cancel();
    setState(() => _isPausedByHold = true);
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    setState(() => _isPausedByHold = false);
    _resumePlayback();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_replyFocusNode.hasFocus) return;
    if (details.delta.dy > 0 || _verticalDragOffset > 0) {
      _playbackTimer?.cancel();
      setState(() {
        _verticalDragOffset = (_verticalDragOffset + details.delta.dy).clamp(
          0.0,
          240.0,
        );
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_replyFocusNode.hasFocus) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_verticalDragOffset > 110 || velocity > 700) {
      HapticFeedback.lightImpact();
      context.pop();
    } else {
      setState(() => _verticalDragOffset = 0.0);
      _resumePlayback();
    }
  }

  Future<void> _showViewersSheet(Story story) async {
    _playbackTimer?.cancel();
    final res = await ref
        .read(storyRepositoryProvider)
        .getStoryViewers(story.id);
    if (!mounted) return;
    final viewers = res is Ok<List<StoryViewer>>
        ? res.value
        : const <StoryViewer>[];

    await AppBottomSheet.show<void>(
      context,
      title: '${AppStrings.ber02ViewersTitle} (${viewers.length})',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.ber02FollowersOnlyNotice,
            style: context.typo.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          if (viewers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  AppStrings.ber02NoViewsYet,
                  style: context.typo.caption,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: viewers.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final v = viewers[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppAvatar(
                      name: v.viewer.displayName,
                      seed: v.viewer.avatarSeed,
                      size: AppSizes.avatarSm,
                    ),
                    title: Text(v.viewer.displayName, style: context.typo.body),
                    subtitle: Text(
                      '${v.viewer.marga} · ${v.viewer.city}',
                      style: context.typo.caption,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );

    if (mounted) _resumePlayback();
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    // Larangan PRD / Tahap 3: UI Fase 2 tidak tampil bila flags.stories == false
    if (!flags.stories) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.ber02Title)),
        body: StateView.contentUnavailable(
          onBack: () => context.go(AppPages.berandaPath),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.ber02Title)),
        body: StateView.fromError(_error!, onRetry: _loadStories),
      );
    }

    if (_stories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.ber02Title)),
        body: StateView.empty(
          message: 'Belum ada cerita aktif dari pengikut.',
          actionLabel: AppStrings.ber01CreateStoryBtn,
          onAction: () => context.push(AppPages.ber03.routePath),
        ),
      );
    }

    final story = _stories[_currentIndex];
    final isMine = story.author.id == _myUserId;
    final dragRatio = (_verticalDragOffset / 240.0).clamp(0.0, 1.0);
    final chromeOpacity = _isPausedByHold ? 0.3 : 1.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapUp: (details) {
            if (_replyFocusNode.hasFocus) {
              _replyFocusNode.unfocus();
              return;
            }
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.localPosition.dx < screenWidth * 0.35) {
              _prevStory();
            } else {
              _nextStory();
            }
          },
          onLongPressStart: _onLongPressStart,
          onLongPressEnd: _onLongPressEnd,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Transform.translate(
            offset: Offset(0, _verticalDragOffset),
            child: Transform.scale(
              scale: 1.0 - dragRatio * 0.1,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Tampilan Media Story (Foto / Video)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppRadius.card + dragRatio * 12,
                      ),
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            if (!story.isVideo &&
                                PlaceholderImage.isRealImageSeed(
                                  story.mediaSeed,
                                ))
                              ColoredBox(
                                color: Colors.black,
                                child: PlaceholderImage(
                                  seed: story.mediaSeed,
                                  fit: BoxFit.contain,
                                  borderRadius: BorderRadius.zero,
                                ),
                              )
                            else
                              Container(
                                color: colors.primaryDark,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      story.isVideo
                                          ? Icons.videocam_rounded
                                          : Icons.photo_library_outlined,
                                      size: 64,
                                      color: colors.onPrimary.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      story.isVideo
                                          ? 'Video Cerita (15d)'
                                          : 'Foto Cerita',
                                      style: typo.h3.copyWith(
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Gradasi gelap atas agar header & progress selalu kontras
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 124,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: <Color>[
                                        Colors.black.withValues(alpha: 0.65),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Gradasi gelap bawah agar caption & kotak balas kontras
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 180,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: <Color>[
                                        Colors.black.withValues(alpha: 0.72),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (story.caption.isNotEmpty)
                              Positioned(
                                bottom: isMine ? 84 : 132,
                                left: AppSpacing.lg,
                                right: AppSpacing.lg,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: AppRadius.cardRadius,
                                  ),
                                  child: Text(
                                    story.caption,
                                    textAlign: TextAlign.center,
                                    style: typo.body.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Animasi emoji reaksi yang melayang saat ditekan
                  if (_poppedEmoji != null)
                    Center(
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey<String>(
                            '$_poppedEmoji-${DateTime.now().millisecond}',
                          ),
                          tween: Tween<double>(begin: 0.4, end: 1.25),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Text(
                            _poppedEmoji!,
                            style: const TextStyle(fontSize: 68),
                          ),
                        ),
                      ),
                    ),

                  // Bilah Atas: Indikator Durasi & Info Pengunggah
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: AnimatedOpacity(
                      opacity: chromeOpacity,
                      duration: const Duration(milliseconds: 160),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // Progress Bar
                          Row(
                            children: List<Widget>.generate(_stories.length, (
                              i,
                            ) {
                              var p = 0.0;
                              if (i < _currentIndex) {
                                p = 1.0;
                              } else if (i == _currentIndex) {
                                p = _progress;
                              }
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2.0,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: AppRadius.pillRadius,
                                    child: LinearProgressIndicator(
                                      value: p,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.32,
                                      ),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                      minHeight: 2.8,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Header Info
                          Row(
                            children: <Widget>[
                              AppAvatar(
                                name: story.author.displayName,
                                seed: story.author.avatarSeed,
                                size: AppSizes.avatarSm,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Flexible(
                                          child: Text(
                                            story.author.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: typo.captionStrong.copyWith(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (_isPausedByHold) ...<Widget>[
                                          const SizedBox(width: AppSpacing.xs),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                              borderRadius:
                                                  AppRadius.pillRadius,
                                            ),
                                            child: Text(
                                              AppStrings.ber02PausedIndicator,
                                              style: typo.micro.copyWith(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${story.author.marga} · ${story.author.city}',
                                      style: typo.micro.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: AppStrings.actionClose,
                                onPressed: () => context.pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bilah Bawah: Daftar Penonton (pembuat) ATAU Reaksi Cepat & Balas Story (orang lain)
                  // CATATAN: TANPA tombol bagikan ulang sesuai larangan BER-R12!
                  if (isMine)
                    Positioned(
                      bottom: AppSpacing.lg,
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      child: AnimatedOpacity(
                        opacity: chromeOpacity,
                        duration: const Duration(milliseconds: 160),
                        child: Center(
                          child: InkWell(
                            onTap: () => _showViewersSheet(story),
                            borderRadius: AppRadius.pillRadius,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm + 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                borderRadius: AppRadius.pillRadius,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.visibility_outlined,
                                    color: Colors.white,
                                    size: AppSizes.iconSm,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '${AppStrings.ber02StoryViews}: ${story.viewerCount}',
                                    style: typo.captionStrong.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      bottom: AppSpacing.md,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: AnimatedOpacity(
                        opacity: chromeOpacity,
                        duration: const Duration(milliseconds: 160),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (!_replyFocusNode.hasFocus)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: _quickEmojis
                                      .map(
                                        (emoji) => Semantics(
                                          button: true,
                                          label:
                                              '${AppStrings.ber02QuickReactionLabel} $emoji',
                                          child: InkWell(
                                            onTap: _isSendingReply
                                                ? null
                                                : () => _sendStoryReply(
                                                    story,
                                                    overrideText: emoji,
                                                  ),
                                            borderRadius: AppRadius.pillRadius,
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.38,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.18),
                                                ),
                                              ),
                                              child: Text(
                                                emoji,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.62),
                                  borderRadius: AppRadius.pillRadius,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: _replyController,
                                        focusNode: _replyFocusNode,
                                        style: typo.body.copyWith(
                                          color: Colors.white,
                                        ),
                                        cursorColor: Colors.white,
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (_) =>
                                            _sendStoryReply(story),
                                        decoration: InputDecoration(
                                          hintText: AppStrings.ber02ReplyHint,
                                          hintStyle: typo.body.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: AppSpacing.xs,
                                              ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: AppStrings.ber02ReplySendTooltip,
                                      onPressed: _isSendingReply
                                          ? null
                                          : () => _sendStoryReply(story),
                                      icon: _isSendingReply
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.send_rounded,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
