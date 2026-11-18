import 'dart:math' as math;

import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/placeholder_image.dart';
import 'package:material_ui/material_ui.dart';

/// Avatar bulat pengguna dengan latar gradien berbasis seed dan inisial nama (Tahap 4 & 5).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    super.key,
    this.seed,
    this.size = AppSizes.avatarMd,
    this.showBorder = false,
    this.onTap,
    this.semanticsLabel,
  });

  final String name;
  final String? seed;
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  static String initialsOf(String rawName) {
    final parts = rawName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'H';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1);
    final last = parts.last.substring(0, 1);
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final effectiveSeed = seed ?? name;
    final initials = initialsOf(name);
    final hasRealPhoto = PlaceholderImage.isRealImageSeed(effectiveSeed);

    final avatarBody = RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(color: colors.surface, width: AppSizes.strokeThick)
              : Border.all(color: colors.border, width: AppSizes.strokeThin),
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PlaceholderImage(
                seed: effectiveSeed,
                width: size,
                height: size,
                borderRadius: BorderRadius.zero,
                showMountainSilhouette: false,
              ),
              if (!hasRealPhoto)
                Text(
                  initials,
                  style: typo.bodyStrong.copyWith(
                    color: colors.onPrimary,
                    fontSize: math.max(11, size * 0.36),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final content = onTap != null
        ? GestureDetector(onTap: onTap, child: avatarBody)
        : avatarBody;

    return Semantics(
      image: true,
      button: onTap != null,
      label: semanticsLabel ?? AppStrings.semanticsAvatarFor(name),
      child: content,
    );
  }
}

/// Tumpukan avatar melingkar untuk daftar peserta sesi/komunitas dengan lencana `+N` (Tahap 5).
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    required this.names,
    super.key,
    this.maxVisible = 5,
    this.totalCount,
    this.avatarSize = AppSizes.avatarSm,
    this.overlapFraction = 0.28,
  });

  final List<String> names;
  final int maxVisible;
  final int? totalCount;
  final double avatarSize;
  final double overlapFraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final visibleNames = names.take(maxVisible).toList();
    final effectiveTotal = math.max(totalCount ?? names.length, names.length);
    final overflowCount = effectiveTotal - visibleNames.length;

    if (visibleNames.isEmpty && overflowCount <= 0) {
      return const SizedBox.shrink();
    }

    final step = avatarSize * (1 - overlapFraction);
    final itemCount = visibleNames.length + (overflowCount > 0 ? 1 : 0);
    final totalWidth = itemCount == 0
        ? 0.0
        : avatarSize + (itemCount - 1) * step;

    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(
        children: <Widget>[
          for (var i = 0; i < visibleNames.length; i++)
            Positioned(
              left: i * step,
              child: AppAvatar(
                name: visibleNames[i],
                size: avatarSize,
                showBorder: true,
              ),
            ),
          if (overflowCount > 0)
            Positioned(
              left: visibleNames.length * step,
              child: Semantics(
                label: AppStrings.semanticsAvatarOverflow(overflowCount),
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.chipInactive,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.surface,
                      width: AppSizes.strokeThick,
                    ),
                  ),
                  child: Text(
                    '+$overflowCount',
                    style: typo.micro.copyWith(color: colors.text),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
