import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Gambar placeholder deterministik berbasis `seed` dengan gradien bertema
/// Danau Toba dan tenun ulos Batak, atau merender foto nyata bila `seed` berupa
/// URL (`http`/`https`) maupun Data URI (`data:image/...;base64,...`).
class PlaceholderImage extends StatelessWidget {
  const PlaceholderImage({
    required this.seed,
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppRadius.photoRadius,
    this.caption,
    this.semanticsLabel,
    this.showMountainSilhouette = true,
  });

  final String seed;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final String? caption;
  final String? semanticsLabel;
  final bool showMountainSilhouette;

  static const List<(Color, Color, Color)> _tobaUlosPalettes =
      <(Color, Color, Color)>[
        // Senja Danau Toba & merah ragi hotang
        (Color(0xFF8A1C27), Color(0xFFC85A32), Color(0xFFF2B880)),
        // Biru Tao Toba & perbukitan Samosir
        (Color(0xFF1B4965), Color(0xFF2E6F95), Color(0xFF89C2D9)),
        // Ulos Sibolang & emas
        (Color(0xFF283845), Color(0xFF6B1420), Color(0xFFE8A317)),
        // Hijau Pusuk Buhit & kabut pagi
        (Color(0xFF1F4E3D), Color(0xFF2E7D4F), Color(0xFFA3D9B8)),
        // Maroon Sadum & tenun perak
        (Color(0xFF5A121A), Color(0xFF8A1C27), Color(0xFFD99B82)),
        // Lembayung Tele & senja keemasan
        (Color(0xFF3D2645), Color(0xFF832161), Color(0xFFDA4167)),
      ];

  /// Mengembalikan `true` apabila [seed] merupakan foto nyata (URL atau Data URI base64).
  static bool isRealImageSeed(String? seed) {
    if (seed == null || seed.isEmpty) return false;
    return seed.startsWith('data:image/') ||
        seed.startsWith('http://') ||
        seed.startsWith('https://');
  }

  /// Mendekode Data URI `data:image/...;base64,...` menjadi [Uint8List].
  static Uint8List? tryDecodeDataUri(String seed) {
    if (!seed.startsWith('data:image/')) return null;
    final commaIdx = seed.indexOf(',');
    if (commaIdx == -1 || commaIdx + 1 >= seed.length) return null;
    try {
      return base64Decode(seed.substring(commaIdx + 1));
    } on Object {
      return null;
    }
  }

  static (Color, Color, Color) paletteForSeed(String seed) {
    final sample = seed.length > 64 ? seed.substring(0, 64) : seed;
    final hash = sample.codeUnits.fold<int>(
      0,
      (prev, elem) => (prev * 31 + elem) & 0x7FFFFFFF,
    );
    return _tobaUlosPalettes[hash % _tobaUlosPalettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final colors = context.colors;
    final sample = seed.length > 64 ? seed.substring(0, 64) : seed;
    final palette = paletteForSeed(sample);
    final seedHash = sample.codeUnits.fold<int>(
      17,
      (prev, elem) => (prev * 37 + elem) & 0x7FFFFFFF,
    );

    final isNetworkUrl =
        seed.startsWith('http://') || seed.startsWith('https://');
    final dataUriBytes = tryDecodeDataUri(seed);

    final gradientFallback = RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        willChange: false,
        painter: _TobaUlosPainter(
          topColor: palette.$1,
          midColor: palette.$2,
          accentColor: palette.$3,
          seedHash: seedHash,
          showMountains: showMountainSilhouette,
        ),
        child: caption != null
            ? Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typo.captionStrong.copyWith(color: colors.onPrimary),
                  ),
                ),
              )
            : null,
      ),
    );

    Widget rawVisual;
    if (dataUriBytes != null) {
      rawVisual = Image.memory(
        dataUriBytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => gradientFallback,
      );
    } else if (isNetworkUrl) {
      rawVisual = CachedNetworkImage(
        imageUrl: seed,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => gradientFallback,
        errorWidget: (context, url, error) => gradientFallback,
      );
    } else {
      rawVisual = gradientFallback;
    }

    Widget imageContent = SizedBox(
      width: width,
      height: height,
      child: rawVisual,
    );

    if (borderRadius != BorderRadius.zero) {
      imageContent = ClipRRect(borderRadius: borderRadius, child: imageContent);
    }

    return Semantics(
      image: true,
      label: semanticsLabel ?? caption ?? sample,
      child: imageContent,
    );
  }
}

class _TobaUlosPainter extends CustomPainter {
  const _TobaUlosPainter({
    required this.topColor,
    required this.midColor,
    required this.accentColor,
    required this.seedHash,
    required this.showMountains,
  });

  final Color topColor;
  final Color midColor;
  final Color accentColor;
  final int seedHash;
  final bool showMountains;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[topColor, midColor, accentColor],
        stops: const <double>[0.0, 0.62, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, gradientPaint);

    // Garis tenun ulos horizontal halus
    final ulosPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const stripeCount = 5;
    for (var i = 1; i <= stripeCount; i++) {
      final y = size.height * (i / (stripeCount + 1));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ulosPaint);
    }

    if (!showMountains || size.height < 36) {
      return;
    }

    // Siluet perbukitan Danau Toba berbasis seed
    final peakShift = ((seedHash % 40) - 20) / 100.0;
    final mountainPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * (0.28 + peakShift * 0.3),
        size.height * 0.48,
        size.width * 0.55,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * (0.78 - peakShift * 0.2),
        size.height * 0.52,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..close();

    final mountainPaint = Paint()
      ..color = topColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    canvas.drawPath(mountainPath, mountainPaint);
  }

  @override
  bool shouldRepaint(covariant _TobaUlosPainter oldDelegate) {
    return oldDelegate.seedHash != seedHash ||
        oldDelegate.topColor != topColor ||
        oldDelegate.showMountains != showMountains;
  }
}
