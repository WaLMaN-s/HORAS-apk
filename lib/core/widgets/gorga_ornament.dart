import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Penempatan ornamen geometris Gorga Batak (Tahap 5).
enum GorgaPlacement { cornerTopRight, cornerTopLeft, headerBand }

/// Ornamen geometris halus Gorga Batak (merah-putih-hitam/monokrom tema) untuk sudut atau header.
class GorgaOrnament extends StatelessWidget {
  const GorgaOrnament({
    super.key,
    this.placement = GorgaPlacement.headerBand,
    this.width = 160,
    this.height = 24,
    this.color,
    this.opacity = 0.22,
  });

  final GorgaPlacement placement;
  final double width;
  final double height;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strokeColor = (color ?? colors.primary).withValues(alpha: opacity);

    return Semantics(
      label: AppStrings.semanticsGorga,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _GorgaGeometricPainter(
            placement: placement,
            strokeColor: strokeColor,
          ),
        ),
      ),
    );
  }
}

class _GorgaGeometricPainter extends CustomPainter {
  const _GorgaGeometricPainter({
    required this.placement,
    required this.strokeColor,
  });

  final GorgaPlacement placement;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    switch (placement) {
      case GorgaPlacement.headerBand:
        _paintBand(canvas, size, paint);
      case GorgaPlacement.cornerTopRight:
        _paintCorner(canvas, size, paint, mirrorHorizontal: true);
      case GorgaPlacement.cornerTopLeft:
        _paintCorner(canvas, size, paint, mirrorHorizontal: false);
    }
  }

  void _paintBand(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset(0, 1), Offset(w, 1), paint);
    canvas.drawLine(Offset(0, h - 1), Offset(w, h - 1), paint);

    final step = h.clamp(12.0, 28.0);
    final count = (w / step).floor();
    for (var i = 0; i < count; i++) {
      final x = i * step;
      final cx = x + step / 2;
      final cy = h / 2;
      final r = (step * 0.34).clamp(3.0, h * 0.4);

      final diamond = Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r, cy)
        ..close();
      canvas.drawPath(diamond, paint);
    }
  }

  void _paintCorner(
    Canvas canvas,
    Size size,
    Paint paint, {
    required bool mirrorHorizontal,
  }) {
    canvas.save();
    if (mirrorHorizontal) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final w = size.width;
    final h = size.height;
    final outer = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(outer, paint);

    final inner = Path()
      ..moveTo(w * 0.12, h * 0.12)
      ..lineTo(w * 0.68, h * 0.12)
      ..lineTo(w * 0.12, h * 0.68)
      ..close();
    canvas.drawPath(inner, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GorgaGeometricPainter oldDelegate) {
    return oldDelegate.placement != placement ||
        oldDelegate.strokeColor != strokeColor;
  }
}
