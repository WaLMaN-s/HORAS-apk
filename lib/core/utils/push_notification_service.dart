import 'dart:async';

import 'package:clock/clock.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:horas/core/router/app_pages.dart';
import 'package:horas/core/router/app_router.dart';
import 'package:horas/domain/models/system_models.dart';
import 'package:horas/domain/policies/app_limits.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> horasFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on Object {
    // Abaikan bila Firebase belum dikonfigurasi pada build lokal.
  }
}

/// Layanan Push Notification FCM (`firebase_core` + `firebase_messaging`) dengan
/// graceful fallback ketika `google-services.json` / `GoogleService-Info.plist`
/// belum tersedia, penghormatan jam tenang (22.00-06.00 WIB), serta deep link PRD 9.
final class PushNotificationService {
  PushNotificationService({FlutterLocalNotificationsPlugin? localPlugin})
    : _localPlugin = localPlugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _localPlugin;
  bool _isConfigured = false;
  bool get isConfigured => _isConfigured;

  Future<void> initialize({
    required void Function(String routePath) onDeepLinkTap,
    SupabaseClient? supabaseClient,
  }) async {
    try {
      await Firebase.initializeApp();
      _isConfigured = true;
    } on Object catch (e) {
      // Graceful fallback: aplikasi tetap berjalan penuh tanpa push bila belum ada google-services.json
      _isConfigured = false;
      if (kDebugMode) {
        debugPrint('HORAS Push skipped (Firebase belum dikonfigurasi): $e');
      }
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(horasFirebaseBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      await _localPlugin.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
        ),
        onDidReceiveNotificationResponse: (details) {
          final payload = details.payload;
          if (payload != null && payload.isNotEmpty) {
            onDeepLinkTap(normalizeHorasDeepLink(Uri.parse(payload)));
          }
        },
      );

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty && supabaseClient != null) {
        await _syncFcmToken(supabaseClient, token);
      }
      messaging.onTokenRefresh.listen((newToken) {
        if (supabaseClient != null) {
          unawaited(_syncFcmToken(supabaseClient, newToken));
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        onDeepLinkTap(resolveDeepLinkFromData(initialMessage.data));
      }

      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        onDeepLinkTap(resolveDeepLinkFromData(msg.data));
      });

      FirebaseMessaging.onMessage.listen((msg) {
        unawaited(_handleForegroundMessage(msg));
      });
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('HORAS Push listener setup skipped: $e');
      }
    }
  }

  Future<void> _syncFcmToken(SupabaseClient client, String token) async {
    if (client.auth.currentUser == null) return;
    try {
      await client.rpc<Object?>(
        'register_fcm_token',
        params: <String, Object?>{'p_token': token},
      );
    } on Object {
      // Abaikan kegagalan sinkronisasi token saat offline.
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage msg) async {
    final typeRaw = (msg.data['type'] ?? '').toString();
    final isUrgent =
        typeRaw == NotificationType.accountSecurity.name ||
        typeRaw == NotificationType.moderationAction.name ||
        typeRaw == NotificationType.sessionUpdatedOrCancelled.name ||
        typeRaw == 'sistem_keamanan';

    // Hormati jam tenang 22.00-06.00 (PRD 9) untuk notifikasi non-darurat
    final nowHour = clock.now().hour;
    final isQuietHour =
        nowHour >= AppLimits.quietHoursStartHour ||
        nowHour < AppLimits.quietHoursEndHour;
    if (isQuietHour && !isUrgent) return;

    final title =
        msg.notification?.title ?? (msg.data['title']?.toString() ?? 'HORAS');
    final body = msg.notification?.body ?? (msg.data['body']?.toString() ?? '');
    final deepLink = resolveDeepLinkFromData(msg.data);

    try {
      await _localPlugin.show(
        id: msg.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'horas_push_general',
            'Notifikasi HORAS',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: deepLink,
      );
    } on Object {
      // Abaikan bila platform tanpa dukungan plugin lokal.
    }
  }

  /// Pemetaan payload notifikasi ke rute internal aplikasi sesuai Tabel PRD 9.
  static String resolveDeepLinkFromData(Map<String, dynamic> data) {
    final rawLink = (data['deepLink'] ?? data['action_route'] ?? '')
        .toString()
        .trim();
    if (rawLink.isNotEmpty) {
      final parsed = Uri.parse(rawLink);
      final normalized = normalizeHorasDeepLink(parsed);
      return parsed.hasQuery ? '$normalized?${parsed.query}' : normalized;
    }
    final type = (data['type'] ?? '').toString();
    final targetId = (data['targetId'] ?? '').toString();
    return switch (type) {
      'newMessage' =>
        targetId.isNotEmpty
            ? '${AppPages.psn03.routePath}?id=$targetId'
            : AppPages.psn01.routePath,
      'messageRequestReceived' => AppPages.psn02.routePath,
      'connectionRequestReceived' ||
      'connectionAccepted' => AppPages.akn12.routePath,
      'communityJoinRequest' ||
      'communityJoinApproved' ||
      'communityAnnouncement' =>
        targetId.isNotEmpty
            ? '${AppPages.sek06.routePath}?id=$targetId'
            : AppPages.sekitarPath,
      'sessionJoinOrWaitlistPromoted' ||
      'sessionUpdatedOrCancelled' ||
      'sessionReminder' =>
        targetId.isNotEmpty
            ? '${AppPages.man02.routePath}?id=$targetId'
            : AppPages.mainPath,
      'postLikedOrCommented' =>
        targetId.isNotEmpty
            ? '${AppPages.ber06.routePath}?id=$targetId'
            : AppPages.berandaPath,
      'partuturanClaimReceived' => AppPages.tar07.routePath,
      'moderationAction' || 'reportOutcome' => AppPages.sis05.routePath,
      _ => AppPages.sis01.routePath,
    };
  }
}
