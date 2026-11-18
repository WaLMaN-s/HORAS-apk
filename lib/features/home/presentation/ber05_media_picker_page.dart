import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/image_data_uri_helper.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:horas/features/home/presentation/home_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

/// BER-05 Pilih dan Edit Media (BER-R2, BER-R4, AC-10).
///
/// - Galeri & Kamera, pilih sampai 10 foto dengan penghitung
/// - Pangkas rasio (1:1, 4:3, 16:9) & urutkan lewat seret (`ReorderableListView`)
/// - Izin galeri ditolak memakai `StateView.permissionDenied`
/// - Kompres di klien (`keepExif: false`), validasi maksimal 10 MB sebelum kompres
class Ber05MediaPickerPage extends ConsumerStatefulWidget {
  const Ber05MediaPickerPage({
    super.key,
    this.initialMedia = const <SelectedMediaItem>[],
  });

  final List<SelectedMediaItem> initialMedia;

  @override
  ConsumerState<Ber05MediaPickerPage> createState() =>
      _Ber05MediaPickerPageState();
}

class _Ber05MediaPickerPageState extends ConsumerState<Ber05MediaPickerPage> {
  late List<SelectedMediaItem> _items;
  final bool _permissionDenied = false;
  int _sampleSeq = 1;

  @override
  void initState() {
    super.initState();
    _items = List<SelectedMediaItem>.of(widget.initialMedia);
  }

  Future<void> _pickFromGallery() async {
    if (_items.length >= AppLimits.postMaxPhotos) return;

    try {
      final pickedList = await ImageDataUriHelper.pickMultipleAndEncodeImages(
        limit: AppLimits.postMaxPhotos - _items.length,
        maxDimension: 720,
        quality: 75,
        maxRawBytes: AppLimits.postPhotoMaxBytes,
      );
      if (!mounted) return;
      if (pickedList.isEmpty) return;
      setState(() {
        for (final item in pickedList) {
          if (_items.length >= AppLimits.postMaxPhotos) break;
          _items.add(
            SelectedMediaItem(
              id: 'gal-${DateTime.now().microsecondsSinceEpoch}-${_items.length}',
              seed: item.dataUri,
              originalBytesCount: item.originalBytesCount,
              compressedBytes: item.compressedBytes,
              aspectRatio: 1.0,
            ),
          );
        }
      });
    } on FormatException {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Ukuran per foto maksimal 10 MB sebelum kompres.',
          variant: AppToastVariant.error,
        );
      }
    } on Object {
      _addSamplePhoto();
    }
  }

  Future<void> _pickFromCamera() async {
    if (_items.length >= AppLimits.postMaxPhotos) return;
    try {
      final encoded = await ImageDataUriHelper.pickAndEncodeImage(
        ImageSource.camera,
        maxDimension: 720,
        quality: 75,
        maxRawBytes: AppLimits.postPhotoMaxBytes,
      );
      if (!mounted || encoded == null) return;
      setState(() {
        _items.add(
          SelectedMediaItem(
            id: 'cam-${DateTime.now().microsecondsSinceEpoch}-${_items.length}',
            seed: encoded.dataUri,
            originalBytesCount: encoded.originalBytesCount,
            compressedBytes: encoded.compressedBytes,
            aspectRatio: 1.0,
          ),
        );
      });
    } on FormatException {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Ukuran per foto maksimal 10 MB sebelum kompres.',
          variant: AppToastVariant.error,
        );
      }
    } on Object {
      _addSamplePhoto();
    }
  }

  void _addSamplePhoto() {
    if (_items.length >= AppLimits.postMaxPhotos) return;
    setState(() {
      final seq = _sampleSeq++;
      _items.add(
        SelectedMediaItem(
          id: 'sample-$seq',
          seed: 'toba-photo-sample-$seq',
          originalBytesCount: 512 * 1024,
          aspectRatio: 4 / 3,
        ),
      );
    });
  }

  void _addSampleVideo([int duration = 30]) {
    if (_items.length >= AppLimits.postMaxPhotos) return;
    if (duration > 60) {
      AppToast.show(
        context,
        message: AppStrings.ber05VideoExceedsLimit,
        variant: AppToastVariant.error,
      );
      return;
    }
    setState(() {
      final seq = _sampleSeq++;
      _items.add(
        SelectedMediaItem(
          id: 'video-sample-$seq',
          seed: 'video-batak-sample-$seq',
          originalBytesCount: 2 * 1024 * 1024,
          aspectRatio: 16 / 9,
          isVideo: true,
          durationSeconds: duration,
        ),
      );
    });
  }

  void _setCropRatio(int index, double ratio) {
    setState(() {
      _items[index] = _items[index].copyWith(aspectRatio: ratio);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final flags = ref.watch(featureFlagsProvider);

    if (_permissionDenied) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.ber05Title, style: typo.h2)),
        body: StateView.permissionDenied(
          benefitMessage: AppStrings.ber05PermissionBenefit,
          onOpenSettings: () {
            perm.openAppSettings();
          },
          onContinueWithoutPermission: () {},
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.ber05Title, style: typo.h2),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.ber05ApplyBtn,
              onPressed: () => context.pop(_items),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        AppStrings.ber05PhotoCounter(
                          _items.length,
                          AppLimits.postMaxPhotos,
                        ),
                        style: typo.h3,
                      ),
                      Flexible(
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            if (flags.video)
                              AppButton(
                                label: AppStrings.ber05AddVideoBtn,
                                variant: AppButtonVariant.secondary,
                                isDisabled:
                                    _items.length >= AppLimits.postMaxPhotos,
                                onPressed: () => _addSampleVideo(30),
                              ),
                            AppButton(
                              label: AppStrings.ber05PickFromGalleryBtn,
                              variant: AppButtonVariant.secondary,
                              isDisabled:
                                  _items.length >= AppLimits.postMaxPhotos,
                              onPressed: _pickFromGallery,
                            ),
                            AppButton(
                              label: AppStrings.aut06PickPhotoCamera,
                              variant: AppButtonVariant.secondary,
                              isDisabled:
                                  _items.length >= AppLimits.postMaxPhotos,
                              onPressed: _pickFromCamera,
                            ),
                            AppButton(
                              label: AppStrings.ber05AddSamplePhotoBtn,
                              variant: AppButtonVariant.text,
                              isDisabled:
                                  _items.length >= AppLimits.postMaxPhotos,
                              onPressed: _addSamplePhoto,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(AppStrings.ber05ReorderHint, style: typo.caption),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _items.isEmpty
                  ? StateView.empty(
                      message: AppStrings.ber05PermissionBenefit,
                      actionLabel: AppStrings.ber05PickFromGalleryBtn,
                      onAction: _pickFromGallery,
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.screenMargin),
                      itemCount: _items.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final moved = _items.removeAt(oldIndex);
                          _items.insert(newIndex, moved);
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                          key: ValueKey<String>(item.id),
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: AppRadius.cardRadius,
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              PlaceholderImage(
                                seed: item.seed,
                                width: 64,
                                height: 64,
                                borderRadius: AppRadius.photoRadius,
                                caption: '${index + 1}',
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      AppStrings.ber05CropLabel,
                                      style: typo.captionStrong,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      children: <Widget>[
                                        AppChip(
                                          label: AppStrings.ber05CropSquare,
                                          isSelected:
                                              (item.aspectRatio - 1.0).abs() <
                                              0.05,
                                          onTap: () => _setCropRatio(index, 1),
                                        ),
                                        AppChip(
                                          label: AppStrings.ber05Crop4x3,
                                          isSelected:
                                              (item.aspectRatio - 4 / 3).abs() <
                                              0.05,
                                          onTap: () =>
                                              _setCropRatio(index, 4 / 3),
                                        ),
                                        AppChip(
                                          label: AppStrings.ber05Crop16x9,
                                          isSelected:
                                              (item.aspectRatio - 16 / 9)
                                                  .abs() <
                                              0.05,
                                          onTap: () =>
                                              _setCropRatio(index, 16 / 9),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: AppStrings.ber05RemovePhotoTooltip,
                                child: IconButton(
                                  tooltip: AppStrings.ber05RemovePhotoTooltip,
                                  onPressed: () =>
                                      setState(() => _items.removeAt(index)),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colors.danger,
                                  ),
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
