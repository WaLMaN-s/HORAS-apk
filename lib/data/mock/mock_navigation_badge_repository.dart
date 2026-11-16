import 'package:horas/domain/repositories/navigation_badge_repository.dart';

/// Implementasi mock untuk [NavigationBadgeRepository] (diperluas di Prompt 2).
final class MockNavigationBadgeRepository implements NavigationBadgeRepository {
  const MockNavigationBadgeRepository();

  @override
  UnreadCounts currentUnreadCounts() {
    return (unreadMessages: 2, unreadNotifications: 3);
  }
}
