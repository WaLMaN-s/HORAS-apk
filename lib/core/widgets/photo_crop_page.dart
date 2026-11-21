import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/utils/image_data_uri_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

/// Opsi rasio pemotongan foto pada [PhotoCropPage].
typedef CropAspectPreset = ({String label, double ratio});

const List<CropAspectPreset> kDefaultCropPresets = <CropAspectPreset>[
  (label: '1:1', ratio: 1.0),
  (label: '4:5', ratio: 4 / 5),
  (label: '4:3', ratio: 4 / 3),
  (label: '16:9', ratio: 16 / 9),
  (label: '9:16', ratio: 9 / 16),
  (label: '9:18', ratio: 9 / 18),
];

/// Layar interaktif untuk menggeser, zoom, memutar, dan memotong foto
/// sebelum dikompres bebas EXIF (`AC-10`) menjadi Data URI.
class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({
    required this.imageBytes,
    this.fileName = 'cropped-photo.jpg',
    this.initialAspectRatio = 1.0,
    this.isCircularPreview = false,
    this.allowAspectSwitch = true,
    this.aspectPresets = kDefaultCropPresets,
    this.outputMaxDimension = 720,
    this.quality = 78,
    this.maxRawBytes,
    super.key,
  });

  final Uint8List imageBytes;
  final String fileName;
  final double initialAspectRatio;
  final bool isCircularPreview;
  final bool allowAspectSwitch;
  final List<CropAspectPreset> aspectPresets;
  final int outputMaxDimension;
  final int quality;
  final int? maxRawBytes;

  /// Membuka [PhotoCropPage] secara modal layar penuh dan mengembalikan hasil terpotong.
  static Future<EncodedImageResult?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String fileName = 'cropped-photo.jpg',
    double initialAspectRatio = 1.0,
    bool isCircularPreview = false,
    bool allowAspectSwitch = true,
    List<CropAspectPreset> aspectPresets = kDefaultCropPresets,
    int outputMaxDimension = 720,
    int quality = 78,
    int? maxRawBytes,
  }) {
    return Navigator.of(context, rootNavigator: true).push<EncodedImageResult>(
      MaterialPageRoute<EncodedImageResult>(
        fullscreenDialog: true,
        builder: (_) => PhotoCropPage(
          imageBytes: imageBytes,
          fileName: fileName,
          initialAspectRatio: initialAspectRatio,
          isCircularPreview: isCircularPreview,
          allowAspectSwitch: allowAspectSwitch,
          aspectPresets: aspectPresets,
          outputMaxDimension: outputMaxDimension,
          quality: quality,
          maxRawBytes: maxRawBytes,
        ),
      ),
    );
  }

  /// Helper terpadu: memilih foto dari [source] lalu langsung membuka layar crop [PhotoCropPage].
  static Future<EncodedImageResult?> pickAndCropImage(
    BuildContext context, {
    required ImageSource source,
    double initialAspectRatio = 1.0,
    bool isCircularPreview = false,
    bool allowAspectSwitch = true,
    int outputMaxDimension = 720,
    int quality = 78,
    int? maxRawBytes,
  }) async {
    final raw = await ImageDataUriHelper.pickRawImage(
      source,
      maxDimension: math.max(outputMaxDimension * 2, 1280),
      quality: 90,
    );
    if (raw == null || !context.mounted) return null;
    return show(
      context,
      imageBytes: raw.bytes,
      fileName: raw.name,
      initialAspectRatio: initialAspectRatio,
      isCircularPreview: isCircularPreview,
      allowAspectSwitch: allowAspectSwitch,
      outputMaxDimension: outputMaxDimension,
      quality: quality,
      maxRawBytes: maxRawBytes,
    );
  }

  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage> {
  final GlobalKey _cropBoundaryKey = GlobalKey();
  final TransformationController _transformCtrl = TransformationController();

  late double _aspectRatio;
  int _quarterTurns = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _aspectRatio = widget.initialAspectRatio;
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _resetTransform() {
    setState(() {
      _quarterTurns = 0;
      _transformCtrl.value = Matrix4.identity();
    });
  }

  void _rotateRight() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _transformCtrl.value = Matrix4.identity();
    });
  }

  Future<void> _confirmCrop() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final renderObj = _cropBoundaryKey.currentContext?.findRenderObject();
      if (renderObj is! RenderRepaintBoundary) {
        final fallback = await ImageDataUriHelper.encodeBytes(
          widget.imageBytes,
          name: widget.fileName,
          maxDimension: widget.outputMaxDimension,
          quality: widget.quality,
          maxRawBytes: widget.maxRawBytes,
          aspectRatio: _aspectRatio,
        );
        if (mounted) Navigator.of(context).pop(fallback);
        return;
      }

      final boxSize = renderObj.size;
      final longest = math.max(boxSize.width, boxSize.height);
      final pixelRatio = longest > 0
          ? (widget.outputMaxDimension / longest).clamp(1.0, 3.0)
          : 2.0;

      final image = await renderObj.toImage(pixelRatio: pixelRatio);
      final actualAspectRatio = image.height > 0
          ? image.width / image.height
          : _aspectRatio;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      final rawPng = byteData?.buffer.asUint8List() ?? widget.imageBytes;
      final encoded = await ImageDataUriHelper.encodeBytes(
        rawPng,
        name: widget.fileName,
        maxDimension: widget.outputMaxDimension,
        quality: widget.quality,
        maxRawBytes: widget.maxRawBytes,
        aspectRatio: actualAspectRatio,
      );
      if (mounted) {
        Navigator.of(context).pop(encoded);
      }
    } on Object {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: AppStrings.actionCancel,
          icon: const Icon(Icons.close_rounded),
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.cropPageTitle,
          style: typo.h3.copyWith(color: Colors.white),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _confirmCrop,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text(AppStrings.cropApplyBtn),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                AppStrings.cropHint,
                style: typo.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: KeyedSubtree(
                    key: ValueKey<double>(_aspectRatio),
                    child: AspectRatio(
                      aspectRatio: _aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          // Area gambar yang dipotong & direkam RepaintBoundary
                          RepaintBoundary(
                            key: _cropBoundaryKey,
                            child: ClipRect(
                              child: ColoredBox(
                                color: Colors.black,
                                child: InteractiveViewer(
                                  transformationController: _transformCtrl,
                                  minScale: 1.0,
                                  maxScale: 4.5,
                                  boundaryMargin: const EdgeInsets.all(240),
                                  child: Center(
                                    child: RotatedBox(
                                      quarterTurns: _quarterTurns,
                                      child: Image.memory(
                                        widget.imageBytes,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Garis kisi bantu 3x3 + bingkai pemotong (tidak ikut terekam)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CropGridPainter(
                                borderColor: colors.primary,
                                isCircular: widget.isCircularPreview,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Kontrol Rotasi, Reset, & Pilihan Rasio
            Container(
              color: Colors.black.withValues(alpha: 0.9),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.allowAspectSwitch) ...<Widget>[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      alignment: WrapAlignment.center,
                      children: widget.aspectPresets.map((preset) {
                        final selected =
                            (_aspectRatio - preset.ratio).abs() < 0.025;
                        return ChoiceChip(
                          label: Text(preset.label),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _aspectRatio = preset.ratio;
                              _transformCtrl.value = Matrix4.identity();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        onPressed: _rotateRight,
                        icon: const Icon(Icons.rotate_right_rounded),
                        label: const Text(AppStrings.cropRotateTooltip),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        onPressed: _resetTransform,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(AppStrings.cropResetTooltip),
                      ),
                    ],
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

class _CropGridPainter extends CustomPainter {
  const _CropGridPainter({required this.borderColor, required this.isCircular});

  final Color borderColor;
  final bool isCircular;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (isCircular) {
      final radius = math.min(size.width, size.height) / 2;
      canvas.drawCircle(size.center(Offset.zero), radius - 1, borderPaint);
    } else {
      canvas.drawRect(Offset.zero & size, borderPaint);
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (var i = 1; i <= 2; i++) {
      final dx = size.width * (i / 3);
      final dy = size.height * (i / 3);
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropGridPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.isCircular != isCircular;
}
