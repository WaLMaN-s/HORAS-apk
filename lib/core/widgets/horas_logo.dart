import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Logo resmi HORAS: siluet atap Rumah Bolon (`CustomPainter`) + wordmark serif
/// `PlayfairDisplay` + tagline opsional (Tahap 4 & 5).
class HorasLogo extends StatelessWidget {
  const HorasLogo({
    super.key,
    this.showRoof = true,
    this.showTagline = false,
    this.wordmarkFontSize = 32,
    this.color,
  });

  final bool showRoof;
  final bool showTagline;
  final double wordmarkFontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final effectiveColor = color ?? colors.primary;

    return Semantics(
      label: AppStrings.semanticsLogo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showRoof) ...<Widget>[
            SizedBox(
              width: wordmarkFontSize * 2.2,
              height: wordmarkFontSize * 1.15,
              child: CustomPaint(
                painter: _RumahBolonPainter(
                  primaryColor: effectiveColor,
                  accentColor: colors.text,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          Text(
            AppStrings.appWordmark,
            style: typo.wordmark.copyWith(
              fontSize: wordmarkFontSize,
              color: effectiveColor,
            ),
          ),
          if (showTagline) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.appTagline,
              textAlign: TextAlign.center,
              style: typo.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _RumahBolonPainter extends CustomPainter {
  const _RumahBolonPainter({
    required this.primaryColor,
    required this.accentColor,
  });

  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Siluet atap pelana melengkung khas Rumah Bolon Batak
    final roofPath = Path()
      ..moveTo(w * 0.08, h * 0.62)
      ..quadraticBezierTo(w * 0.36, h * 0.46, w * 0.50, h * 0.08)
      ..quadraticBezierTo(w * 0.64, h * 0.46, w * 0.92, h * 0.62)
      ..lineTo(w * 0.78, h * 0.76)
      ..quadraticBezierTo(w * 0.50, h * 0.64, w * 0.22, h * 0.76)
      ..close();

    final roofPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(roofPath, roofPaint);

    // Garis gorga segitiga bagian dalam atap
    final innerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final innerTriangle = Path()
      ..moveTo(w * 0.30, h * 0.70)
      ..lineTo(w * 0.50, h * 0.32)
      ..lineTo(w * 0.70, h * 0.70)
      ..close();
    canvas.drawPath(innerTriangle, innerPaint);

    // Balok dasar rumah panggung
    final basePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.18, h * 0.88),
      Offset(w * 0.82, h * 0.88),
      basePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RumahBolonPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
