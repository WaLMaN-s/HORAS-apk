import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
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

/// Shell utama dengan 5 tab bilah bawah bergaya referensi (PRD 4, Tahap 6).
///
/// - Mengingat tab terakhir selama sesi.
/// - Ketuk ulang tab aktif = kembali ke halaman awal tab dan menggulung ke atas.
class MainShellScaffold extends ConsumerWidget {
  const MainShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  Future<void> _onTabTapped(WidgetRef ref, int index) async {
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

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.border, width: AppSizes.strokeThin),
          ),
          boxShadow: AppShadows.subtleBar(colors.shadow),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppSizes.bottomNavHeight,
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
  });

  final _BottomNavTabSpec spec;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final TextStyle labelStyle;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected ? activeColor : inactiveColor;
    final semanticsLabel = badgeCount > 0
        ? '${AppStrings.semanticsTab(spec.label, spec.sublabel)}, ${AppStrings.semanticsUnreadBadge(badgeCount)}'
        : AppStrings.semanticsTab(spec.label, spec.sublabel);

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTouchTarget,
            minWidth: AppSizes.minTouchTarget,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                child: Icon(
                  isSelected ? spec.activeIcon : spec.icon,
                  size: AppSizes.iconMd,
                  color: fgColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle.copyWith(
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
