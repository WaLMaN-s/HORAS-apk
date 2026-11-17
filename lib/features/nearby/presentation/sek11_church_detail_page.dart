import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-11 Detail Gereja (SEK-R13).
///
/// - Denominasi (HKBP, GKPI, HKI, GKPS, GBKP, lainnya).
/// - Jadwal ibadah, kontak, kegiatan.
/// - Jumlah jemaat di HORAS hanya tampil bila minimal 5 orang (SEK-R13).
/// - Lencana Terverifikasi vs Belum diverifikasi.
/// - Gereja asal opsional dan bawaan tersembunyi (SEK-R13).
/// - Catatan privasi: admin gereja tidak dapat melihat data pribadi jemaat.
/// - Verifikasi gereja lewat SIS-06.
/// - Status: memuat, kosong/error, offline.
class Sek11ChurchDetailPage extends ConsumerStatefulWidget {
  const Sek11ChurchDetailPage({required this.churchId, super.key});

  final String churchId;

  @override
  ConsumerState<Sek11ChurchDetailPage> createState() =>
      _Sek11ChurchDetailPageState();
}

class _Sek11ChurchDetailPageState extends ConsumerState<Sek11ChurchDetailPage> {
  bool _isLoading = true;
  AppError? _error;
  Church? _church;
  List<CommunityEvent> _events = const <CommunityEvent>[];
  bool _isSettingHomeChurch = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final churchRepo = ref.read(churchRepositoryProvider);

    final churchRes = await churchRepo.getChurchById(widget.churchId);

    if (!mounted) return;
    if (churchRes is Err<Church>) {
      setState(() {
        _isLoading = false;
        _error = churchRes.failure;
      });
      return;
    }

    final eventsRes = await churchRepo.getChurchEvents(widget.churchId);

    if (!mounted) return;
    setState(() {
      _church = (churchRes as Ok<Church>).value;
      if (eventsRes is Ok<List<CommunityEvent>>) {
        _events = eventsRes.value;
      }
      _isLoading = false;
    });
  }

  Future<void> _onSetHomeChurch() async {
    final colors = context.colors;
    final typo = context.typo;

    bool showOnProfile = false; // Bawaan tersembunyi (SEK-R13)

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              title: Text(AppStrings.sek11SetHomeChurchBtn, style: typo.h3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pilih ${_church?.name ?? "gereja"} sebagai gereja asal Anda?',
                    style: typo.body,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.chipInactive,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Text(
                      AppStrings.sek11HomeChurchNotice,
                      style: typo.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Tampilkan di profil', style: typo.bodyStrong),
                    subtitle: Text(
                      'Izinkan kenalan melihat gereja asal Anda',
                      style: typo.micro.copyWith(color: colors.textMuted),
                    ),
                    value: showOnProfile,
                    onChanged: (val) {
                      setDialogState(() {
                        showOnProfile = val;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(AppStrings.actionCancel, style: typo.body),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(AppStrings.actionSave, style: typo.bodyStrong),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSettingHomeChurch = true);
    final churchRepo = ref.read(churchRepositoryProvider);
    final res = await churchRepo.setMyHomeChurch(
      widget.churchId,
      isVisible: showOnProfile,
    );

    if (!mounted) return;
    setState(() => _isSettingHomeChurch = false);

    if (res is Ok<Church>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gereja asal berhasil diperbarui.')),
      );
    } else if (res is Err<Church>) {
      final err = res.failure;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message), backgroundColor: colors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sek11Title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _church == null) {
      final isOffline = _error is OfflineError;
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sek11Title)),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  isOffline ? Icons.wifi_off_outlined : Icons.error_outline,
                  color: colors.danger,
                  size: AppSizes.iconLg,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error?.message ?? AppStrings.stateServerErrorTitle,
                  style: typo.bodyStrong,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: AppSizes.iconSm),
                  label: const Text(AppStrings.actionRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final church = _church!;

    return Scaffold(
      appBar: AppBar(
        title: Text(church.name),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.actionRetry,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            // Header card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.border.withValues(alpha: 0.6)),
                boxShadow: AppShadows.softCard(colors.shadow),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.church,
                          color: colors.primary,
                          size: AppSizes.iconLg,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(church.name, style: typo.h3),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.chipInactive,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                church.denomination.label,
                                style: typo.micro.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Verification status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: church.isVerified
                          ? Colors.blue.withValues(alpha: 0.1)
                          : colors.chipInactive,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          church.isVerified
                              ? Icons.verified
                              : Icons.info_outline,
                          size: AppSizes.iconSm,
                          color: church.isVerified
                              ? Colors.blue
                              : colors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          church.isVerified
                              ? AppStrings.sek10VerifiedBadge
                              : AppStrings.sek10UnverifiedBadge,
                          style: typo.caption.copyWith(
                            color: church.isVerified
                                ? Colors.blue
                                : colors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),

                  // Member count rule: only display if >= 5 (SEK-R13)
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.people_outline,
                        size: AppSizes.iconSm,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          church.memberCount >= 5
                              ? AppStrings.sek10MemberCountFormat(
                                  church.memberCount,
                                )
                              : AppStrings.sek10MemberCountHidden,
                          style: typo.caption.copyWith(
                            color: church.memberCount >= 5
                                ? colors.text
                                : colors.textMuted,
                            fontStyle: church.memberCount >= 5
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Set Home Church action button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                onPressed: _isSettingHomeChurch ? null : _onSetHomeChurch,
                icon: const Icon(Icons.home_outlined),
                label: _isSettingHomeChurch
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(AppStrings.sek11SetHomeChurchBtn),
              ),
            ),

            if (!church.isVerified) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    context.push(AppPages.sis06.routePath);
                  },
                  icon: const Icon(
                    Icons.verified_outlined,
                    size: AppSizes.iconSm,
                  ),
                  label: const Text(AppStrings.sek11VerifyChurchBtn),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Kontak & Lokasi
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(AppStrings.sek11Contacts, style: typo.bodyStrong),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.location_on_outlined,
                        size: AppSizes.iconSm,
                        color: colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${church.address}, ${church.city}',
                          style: typo.body,
                        ),
                      ),
                    ],
                  ),
                  if (church.contactPhone.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.phone_outlined,
                          size: AppSizes.iconSm,
                          color: colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(church.contactPhone, style: typo.body),
                      ],
                    ),
                  ],
                  if (church.contactEmail.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.email_outlined,
                          size: AppSizes.iconSm,
                          color: colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(church.contactEmail, style: typo.body),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Jadwal Ibadah
            Text(AppStrings.sek11ServiceSchedules, style: typo.h3),
            const SizedBox(height: AppSpacing.sm),
            if (church.serviceSchedules.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  'Belum ada jadwal ibadah terdaftar.',
                  style: typo.caption.copyWith(color: colors.textMuted),
                ),
              )
            else
              ...church.serviceSchedules.map(
                (ChurchServiceSchedule sched) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.chipInactive,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Icon(
                          Icons.schedule,
                          color: colors.primary,
                          size: AppSizes.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${sched.dayOfWeek} · ${sched.time}',
                              style: typo.bodyStrong,
                            ),
                            Text(
                              'Bahasa: ${sched.language}',
                              style: typo.caption.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.lg),

            // Kegiatan Gereja
            Text(AppStrings.sek11ChurchEventsTitle, style: typo.h3),
            const SizedBox(height: AppSpacing.sm),
            if (_events.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  AppStrings.sek09EmptyEvents,
                  style: typo.caption.copyWith(color: colors.textMuted),
                ),
              )
            else
              ..._events.map(
                (event) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(event.title, style: typo.bodyStrong),
                    subtitle: Text(
                      '${event.startTime.toLocal().toString().substring(0, 16)} · ${event.locationName}',
                      style: typo.caption,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push(
                        '${AppPages.sek09.routePath}?id=${event.id}',
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // Catatan privasi admin (SEK-R13)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.border.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.security,
                    size: AppSizes.iconSm,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.sek11AdminPrivacyNotice,
                      style: typo.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
