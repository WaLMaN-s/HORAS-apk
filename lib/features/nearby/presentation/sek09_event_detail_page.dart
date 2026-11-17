import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:horas/core/config/feature_flags.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/theme/app_theme.dart';
import 'package:horas/core/theme/app_tokens.dart';
import 'package:horas/core/widgets/widgets.dart';
import 'package:horas/domain/models/models.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// SEK-09 Detail Kegiatan + RSVP (SEK-R12).
///
/// - Detail waktu, lokasi (teks + tautan peta), kapasitas opsional, RSVP (Hadir/Mungkin/Tidak).
/// - Formulir Buat kegiatan untuk Pengurus (tidak bisa tanggal lampau).
/// - Pengingat H-1, pembatalan menotifikasi yang RSVP.
/// - Memiliki status memuat, kosong, offline, error.
class Sek09EventDetailPage extends ConsumerStatefulWidget {
  const Sek09EventDetailPage({
    super.key,
    this.eventId = '',
    this.communityId = '',
    this.openCreateForm = false,
  });

  final String eventId;
  final String communityId;
  final bool openCreateForm;

  @override
  ConsumerState<Sek09EventDetailPage> createState() =>
      _Sek09EventDetailPageState();
}

class _Sek09EventDetailPageState extends ConsumerState<Sek09EventDetailPage> {
  bool _isLoading = true;
  AppError? _error;
  CommunityEvent? _event;
  List<EventAttendee> _attendees = const <EventAttendee>[];
  bool _isManager = false;
  bool _isRsvping = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await _load();
      if (widget.openCreateForm && mounted) {
        _showCreateEventSheet();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final eventRepo = ref.read(eventRepositoryProvider);
    final commRepo = ref.read(communityRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final uid = authRepo.currentUserId;

    if (widget.eventId.isNotEmpty) {
      final res = await eventRepo.getEventById(widget.eventId);
      if (!mounted) return;
      if (res is Err<CommunityEvent>) {
        setState(() {
          _isLoading = false;
          _error = res.failure;
        });
        return;
      }
      final evt = (res as Ok<CommunityEvent>).value;
      final attRes = await eventRepo.getEventAttendees(evt.id);
      final attendeesList = attRes is Ok<List<EventAttendee>>
          ? attRes.value
          : const <EventAttendee>[];

      // Cek apakah pengguna pengurus komunitas ini
      final commRes = await commRepo.getCommunityById(evt.communityId);
      bool isMgr = false;
      if (commRes is Ok<Community>) {
        final c = commRes.value;
        isMgr = (c.ownerId == uid) || c.managerIds.contains(uid);
      }

      setState(() {
        _event = evt;
        _attendees = attendeesList;
        _isManager = isMgr;
        _isLoading = false;
      });
    } else if (widget.communityId.isNotEmpty) {
      final listRes = await eventRepo.getEvents(widget.communityId);
      if (!mounted) return;
      if (listRes is Err<List<CommunityEvent>>) {
        setState(() {
          _isLoading = false;
          _error = listRes.failure;
        });
        return;
      }
      final events = (listRes as Ok<List<CommunityEvent>>).value;
      if (events.isNotEmpty) {
        final firstEvt = events.first;
        final attRes = await eventRepo.getEventAttendees(firstEvt.id);
        final commRes = await commRepo.getCommunityById(widget.communityId);
        bool isMgr = false;
        if (commRes is Ok<Community>) {
          final c = commRes.value;
          isMgr = (c.ownerId == uid) || c.managerIds.contains(uid);
        }
        setState(() {
          _event = firstEvt;
          _attendees = attRes is Ok<List<EventAttendee>>
              ? attRes.value
              : const <EventAttendee>[];
          _isManager = isMgr;
          _isLoading = false;
        });
      } else {
        setState(() {
          _event = null;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _error = const UnavailableError(
          message: AppStrings.stateContentUnavailableMessage,
        );
      });
    }
  }

  Future<void> _handleRsvp(EventRsvpStatus status) async {
    if (_event == null || _isRsvping) return;
    setState(() => _isRsvping = true);

    final eventRepo = ref.read(eventRepositoryProvider);
    final res = await eventRepo.rsvpEvent(eventId: _event!.id, status: status);

    if (!mounted) return;
    setState(() => _isRsvping = false);

    if (res is Ok<CommunityEvent>) {
      setState(() {
        _event = res.value;
      });
      final attRes = await eventRepo.getEventAttendees(_event!.id);
      if (mounted && attRes is Ok<List<EventAttendee>>) {
        setState(() {
          _attendees = attRes.value;
        });
      }
    } else if (res is Err<CommunityEvent>) {
      AppToast.show(
        context,
        message: res.failure.message,
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> _cancelEvent() async {
    if (_event == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.sek09CancelConfirmTitle),
        content: const Text(AppStrings.sek09CancelConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
            onPressed: () => ctx.pop(true),
            child: const Text(AppStrings.sek09CancelEventBtn),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final res = await ref.read(eventRepositoryProvider).cancelEvent(_event!.id);
    if (!mounted) return;

    if (res is Ok<CommunityEvent>) {
      setState(() {
        _event = res.value;
      });
      AppToast.show(
        context,
        message:
            'Kegiatan telah dibatalkan. Notifikasi dikirim ke seluruh peserta.',
        variant: AppToastVariant.success,
      );
    }
  }

  void _showCreateEventSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final mapCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final now = ref.read(authRepositoryProvider).currentTime;
    final startTime = now.add(const Duration(days: 2, hours: 2));
    final endTime = now.add(const Duration(days: 2, hours: 5));
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom:
                      MediaQuery.of(sheetContext).viewInsets.bottom +
                      AppSpacing.lg,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppStrings.sek09CreateEventTitle,
                        style: sheetContext.typo.h3,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: titleCtrl,
                        label: 'Nama Kegiatan',
                        hintText:
                            'Misal: Bona Taon, Latihan Koor, Pertemuan Adat',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: locCtrl,
                        label: 'Lokasi Kegiatan',
                        hintText: 'Nama gedung / sopo / alamat lengkap',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: mapCtrl,
                        label: 'Tautan Peta (Opsional)',
                        hintText: 'https://maps.google.com/?q=...',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: capCtrl,
                        label: AppStrings.sek09CapacityLabel,
                        hintText: 'Kosongkan jika tanpa batas kuota',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: descCtrl,
                        label: 'Deskripsi / Jadwal Acara',
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Pengingat H-1 Notice
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: sheetContext.colors.chipInactive,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.notifications_active_outlined,
                              color: sheetContext.colors.primary,
                              size: AppSizes.iconSm,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                AppStrings.sek09ReminderNotice,
                                style: sheetContext.typo.micro,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Simpan & Publikasikan Kegiatan',
                        variant: AppButtonVariant.primary,
                        isExpanded: true,
                        isLoading: isSubmitting,
                        onPressed: () async {
                          final cleanTitle = titleCtrl.text.trim();
                          final cleanLoc = locCtrl.text.trim();
                          if (cleanTitle.isEmpty || cleanLoc.isEmpty) {
                            AppToast.show(
                              sheetContext,
                              message: 'Nama dan lokasi kegiatan wajib diisi.',
                              variant: AppToastVariant.error,
                            );
                            return;
                          }

                          // SEK-R12: Validasi waktu mulai tidak bisa tanggal lampau
                          if (startTime.isBefore(now)) {
                            AppToast.show(
                              sheetContext,
                              message: AppStrings.sek09PastDateError,
                              variant: AppToastVariant.error,
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          final capVal = int.tryParse(capCtrl.text.trim());
                          final targetCommId =
                              _event?.communityId ?? widget.communityId;

                          final res = await ref
                              .read(eventRepositoryProvider)
                              .createEvent(
                                communityId: targetCommId,
                                title: cleanTitle,
                                description: descCtrl.text.trim(),
                                startTime: startTime,
                                endTime: endTime,
                                locationName: cleanLoc,
                                mapLink: mapCtrl.text.trim().isNotEmpty
                                    ? mapCtrl.text.trim()
                                    : null,
                                capacity: capVal,
                              );

                          if (!sheetContext.mounted) return;
                          setModalState(() => isSubmitting = false);

                          if (res is Ok<CommunityEvent>) {
                            sheetContext.pop();
                            if (mounted) {
                              AppToast.show(
                                context,
                                message: 'Kegiatan berhasil dibuat!',
                                variant: AppToastVariant.success,
                              );
                              await _load();
                            }
                          } else if (res is Err<CommunityEvent>) {
                            AppToast.show(
                              sheetContext,
                              message: res.failure.message,
                              variant: AppToastVariant.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final colors = context.colors;
    final typo = context.typo;

    if (!flags.events) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sek09Title)),
        body: StateView.contentUnavailable(
          onBack: () => context.go(AppPages.sekitarPath),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sek09Title)),
        body: const SingleChildScrollView(
          child: StateView.loading(itemCount: 3),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sek09Title)),
        body: StateView.fromError(_error!, onRetry: _load),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.sek09Title)),
        body: StateView.empty(
          message: AppStrings.sek09EmptyEvents,
          actionLabel: _isManager ? 'Buat Kegiatan' : AppStrings.semanticsBack,
          onAction: () {
            if (_isManager) {
              _showCreateEventSheet();
            } else {
              context.pop();
            }
          },
        ),
      );
    }

    final event = _event!;
    final dateFmt = DateFormat('EEEE, d MMMM yyyy · HH:mm', 'id');
    final timeRange =
        '${dateFmt.format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)} WIB';

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sek09Title),
        actions: <Widget>[
          if (_isManager && !event.isCancelled)
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: colors.danger),
              tooltip: AppStrings.sek09CancelEventBtn,
              onPressed: _cancelEvent,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            if (event.isCancelled)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: colors.danger),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, color: colors.danger),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Kegiatan ini telah dibatalkan oleh pengurus.',
                        style: typo.captionStrong.copyWith(
                          color: colors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Judul & Nama Komunitas
            Text(event.title, style: typo.h2),
            if (event.communityName.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                event.communityName,
                style: typo.caption.copyWith(color: colors.primary),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Informasi Waktu & Lokasi
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.chipInactive,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.calendar_today_outlined,
                        color: colors.primary,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(timeRange, style: typo.bodyStrong)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.location_on_outlined,
                        color: colors.primary,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(event.locationName, style: typo.body),
                      ),
                    ],
                  ),
                  if (event.capacity != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.people_alt_outlined,
                          color: colors.primary,
                          size: AppSizes.iconMd,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Kapasitas: ${event.capacity} peserta (${event.attendeeCount} terisi)',
                            style: typo.caption,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Deskripsi
            if (event.description.isNotEmpty) ...<Widget>[
              Text('Tentang Kegiatan', style: typo.bodyStrong),
              const SizedBox(height: AppSpacing.sm),
              Text(event.description, style: typo.body),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Bagian RSVP (Hadir / Mungkin / Tidak)
            if (!event.isCancelled) ...<Widget>[
              Text('Konfirmasi Kehadiran Anda', style: typo.bodyStrong),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: event.myRsvp == EventRsvpStatus.hadir
                            ? colors.success
                            : null,
                        foregroundColor: event.myRsvp == EventRsvpStatus.hadir
                            ? Colors.white
                            : colors.text,
                        side: BorderSide(
                          color: event.myRsvp == EventRsvpStatus.hadir
                              ? colors.success
                              : colors.border,
                        ),
                        minimumSize: const Size.fromHeight(
                          AppSizes.minTouchTarget,
                        ),
                      ),
                      onPressed: () => _handleRsvp(EventRsvpStatus.hadir),
                      child: const Text(AppStrings.sek09RsvpHadir),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: event.myRsvp == EventRsvpStatus.mungkin
                            ? colors.confidenceAmber
                            : null,
                        foregroundColor: event.myRsvp == EventRsvpStatus.mungkin
                            ? Colors.white
                            : colors.text,
                        side: BorderSide(
                          color: event.myRsvp == EventRsvpStatus.mungkin
                              ? colors.confidenceAmber
                              : colors.border,
                        ),
                        minimumSize: const Size.fromHeight(
                          AppSizes.minTouchTarget,
                        ),
                      ),
                      onPressed: () => _handleRsvp(EventRsvpStatus.mungkin),
                      child: const Text(AppStrings.sek09RsvpMungkin),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: event.myRsvp == EventRsvpStatus.tidak
                            ? colors.danger
                            : null,
                        foregroundColor: event.myRsvp == EventRsvpStatus.tidak
                            ? Colors.white
                            : colors.text,
                        side: BorderSide(
                          color: event.myRsvp == EventRsvpStatus.tidak
                              ? colors.danger
                              : colors.border,
                        ),
                        minimumSize: const Size.fromHeight(
                          AppSizes.minTouchTarget,
                        ),
                      ),
                      onPressed: () => _handleRsvp(EventRsvpStatus.tidak),
                      child: const Text(AppStrings.sek09RsvpTidak),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Daftar Peserta Hadir (RSVP)
            Text(
              '${AppStrings.sek09AttendeesTitle} (${_attendees.length})',
              style: typo.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_attendees.isEmpty)
              Text(
                'Belum ada konfirmasi kehadiran.',
                style: typo.caption.copyWith(color: colors.textMuted),
              )
            else
              ...List<Widget>.generate(_attendees.length, (idx) {
                final att = _attendees[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      AppAvatar(
                        name: att.user.displayName,
                        seed: att.user.avatarSeed,
                        size: AppSizes.avatarSm,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${att.user.displayName} (${att.user.marga})',
                          style: typo.body,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: att.status == EventRsvpStatus.hadir
                              ? colors.success.withValues(alpha: 0.15)
                              : (att.status == EventRsvpStatus.mungkin
                                    ? colors.confidenceAmber.withValues(
                                        alpha: 0.15,
                                      )
                                    : colors.danger.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          att.status.name.toUpperCase(),
                          style: typo.micro.copyWith(
                            color: att.status == EventRsvpStatus.hadir
                                ? colors.success
                                : (att.status == EventRsvpStatus.mungkin
                                      ? colors.confidenceAmber
                                      : colors.danger),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
