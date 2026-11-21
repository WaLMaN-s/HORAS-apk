import 'dart:io';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/image_data_uri_helper.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/home/presentation/home_feed_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

/// BER-03 Buat Story bergaya Instagram Story Studio (`BER-R12`).
///
/// - Otomatis membuka kamera saat halaman dibuka di perangkat nyata (ala Instagram).
/// - Foto atau video maks 15 detik, tayang 24 jam, hanya untuk pengikut.
/// - Rasio 9:16 / 9:18 dipertahankan penuh tanpa distorsi (bebas EXIF/GPS).
/// - Tanpa tombol bagikan ulang (`BER-R12`).
class Ber03CreateStoryPage extends ConsumerStatefulWidget {
  const Ber03CreateStoryPage({super.key});

  @override
  ConsumerState<Ber03CreateStoryPage> createState() =>
      _Ber03CreateStoryPageState();
}

class _Ber03CreateStoryPageState extends ConsumerState<Ber03CreateStoryPage> {
  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  final _captionController = TextEditingController();
  bool _isVideo = false;
  int _durationSeconds = 5;
  String _mediaSeed = 'sample-story-photo';
  bool _hasCapturedOrPickedMedia = false;
  bool _isLaunchingCamera = false;
  bool _autoCameraTriggered = false;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoCameraTriggered || _isFlutterTest) return;
      if (!ref.read(featureFlagsProvider).stories) return;
      _autoCameraTriggered = true;
      _selectPhoto(ImageSource.camera, isAutoLaunch: true);
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _selectPhoto(
    ImageSource source, {
    bool isAutoLaunch = false,
  }) async {
    if (_isLaunchingCamera) return;
    if (source == ImageSource.camera) {
      setState(() => _isLaunchingCamera = true);
    }
    try {
      final raw = await ImageDataUriHelper.pickRawImage(
        source,
        maxDimension: 1440,
        quality: 90,
      );
      if (!mounted) return;
      if (source == ImageSource.camera) {
        setState(() => _isLaunchingCamera = false);
      }
      if (raw == null) {
        // Pengguna menekan kembali dari kamera/galeri: tetap di studio Story siap potret/pilih galeri.
        return;
      }
      final cropped = await PhotoCropPage.show(
        context,
        imageBytes: raw.bytes,
        fileName: raw.name,
        initialAspectRatio: 9 / 16,
        outputMaxDimension: 1080,
        quality: 80,
      );
      if (!mounted || cropped == null) return;
      setState(() {
        _isVideo = false;
        _durationSeconds = 5;
        _mediaSeed = cropped.dataUri;
        _hasCapturedOrPickedMedia = true;
      });
      return;
    } on Object {
      if (mounted && source == ImageSource.camera) {
        setState(() => _isLaunchingCamera = false);
      }
      // Pada peluncuran kamera otomatis di emulator tanpa kamera, tampilkan studio siap pakai.
      if (isAutoLaunch) return;
    }
    if (!mounted) return;
    setState(() {
      _isVideo = false;
      _durationSeconds = 5;
      _mediaSeed = 'story-photo-${DateTime.now().microsecondsSinceEpoch}';
      _hasCapturedOrPickedMedia = true;
    });
  }

  Future<void> _cropCurrentPhoto() async {
    final bytes = ImageDataUriHelper.decodeDataUri(_mediaSeed);
    if (bytes == null) return;
    final cropped = await PhotoCropPage.show(
      context,
      imageBytes: bytes,
      initialAspectRatio: 9 / 16,
      outputMaxDimension: 1080,
      quality: 80,
    );
    if (!mounted || cropped == null) return;
    setState(() {
      _isVideo = false;
      _mediaSeed = cropped.dataUri;
      _hasCapturedOrPickedMedia = true;
    });
  }

  void _selectVideo() {
    HapticFeedback.lightImpact().ignore();
    // BER-R12: Video maksimal 15 detik
    setState(() {
      _isVideo = true;
      _durationSeconds = 15;
      _mediaSeed = 'story-video-${DateTime.now().microsecondsSinceEpoch}';
      _hasCapturedOrPickedMedia = true;
    });
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact().ignore();
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

    ref.read(storiesRefreshTickProvider.notifier).bump();
    AppToast.show(
      context,
      message: 'Cerita berhasil dibagikan untuk pengikutmu (24 jam).',
      variant: AppToastVariant.success,
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;
    final hasRealPhoto =
        !_isVideo && PlaceholderImage.isRealImageSeed(_mediaSeed);

    if (!flags.stories) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.ber03Title)),
        body: StateView.contentUnavailable(
          onBack: () => context.go(AppPages.berandaPath),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Bilah Atas Story Studio (Tutup · Judul · Ambil Ulang / Potong · Bagikan)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Semantics(
                    button: true,
                    label: AppStrings.actionClose,
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: AppSizes.minTouchTarget,
                        minHeight: AppSizes.minTouchTarget,
                      ),
                      tooltip: AppStrings.actionClose,
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      AppStrings.ber03Title,
                      style: typo.h3.copyWith(color: Colors.white),
                    ),
                  ),
                  if (hasRealPhoto)
                    Semantics(
                      button: true,
                      label: AppStrings.ber03CropPhotoBtn,
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSizes.minTouchTarget,
                          minHeight: AppSizes.minTouchTarget,
                        ),
                        tooltip: AppStrings.ber03CropPhotoBtn,
                        onPressed: _cropCurrentPhoto,
                        icon: const Icon(
                          Icons.crop_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  AppButton(
                    label: AppStrings.ber03PublishBtn,
                    variant: AppButtonVariant.primary,
                    compact: true,
                    isLoading: _isPublishing,
                    onPressed: _isPublishing ? null : _publish,
                  ),
                ],
              ),
            ),

            // Kanvas Pratinjau Story 9:16 Layar Penuh
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.cardRadius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (hasRealPhoto)
                        ColoredBox(
                          color: Colors.black,
                          child: PlaceholderImage(
                            seed: _mediaSeed,
                            fit: BoxFit.contain,
                            borderRadius: BorderRadius.zero,
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[colors.primaryDark, Colors.black],
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  if (_isLaunchingCamera)
                                    const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  else
                                    Semantics(
                                      button: true,
                                      label: AppStrings.aut06PickPhotoCamera,
                                      child: InkWell(
                                        onTap: () =>
                                            _selectPhoto(ImageSource.camera),
                                        borderRadius: AppRadius.pillRadius,
                                        child: Container(
                                          width: 84,
                                          height: 84,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withValues(
                                              alpha: 0.14,
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                          ),
                                          child: Icon(
                                            _isVideo
                                                ? Icons.videocam_rounded
                                                : Icons.camera_alt_rounded,
                                            size: 38,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    _isVideo
                                        ? '${AppStrings.ber03VideoLabel} (${_durationSeconds}d)'
                                        : (_hasCapturedOrPickedMedia
                                              ? AppStrings.ber03PhotoLabel
                                              : AppStrings
                                                    .ber03CameraReadyHint),
                                    textAlign: TextAlign.center,
                                    style: typo.bodyStrong.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    AppStrings.ber03DurationNotice,
                                    textAlign: TextAlign.center,
                                    style: typo.caption.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Lencana pengingat privasi 24 jam (BER-R12)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.56),
                            borderRadius: AppRadius.pillRadius,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.lock_clock_outlined,
                                color: Colors.white,
                                size: AppSizes.iconXs,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                AppStrings.ber02FollowersOnlyNotice,
                                style: typo.micro.copyWith(color: Colors.white),
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

            // Kontrol Bawah ala Instagram Story: Kamera / Galeri / Potong / Video + Caption
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _StoryActionPill(
                          icon: Icons.camera_alt_rounded,
                          label: hasRealPhoto
                              ? AppStrings.ber03RetakeCameraBtn
                              : AppStrings.aut06PickPhotoCamera,
                          highlighted: !hasRealPhoto && !_isVideo,
                          onTap: () => _selectPhoto(ImageSource.camera),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StoryActionPill(
                          icon: Icons.photo_library_outlined,
                          label: AppStrings.aut06PickPhotoGallery,
                          highlighted: hasRealPhoto,
                          onTap: () => _selectPhoto(ImageSource.gallery),
                        ),
                        if (hasRealPhoto) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          _StoryActionPill(
                            icon: Icons.crop_rounded,
                            label: AppStrings.ber03CropPhotoBtn,
                            onTap: _cropCurrentPhoto,
                          ),
                        ],
                        const SizedBox(width: AppSpacing.sm),
                        _StoryActionPill(
                          icon: Icons.videocam_outlined,
                          label: AppStrings.ber03VideoLabel,
                          highlighted: _isVideo,
                          onTap: _selectVideo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _captionController,
                    maxLines: 2,
                    minLines: 1,
                    style: typo.body.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: AppStrings.ber03CaptionHint,
                      hintStyle: typo.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.12),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.pillRadius,
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pillRadius,
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pillRadius,
                        borderSide: BorderSide(color: colors.primary),
                      ),
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

class _StoryActionPill extends StatelessWidget {
  const _StoryActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: highlighted
                  ? colors.primary
                  : Colors.white.withValues(alpha: 0.14),
              borderRadius: AppRadius.pillRadius,
              border: Border.all(
                color: highlighted
                    ? colors.primary
                    : Colors.white.withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: AppSizes.iconSm, color: Colors.white),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: typo.captionStrong.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
