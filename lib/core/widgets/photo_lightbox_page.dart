import 'package:flutter/services.dart' show HapticFeedback;
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/placeholder_image.dart';
import 'package:material_ui/material_ui.dart';

/// Penampil foto layar penuh bergaya Instagram dengan pinch-to-zoom,
/// geser antar foto, dan geser ke bawah untuk menutup.
class PhotoLightboxPage extends StatefulWidget {
  const PhotoLightboxPage({
    required this.seeds,
    super.key,
    this.initialIndex = 0,
    this.title,
    this.isCircular = false,
  });

  final List<String> seeds;
  final int initialIndex;
  final String? title;
  final bool isCircular;

  static Future<void> show(
    BuildContext context, {
    required List<String> seeds,
    int initialIndex = 0,
    String? title,
    bool isCircular = false,
  }) {
    if (seeds.isEmpty) return Future<void>.value();
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: PhotoLightboxPage(
              seeds: seeds,
              initialIndex: initialIndex.clamp(0, seeds.length - 1),
              title: title,
              isCircular: isCircular,
            ),
          );
        },
      ),
    );
  }

  @override
  State<PhotoLightboxPage> createState() => _PhotoLightboxPageState();
}

class _PhotoLightboxPageState extends State<PhotoLightboxPage> {
  late final PageController _pageController;
  late int _currentIndex;
  double _verticalDragOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.seeds.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _verticalDragOffset = (_verticalDragOffset + details.delta.dy).clamp(
        -160.0,
        240.0,
      );
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_verticalDragOffset.abs() > 100 || velocity.abs() > 700) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
    } else {
      setState(() => _verticalDragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final dragRatio = (_verticalDragOffset.abs() / 240.0).clamp(0.0, 1.0);
    final bgOpacity = (0.96 - dragRatio * 0.45).clamp(0.45, 0.96);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Stack(
            children: <Widget>[
              Transform.translate(
                offset: Offset(0, _verticalDragOffset),
                child: Transform.scale(
                  scale: 1.0 - dragRatio * 0.12,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.seeds.length,
                    onPageChanged: (idx) => setState(() => _currentIndex = idx),
                    itemBuilder: (context, index) {
                      final seed = widget.seeds[index];
                      return Center(
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: widget.isCircular
                                ? ClipOval(
                                    child: PlaceholderImage(
                                      seed: seed,
                                      width: 280,
                                      height: 280,
                                      borderRadius: BorderRadius.zero,
                                      showMountainSilhouette: false,
                                    ),
                                  )
                                : AspectRatio(
                                    aspectRatio: 1.0,
                                    child: PlaceholderImage(
                                      seed: seed,
                                      borderRadius: AppRadius.photoRadius,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.xs,
                left: AppSpacing.md,
                right: AppSpacing.xs,
                child: Row(
                  children: <Widget>[
                    if (widget.title != null && widget.title!.isNotEmpty)
                      Expanded(
                        child: Text(
                          widget.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.bodyStrong.copyWith(color: Colors.white),
                        ),
                      )
                    else
                      const Spacer(),
                    Semantics(
                      button: true,
                      label: AppStrings.ber01PhotoViewerClose,
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppSizes.minTouchTarget,
                          minHeight: AppSizes.minTouchTarget,
                        ),
                        tooltip: AppStrings.ber01PhotoViewerClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: AppSizes.iconMd - 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.seeds.length > 1)
                Positioned(
                  bottom: AppSpacing.xl,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(widget.seeds.length, (i) {
                      final active = i == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: AppRadius.pillRadius,
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
