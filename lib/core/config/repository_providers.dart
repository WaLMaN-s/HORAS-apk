import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/utils/session_reminder_service.dart';
import 'package:horas/core/utils/shared_prefs_provider.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/domain/repositories/repositories.dart';

/// Sakelar latensi jaringan tiruan (300–800 ms di aplikasi; dapat di-override `false` di tes).
final enableMockNetworkLatencyProvider = Provider<bool>((ref) => true);

/// Penyimpanan in-memory pusat untuk backend tiruan.
final mockStoreProvider = Provider<MockStore>((ref) {
  final config = ref.watch(appConfigProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final enableLatency = ref.watch(enableMockNetworkLatencyProvider);
  final store = MockStore(
    appConfig: config,
    prefs: prefs,
    enableNetworkLatency: enableLatency,
  );
  ref.onDispose(store.dispose);
  return store;
});

/// 1. Provider [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository(ref.watch(mockStoreProvider));
});

/// 2. Provider [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return MockProfileRepository(ref.watch(mockStoreProvider));
});

/// 3. Provider [PrivacyRepository].
final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  return MockPrivacyRepository(ref.watch(mockStoreProvider));
});

/// 4. Provider [FollowRepository].
final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return MockFollowRepository(ref.watch(mockStoreProvider));
});

/// 5. Provider [ConnectionRepository].
final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return MockConnectionRepository(ref.watch(mockStoreProvider));
});

/// 6. Provider [BlockRepository].
final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return MockBlockRepository(ref.watch(mockStoreProvider));
});

/// 7. Provider [PostRepository].
final postRepositoryProvider = Provider<PostRepository>((ref) {
  return MockPostRepository(ref.watch(mockStoreProvider));
});

/// 8. Provider [CommentRepository].
final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return MockCommentRepository(ref.watch(mockStoreProvider));
});

/// 9. Provider [SearchRepository].
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return MockSearchRepository(ref.watch(mockStoreProvider));
});

/// 10. Provider [NearbyRepository].
final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  return MockNearbyRepository(ref.watch(mockStoreProvider));
});

/// 11. Provider [CommunityRepository].
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return MockCommunityRepository(
    ref.watch(mockStoreProvider),
    ref.watch(chatRepositoryProvider),
  );
});

/// Layanan pengingat lokal sesi Main (`MAN-R11`).
final sessionReminderServiceProvider = Provider<SessionReminderService>((ref) {
  return LocalSessionReminderService();
});

/// 12. Provider [SessionRepository].
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return MockSessionRepository(
    ref.watch(mockStoreProvider),
    ref.watch(chatRepositoryProvider),
  );
});

/// 13. Provider [CourtRepository].
final courtRepositoryProvider = Provider<CourtRepository>((ref) {
  return MockCourtRepository(ref.watch(mockStoreProvider));
});

/// 14. Provider [ChatRepository].
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return MockChatRepository(ref.watch(mockStoreProvider));
});

/// 15. Provider [NotificationRepository].
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return MockNotificationRepository(ref.watch(mockStoreProvider));
});

/// 16. Provider [ReportRepository].
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return MockReportRepository(ref.watch(mockStoreProvider));
});

/// 17. Provider [VerificationRepository].
final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return MockVerificationRepository(ref.watch(mockStoreProvider));
});

/// 18. Provider [TaromboRepository].
final taromboRepositoryProvider = Provider<TaromboRepository>((ref) {
  return MockTaromboRepository(ref.watch(mockStoreProvider));
});

/// 19. Provider [PartuturanRepository].
final partuturanRepositoryProvider = Provider<PartuturanRepository>((ref) {
  return MockPartuturanRepository(ref.watch(mockStoreProvider));
});

/// 20. Provider [SupportRepository].
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return MockSupportRepository(ref.watch(mockStoreProvider));
});

/// 21. Provider [AccountLifecycleRepository].
final accountLifecycleRepositoryProvider = Provider<AccountLifecycleRepository>(
  (ref) {
    return MockAccountLifecycleRepository(ref.watch(mockStoreProvider));
  },
);

/// 22. Provider [DebugSimulationRepository].
final debugSimulationRepositoryProvider = Provider<DebugSimulationRepository>((
  ref,
) {
  return MockDebugSimulationRepository(ref.watch(mockStoreProvider));
});

/// 23. Provider [NavigationBadgeRepository].
final navigationBadgeRepositoryProvider = Provider<NavigationBadgeRepository>((
  ref,
) {
  return StoreBackedNavigationBadgeRepository(ref.watch(mockStoreProvider));
});

/// Stream live jumlah lencana belum dibaca (Pesan & Notifikasi) untuk bilah atas.
final unreadCountsProvider = StreamProvider<UnreadCounts>((ref) {
  final badges = ref.watch(navigationBadgeRepositoryProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final notifRepo = ref.watch(notificationRepositoryProvider);
  final controller = StreamController<UnreadCounts>();

  controller.add(badges.currentUnreadCounts());
  final sub1 = chatRepo.watchConversations().listen((_) {
    if (!controller.isClosed) controller.add(badges.currentUnreadCounts());
  });
  final sub2 = notifRepo.watchNotifications().listen((_) {
    if (!controller.isClosed) controller.add(badges.currentUnreadCounts());
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });
  return controller.stream;
});
