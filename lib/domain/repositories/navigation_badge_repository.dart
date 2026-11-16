/// Ringkasan lencana belum dibaca untuk bilah atas (Pesan & Notifikasi — PRD 4.2).
typedef UnreadCounts = ({int unreadMessages, int unreadNotifications});

/// Antarmuka abstrak repository ringkasan lencana navigasi (Tahap 3).
///
/// UI hanya berbicara ke antarmuka ini lewat provider Riverpod, tidak pernah
/// mengimpor implementasi `data/mock` atau `data/supabase` secara langsung.
abstract interface class NavigationBadgeRepository {
  UnreadCounts currentUnreadCounts();
}
