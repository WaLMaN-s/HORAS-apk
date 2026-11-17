import 'dart:async';

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

/// BER-02 Penampil Story (BER-R12).
///
/// - Foto/video maks 15 detik, tayang 24 jam, hanya untuk pengikut.
/// - Daftar penonton hanya terlihat pembuat.
/// - TANPA tombol bagikan ulang (BER-R12).
/// - Memiliki status memuat, kosong, offline, error.
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
  bool _isLoading = true;
  AppError? _error;
  List<Story> _stories = const <Story>[];
  int _currentIndex = 0;
  Timer? _playbackTimer;
  double _progress = 0.0;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadStories);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
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
    int targetIdx = 0;
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
    if (_stories.isEmpty || _currentIndex >= _stories.length) return;

    final currentStory = _stories[_currentIndex];
    ref.read(storyRepositoryProvider).markStoryViewed(currentStory.id).ignore();

    final totalSeconds = currentStory.durationSeconds.clamp(3, 15);
    const tickMs = 100;
    final totalTicks = (totalSeconds * 1000) ~/ tickMs;
    var currentTick = 0;

    _playbackTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      currentTick++;
      setState(() {
        _progress = (currentTick / totalTicks).clamp(0.0, 1.0);
      });
      if (currentTick >= totalTicks) {
        t.cancel();
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
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
      setState(() {
        _currentIndex--;
      });
      _startPlayback();
    }
  }

  void _showViewersSheet(Story story) async {
    _playbackTimer?.cancel();
    final res = await ref
        .read(storyRepositoryProvider)
        .getStoryViewers(story.id);
    if (!mounted) return;
    final viewers = res is Ok<List<StoryViewer>>
        ? res.value
        : const <StoryViewer>[];

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${AppStrings.ber02ViewersTitle} (${viewers.length})',
                  style: ctx.typo.h3,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.ber02FollowersOnlyNotice,
                  style: ctx.typo.micro.copyWith(color: ctx.colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                if (viewers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Center(
                      child: Text(
                        AppStrings.ber02NoViewsYet,
                        style: ctx.typo.caption,
                      ),
                    ),
                  )
                else
                  Flexible(
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
                          title: Text(
                            v.viewer.displayName,
                            style: ctx.typo.body,
                          ),
                          subtitle: Text(
                            '${v.viewer.marga} · ${v.viewer.city}',
                            style: ctx.typo.caption,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) _startPlayback();
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapUp: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.localPosition.dx < screenWidth * 0.35) {
              _prevStory();
            } else {
              _nextStory();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Tampilan Media Story (Foto / Video)
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.primaryDark,
                      borderRadius: BorderRadius.circular(AppRadius.photo),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          story.isVideo
                              ? Icons.videocam_rounded
                              : Icons.photo_library_outlined,
                          size: 64,
                          color: colors.onPrimary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          story.isVideo ? 'Video Cerita (15d)' : 'Foto Cerita',
                          style: typo.h3.copyWith(color: colors.onPrimary),
                        ),
                        if (story.caption.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                              child: Text(
                                story.caption,
                                textAlign: TextAlign.center,
                                style: typo.body.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Bilah Atas: Indikator Durasi & Info Pengunggah
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Progress Bar
                    Row(
                      children: List<Widget>.generate(_stories.length, (i) {
                        double p = 0.0;
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
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: p,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.35,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 3,
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
                              Text(
                                story.author.displayName,
                                style: typo.captionStrong.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${story.author.marga} · ${story.author.city}',
                                style: typo.micro.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: AppStrings.actionClose,
                          onPressed: () => context.pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bilah Bawah: Daftar Penonton (HANYA terlihat pembuat — BER-R12)
              // CATATAN: TANPA tombol bagikan ulang sesuai larangan BER-R12!
              if (isMine)
                Positioned(
                  bottom: AppSpacing.lg,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: Center(
                    child: InkWell(
                      onTap: () => _showViewersSheet(story),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
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
            ],
          ),
        ),
      ),
    );
  }
}
