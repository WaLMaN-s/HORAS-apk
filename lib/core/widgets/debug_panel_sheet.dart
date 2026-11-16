import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/app_bottom_sheet.dart';
import 'package:horas/core/widgets/app_button.dart';
import 'package:horas/core/widgets/app_chip.dart';
import 'package:horas/core/widgets/section_header.dart';
import 'package:material_ui/material_ui.dart';

/// Panel Debug HORAS khusus build non-prod (`dev` / `beta`), dibuka dengan tekan lama
/// logo HORAS di halaman Tentang HORAS (`AKN-15` — Prompt 2 Bagian D).
///
/// Berbicara hanya ke antarmuka `DebugSimulationRepository` lewat provider.
class DebugPanelSheet extends ConsumerStatefulWidget {
  const DebugPanelSheet({super.key});

  /// Membuka Panel Debug jika dan hanya jika `appConfig.isProd == false`.
  static Future<void> showIfNonProd(BuildContext context, WidgetRef ref) async {
    final config = ref.read(appConfigProvider);
    if (config.isProd) {
      return;
    }
    await AppBottomSheet.show<void>(
      context,
      title: AppStrings.debugPanelTitle,
      child: const DebugPanelSheet(),
    );
  }

  @override
  ConsumerState<DebugPanelSheet> createState() => _DebugPanelSheetState();
}

class _DebugPanelSheetState extends ConsumerState<DebugPanelSheet> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(debugSimulationRepositoryProvider);
    final sim = repo.state;
    final users = repo.availableMockUsers;
    final colors = context.colors;
    final typo = context.typo;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 1. Toggle skenario: offline, error server, kosong, lambat
          const SectionHeader(title: AppStrings.debugSectionScenarios),
          const SizedBox(height: AppSpacing.xs),
          _buildSwitchTile(
            label: AppStrings.debugToggleOffline,
            value: sim.isOffline,
            onChanged: (val) => setState(() => repo.setOffline(val)),
          ),
          _buildSwitchTile(
            label: AppStrings.debugToggleServerError,
            value: sim.isServerError,
            onChanged: (val) => setState(() => repo.setServerError(val)),
          ),
          _buildSwitchTile(
            label: AppStrings.debugToggleEmpty,
            value: sim.isEmptyState,
            onChanged: (val) => setState(() => repo.setEmptyState(val)),
          ),
          _buildSwitchTile(
            label: AppStrings.debugToggleSlow,
            value: sim.isSlowNetwork,
            onChanged: (val) => setState(() => repo.setSlowNetwork(val)),
          ),
          _buildSwitchTile(
            label: AppStrings.debugToggleChatAutoReply,
            value: sim.isChatAutoReplyEnabled,
            onChanged: (val) =>
                setState(() => repo.setChatAutoReplyEnabled(val)),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Majukan waktu tiruan (Clock) untuk menguji kedaluwarsa 14/30 hari & hapus akun 30 hari
          SectionHeader(
            title: AppStrings.debugSectionClock,
            subtitle:
                '${sim.currentNow.toIso8601String().substring(0, 16)} (+${sim.timeOffset.inHours}j)',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppChip(
                label: AppStrings.debugClockAdvance1Hour,
                onTap: () =>
                    setState(() => repo.advanceClock(const Duration(hours: 1))),
              ),
              AppChip(
                label: AppStrings.debugClockAdvance1Day,
                onTap: () =>
                    setState(() => repo.advanceClock(const Duration(days: 1))),
              ),
              AppChip(
                label: AppStrings.debugClockAdvance14Days,
                onTap: () =>
                    setState(() => repo.advanceClock(const Duration(days: 14))),
              ),
              AppChip(
                label: AppStrings.debugClockAdvance30Days,
                onTap: () =>
                    setState(() => repo.advanceClock(const Duration(days: 30))),
              ),
              AppChip(
                label: AppStrings.debugClockReset,
                isSelected: sim.timeOffset != Duration.zero,
                onTap: () => setState(repo.resetClock),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3. Ganti pengguna tiruan
          const SectionHeader(title: AppStrings.debugSectionUser),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSizes.minTouchTarget,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: users.take(12).length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final u = users[index];
                final selected = u.id == sim.currentUserId;
                return AppChip(
                  label: '${u.displayName} (${u.subEthnic.displayName})',
                  isSelected: selected,
                  onTap: () async {
                    await repo.switchMockUser(u.id);
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 4. Simulasi tindakan moderasi & Reset data
          SectionHeader(
            title: AppStrings.debugSectionModeration,
            subtitle: 'Strike aktif (90h): ${sim.activeStrikesCount}',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppButton(
                label: AppStrings.debugAddStrike,
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(repo.simulateAddStrike),
              ),
              AppButton(
                label: AppStrings.debugSuspendAccount,
                variant: AppButtonVariant.secondary,
                isDestructive: true,
                onPressed: () => setState(repo.simulateSuspendCurrentAccount),
              ),
              AppButton(
                label: AppStrings.debugClearSanctions,
                variant: AppButtonVariant.text,
                onPressed: () => setState(repo.clearAccountSanctions),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: colors.border),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: AppStrings.debugResetAllData,
            variant: AppButtonVariant.primary,
            isDestructive: true,
            isExpanded: true,
            onPressed: () async {
              await repo.resetAllData();
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pengguna aktif: ${sim.currentUserId}',
            textAlign: TextAlign.center,
            style: typo.micro,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final typo = context.typo;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: typo.body)),
          Switch(
            value: value,
            activeTrackColor: colors.buttonPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
