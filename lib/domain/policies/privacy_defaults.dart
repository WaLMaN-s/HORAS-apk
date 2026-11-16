/// Pilihan visibilitas bidang profil dan privasi bawaan sesuai PRD 7.1.
enum FieldVisibility {
  everyone,
  connectedOnly,
  onlyMe,
}

/// Pilihan siapa yang dapat mengirim permintaan Kenalan (PRD 7.1).
enum ConnectionRequestAllowance {
  everyone,
  sameCommunity,
  noOne,
}

/// Tipe visibilitas akun (PRD 7.1).
enum AccountVisibilityType {
  publicAccount,
  privateAccount,
}

/// Pengaturan privasi bawaan yang ketat dan aman bagi pengguna baru (PRD 1.2, 7.1).
final class PrivacySettingsPolicy {
  const PrivacySettingsPolicy({
    this.motherMarga = FieldVisibility.connectedOnly,
    this.showAgeGroup = false,
    this.subdistrict = FieldVisibility.connectedOnly,
    this.joinedCommunities = FieldVisibility.connectedOnly,
    this.homeChurch = FieldVisibility.onlyMe,
    this.tarombo = FieldVisibility.onlyMe,
    this.discoverableInNearbyAndSearch = true,
    this.whoCanSendConnectionRequest = ConnectionRequestAllowance.everyone,
    this.allowMessagesFromSharedContext = true,
    this.sendReadReceipts = true,
    this.accountType = AccountVisibilityType.publicAccount,
  });

  /// Bawaan: Terhubung (PRD 7.1).
  final FieldVisibility motherMarga;

  /// Bawaan: Tersembunyi (`false`); tidak pernah menampilkan usia pasti (PRD 7.1, SEK-R2).
  final bool showAgeGroup;

  /// Bawaan: Terhubung (PRD 7.1).
  final FieldVisibility subdistrict;

  /// Bawaan: Terhubung; komunitas Tertutup tidak pernah tampil (PRD 7.1, AC-13).
  final FieldVisibility joinedCommunities;

  /// Bawaan: Hanya saya / opt-in (PRD 7.1, K7).
  final FieldVisibility homeChurch;

  /// Bawaan: Hanya saya (PRD 7.1, TAR-R10).
  final FieldVisibility tarombo;

  /// Bawaan: Ya, level kota (PRD 7.1, SEK-R3).
  final bool discoverableInNearbyAndSearch;

  /// Bawaan: Semua (PRD 7.1).
  final ConnectionRequestAllowance whoCanSendConnectionRequest;

  /// Bawaan: Izinkan sebagai Permintaan pesan (PRD 7.1, PSN-R1).
  final bool allowMessagesFromSharedContext;

  /// Bawaan: Ya (PRD 7.1, PSN-R3).
  final bool sendReadReceipts;

  /// Bawaan: Publik (PRD 7.1).
  final AccountVisibilityType accountType;
}
