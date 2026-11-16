import 'package:horas/domain/repositories/navigation_badge_repository.dart';

/// Implementasi Supabase untuk [NavigationBadgeRepository] (diisi penuh di Prompt 11).
final class SupabaseNavigationBadgeRepository
    implements NavigationBadgeRepository {
  const SupabaseNavigationBadgeRepository();

  @override
  UnreadCounts currentUnreadCounts() {
    return (unreadMessages: 0, unreadNotifications: 0);
  }
}
