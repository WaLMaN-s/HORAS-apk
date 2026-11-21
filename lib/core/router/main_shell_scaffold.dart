import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/app_avatar.dart';
import 'package:horas/core/widgets/placeholder_image.dart';
import 'package:material_ui/material_ui.dart';

/// Definisi satu item bilah navigasi bawah 5 tab sesuai PRD 4 & referensi visual.
final class _BottomNavTabSpec {
  const _BottomNavTabSpec({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final IconData activeIcon;
}

const List<_BottomNavTabSpec> _kBottomTabs = <_BottomNavTabSpec>[
  _BottomNavTabSpec(
    label: AppStrings.tabBeranda,
    sublabel: AppStrings.tabBerandaSub,
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  _BottomNavTabSpec(
    label: AppStrings.tabSekitar,
    sublabel: AppStrings.tabSekitarSub,
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore_rounded,
  ),
  _BottomNavTabSpec(
    label: AppStrings.tabPesan,
    sublabel: AppStrings.tabPesanSub,
    icon: Icons.chat_bubble_outline_rounded,
    activeIcon: Icons.chat_bubble_rounded,
  ),
  _BottomNavTabSpec(
    label: AppStrings.tabMain,
    sublabel: AppStrings.tabMainSub,
    icon: Icons.emoji_events_outlined,
    activeIcon: Icons.emoji_events_rounded,
  ),
  _BottomNavTabSpec(
    label: AppStrings.tabAkun,
    sublabel: AppStrings.tabAkunSub,
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
  ),
];

/// Shell utama dengan 5 tab bilah bawah bergaya IG/Threads (PRD 4, Tahap 6).
///
/// - Mengingat tab terakhir selama sesi.
/// - Ketuk ulang tab aktif = kembali ke halaman awal tab dan menggulung ke atas.
/// - Tab Akun menampilkan foto profil mini pengguna bila tersedia.
class MainShellScaffold extends ConsumerWidget {
  const MainShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  Future<void> _onTabTapped(WidgetRef ref, int index) async {
    HapticFeedback.selectionClick().ignore();
    final currentIndex = navigationShell.currentIndex;
    final navController = ref.read(shellNavigationProvider.notifier);

    if (index == currentIndex) {
      navigationShell.goBranch(index, initialLocation: true);
      await navController.onReTapActiveTab(index);
    } else {
      navController.selectTab(index);
      navigationShell.goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typo = context.typo;
    final currentIndex = navigationShell.currentIndex;
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ??
        ref.read(navigationBadgeRepositoryProvider).currentUnreadCounts();
    final sessionProfile = ref
        .watch(authRepositoryProvider)
        .currentSessionProfile;
    final hasProfilePhoto =
        sessionProfile != null &&
        PlaceholderImage.isRealImageSeed(sessionProfile.avatarSeed);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.border.withValues(alpha: 0.65),
              width: AppSizes.strokeThin,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: <Widget>[
                for (var i = 0; i < _kBottomTabs.length; i++)
                  Expanded(
                    child: _BottomNavBarItem(
                      spec: _kBottomTabs[i],
                      isSelected: i == currentIndex,
                      badgeCount: i == 2 ? unreadCounts.unreadMessages : 0,
                      activeColor: colors.accent,
                      inactiveColor: colors.textMuted,
                      labelStyle: typo.micro,
                      avatarName: (i == 4 && hasProfilePhoto)
                          ? sessionProfile.displayName
                          : null,
                      avatarSeed: (i == 4 && hasProfilePhoto)
                          ? sessionProfile.avatarSeed
                          : null,
                      onTap: () => _onTabTapped(ref, i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBarItem extends StatelessWidget {
  const _BottomNavBarItem({
    required this.spec,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.labelStyle,
    required this.onTap,
    this.badgeCount = 0,
    this.avatarName,
    this.avatarSeed,
  });

  final _BottomNavTabSpec spec;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final TextStyle labelStyle;
  final VoidCallback onTap;
  final int badgeCount;
  final String? avatarName;
  final String? avatarSeed;

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected ? activeColor : inactiveColor;
    final semanticsLabel = badgeCount > 0
        ? '${AppStrings.semanticsTab(spec.label, spec.sublabel)}, ${AppStrings.semanticsUnreadBadge(badgeCount)}'
        : AppStrings.semanticsTab(spec.label, spec.sublabel);

    final Widget iconWidget;
    if (avatarName != null && avatarSeed != null) {
      iconWidget = Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? activeColor
                : inactiveColor.withValues(alpha: 0.4),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: AppAvatar(
          name: avatarName!,
          seed: avatarSeed,
          size: AppSizes.iconMd - 1,
        ),
      );
    } else {
      iconWidget = Icon(
        isSelected ? spec.activeIcon : spec.icon,
        size: AppSizes.iconMd + 1,
        color: fgColor,
      );
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: activeColor.withValues(alpha: 0.06),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTouchTarget,
            minWidth: AppSizes.minTouchTarget,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: Badge(
                  isLabelVisible: badgeCount > 0,
                  backgroundColor: activeColor,
                  label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                  child: iconWidget,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle.copyWith(
                  fontSize: 10.5,
                  color: fgColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
