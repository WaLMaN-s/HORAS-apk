import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:material_ui/material_ui.dart';

/// AKN-10 Pengaturan Notifikasi per Jenis & Jam Tenang 22.00-06.00 (`AKN-R5`, PRD 9).
class Akn10NotificationPrefsPage extends ConsumerStatefulWidget {
  const Akn10NotificationPrefsPage({super.key});

  @override
  ConsumerState<Akn10NotificationPrefsPage> createState() =>
      _Akn10NotificationPrefsPageState();
}

class _Akn10NotificationPrefsPageState
    extends ConsumerState<Akn10NotificationPrefsPage> {
  NotificationPreferences _prefs = const NotificationPreferences();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final res = await ref
        .read(notificationRepositoryProvider)
        .getNotificationPreferences();
    if (!mounted) return;
    setState(() {
      if (res is Ok<NotificationPreferences>) _prefs = res.value;
      _isLoading = false;
    });
  }

  Future<void> _save(NotificationPreferences next) async {
    setState(() => _prefs = next);
    final res = await ref
        .read(notificationRepositoryProvider)
        .updateNotificationPreferences(next);
    if (!mounted) return;
    if (res is Ok<NotificationPreferences>) {
      setState(() => _prefs = res.value);
      AppToast.show(
        context,
        message: AppStrings.akn10SavedToast,
        variant: AppToastVariant.success,
      );
    }
  }

  String _labelForType(NotificationType t) {
    return switch (t) {
      NotificationType.connectionRequestReceived => 'Permintaan Kenalan masuk',
      NotificationType.connectionAccepted => 'Kenalan diterima',
      NotificationType.newMessage => 'Pesan baru',
      NotificationType.messageRequestReceived => 'Permintaan pesan',
      NotificationType.postLikedOrCommented => 'Suka dan komentar',
      NotificationType.newFollower => 'Pengikut baru / permintaan ikuti',
      NotificationType.communityJoinRequest => 'Permintaan gabung komunitas',
      NotificationType.communityJoinApproved => 'Persetujuan gabung komunitas',
      NotificationType.communityAnnouncement => 'Pengumuman komunitas',
      NotificationType.eventReminder => 'Pengingat kegiatan',
      NotificationType.sessionJoinOrWaitlistPromoted =>
        'Gabung sesi / daftar tunggu naik',
      NotificationType.sessionUpdatedOrCancelled =>
        'Sesi diubah atau dibatalkan',
      NotificationType.sessionReminder => 'Pengingat sesi (H-1, 2 jam)',
      NotificationType.partuturanClaimReceived => 'Klaim Kami kerabat masuk',
      NotificationType.reportOutcome => 'Hasil laporan',
      NotificationType.moderationAction => 'Tindakan moderasi (Terkunci)',
      NotificationType.accountSecurity => 'Keamanan akun (Terkunci)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;
    final types = NotificationType.values
        .where((t) => t != NotificationType.eventReminder || flags.events)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.akn10Title)),
      body: SafeArea(
        child: _isLoading
            ? const SingleChildScrollView(
                child: StateView.loading(itemCount: 3),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.confidenceAmberSurface,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Text(
                      AppStrings.akn10LockedSecurityNote,
                      style: typo.caption.copyWith(color: colors.text),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.akn10QuietHoursTitle),
                    subtitle: const Text(AppStrings.akn10QuietHoursDesc),
                    value: _prefs.quietHoursEnabled,
                    onChanged: (v) =>
                        _save(_prefs.copyWith(quietHoursEnabled: v)),
                  ),
                  Divider(color: colors.border),
                  ...types.map((t) {
                    final locked = !t.canDisable;
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: <Widget>[
                          if (locked) ...<Widget>[
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Expanded(child: Text(_labelForType(t))),
                        ],
                      ),
                      value: _prefs.isEnabled(t),
                      onChanged: locked
                          ? null
                          : (v) => _save(_prefs.setTypeEnabled(t, v)),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
