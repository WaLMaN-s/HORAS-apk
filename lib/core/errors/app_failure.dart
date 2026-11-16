/// Kegagalan domain/aplikasi bertipe yang dipetakan langsung ke [StateView] (PRD 5.2, Prompt 2 Bagian B).
sealed class AppError {
  const AppError({required this.message});

  final String message;
}

/// Alias kompatibilitas untuk [AppError].
typedef AppFailure = AppError;

/// 1. Offline: tanpa koneksi internet (PRD 5.2).
final class OfflineError extends AppError {
  const OfflineError({required super.message});
}

typedef NetworkFailure = OfflineError;

/// 2. Server: error server dengan kode referensi untuk dukungan (PRD 5.2).
final class ServerError extends AppError {
  const ServerError({required super.message, required this.referenceCode});

  final String referenceCode;
}

typedef ServerFailure = ServerError;

/// 3. PermissionDenied: izin sistem ditolak (PRD 5.2, AUT-R10).
final class PermissionDeniedError extends AppError {
  const PermissionDeniedError({
    required super.message,
    required this.permissionName,
  });

  final String permissionName;
}

typedef PermissionDeniedFailure = PermissionDeniedError;

/// 4. Unavailable: konten tidak tersedia secara netral tanpa membocorkan alasan (PRD 5.2).
final class UnavailableError extends AppError {
  const UnavailableError({required super.message});
}

typedef ContentUnavailableFailure = UnavailableError;

/// 5. Suspended: akun dibatasi atau ditangguhkan beserta alasan umum (PRD 5.2, SIS-R4).
final class SuspendedError extends AppError {
  const SuspendedError({required super.message, this.canAppeal = true});

  final bool canAppeal;
}

typedef AccountRestrictedFailure = SuspendedError;

/// 6. RateLimited: batas kuota terlampaui beserta waktu kapan boleh mencoba lagi (PRD 7.2).
final class RateLimitedError extends AppError {
  const RateLimitedError({
    required super.message,
    required this.retryAt,
    this.retryAfter,
  });

  final DateTime retryAt;
  final Duration? retryAfter;
}

typedef RateLimitFailure = RateLimitedError;

/// 7. Validation: input tidak memenuhi aturan bisnis (PRD bagian 6).
final class ValidationError extends AppError {
  const ValidationError({required super.message, this.field});

  final String? field;
}

typedef ValidationFailure = ValidationError;
