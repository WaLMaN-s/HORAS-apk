import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/theme/theme_mode_controller.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/page_spec.dart';
import 'package:material_ui/material_ui.dart';

/// Halaman placeholder terstruktur untuk halaman inventaris PRD 5.1 yang belum dibangun (Tahap 6).
///
/// Mematuhi aturan:
/// - Halaman Fase 2 tidak boleh menampilkan UI Fase 2 bila `FeatureFlags` terkait bernilai `false`.
/// - Berbicara ke antarmuka repository lewat provider (`navigationBadgeRepositoryProvider`).
class SegeraPage extends ConsumerWidget {
  const SegeraPage({
    required this.pageSpec,
    super.key,
    this.tabIndex,
  });

  final PageSpec pageSpec;
  final int? tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    // Larangan PRD / Tahap 3: UI Fase 2 tidak tampil bila FeatureFlags false.
    if (!pageSpec.isAvailable(flags)) {
      return Scaffold(
        appBar: AppBar(
          leading: _buildBackButton(context),
          title: Text(AppStrings.stateContentUnavailableTitle, style: typo.h2),
        ),
        body: StateView.contentUnavailable(
          onBack: () => context.go(AppPages.berandaPath),
        ),
      );
    }

    final unreadCounts = ref
        .watch(navigationBadgeRepositoryProvider)
        .currentUnreadCounts();
    final scrollController = tabIndex != null
        ? ref
              .read(shellNavigationProvider.notifier)
              .scrollControllerForTab(tabIndex!)
        : null;

    // Subhalaman di modul yang sama; saring halaman Fase 2 bila flag false.
    final relatedPages = AppPages.pagesForModule(pageSpec.module)
        .where((p) => p.id != pageSpec.id && p.isAvailable(flags))
        .toList();

    final isRootTab = tabIndex != null;

    return Scaffold(
      appBar: AppBar(
        leading: isRootTab ? null : _buildBackButton(context),
        title: pageSpec.id == AppPages.ber01.id
            ? const HorasLogo(showRoof: false, wordmarkFontSize: 26)
            : Text(pageSpec.title, style: typo.h1),
        actions: _buildTopBarActions(
          context,
          ref,
          unreadMessages: unreadCounts.unreadMessages,
          unreadNotifications: unreadCounts.unreadNotifications,
        ),
      ),
      body: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
          vertical: AppSpacing.md,
        ),
        children: <Widget>[
          const GorgaOrnament(
            width: double.infinity,
            height: 20,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.border),
              boxShadow: AppShadows.softCard(colors.shadow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    AppChip(
                      label: pageSpec.id,
                      isSelected: true,
                    ),
                    AppChip(
                      label: _phaseLabel(pageSpec.phase),
                    ),
                    const VerifiedBadge(
                      isVerified: true,
                      showLabel: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(pageSpec.title, style: typo.h1),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  pageSpec.purpose,
                  style: typo.body.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                PlaceholderImage(
                  seed: '${pageSpec.id}-${pageSpec.title}',
                  height: 128,
                  width: double.infinity,
                  caption: '${pageSpec.module.label} · ${pageSpec.title}',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.segeraInfoDescription,
                  style: typo.caption,
                ),
              ],
            ),
          ),
          if (relatedPages.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: AppStrings.segeraSectionSubpages,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final subpage in relatedPages)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.cardRadius,
                    side: BorderSide(color: colors.border),
                  ),
                  child: InkWell(
                    borderRadius: AppRadius.cardRadius,
                    onTap: () => context.push(subpage.routePath),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSizes.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colors.chipInactive,
                                borderRadius: AppRadius.buttonRadius,
                              ),
                              child: Text(
                                subpage.id,
                                style: typo.micro.copyWith(color: colors.text),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(subpage.title, style: typo.bodyStrong),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    subpage.purpose,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: typo.caption,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: AppSizes.iconMd,
                              color: colors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.semanticsBack,
      child: IconButton(
        constraints: const BoxConstraints(
          minWidth: AppSizes.minTouchTarget,
          minHeight: AppSizes.minTouchTarget,
        ),
        tooltip: AppStrings.semanticsBack,
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppPages.berandaPath);
          }
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }

  List<Widget> _buildTopBarActions(
    BuildContext context,
    WidgetRef ref, {
    required int unreadMessages,
    required int unreadNotifications,
  }) {
    final actions = <Widget>[];

    // PRD 4.2 & 4.3: Beranda memiliki Pencarian, Tambah Postingan, Notifikasi, dan Pesan.
    if (pageSpec.id == AppPages.ber01.id) {
      actions.add(
        _TopBarIconButton(
          icon: Icons.add_box_outlined,
          semanticsLabel: AppStrings.semanticsCreatePost,
          onTap: () => context.push(AppPages.ber04.routePath),
        ),
      );
      actions.add(
        _TopBarIconButton(
          icon: Icons.search_rounded,
          semanticsLabel: AppStrings.semanticsSearch,
          onTap: () => context.push(AppPages.ber09.routePath),
        ),
      );
      actions.add(
        _TopBarIconButton(
          icon: Icons.notifications_none_rounded,
          semanticsLabel: AppStrings.semanticsNotifications,
          badgeCount: unreadNotifications,
          onTap: () => context.push(AppPages.sis01.routePath),
        ),
      );
      actions.add(
        _TopBarIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          semanticsLabel: AppStrings.semanticsMessages,
          badgeCount: unreadMessages,
          onTap: () => context.push(AppPages.psn01.routePath),
        ),
      );
      return actions;
    }

    // PRD 4.3: Tombol buat sesi ada di tab Main.
    if (pageSpec.id == AppPages.man01.id) {
      actions.add(
        _TopBarIconButton(
          icon: Icons.add_circle_outline_rounded,
          semanticsLabel: AppStrings.semanticsCreateSession,
          onTap: () => context.push(AppPages.man03.routePath),
        ),
      );
    }

    // Tab Akun menyediakan tombol cepat ganti mode tema & Pengaturan.
    if (pageSpec.id == AppPages.akn01.id) {
      actions.add(
        _TopBarIconButton(
          icon: Icons.brightness_6_outlined,
          semanticsLabel: AppStrings.semanticsToggleTheme,
          onTap: () => ref.read(themeModeProvider.notifier).cycleThemeMode(),
        ),
      );
      actions.add(
        _TopBarIconButton(
          icon: Icons.settings_outlined,
          semanticsLabel: AppStrings.semanticsSettings,
          onTap: () => context.push(AppPages.akn07.routePath),
        ),
      );
    }

    // PRD 4.2: Ikon Notifikasi ada di bilah atas tab lain.
    if (tabIndex != null) {
      actions.add(
        _TopBarIconButton(
          icon: Icons.notifications_none_rounded,
          semanticsLabel: AppStrings.semanticsNotifications,
          badgeCount: unreadNotifications,
          onTap: () => context.push(AppPages.sis01.routePath),
        ),
      );
    }

    return actions;
  }

  static String _phaseLabel(int phase) {
    return switch (phase) {
      1 => AppStrings.segeraPhase1Badge,
      2 => AppStrings.segeraPhase2Badge,
      _ => AppStrings.segeraPhase3Badge,
    };
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final effectiveLabel = badgeCount > 0
        ? '$semanticsLabel, ${AppStrings.semanticsUnreadBadge(badgeCount)}'
        : semanticsLabel;

    return Semantics(
      button: true,
      label: effectiveLabel,
      child: IconButton(
        constraints: const BoxConstraints(
          minWidth: AppSizes.minTouchTarget,
          minHeight: AppSizes.minTouchTarget,
        ),
        tooltip: semanticsLabel,
        onPressed: onTap,
        icon: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Icon(icon, size: AppSizes.iconMd, color: colors.text),
            if (badgeCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.buttonPrimary,
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: typo.micro.copyWith(
                      color: colors.onPrimary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
