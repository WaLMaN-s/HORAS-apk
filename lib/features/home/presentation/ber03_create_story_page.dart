import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// BER-03 Buat Story (BER-R12).
///
/// - Foto atau video maks 15 detik, tayang 24 jam, hanya untuk pengikut.
/// - Memiliki status memuat, offline, error.
class Ber03CreateStoryPage extends ConsumerStatefulWidget {
  const Ber03CreateStoryPage({super.key});

  @override
  ConsumerState<Ber03CreateStoryPage> createState() =>
      _Ber03CreateStoryPageState();
}

class _Ber03CreateStoryPageState extends ConsumerState<Ber03CreateStoryPage> {
  final _captionController = TextEditingController();
  bool _isVideo = false;
  int _durationSeconds = 5;
  String _mediaSeed = 'sample-story-photo';
  bool _isPublishing = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _selectPhoto() {
    setState(() {
      _isVideo = false;
      _durationSeconds = 5;
      _mediaSeed = 'story-photo-${DateTime.now().microsecondsSinceEpoch}';
    });
  }

  void _selectVideo() {
    // BER-R12: Video maksimal 15 detik
    setState(() {
      _isVideo = true;
      _durationSeconds = 15;
      _mediaSeed = 'story-video-${DateTime.now().microsecondsSinceEpoch}';
    });
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    setState(() => _isPublishing = true);

    final repo = ref.read(storyRepositoryProvider);
    final res = await repo.createStory(
      mediaSeed: _mediaSeed,
      isVideo: _isVideo,
      durationSeconds: _durationSeconds,
      caption: _captionController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isPublishing = false);

    if (res is Err<Story>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }

    AppToast.show(
      context,
      message: 'Cerita berhasil dibagikan untuk pengikutmu (24 jam).',
      variant: AppToastVariant.success,
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    if (!flags.stories) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.ber03Title)),
        body: StateView.contentUnavailable(
          onBack: () => context.go(AppPages.berandaPath),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.ber03Title),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: AppButton(
              label: AppStrings.ber03PublishBtn,
              variant: AppButtonVariant.primary,
              isLoading: _isPublishing,
              onPressed: _publish,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            // Kotak Pratinjau Media
            AspectRatio(
              aspectRatio: 9 / 12,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.primaryDark,
                  borderRadius: BorderRadius.circular(AppRadius.photo),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      _isVideo
                          ? Icons.videocam_rounded
                          : Icons.photo_library_outlined,
                      size: 64,
                      color: colors.onPrimary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _isVideo
                          ? '${AppStrings.ber03VideoLabel} (${_durationSeconds}d)'
                          : AppStrings.ber03PhotoLabel,
                      style: typo.h3.copyWith(color: colors.onPrimary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.ber03DurationNotice,
                      style: typo.caption.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Pilihan Foto atau Video
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: !_isVideo ? colors.primary : colors.text,
                      side: BorderSide(
                        color: !_isVideo ? colors.primary : colors.border,
                        width: !_isVideo ? 2 : 1,
                      ),
                      minimumSize: const Size.fromHeight(
                        AppSizes.minTouchTarget,
                      ),
                    ),
                    onPressed: _selectPhoto,
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text(AppStrings.ber03PhotoLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isVideo ? colors.primary : colors.text,
                      side: BorderSide(
                        color: _isVideo ? colors.primary : colors.border,
                        width: _isVideo ? 2 : 1,
                      ),
                      minimumSize: const Size.fromHeight(
                        AppSizes.minTouchTarget,
                      ),
                    ),
                    onPressed: _selectVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text(AppStrings.ber03VideoLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Bidang Keterangan
            AppTextField(
              controller: _captionController,
              label: AppStrings.ber03CaptionHint,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),

            // Catatan Privasi Story
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.lock_clock_outlined,
                    color: colors.primary,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Tayang selama 24 jam dan hanya dapat dilihat oleh pengikutmu. Tanpa tombol bagikan ulang untuk menjaga privasi (BER-R12).',
                      style: typo.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
