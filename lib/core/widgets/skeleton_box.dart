import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Kerangka pemuatan beranimasi shimmer meluncur sesuai PRD 5.2 (bukan putaran layar penuh).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = AppSpacing.lg,
    this.borderRadius = AppRadius.photoRadius,
    this.isCircle = false,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final bool isCircle;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseColor = colors.chipInactive;
    final highlightColor = Color.lerp(
      colors.chipInactive,
      colors.border,
      0.72,
    )!;

    return Semantics(
      label: AppStrings.semanticsLoading,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final slide = _controller.value * 2.6 - 1.3;
          return Container(
            width: widget.isCircle ? widget.height : widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.isCircle ? null : widget.borderRadius,
              gradient: LinearGradient(
                begin: Alignment(slide - 0.85, -0.15),
                end: Alignment(slide + 0.85, 0.15),
                colors: <Color>[baseColor, highlightColor, baseColor],
                stops: const <double>[0.1, 0.5, 0.9],
              ),
            ),
          );
        },
      ),
    );
  }
}
