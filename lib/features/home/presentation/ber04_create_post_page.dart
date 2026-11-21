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

/// BER-04 Buat Postingan (BER-R2, BER-R3, BER-R4, BER-R10, BER-R11, Alur A6).
///
/// - Teks maksimal 2.000 karakter dengan penghitung
/// - 0 sampai 10 foto (lewat `BER-05`)
/// - Minimal ada teks atau satu foto
/// - Visibilitas: Publik / Pengikut saja / Komunitas tertentu (bawaan mengikuti tipe akun)
/// - Tag lokasi opsional hanya level kota
/// - Tanpa tag orang, tanpa hashtag (Fase 2 flag off)
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

  Future<void> _onSubmit() async {
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
    final textLength = _textController.text.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.ber04Title, style: typo.h2),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.ber04SubmitBtn,
              isLoading: _isSubmitting,
              onPressed: _onSubmit,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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

              AppTextField(
                hintText: AppStrings.ber04TextHint,
                controller: _textController,
                maxLines: 6,
                maxLength: AppLimits.postTextMaxChars,
                errorText: _errorText,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$textLength/${AppLimits.postTextMaxChars}',
                  style: typo.micro,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Foto terpilih (0-10)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        AppButton(
                          label: AppStrings.aut06PickPhotoGallery,
                          variant: AppButtonVariant.secondary,
                          leadingIcon: Icons.add_photo_alternate_outlined,
                          onPressed: _pickDirectFromGallery,
                        ),
                        AppButton(
                          label: AppStrings.aut06PickPhotoCamera,
                          variant: AppButtonVariant.secondary,
                          leadingIcon: Icons.camera_alt_outlined,
                          onPressed: _pickDirectFromCamera,
                        ),
                        AppButton(
                          label: AppStrings.ber04AddMediaBtn,
                          variant: AppButtonVariant.text,
                          leadingIcon: Icons.photo_library_outlined,
                          onPressed: _openMediaPicker,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    AppStrings.ber05PhotoCounter(
                      _selectedMedia.length,
                      AppLimits.postMaxPhotos,
                    ),
                    style: typo.captionStrong,
                  ),
                ],
              ),
              if (_selectedMedia.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 92,
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
                                ? () => _cropSelectedMedia(index)
                                : null,
                            child: PlaceholderImage(
                              seed: item.seed,
                              width: 92,
                              height: 92,
                              borderRadius: AppRadius.photoRadius,
                            ),
                          ),
                          if (canCrop)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: InkWell(
                                onTap: () => _cropSelectedMedia(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
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
                            top: 2,
                            right: 2,
                            child: Semantics(
                              button: true,
                              label: AppStrings.ber05RemovePhotoTooltip,
                              child: InkWell(
                                onTap: () => setState(
                                  () => _selectedMedia.removeAt(index),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: colors.text,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: AppSizes.iconXs,
                                    color: colors.surface,
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
              const SizedBox(height: AppSpacing.lg),

              // Visibilitas postingan (BER-R3)
              Text(AppStrings.ber04VisibilityLabel, style: typo.captionStrong),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppChip(
                    label: AppStrings.ber04VisibilityPublic,
                    isSelected: _visibility == PostVisibility.publicPost,
                    onTap: () =>
                        setState(() => _visibility = PostVisibility.publicPost),
                  ),
                  AppChip(
                    label: AppStrings.ber04VisibilityFollowers,
                    isSelected: _visibility == PostVisibility.followersOnly,
                    onTap: () => setState(
                      () => _visibility = PostVisibility.followersOnly,
                    ),
                  ),
                  AppChip(
                    label: AppStrings.ber04VisibilityCommunities,
                    isSelected:
                        _visibility == PostVisibility.specificCommunities,
                    onTap: () => setState(
                      () => _visibility = PostVisibility.specificCommunities,
                    ),
                  ),
                ],
              ),

              if (_visibility ==
                  PostVisibility.specificCommunities) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.ber04SelectCommunitiesLabel,
                  style: typo.captionStrong,
                ),
                const SizedBox(height: AppSpacing.xs),
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
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Tag lokasi opsional hanya level kota (BER-R4)
              Text(AppStrings.ber04CityTagLabel, style: typo.captionStrong),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppChip(
                    label: AppStrings.ber04NoCityTag,
                    isSelected: _selectedCityTag == null,
                    onTap: () => setState(() => _selectedCityTag = null),
                  ),
                  for (final c in _cities.take(6))
                    AppChip(
                      label: c.name,
                      isSelected: _selectedCityTag == c.name,
                      onTap: () => setState(() => _selectedCityTag = c.name),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              AppButton(
                label: AppStrings.ber04SubmitBtn,
                isExpanded: true,
                isLoading: _isSubmitting,
                onPressed: _onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
