import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:horas/domain/models/play_models.dart';
import 'package:horas/domain/policies/horas_policies.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Antarmuka pengingat lokal sesi Main (`MAN-R11`).
abstract interface class SessionReminderService {
  Future<void> scheduleForSession({
    required PlaySession session,
    required DateTime now,
  });
  Future<void> cancelForSession(String sessionId);
}

/// Implementasi pengingat lokal menggunakan `flutter_local_notifications` +
/// `flutter_timezone` dengan penghormatan jam tenang 22.00-06.00 (`MAN-R11`).
///
/// Menangani kegagalan plugin/platform secara halus sehingga uji unit/widget
/// maupun perangkat tanpa saluran notifikasi tetap berjalan aman.
final class LocalSessionReminderService implements SessionReminderService {
  LocalSessionReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      tz_data.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone().timeout(
        const Duration(milliseconds: 500),
      );
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );
      await _plugin
          .initialize(settings: settings)
          .timeout(const Duration(milliseconds: 500));
      _initialized = true;
      return true;
    } on Object {
      // Pada widget test atau platform tanpa implementasi native, jangan gagalkan alur UI.
      return false;
    }
  }

  int _idFor(String sessionId, int slot) {
    return (sessionId.hashCode.abs() % 100000) * 10 + slot;
  }

  @override
  Future<void> scheduleForSession({
    required PlaySession session,
    required DateTime now,
  }) async {
    final ready = await _ensureInitialized();
    if (!ready) return;

    final schedule = HorasPolicies.computeSessionReminders(
      sessionStartTime: session.startTime,
      now: now,
    );

    const androidDetails = AndroidNotificationDetails(
      'horas_session_reminders',
      'Pengingat Sesi Main',
      channelDescription:
          'Pengingat H-1 pukul 19.00 dan 2 jam sebelum sesi main.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      if (schedule.reminderHMinus1 != null) {
        final h1 = schedule.reminderHMinus1!;
        await _plugin
            .zonedSchedule(
              id: _idFor(session.id, 1),
              title: 'Pengingat Main Besok: ${session.title}',
              body:
                  'Sesi main di ${session.visibleVenueText} besok. Siapkan perlengkapanmu!',
              scheduledDate: tz.TZDateTime.from(h1, tz.local),
              notificationDetails: details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: 'horas://app/main/sesi-detail?id=${session.id}',
            )
            .timeout(const Duration(milliseconds: 500));
      }
      if (schedule.reminder2HoursBefore != null) {
        final h2 = schedule.reminder2HoursBefore!;
        await _plugin
            .zonedSchedule(
              id: _idFor(session.id, 2),
              title: '2 Jam Lagi: ${session.title}',
              body:
                  'Sesi main di ${session.visibleVenueText} akan segera dimulai.',
              scheduledDate: tz.TZDateTime.from(h2, tz.local),
              notificationDetails: details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: 'horas://app/main/sesi-detail?id=${session.id}',
            )
            .timeout(const Duration(milliseconds: 500));
      }
    } on Object {
      // Abaikan bila izin jadwal alarm / plugin belum tersedia.
    }
  }

  @override
  Future<void> cancelForSession(String sessionId) async {
    try {
      await _plugin
          .cancel(id: _idFor(sessionId, 1))
          .timeout(const Duration(milliseconds: 500));
      await _plugin
          .cancel(id: _idFor(sessionId, 2))
          .timeout(const Duration(milliseconds: 500));
    } on Object {
      // Abaikan pada environment test.
    }
  }
}
