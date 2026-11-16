import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/app_config.dart';
import 'package:horas/data/mock/mock_navigation_badge_repository.dart';
import 'package:horas/data/supabase/supabase_navigation_badge_repository.dart';
import 'package:horas/domain/repositories/navigation_badge_repository.dart';

/// Provider antarmuka [NavigationBadgeRepository] yang memilih implementasi
/// berdasarkan [AppConfig.useMockBackend].
final navigationBadgeRepositoryProvider = Provider<NavigationBadgeRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockBackend) {
    return const MockNavigationBadgeRepository();
  }
  return const SupabaseNavigationBadgeRepository();
});
