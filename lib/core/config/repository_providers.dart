import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/core/utils/session_reminder_service.dart';
import 'package:horas/core/utils/shared_prefs_provider.dart';
import 'package:horas/data/mock/mock_repositories.dart';
import 'package:horas/data/mock/mock_store.dart';
import 'package:horas/data/supabase/supabase_repositories.dart';
import 'package:horas/domain/repositories/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Penanda epoch sesi login/logout agar seluruh controller & halaman tab otomatis
/// menyegarkan data saat pengguna keluar atau berpindah akun tanpa perlu refresh manual.
class AuthSessionEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final authSessionEpochProvider =
    NotifierProvider<AuthSessionEpochNotifier, int>(
      AuthSessionEpochNotifier.new,
    );

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

/// Gerbang Supabase terpusat (dipakai saat `USE_MOCK_BACKEND=false`).
final supabaseGatewayProvider = Provider<SupabaseGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final gw = SupabaseGateway(
    client: Supabase.instance.client,
    prefs: prefs,
    appConfig: config,
  );
  ref.onDispose(gw.cache.dispose);
  return gw;
});

/// Penanda apakah data yang ditampilkan sedang berasal dari cache offline (AC-15).
final offlineCacheStatusProvider = Provider<ValueListenable<bool>>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockBackend) {
    return ValueNotifier<bool>(false);
  }
  return ref.watch(supabaseGatewayProvider).cache.isShowingCachedData;
});

/// 1. Provider [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseAuthRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockAuthRepository(ref.watch(mockStoreProvider));
});

/// 2. Provider [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseProfileRepository(
      ref.watch(supabaseGatewayProvider),
      ref.watch(authRepositoryProvider) as SupabaseAuthRepository,
    );
  }
  return MockProfileRepository(ref.watch(mockStoreProvider));
});

/// 3. Provider [PrivacyRepository].
final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabasePrivacyRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockPrivacyRepository(ref.watch(mockStoreProvider));
});

/// 4. Provider [FollowRepository].
final followRepositoryProvider = Provider<FollowRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseFollowRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockFollowRepository(ref.watch(mockStoreProvider));
});

/// 5. Provider [ConnectionRepository].
final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseConnectionRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockConnectionRepository(ref.watch(mockStoreProvider));
});

/// 6. Provider [BlockRepository].
final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    ref.watch(authSessionEpochProvider);
    return SupabaseBlockRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockBlockRepository(ref.watch(mockStoreProvider));
});

/// 7. Provider [PostRepository].
final postRepositoryProvider = Provider<PostRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabasePostRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockPostRepository(ref.watch(mockStoreProvider));
});

/// 8. Provider [CommentRepository].
final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseCommentRepository(
      ref.watch(supabaseGatewayProvider),
      ref.watch(postRepositoryProvider) as SupabasePostRepository,
    );
  }
  return MockCommentRepository(ref.watch(mockStoreProvider));
});

/// 9. Provider [SearchRepository].
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseSearchRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockSearchRepository(ref.watch(mockStoreProvider));
});

/// 10. Provider [NearbyRepository].
final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    ref.watch(authSessionEpochProvider);
    return SupabaseNearbyRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockNearbyRepository(ref.watch(mockStoreProvider));
});

/// 11. Provider [CommunityRepository].
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseCommunityRepository(ref.watch(supabaseGatewayProvider));
  }
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
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseSessionRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockSessionRepository(
    ref.watch(mockStoreProvider),
    ref.watch(chatRepositoryProvider),
  );
});

/// 13. Provider [CourtRepository].
final courtRepositoryProvider = Provider<CourtRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseCourtRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockCourtRepository(ref.watch(mockStoreProvider));
});

/// 14. Provider [ChatRepository].
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    ref.watch(authSessionEpochProvider);
    final repo = SupabaseChatRepository(ref.watch(supabaseGatewayProvider));
    ref.onDispose(repo.dispose);
    return repo;
  }
  return MockChatRepository(ref.watch(mockStoreProvider));
});

/// 15. Provider [NotificationRepository].
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    ref.watch(authSessionEpochProvider);
    final repo = SupabaseNotificationRepository(
      ref.watch(supabaseGatewayProvider),
    );
    ref.onDispose(repo.dispose);
    return repo;
  }
  return MockNotificationRepository(ref.watch(mockStoreProvider));
});

/// 16. Provider [ReportRepository].
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseReportRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockReportRepository(ref.watch(mockStoreProvider));
});

/// 17. Provider [VerificationRepository].
final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseVerificationRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockVerificationRepository(ref.watch(mockStoreProvider));
});

/// 18. Provider [TaromboRepository].
final taromboRepositoryProvider = Provider<TaromboRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    ref.watch(authSessionEpochProvider);
    return SupabaseTaromboRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockTaromboRepository(ref.watch(mockStoreProvider));
});

/// 19. Provider [PartuturanRepository].
final partuturanRepositoryProvider = Provider<PartuturanRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabasePartuturanRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockPartuturanRepository(ref.watch(mockStoreProvider));
});

/// 20. Provider [SupportRepository].
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseSupportRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockSupportRepository(ref.watch(mockStoreProvider));
});

/// 21. Provider [AccountLifecycleRepository].
final accountLifecycleRepositoryProvider = Provider<AccountLifecycleRepository>(
  (ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.useMockBackend) {
      return SupabaseAccountLifecycleRepository(
        ref.watch(supabaseGatewayProvider),
      );
    }
    return MockAccountLifecycleRepository(ref.watch(mockStoreProvider));
  },
);

/// 22. Provider [DebugSimulationRepository].
final debugSimulationRepositoryProvider = Provider<DebugSimulationRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseDebugSimulationRepository(
      ref.watch(supabaseGatewayProvider),
    );
  }
  return MockDebugSimulationRepository(ref.watch(mockStoreProvider));
});

/// 23. Provider [NavigationBadgeRepository].
final navigationBadgeRepositoryProvider = Provider<NavigationBadgeRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return LiveSupabaseNavigationBadgeRepository(
      ref.watch(supabaseGatewayProvider),
    );
  }
  return StoreBackedNavigationBadgeRepository(ref.watch(mockStoreProvider));
});

/// 24. Provider [StoryRepository] (BER-02, BER-03, BER-R12).
final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseStoryRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockStoryRepository(ref.watch(mockStoreProvider));
});

/// 25. Provider [EventRepository] (SEK-09, SEK-R12).
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseEventRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockEventRepository(ref.watch(mockStoreProvider));
});

/// 26. Provider [ChurchRepository] (SEK-10, SEK-11, SEK-R13).
final churchRepositoryProvider = Provider<ChurchRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useMockBackend) {
    return SupabaseChurchRepository(ref.watch(supabaseGatewayProvider));
  }
  return MockChurchRepository(ref.watch(mockStoreProvider));
});

/// 27. Provider [PartuturanDictionaryRepository] (TAR-08, TAR-R6).
final partuturanDictionaryRepositoryProvider =
    Provider<PartuturanDictionaryRepository>((ref) {
      final config = ref.watch(appConfigProvider);
      if (!config.useMockBackend) {
        return SupabasePartuturanDictionaryRepository(
          ref.watch(supabaseGatewayProvider),
        );
      }
      return MockPartuturanDictionaryRepository(ref.watch(mockStoreProvider));
    });

/// Stream live jumlah lencana belum dibaca (Pesan & Notifikasi) untuk bilah atas.
final unreadCountsProvider = StreamProvider<UnreadCounts>((ref) {
  ref.watch(authSessionEpochProvider);
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
