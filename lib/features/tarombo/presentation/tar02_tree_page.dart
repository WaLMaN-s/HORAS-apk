import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/features/tarombo/presentation/tarombo_consent_sheet.dart';
import 'package:horas/features/tarombo/presentation/tarombo_controller.dart';
import 'package:material_ui/material_ui.dart';

/// TAR-02 Pohon Silsilah: maksimal 3 generasi ke atas dari pemilik (`TAR-R12`).
///
/// Digambar dengan `CustomPainter` di dalam `InteractiveViewer`. Node menampilkan
/// nama, marga, dan lencana hubungan. Pohon lengkap dibuka pada Fase 3.
class Tar02TreePage extends ConsumerWidget {
  const Tar02TreePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taromboControllerProvider);
    final controller = ref.read(taromboControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tar02Title),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.tar01AddMemberBtn,
            onPressed: () async {
              final ok = await ensureTaromboConsent(context, ref);
              if (ok && context.mounted) {
                await context.push(AppPages.tar03.routePath);
              }
            },
            icon: Semantics(
              label: AppStrings.tar01AddMemberBtn,
              child: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ),
        ],
      ),
      body: _buildBody(context, ref, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    TaromboState state,
    TaromboController controller,
  ) {
    final typo = context.typo;
    final colors = context.colors;
    if (state.isLoading) {
      return const SingleChildScrollView(
        child: StateView.loading(itemCount: 3),
      );
    }

    if (state.error != null) {
      return StateView.fromError(state.error!, onRetry: controller.loadAll);
    }

    if (state.members.isEmpty || state.profile == null) {
      return StateView.empty(
        message: AppStrings.tar01EmptyDataMessage,
        actionLabel: AppStrings.tar01AddMemberBtn,
        onAction: () async {
          final ok = await ensureTaromboConsent(context, ref);
          if (ok && context.mounted) {
            await context.push(AppPages.tar03.routePath);
          }
        },
      );
    }

    final me = state.profile!;
    FamilyMember? findByType(FamilyRelationType t) =>
        state.members.where((m) => m.relationType == t).firstOrNull;

    final father = findByType(FamilyRelationType.father);
    final mother = findByType(FamilyRelationType.mother);
    final patGrandfather = findByType(FamilyRelationType.paternalGrandfather);
    final matGrandfather = findByType(FamilyRelationType.maternalGrandfather);

    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppStrings.tar02SubtitleFullTreeSoon,
                style: typo.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(AppStrings.tar02ThreeGenNotice, style: typo.caption),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            minScale: 0.55,
            maxScale: 2.0,
            boundaryMargin: const EdgeInsets.all(AppSpacing.xxl),
            constrained: false,
            child: SizedBox(
              width: 660,
              height: 460,
              child: Stack(
                children: <Widget>[
                  CustomPaint(
                    size: const Size(660, 460),
                    painter: _TaromboTreePainter(
                      lineColor: colors.primary,
                      hasFather: father != null,
                      hasMother: mother != null,
                      hasPatGrandfather: patGrandfather != null,
                      hasMatGrandfather: matGrandfather != null,
                    ),
                  ),
                  // Generasi +2 (Kakek dari Ayah & Kakek dari Ibu)
                  Positioned(
                    left: 50,
                    top: 24,
                    width: 240,
                    child: _TreeNodeCard(
                      member: patGrandfather,
                      relationLabel: AppStrings.tar01ItemPaternalGrandfather,
                      onTapMember: () => context.push(
                        '${AppPages.tar04.routePath}?id=${patGrandfather!.id}',
                      ),
                      onTapEmpty: () => _openAddForType(
                        context,
                        ref,
                        FamilyRelationType.paternalGrandfather,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 370,
                    top: 24,
                    width: 240,
                    child: _TreeNodeCard(
                      member: matGrandfather,
                      relationLabel: AppStrings.tar01ItemMaternalGrandfather,
                      onTapMember: () => context.push(
                        '${AppPages.tar04.routePath}?id=${matGrandfather!.id}',
                      ),
                      onTapEmpty: () => _openAddForType(
                        context,
                        ref,
                        FamilyRelationType.maternalGrandfather,
                      ),
                    ),
                  ),
                  // Generasi +1 (Ayah & Ibu)
                  Positioned(
                    left: 50,
                    top: 176,
                    width: 240,
                    child: _TreeNodeCard(
                      member: father,
                      relationLabel: AppStrings.tar01ItemFather,
                      onTapMember: () => context.push(
                        '${AppPages.tar04.routePath}?id=${father!.id}',
                      ),
                      onTapEmpty: () => _openAddForType(
                        context,
                        ref,
                        FamilyRelationType.father,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 370,
                    top: 176,
                    width: 240,
                    child: _TreeNodeCard(
                      member: mother,
                      relationLabel: AppStrings.tar01ItemMother,
                      onTapMember: () => context.push(
                        '${AppPages.tar04.routePath}?id=${mother!.id}',
                      ),
                      onTapEmpty: () => _openAddForType(
                        context,
                        ref,
                        FamilyRelationType.mother,
                      ),
                    ),
                  ),
                  // Generasi 0 (Pemilik)
                  Positioned(
                    left: 200,
                    top: 332,
                    width: 260,
                    child: _SelfNodeCard(profile: me),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(AppStrings.tar02ZoomHint, style: typo.micro),
        ),
      ],
    );
  }

  Future<void> _openAddForType(
    BuildContext context,
    WidgetRef ref,
    FamilyRelationType type,
  ) async {
    final ok = await ensureTaromboConsent(context, ref);
    if (ok && context.mounted) {
      await context.push('${AppPages.tar03.routePath}?type=${type.name}');
    }
  }
}

class _TaromboTreePainter extends CustomPainter {
  const _TaromboTreePainter({
    required this.lineColor,
    required this.hasFather,
    required this.hasMother,
    required this.hasPatGrandfather,
    required this.hasMatGrandfather,
  });

  final Color lineColor;
  final bool hasFather;
  final bool hasMother;
  final bool hasPatGrandfather;
  final bool hasMatGrandfather;

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final mutedPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // Pusat horizontal kiri (x=170) & kanan (x=490) & tengah pemilik (x=330)
    const leftX = 170.0;
    const rightX = 490.0;
    const centerX = 330.0;

    // Garis Gen +2 -> Gen +1 (Kakek Ayah -> Ayah)
    canvas.drawLine(
      const Offset(leftX, 118),
      const Offset(leftX, 176),
      (hasFather && hasPatGrandfather) ? activePaint : mutedPaint,
    );

    // Garis Gen +2 -> Gen +1 (Kakek Ibu -> Ibu)
    canvas.drawLine(
      const Offset(rightX, 118),
      const Offset(rightX, 176),
      (hasMother && hasMatGrandfather) ? activePaint : mutedPaint,
    );

    // Garis Ayah & Ibu -> Pemilik
    const parentBottomY = 270.0;
    const joinY = 302.0;
    const selfTopY = 332.0;

    canvas.drawLine(
      const Offset(leftX, parentBottomY),
      const Offset(leftX, joinY),
      hasFather ? activePaint : mutedPaint,
    );
    canvas.drawLine(
      const Offset(rightX, parentBottomY),
      const Offset(rightX, joinY),
      hasMother ? activePaint : mutedPaint,
    );
    canvas.drawLine(
      const Offset(leftX, joinY),
      const Offset(rightX, joinY),
      (hasFather || hasMother) ? activePaint : mutedPaint,
    );
    canvas.drawLine(
      const Offset(centerX, joinY),
      const Offset(centerX, selfTopY),
      (hasFather || hasMother) ? activePaint : mutedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TaromboTreePainter oldDelegate) {
    return lineColor != oldDelegate.lineColor ||
        hasFather != oldDelegate.hasFather ||
        hasMother != oldDelegate.hasMother ||
        hasPatGrandfather != oldDelegate.hasPatGrandfather ||
        hasMatGrandfather != oldDelegate.hasMatGrandfather;
  }
}

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({
    required this.member,
    required this.relationLabel,
    required this.onTapMember,
    required this.onTapEmpty,
  });

  final FamilyMember? member;
  final String relationLabel;
  final VoidCallback onTapMember;
  final VoidCallback onTapEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (member == null) {
      return InkWell(
        onTap: onTapEmpty,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          height: 94,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.chipInactive,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.add_circle_outline_rounded, color: colors.textMuted),
              const SizedBox(height: AppSpacing.xs),
              Text(
                relationLabel,
                style: typo.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTapMember,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        height: 94,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colors.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.pillRadius,
              ),
              child: Text(
                relationLabel,
                style: typo.micro.copyWith(color: colors.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              member!.fullName,
              style: typo.bodyStrong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${member!.marga} · ${member!.lifeStatus.label}',
              style: typo.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelfNodeCard extends StatelessWidget {
  const _SelfNodeCard({required this.profile});

  final Profil profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Container(
      height: 100,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.2),
              borderRadius: AppRadius.pillRadius,
            ),
            child: Text(
              AppStrings.tar02SelfNodeRole,
              style: typo.micro.copyWith(color: colors.onPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            profile.displayName,
            style: typo.bodyStrong.copyWith(color: colors.onPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${profile.marga} · ${profile.subEthnic.displayName}',
            style: typo.caption.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
