import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/shell_navigation_controller.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/nearby/presentation/nearby_widgets.dart';
import 'package:horas/features/play/presentation/play_controller.dart';
import 'package:horas/features/play/presentation/play_models.dart';
import 'package:material_ui/material_ui.dart';

/// MAN-01 Main (Utama): daftar sesi di sekitar dan lapangan populer (`MAN-R1` .. `MAN-R10`).
class Man01PlayPage extends ConsumerWidget {
  const Man01PlayPage({super.key, this.tabIndex = 3});

  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playControllerProvider);
    final controller = ref.read(playControllerProvider.notifier);
    final unreadCounts = ref
        .watch(navigationBadgeRepositoryProvider)
        .currentUnreadCounts();
    final scrollController = ref
        .read(shellNavigationProvider.notifier)
        .scrollControllerForTab(tabIndex);
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.man01Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.man01CreateSessionBtn,
            onPressed: () async {
              await context.push(AppPages.man03.routePath);
              await controller.loadInitial();
            },
            icon: Semantics(
              label: AppStrings.man01CreateSessionBtn,
              child: const Icon(Icons.add_box_outlined),
            ),
          ),
          IconButton(
            tooltip: AppStrings.man01FilterTooltip,
            onPressed: () => context.push(AppPages.man02.routePath),
            icon: Badge(
              isLabelVisible: state.filter.hasActiveFilters,
              label: Text('${state.filter.activeFilterCount}'),
              child: Semantics(
                label: AppStrings.man01FilterTooltip,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.man01HistoryTooltip,
            onPressed: () => context.push(AppPages.man09.routePath),
            icon: Semantics(
              label: AppStrings.man01HistoryTooltip,
              child: const Icon(Icons.history_rounded),
            ),
          ),
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
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.sm,
              AppSpacing.screenMargin,
              AppSpacing.sm,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.location_on_outlined,
                    color: colors.primary,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(AppStrings.sek01AreaLabel, style: typo.micro),
                        Text(state.selectedCity, style: typo.bodyStrong),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showManualAreaPickerSheet(
                        context: context,
                        cities: state.availableCities,
                        selectedCity: state.selectedCity,
                      );
                      if (picked != null && picked.isNotEmpty) {
                        await controller.setSelectedCity(picked);
                      }
                    },
                    child: const Text(AppStrings.sek02ChangeAreaBtn),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildBody(context, state, controller, scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PlayState state,
    PlayController controller,
    ScrollController scrollController,
  ) {
    if (state.isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 4),
      );
    }

    if (state.locationPermissionDenied) {
      return StateView.permissionDenied(
        benefitMessage: AppStrings.sek01LocationPermissionBenefit,
        onOpenSettings: () async {
          final picked = await showManualAreaPickerSheet(
            context: context,
            cities: state.availableCities,
            selectedCity: state.selectedCity,
          );
          if (picked != null && picked.isNotEmpty) {
            await controller.setSelectedCity(picked);
          }
        },
        onContinueWithoutPermission: controller.continueWithManualArea,
      );
    }

    if (state.error != null) {
      return StateView.fromError(state.error!, onRetry: controller.loadInitial);
    }

    if (state.sessions.isEmpty) {
      return StateView.empty(
        message: AppStrings.man01EmptyMessage,
        actionLabel: AppStrings.man01CreateSessionBtn,
        onAction: () => context.push(AppPages.man03.routePath),
      );
    }

    final colors = context.colors;
    final typo = context.typo;

    return RefreshIndicator(
      onRefresh: controller.loadInitial,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.sm,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          for (final session in state.sessions)
            SessionSummaryCard(
              session: session,
              onTap: () async {
                await context.push(
                  '${AppPages.man04.routePath}?id=${session.id}',
                );
                await controller.loadInitial();
              },
            ),
          if (state.courts.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: AppStrings.man01PopularCourtsSection,
              actionLabel: AppStrings.man01AllCourtsAction,
              onActionTap: () => context.push(AppPages.man07.routePath),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final court in state.courts.take(3))
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Icon(
                    Icons.sports_tennis_outlined,
                    color: colors.primary,
                  ),
                  title: Text(court.name, style: typo.bodyStrong),
                  subtitle: Text(
                    '${court.city} · ${AppStrings.man08EstimatedPricePrefix}: ${court.estimatedPriceText}',
                    style: typo.caption,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(
                    '${AppPages.man08.routePath}?id=${court.id}',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Kartu ringkas Sesi Main untuk `MAN-01` dan `MAN-09`.
class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({
    required this.session,
    required this.onTap,
    super.key,
  });

  final PlaySession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final feeText = PlayFormatters.formatRupiah(
      session.feePerPersonRupiah,
      freeLabel: AppStrings.man01FreeFeeLabel,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppChip(
                    label: session.sportType.label,
                    isSelected: true,
                    customBackgroundColor: colors.primary.withValues(
                      alpha: 0.12,
                    ),
                    customForegroundColor: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(session.skillLevel.label, style: typo.captionStrong),
                  const Spacer(),
                  Text(
                    feeText,
                    style: typo.bodyStrong.copyWith(color: colors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(session.title, style: typo.h3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${PlayFormatters.formatTimeWindow(session.startTime, session.endTime)} · ${session.visibleVenueText}',
                style: typo.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppStrings.man01ParticipantsRatio(
                        session.participantCount,
                        session.maxSlots,
                      ),
                      style: typo.captionStrong,
                    ),
                  ),
                  if (session.status == SessionStatus.cancelled)
                    Text(
                      AppStrings.man04StatusCancelledBadge,
                      style: typo.micro.copyWith(color: colors.danger),
                    )
                  else if (session.status == SessionStatus.completed)
                    Text(
                      AppStrings.man04StatusCompletedBadge,
                      style: typo.micro,
                    )
                  else
                    Text(
                      session.isJoinedByMe
                          ? AppStrings.man09TabJoined
                          : AppStrings.man04JoinBtn,
                      style: typo.bodyStrong.copyWith(color: colors.primary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
