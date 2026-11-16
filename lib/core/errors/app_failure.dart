/// Kegagalan domain/aplikasi yang dipetakan langsung ke status standar PRD 5.2.
sealed class AppFailure {
  const AppFailure({required this.message});

  final String message;
}

/// Tanpa koneksi internet (PRD 5.2).
final class NetworkFailure extends AppFailure {
  const NetworkFailure({required super.message});
}

/// Error server dengan kode referensi untuk dukungan (PRD 5.2).
final class ServerFailure extends AppFailure {
  const ServerFailure({required super.message, required this.referenceCode});

  final String referenceCode;
}

/// Izin sistem ditolak (PRD 5.2, AUT-R10).
final class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure({
    required super.message,
    required this.permissionName,
  });

  final String permissionName;
}

/// Konten tidak tersedia: dihapus, privat, atau diblokir — netral tanpa bocor alasan (PRD 5.2).
final class ContentUnavailableFailure extends AppFailure {
  const ContentUnavailableFailure({required super.message});
}

/// Akun dibatasi atau ditangguhkan beserta alasan umum (PRD 5.2, SIS-R4).
final class AccountRestrictedFailure extends AppFailure {
  const AccountRestrictedFailure({
    required super.message,
    this.canAppeal = true,
  });

  final bool canAppeal;
}

/// Batas kuota / rate limit terlampaui (PRD 7.2).
final class RateLimitFailure extends AppFailure {
  const RateLimitFailure({required super.message, this.retryAfter});

  final Duration? retryAfter;
}

/// Validasi input tidak memenuhi aturan bisnis (PRD bagian 6).
final class ValidationFailure extends AppFailure {
  const ValidationFailure({required super.message, this.field});

  final String? field;
}
