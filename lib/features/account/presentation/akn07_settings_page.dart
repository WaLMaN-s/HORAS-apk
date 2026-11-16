import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/theme/theme_mode_controller.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-07 Pengaturan Utama, Mode Gelap, & Bahasa.
class Akn07SettingsPage extends ConsumerWidget {
  const Akn07SettingsPage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmDialog.show(
      context,
      title: AppStrings.akn09LogoutBtn,
      message: AppStrings.akn07LogoutConfirmBody,
      confirmLabel: AppStrings.akn09LogoutBtn,
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(authRepositoryProvider).logout();
    if (context.mounted) {
      context.go(AppPages.aut03.routePath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn07Title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const SectionHeader(title: AppStrings.akn07AppearanceSection),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.akn07ThemeModeLabel,
              style: context.typo.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                AppChip(
                  label: AppStrings.akn07ThemeSystem,
                  isSelected: currentTheme == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.system),
                ),
                AppChip(
                  label: AppStrings.akn07ThemeLight,
                  isSelected: currentTheme == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.light),
                ),
                AppChip(
                  label: AppStrings.akn07ThemeDark,
                  isSelected: currentTheme == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_rounded),
              title: const Text(AppStrings.akn07LanguageLabel),
              trailing: Text(
                AppStrings.akn07LanguageValue,
                style: context.typo.bodyStrong.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
            Divider(color: colors.border),
            const SizedBox(height: AppSpacing.md),

            const SectionHeader(title: AppStrings.akn07AccountSection),
            _NavTile(
              icon: Icons.lock_outline_rounded,
              title: AppStrings.akn08Title,
              route: AppPages.akn08.routePath,
            ),
            _NavTile(
              icon: Icons.security_rounded,
              title: AppStrings.akn09Title,
              route: AppPages.akn09.routePath,
            ),
            _NavTile(
              icon: Icons.notifications_active_outlined,
              title: AppStrings.akn10Title,
              route: AppPages.akn10.routePath,
            ),
            _NavTile(
              icon: Icons.block_rounded,
              title: AppStrings.akn11Title,
              route: AppPages.akn11.routePath,
            ),
            _NavTile(
              icon: Icons.people_outline_rounded,
              title: AppStrings.akn12Title,
              route: AppPages.akn12.routePath,
            ),
            _NavTile(
              icon: Icons.download_outlined,
              title: AppStrings.akn13Title,
              route: AppPages.akn13.routePath,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded, color: colors.danger),
              title: Text(
                AppStrings.akn09LogoutBtn,
                style: context.typo.body.copyWith(color: colors.danger),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _confirmLogout(context, ref),
            ),
            Divider(color: colors.border),
            const SizedBox(height: AppSpacing.md),

            const SectionHeader(title: AppStrings.akn07SupportSection),
            _NavTile(
              icon: Icons.fact_check_outlined,
              title: AppStrings.sis03Title,
              route: AppPages.sis03.routePath,
            ),
            _NavTile(
              icon: Icons.help_outline_rounded,
              title: AppStrings.sis04Title,
              route: AppPages.sis04.routePath,
            ),
            _NavTile(
              icon: Icons.support_agent_rounded,
              title: AppStrings.sis05Title,
              route: AppPages.sis05.routePath,
            ),
            _NavTile(
              icon: Icons.verified_outlined,
              title: AppStrings.sis06Title,
              route: AppPages.sis06.routePath,
            ),
            _NavTile(
              icon: Icons.assignment_turned_in_outlined,
              title: AppStrings.sis07Title,
              route: AppPages.sis07.routePath,
            ),
            _NavTile(
              icon: Icons.gavel_outlined,
              title: AppStrings.sis08Title,
              route: AppPages.sis08.routePath,
            ),
            _NavTile(
              icon: Icons.info_outline_rounded,
              title: AppStrings.akn15Title,
              route: AppPages.akn15.routePath,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.text;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: context.typo.body.copyWith(color: color)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(route).ignore(),
    );
  }
}
