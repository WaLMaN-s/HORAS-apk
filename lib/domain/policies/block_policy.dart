import 'package:horas/domain/models/user_models.dart';

/// Kebijakan pemblokiran terpusat untuk seluruh repository HORAS (`AKN-R6`, `AC-11`).
///
/// Menjamin efek blokir dua arah secara konsisten di profil, postingan,
/// komentar, pencarian, Sekitar, chat pribadi, daftar suka, dan pesan grup.
abstract final class BlockPolicy {
  /// Memeriksa apakah ada pemblokiran dua arah antara [userAId] dan [userBId].
  static bool isBlockedBetween({
    required Iterable<Block> blocks,
    required String userAId,
    required String userBId,
  }) {
    for (final b in blocks) {
      if ((b.blockerId == userAId && b.blockedUser.id == userBId) ||
          (b.blockerId == userBId && b.blockedUser.id == userAId)) {
        return true;
      }
    }
    return false;
  }

  /// Memeriksa apakah [blockerId] secara spesifik memblokir [targetId]
  /// (dipakai antara lain untuk menyembunyikan pesan di grup bersama — `AKN-R6`).
  static bool hasUserBlocked({
    required Iterable<Block> blocks,
    required String blockerId,
    required String targetId,
  }) {
    for (final b in blocks) {
      if (b.blockerId == blockerId && b.blockedUser.id == targetId) {
        return true;
      }
    }
    return false;
  }

  /// Menyaring daftar entitas agar item milik pihak yang saling memblokir
  /// dengan [viewerId] tidak pernah muncul (`AKN-R6`, `AC-11`).
  static List<T> filterBlockedUsers<T>({
    required Iterable<T> items,
    required String? viewerId,
    required String Function(T item) ownerIdOf,
    required Iterable<Block> blocks,
  }) {
    if (viewerId == null) {
      return List<T>.unmodifiable(items);
    }
    return items
        .where(
          (item) => !isBlockedBetween(
            blocks: blocks,
            userAId: viewerId,
            userBId: ownerIdOf(item),
          ),
        )
        .toList(growable: false);
  }
}
