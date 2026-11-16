import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:horas/features/tarombo/presentation/tarombo_consent_sheet.dart';
import 'package:horas/features/tarombo/presentation/tarombo_controller.dart';
import 'package:material_ui/material_ui.dart';

/// TAR-01 Dashboard Tarombo (`TAR-R1` .. `TAR-R12`).
class Tar01DashboardPage extends ConsumerWidget {
  const Tar01DashboardPage({super.key, this.tabIndex = 2});

  final int tabIndex;

  Future<void> _openAddMember(BuildContext context, WidgetRef ref) async {
    final consented = await ensureTaromboConsent(context, ref);
    if (consented && context.mounted) {
      await context.push(AppPages.tar03.routePath);
    }
  }

  Future<void> _openMotherMargaSheet(
    BuildContext context,
    WidgetRef ref,
    String? initialValue,
  ) async {
    final ctrl = TextEditingController(text: initialValue ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.tar01EditMotherMargaBtn),
        content: AppTextField(
          controller: ctrl,
          label: AppStrings.tar01MotherMargaLabel,
          hintText: AppStrings.tar03MargaHint,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text.trim()),
            child: const Text(AppStrings.tar03SaveBtn),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved == null || !context.mounted) return;
    final res = await ref
        .read(taromboControllerProvider.notifier)
        .updateMotherMarga(saved);
    if (!context.mounted) return;
    if (res is Err<Profil>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: AppStrings.tar01DeleteAllConfirmTitle,
      message: AppStrings.tar01DeleteAllConfirmBody,
      confirmLabel: AppStrings.tar01DeleteAllBtn,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final res = await ref
        .read(taromboControllerProvider.notifier)
        .deleteAllTarombo();
    if (!context.mounted) return;
    if (res is Err<void>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
      return;
    }
    AppToast.show(
      context,
      message: AppStrings.tar01DeleteAllDoneToast,
      variant: AppToastVariant.success,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taromboControllerProvider);
    final controller = ref.read(taromboControllerProvider.notifier);
    final unreadCounts = ref
        .watch(navigationBadgeRepositoryProvider)
        .currentUnreadCounts();
    final scrollController = ref
        .read(shellNavigationProvider.notifier)
        .scrollControllerForTab(tabIndex);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tar01Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.semanticsNotifications,
            onPressed: () => context.push(AppPages.sis01.routePath),
            icon: Badge(
              isLabelVisible: unreadCounts.unreadNotifications > 0,
              label: Text('${unreadCounts.unreadNotifications}'),
              child: Semantics(
                label: AppStrings.semanticsNotifications,
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(context, ref, state, controller, scrollController),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    TaromboState state,
    TaromboController controller,
    ScrollController scrollController,
  ) {
    if (state.isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    }

    if (state.error != null) {
      return StateView.fromError(state.error!, onRetry: controller.loadAll);
    }

    final me = state.profile;
    if (me == null) {
      return StateView.empty(
        message: AppStrings.tar01EmptyDataMessage,
        actionLabel: AppStrings.tar01AddMemberBtn,
        onAction: () => _openAddMember(context, ref),
      );
    }

    final colors = context.colors;
    final typo = context.typo;
    final isNeutral =
        !me.subEthnic.isPhase1RuleValidated || !me.isMargaVerified;
    final memberTypes = state.members.map((m) => m.relationType).toSet();
    final motherMarga = (me.motherMarga ?? '').trim();

    return RefreshIndicator(
      onRefresh: controller.loadAll,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.md,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          // Banner Mode Netral (AC-04, TAR-R6)
          if (isNeutral) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.border),
              ),
              child: Text(AppStrings.tar01NeutralBanner, style: typo.caption),
            ),
          ],

          // Kartu Identitas Adat
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(AppStrings.tar01IdentityTitle, style: typo.h3),
                const SizedBox(height: AppSpacing.sm),
                Text(me.displayName, style: typo.h2),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${me.marga} · ${me.subEthnic.displayName}',
                  style: typo.bodyStrong.copyWith(color: colors.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${AppStrings.tar01MotherMargaLabel}: ${motherMarga.isEmpty ? AppStrings.tar01MotherMargaEmpty : motherMarga}',
                        style: typo.caption,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _openMotherMargaSheet(context, ref, me.motherMarga),
                      child: const Text(AppStrings.tar01EditMotherMargaBtn),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Kartu Kelengkapan 5 Butir (TAR-R11)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        AppStrings.tar01CompletenessTitle,
                        style: typo.h3,
                      ),
                    ),
                    Text(
                      AppStrings.tar01CompletenessPercent(
                        state.completenessPercent,
                      ),
                      style: typo.bodyStrong.copyWith(color: colors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(AppStrings.tar01CompletenessSubtitle, style: typo.caption),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.pillRadius,
                  child: LinearProgressIndicator(
                    value: (state.completenessPercent / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: colors.chipInactive,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    _CompletenessItemChip(
                      label: AppStrings.tar01ItemMotherMarga,
                      done: motherMarga.isNotEmpty,
                    ),
                    _CompletenessItemChip(
                      label: AppStrings.tar01ItemFather,
                      done: memberTypes.contains(FamilyRelationType.father),
                    ),
                    _CompletenessItemChip(
                      label: AppStrings.tar01ItemMother,
                      done: memberTypes.contains(FamilyRelationType.mother),
                    ),
                    _CompletenessItemChip(
                      label: AppStrings.tar01ItemPaternalGrandfather,
                      done: memberTypes.contains(
                        FamilyRelationType.paternalGrandfather,
                      ),
                    ),
                    _CompletenessItemChip(
                      label: AppStrings.tar01ItemMaternalGrandfather,
                      done: memberTypes.contains(
                        FamilyRelationType.maternalGrandfather,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Pintasan Navigasi Modul Tarombo
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppButton(
                label: AppStrings.tar01OpenTreeBtn,
                leadingIcon: Icons.account_tree_outlined,
                onPressed: () => context.push(AppPages.tar02.routePath),
              ),
              AppButton(
                label: AppStrings.tar01AddMemberBtn,
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.person_add_alt_1_outlined,
                onPressed: () => _openAddMember(context, ref),
              ),
              AppButton(
                label: AppStrings.tar01CheckPartuturanBtn,
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.calculate_outlined,
                onPressed: () => context.push(AppPages.tar06.routePath),
              ),
              AppButton(
                label: state.incomingClaims.isNotEmpty
                    ? '${AppStrings.tar01ConfirmationsBtn} (${state.incomingClaims.length})'
                    : AppStrings.tar01ConfirmationsBtn,
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.verified_outlined,
                onPressed: () => context.push(AppPages.tar07.routePath),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Permintaan Konfirmasi Hubungan Masuk (TAR-07)
          SectionHeader(
            title: AppStrings.tar01IncomingClaimsTitle,
            actionLabel: AppStrings.actionSeeAll,
            onActionTap: () => context.push(AppPages.tar07.routePath),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.incomingClaims.isEmpty)
            Text(AppStrings.tar07EmptyIncoming, style: typo.caption)
          else
            for (final claim in state.incomingClaims.take(3))
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${claim.sender.displayName} (${claim.sender.marga}) → ${claim.claimedTermForReceiver}',
                        style: typo.bodyStrong,
                      ),
                      if ((claim.note ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(claim.note!, style: typo.caption),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          FilledButton(
                            onPressed: () => controller.respondClaim(
                              claimId: claim.id,
                              accept: true,
                            ),
                            child: const Text(AppStrings.sek04AcceptBtn),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton(
                            onPressed: () => controller.respondClaim(
                              claimId: claim.id,
                              accept: false,
                            ),
                            child: const Text(AppStrings.sek04RejectBtn),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.xl),

          // Saran Kerabat (ketuk membuka TAR-05 Detail Hubungan)
          const SectionHeader(title: AppStrings.tar01SuggestionsTitle),
          const SizedBox(height: AppSpacing.sm),
          if (state.suggestions.isEmpty)
            Text(AppStrings.tar01EmptySuggestions, style: typo.caption)
          else
            for (final person in state.suggestions)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: AppAvatar(
                    name: person.displayName,
                    seed: person.avatarSeed,
                  ),
                  title: Text(person.displayName, style: typo.bodyStrong),
                  subtitle: Text(
                    '${person.marga} · ${person.city}',
                    style: typo.caption,
                  ),
                  trailing:
                      person.partuturan != null &&
                          !person.partuturan!.modeNetral
                      ? PartuturanBadge(
                          result: person.partuturan!,
                          onTap: () => context.push(
                            '${AppPages.tar05.routePath}?userId=${person.id}',
                          ),
                        )
                      : null,
                  onTap: () => context.push(
                    '${AppPages.tar05.routePath}?userId=${person.id}',
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.xl),

          // Privasi & Hapus Seluruh Data Tarombo (TAR-R10)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(AppStrings.tar01PrivacyTitle, style: typo.h3),
                const SizedBox(height: AppSpacing.md),
                _PrivacySelectorRow(
                  label: AppStrings.tar01PrivacyTaromboLabel,
                  value: me.privacySettings.tarombo,
                  allowEveryone: false,
                  onChanged: (v) =>
                      controller.updatePrivacy(taromboVisibility: v),
                ),
                const SizedBox(height: AppSpacing.md),
                _PrivacySelectorRow(
                  label: AppStrings.tar01PrivacyMotherMargaLabel,
                  value: me.privacySettings.motherMarga,
                  allowEveryone: true,
                  onChanged: (v) =>
                      controller.updatePrivacy(motherMargaVisibility: v),
                ),
                const SizedBox(height: AppSpacing.md),
                _PrivacySelectorRow(
                  label: AppStrings.tar01PrivacyParentsLabel,
                  value: state.parentNamesVisibility,
                  allowEveryone: true,
                  onChanged: (v) =>
                      controller.updatePrivacy(parentNamesVisibility: v),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: AppStrings.tar01DeleteAllBtn,
                  variant: AppButtonVariant.secondary,
                  isDestructive: true,
                  leadingIcon: Icons.delete_forever_outlined,
                  onPressed: () => _confirmDeleteAll(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletenessItemChip extends StatelessWidget {
  const _CompletenessItemChip({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppChip(
      label: label,
      isSelected: done,
      leadingIcon: done
          ? Icons.check_circle_outline_rounded
          : Icons.circle_outlined,
      customBackgroundColor: done
          ? colors.primary.withValues(alpha: 0.12)
          : colors.chipInactive,
      customForegroundColor: done ? colors.primary : colors.textMuted,
    );
  }
}

class _PrivacySelectorRow extends StatelessWidget {
  const _PrivacySelectorRow({
    required this.label,
    required this.value,
    required this.allowEveryone,
    required this.onChanged,
  });

  final String label;
  final FieldVisibility value;
  final bool allowEveryone;
  final ValueChanged<FieldVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final options = <FieldVisibility>[
      FieldVisibility.onlyMe,
      FieldVisibility.connectedOnly,
      if (allowEveryone) FieldVisibility.everyone,
    ];
    final safeValue = options.contains(value) ? value : FieldVisibility.onlyMe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: typo.captionStrong),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<FieldVisibility>(
          initialValue: safeValue,
          decoration: const InputDecoration(),
          items: <DropdownMenuItem<FieldVisibility>>[
            for (final v in options)
              DropdownMenuItem<FieldVisibility>(
                value: v,
                child: Text(switch (v) {
                  FieldVisibility.onlyMe => AppStrings.tar01VisibilityOnlyMe,
                  FieldVisibility.connectedOnly =>
                    AppStrings.tar01VisibilityConnected,
                  FieldVisibility.everyone =>
                    AppStrings.tar01VisibilityEveryone,
                }),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ],
    );
  }
}
