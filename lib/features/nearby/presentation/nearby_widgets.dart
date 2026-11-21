import 'package:go_router/go_router.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// Kartu profil orang di Sekitar dan Pencarian bergaya IG (`SEK-R2`, `SEK-R6`, `AC-07`).
///
/// Hanya menampilkan foto, nama, marga, badge partuturan (bila ada), atau label Semarga ringkas.
/// Tidak pernah memuat nomor HP, usia pasti, jarak presisi (km), atau koordinat.
class PersonNearbyCard extends StatelessWidget {
  const PersonNearbyCard({
    required this.person,
    required this.onTap,
    super.key,
    this.trailing,
  });

  final PersonSummary person;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final partuturan = person.partuturan;
    final showPartuturan = partuturan != null && !partuturan.modeNetral;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: <Widget>[
                AppAvatar(
                  name: person.displayName,
                  seed: person.avatarSeed,
                  size: 48,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        person.displayName,
                        style: typo.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs + 1),
                      if (showPartuturan)
                        PartuturanBadge(
                          result: partuturan,
                          onTap: () => context.push(
                            '${AppPages.tar05.routePath}?userId=${person.id}',
                          ),
                        )
                      else
                        Text(
                          person.isSameMarga
                              ? '${person.marga} · ${AppStrings.termSemarga}'
                              : person.marga,
                          style: typo.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ] else ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: AppSizes.iconMd,
                    color: colors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu Komunitas pada Jelajah dan Pencarian Sekitar (`SEK-01`, `SEK-05`, `SEK-R9`).
class CommunityCard extends StatelessWidget {
  const CommunityCard({
    required this.community,
    required this.onTap,
    super.key,
  });

  final Community community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    final accessLabel = switch (community.accessType) {
      CommunityAccessType.open => AppStrings.sek05AccessOpen,
      CommunityAccessType.approvalRequired => AppStrings.sek05AccessApproval,
      CommunityAccessType.closed => AppStrings.sek05AccessClosed,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppAvatar(
                  name: community.name,
                  seed: community.avatarSeed,
                  size: 56,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        community.name,
                        style: typo.bodyStrong,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${community.type.label} · ${community.city} · ${AppStrings.sek05MemberCount(community.memberCount)}',
                        style: typo.caption,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.chipInactive,
                              borderRadius: AppRadius.pillRadius,
                            ),
                            child: Text(accessLabel, style: typo.micro),
                          ),
                          // SEK-R9: Punguan marga berlencana Belum diverifikasi sampai SIS-06 disetujui
                          if (community.type == CommunityType.punguanMarga ||
                              community.isVerified)
                            VerifiedBadge(
                              isVerified: community.isVerified,
                              showLabel: community.isVerified,
                              showUnverifiedLabel:
                                  community.type == CommunityType.punguanMarga,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pemilih kota / area manual tanpa GPS (`SEK-01`, `SEK-02`, `SEK-R1`).
Future<String?> showManualAreaPickerSheet({
  required BuildContext context,
  required List<WilayahCity> cities,
  required String selectedCity,
}) {
  return AppBottomSheet.show<String>(
    context,
    title: AppStrings.sek01AreaPickerTitle,
    child: _AreaPickerSheetBody(cities: cities, selectedCity: selectedCity),
  );
}

class _AreaPickerSheetBody extends StatefulWidget {
  const _AreaPickerSheetBody({
    required this.cities,
    required this.selectedCity,
  });

  final List<WilayahCity> cities;
  final String selectedCity;

  @override
  State<_AreaPickerSheetBody> createState() => _AreaPickerSheetBodyState();
}

class _AreaPickerSheetBodyState extends State<_AreaPickerSheetBody> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final colors = context.colors;
    final filtered = widget.cities
        .where(
          (c) =>
              _query.isEmpty ||
              c.name.toLowerCase().contains(_query.toLowerCase()) ||
              c.province.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);

    return SizedBox(
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(AppStrings.sek01AreaPickerSubtitle, style: typo.caption),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _searchCtrl,
            hintText: AppStrings.sek03CityLabel,
            leadingIcon: Icons.location_city_outlined,
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final city = filtered[index];
                final isSelected =
                    city.name.toLowerCase() ==
                    widget.selectedCity.toLowerCase();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(city.name, style: typo.body),
                  subtitle: Text(city.province, style: typo.caption),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: colors.accent)
                      : null,
                  onTap: () => Navigator.of(context).pop(city.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
