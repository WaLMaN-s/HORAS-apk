import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/image_data_uri_helper.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:horas/features/home/presentation/home_feed_controller.dart';
import 'package:horas/features/home/presentation/home_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

/// BER-04 Buat Postingan bergaya Threads (`BER-R2`, `BER-R3`, `BER-R4`, `BER-R10`, `BER-R11`, Alur A6).
///
/// - Teks maksimal 2.000 karakter dengan penghitung
/// - 0 sampai 10 foto (lewat galeri/kamera langsung atau `BER-05`)
/// - Minimal ada teks atau satu foto
/// - Visibilitas: Publik / Pengikut saja / Komunitas tertentu (bawaan mengikuti tipe akun)
/// - Tag lokasi opsional hanya level kota
/// - Draf tersimpan otomatis apabila unggah gagal
class Ber04CreatePostPage extends ConsumerStatefulWidget {
  const Ber04CreatePostPage({super.key});

  @override
  ConsumerState<Ber04CreatePostPage> createState() =>
      _Ber04CreatePostPageState();
}

class _Ber04CreatePostPageState extends ConsumerState<Ber04CreatePostPage> {
  final TextEditingController _textController = TextEditingController();
  PostVisibility _visibility = PostVisibility.publicPost;
  List<SelectedMediaItem> _selectedMedia = <SelectedMediaItem>[];
  final Set<String> _selectedCommunityIds = <String>{};
  String? _selectedCityTag;

  List<Community> _myCommunities = const <Community>[];
  List<WilayahCity> _cities = const <WilayahCity>[];
  bool _isSubmitting = false;
  bool _restoredDraftBanner = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _initDefaultsAndDraft();
  }

  Future<void> _initDefaultsAndDraft() async {
    final postRepo = ref.read(postRepositoryProvider);
    final profile = ref.read(authRepositoryProvider).currentSessionProfile;

    // BER-R3: Bawaan visibilitas mengikuti tipe akun
    var defaultVis = PostVisibility.publicPost;
    if (profile != null &&
        profile.privacySettings.accountType ==
            AccountVisibilityType.privateAccount) {
      defaultVis = PostVisibility.followersOnly;
    }

    final draft = postRepo.getSavedPostDraft();
    if (draft != null && !draft.isEmpty) {
      _textController.text = draft.text;
      defaultVis = draft.visibility;
      _selectedCommunityIds.addAll(draft.communityIds);
      _selectedCityTag = draft.cityTag;
      _selectedMedia = List<SelectedMediaItem>.generate(
        draft.mediaSeeds.length,
        (i) => SelectedMediaItem(
          id: 'restored-$i',
          seed: draft.mediaSeeds[i],
          originalBytesCount: i < draft.mediaSizesBytes.length
              ? draft.mediaSizesBytes[i]
              : 1024,
          aspectRatio: i < draft.mediaAspectRatios.length
              ? draft.mediaAspectRatios[i]
              : 1.0,
        ),
      );
      _restoredDraftBanner = true;
    }

    setState(() => _visibility = defaultVis);

    final commRes = await ref
        .read(communityRepositoryProvider)
        .getCommunities();
    final cityRes = await ref
        .read(nearbyRepositoryProvider)
        .getAvailableCities();
    if (!mounted) return;
    setState(() {
      if (commRes is Ok<List<Community>>) {
        _myCommunities = commRes.value;
      }
      if (cityRes is Ok<List<WilayahCity>>) {
        _cities = cityRes.value;
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _visibilityLabel(PostVisibility vis) {
    return switch (vis) {
      PostVisibility.publicPost => AppStrings.ber04VisibilityPublic,
      PostVisibility.followersOnly => AppStrings.ber04VisibilityFollowers,
      PostVisibility.specificCommunities =>
        AppStrings.ber04VisibilityCommunities,
    };
  }

  IconData _visibilityIcon(PostVisibility vis) {
    return switch (vis) {
      PostVisibility.publicPost => Icons.public_rounded,
      PostVisibility.followersOnly => Icons.people_outline_rounded,
      PostVisibility.specificCommunities => Icons.groups_outlined,
    };
  }

  Future<void> _openMediaPicker() async {
    final picked = await context.push<List<SelectedMediaItem>>(
      AppPages.ber05.routePath,
      extra: _selectedMedia,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedMedia = picked;
        _errorText = null;
      });
    }
  }

  Future<void> _pickDirectFromGallery() async {
    if (_selectedMedia.length >= AppLimits.postMaxPhotos) return;
    final remaining = AppLimits.postMaxPhotos - _selectedMedia.length;
    try {
      if (remaining == 1) {
        await _pickAndCropSingle(ImageSource.gallery, idPrefix: 'gal');
        return;
      }
      final pickedList = await ImageDataUriHelper.pickMultipleAndEncodeImages(
        limit: remaining,
        maxDimension: 960,
        quality: 78,
        maxRawBytes: AppLimits.postPhotoMaxBytes,
      );
      if (!mounted || pickedList.isEmpty) return;
      if (pickedList.length == 1) {
        final item = pickedList.first;
        final cropped = await PhotoCropPage.show(
          context,
          imageBytes: item.compressedBytes,
          fileName: item.name,
          initialAspectRatio: 1.0,
          outputMaxDimension: 800,
          quality: 78,
          maxRawBytes: AppLimits.postPhotoMaxBytes,
        );
        if (!mounted) return;
        final chosen = cropped ?? item;
        setState(() {
          _selectedMedia.add(
            SelectedMediaItem(
              id: 'gal-${DateTime.now().microsecondsSinceEpoch}-${_selectedMedia.length}',
              seed: chosen.dataUri,
              originalBytesCount: chosen.originalBytesCount,
              compressedBytes: chosen.compressedBytes,
              aspectRatio: chosen.aspectRatio,
            ),
          );
          _errorText = null;
        });
        return;
      }
      setState(() {
        for (final item in pickedList) {
          if (_selectedMedia.length >= AppLimits.postMaxPhotos) break;
          _selectedMedia.add(
            SelectedMediaItem(
              id: 'gal-${DateTime.now().microsecondsSinceEpoch}-${_selectedMedia.length}',
              seed: item.dataUri,
              originalBytesCount: item.originalBytesCount,
              compressedBytes: item.compressedBytes,
              aspectRatio: 1.0,
            ),
          );
        }
        _errorText = null;
      });
    } on FormatException {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Ukuran per foto maksimal 10 MB.',
          variant: AppToastVariant.error,
        );
      }
    } on Object {
      await _openMediaPicker();
    }
  }

  Future<void> _pickDirectFromCamera() async {
    if (_selectedMedia.length >= AppLimits.postMaxPhotos) return;
    try {
      await _pickAndCropSingle(ImageSource.camera, idPrefix: 'cam');
    } on FormatException {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Ukuran per foto maksimal 10 MB.',
          variant: AppToastVariant.error,
        );
      }
    } on Object {
      await _openMediaPicker();
    }
  }

  Future<void> _pickAndCropSingle(
    ImageSource source, {
    required String idPrefix,
  }) async {
    final raw = await ImageDataUriHelper.pickRawImage(
      source,
      maxDimension: 1440,
      quality: 88,
    );
    if (!mounted || raw == null) return;
    final cropped = await PhotoCropPage.show(
      context,
      imageBytes: raw.bytes,
      fileName: raw.name,
      initialAspectRatio: 1.0,
      outputMaxDimension: 800,
      quality: 78,
      maxRawBytes: AppLimits.postPhotoMaxBytes,
    );
    if (!mounted || cropped == null) return;
    setState(() {
      _selectedMedia.add(
        SelectedMediaItem(
          id: '$idPrefix-${DateTime.now().microsecondsSinceEpoch}-${_selectedMedia.length}',
          seed: cropped.dataUri,
          originalBytesCount: cropped.originalBytesCount,
          compressedBytes: cropped.compressedBytes,
          aspectRatio: cropped.aspectRatio,
        ),
      );
      _errorText = null;
    });
  }

  Future<void> _cropSelectedMedia(int index) async {
    final item = _selectedMedia[index];
    final bytes =
        item.compressedBytes ?? ImageDataUriHelper.decodeDataUri(item.seed);
    if (bytes == null) return;
    final cropped = await PhotoCropPage.show(
      context,
      imageBytes: bytes,
      initialAspectRatio: item.aspectRatio,
      outputMaxDimension: 800,
      quality: 78,
      maxRawBytes: AppLimits.postPhotoMaxBytes,
    );
    if (!mounted || cropped == null) return;
    setState(() {
      _selectedMedia[index] = item.copyWith(
        seed: cropped.dataUri,
        originalBytesCount: cropped.originalBytesCount,
        compressedBytes: cropped.compressedBytes,
        aspectRatio: cropped.aspectRatio,
      );
    });
  }

  Future<void> _openVisibilitySheet() async {
    await AppBottomSheet.show<void>(
      context,
      title: AppStrings.ber04VisibilityLabel,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final colors = sheetCtx.colors;
          final typo = sheetCtx.typo;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final option in PostVisibility.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _visibilityIcon(option),
                    color: _visibility == option
                        ? colors.accent
                        : colors.textMuted,
                  ),
                  title: Text(_visibilityLabel(option), style: typo.bodyStrong),
                  trailing: _visibility == option
                      ? Icon(Icons.check_circle_rounded, color: colors.accent)
                      : null,
                  onTap: () {
                    setState(() => _visibility = option);
                    setSheetState(() {});
                    if (option != PostVisibility.specificCommunities) {
                      Navigator.of(sheetCtx).pop();
                    }
                  },
                ),
              if (_visibility == PostVisibility.specificCommunities &&
                  _myCommunities.isNotEmpty) ...<Widget>[
                const Divider(),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.ber04SelectCommunitiesLabel,
                  style: typo.captionStrong,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final comm in _myCommunities.take(6))
                      AppChip(
                        label: comm.name,
                        isSelected: _selectedCommunityIds.contains(comm.id),
                        onTap: () {
                          setState(() {
                            if (_selectedCommunityIds.contains(comm.id)) {
                              _selectedCommunityIds.remove(comm.id);
                            } else {
                              _selectedCommunityIds.add(comm.id);
                            }
                          });
                          setSheetState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: AppStrings.actionSave,
                  isExpanded: true,
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCityTagSheet() async {
    await AppBottomSheet.show<void>(
      context,
      title: AppStrings.ber04CityTagLabel,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          AppChip(
            label: AppStrings.ber04NoCityTag,
            isSelected: _selectedCityTag == null,
            onTap: () {
              setState(() => _selectedCityTag = null);
              Navigator.of(context).pop();
            },
          ),
          for (final c in _cities.take(10))
            AppChip(
              label: c.name,
              isSelected: _selectedCityTag == c.name,
              onTap: () {
                setState(() => _selectedCityTag = c.name);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    HapticFeedback.mediumImpact().ignore();
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final postRepo = ref.read(postRepositoryProvider);
    final res = await postRepo.createPost(
      text: _textController.text,
      visibility: _visibility,
      mediaSeeds: _selectedMedia.map((m) => m.seed).toList(growable: false),
      mediaSizesBytes: _selectedMedia
          .map((m) => m.originalBytesCount)
          .toList(growable: false),
      mediaAspectRatios: _selectedMedia
          .map((m) => m.aspectRatio)
          .toList(growable: false),
      rawExifPerMedia: _selectedMedia
          .map((m) => m.rawExifMetadata)
          .toList(growable: false),
      communityIds: _visibility == PostVisibility.specificCommunities
          ? _selectedCommunityIds.toList(growable: false)
          : const <String>[],
      cityTag: _selectedCityTag,
    );

    if (!mounted) return;

    await res.fold(
      onOk: (createdPost) async {
        ref
            .read(homeFeedControllerProvider.notifier)
            .prependCreatedPost(createdPost);
        setState(() => _isSubmitting = false);
        AppToast.show(
          context,
          message:
              createdPost.moderationStatus == PostModerationStatus.underReview
              ? AppStrings.ber04UnderReviewToast
              : AppStrings.ber04PublishedToast,
          variant:
              createdPost.moderationStatus == PostModerationStatus.underReview
              ? AppToastVariant.warning
              : AppToastVariant.success,
        );
        context.pop();
      },
      onErr: (err) async {
        // Alur A6: Bila unggah gagal (offline/server error), simpan draf agar bisa dicoba lagi
        if (err is OfflineError || err is ServerError) {
          await postRepo.savePostDraft(
            PostDraft(
              text: _textController.text,
              mediaSeeds: _selectedMedia.map((m) => m.seed).toList(),
              mediaSizesBytes: _selectedMedia
                  .map((m) => m.originalBytesCount)
                  .toList(),
              mediaAspectRatios: _selectedMedia
                  .map((m) => m.aspectRatio)
                  .toList(),
              visibility: _visibility,
              communityIds: _selectedCommunityIds.toList(),
              cityTag: _selectedCityTag,
            ),
          );
          if (mounted) {
            AppToast.show(
              context,
              message: AppStrings.ber04DraftSavedOnFailToast,
              variant: AppToastVariant.warning,
            );
          }
        }
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _errorText = err.message;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final profile = ref.watch(authRepositoryProvider).currentSessionProfile;
    final textLength = _textController.text.length;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(AppStrings.ber04Title, style: typo.h2),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSizes.strokeThin),
          child: Divider(
            height: AppSizes.strokeThin,
            color: colors.border.withValues(alpha: 0.55),
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.ber04SubmitBtn,
              compact: true,
              isLoading: _isSubmitting,
              onPressed: _onSubmit,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenMargin,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_restoredDraftBanner) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.confidenceAmberSurface,
                          borderRadius: AppRadius.buttonRadius,
                          border: Border.all(color: colors.confidenceAmber),
                        ),
                        child: Text(
                          AppStrings.ber04DraftRestoredNotice,
                          style: typo.captionStrong.copyWith(
                            color: colors.confidenceAmber,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Layout Composer bergaya Threads (Avatar + garis tipis + area ketik lega)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Column(
                            children: <Widget>[
                              AppAvatar(
                                name:
                                    profile?.displayName ?? AppStrings.appName,
                                seed: profile?.avatarSeed ?? 'horas-me',
                                size: AppSizes.avatarMd,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  decoration: BoxDecoration(
                                    color: colors.border.withValues(alpha: 0.6),
                                    borderRadius: AppRadius.pillRadius,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        profile?.displayName ??
                                            AppStrings.appName,
                                        style: typo.bodyStrong,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '$textLength/${AppLimits.postTextMaxChars}',
                                      style: typo.micro,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                AppTextField(
                                  hintText: AppStrings.ber04TextHint,
                                  controller: _textController,
                                  maxLines: 8,
                                  maxLength: AppLimits.postTextMaxChars,
                                  errorText: _errorText,
                                  borderless: true,
                                  onChanged: (_) => setState(() {}),
                                ),
                                if (_selectedMedia.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: AppSpacing.sm),
                                  SizedBox(
                                    height: 116,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _selectedMedia.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: AppSpacing.sm),
                                      itemBuilder: (context, index) {
                                        final item = _selectedMedia[index];
                                        final canCrop =
                                            item.compressedBytes != null ||
                                            item.seed.startsWith('data:image/');
                                        return Stack(
                                          children: <Widget>[
                                            GestureDetector(
                                              onTap: canCrop
                                                  ? () => _cropSelectedMedia(
                                                      index,
                                                    )
                                                  : null,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      AppRadius.photoRadius,
                                                  border: Border.all(
                                                    color: colors.border
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                                child: PlaceholderImage(
                                                  seed: item.seed,
                                                  width: 116,
                                                  height: 116,
                                                  borderRadius:
                                                      AppRadius.photoRadius,
                                                ),
                                              ),
                                            ),
                                            if (canCrop)
                                              Positioned(
                                                bottom: 6,
                                                left: 6,
                                                child: InkWell(
                                                  onTap: () =>
                                                      _cropSelectedMedia(index),
                                                  borderRadius:
                                                      AppRadius.pillRadius,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.72,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.crop_rounded,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Semantics(
                                                button: true,
                                                label: AppStrings
                                                    .ber05RemovePhotoTooltip,
                                                child: InkWell(
                                                  onTap: () => setState(
                                                    () => _selectedMedia
                                                        .removeAt(index),
                                                  ),
                                                  borderRadius:
                                                      AppRadius.pillRadius,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.75,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.close_rounded,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                // Ringkasan pil Visibilitas & Tag Kota
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: <Widget>[
                                    AppChip(
                                      label: _visibilityLabel(_visibility),
                                      leadingIcon: _visibilityIcon(_visibility),
                                      onTap: _openVisibilitySheet,
                                    ),
                                    AppChip(
                                      label:
                                          _selectedCityTag ??
                                          AppStrings.ber04NoCityTag,
                                      leadingIcon: Icons.location_on_outlined,
                                      isSelected: _selectedCityTag != null,
                                      onTap: _openCityTagSheet,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Toolbar Composer Bawah ala Threads (menempel rapi di atas keyboard)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.border.withValues(alpha: 0.55),
                    width: AppSizes.strokeThin,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: AppStrings.aut06PickPhotoGallery,
                    onPressed: _pickDirectFromGallery,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: colors.text,
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.aut06PickPhotoCamera,
                    onPressed: _pickDirectFromCamera,
                    icon: Icon(Icons.camera_alt_outlined, color: colors.text),
                  ),
                  TextButton.icon(
                    onPressed: _openMediaPicker,
                    icon: Icon(
                      Icons.photo_library_outlined,
                      size: AppSizes.iconSm,
                      color: colors.accent,
                    ),
                    label: Text(
                      AppStrings.ber04AddMediaBtn,
                      style: typo.captionStrong.copyWith(color: colors.accent),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      borderRadius: AppRadius.pillRadius,
                    ),
                    child: Text(
                      AppStrings.ber05PhotoCounter(
                        _selectedMedia.length,
                        AppLimits.postMaxPhotos,
                      ),
                      style: typo.micro.copyWith(color: colors.text),
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
