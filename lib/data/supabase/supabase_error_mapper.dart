import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/l10n/app_strings.dart';
import 'package:horas/core/utils/reference_code.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pemeta error respons Supabase (PostgREST, Auth, Functions, Storage, jaringan)
/// menjadi [AppError] domain HORAS (PRD 5.2, docs/API.md).
abstract final class SupabaseErrorMapper {
  static AppError map(Object error, [StackTrace? st]) {
    if (error is AppError) return error;

    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error.runtimeType.toString().contains('ClientException')) {
      return const OfflineError(message: AppStrings.stateOfflineTitle);
    }

    if (error is PostgrestException) {
      final parsed = _tryParseHorasMessage(error.message);
      if (parsed != null) return parsed;
      if (error.code == '42501') {
        return PermissionDeniedError(
          message: error.message.isNotEmpty
              ? error.message
              : 'Akses ke data atau tindakan ini ditolak.',
          permissionName: 'database',
        );
      }
      if (error.code == 'PGRST116') {
        return const UnavailableError(
          message: AppStrings.stateContentUnavailableTitle,
        );
      }
      return ServerError(
        message: error.message.isNotEmpty
            ? error.message
            : 'Terjadi gangguan pada layanan database.',
        referenceCode: ReferenceCode.generate(),
      );
    }

    if (error is FunctionException) {
      final details = error.details;
      if (details is Map) {
        final code = (details['code'] ?? '').toString();
        final msg =
            (details['message'] ?? error.reasonPhrase ?? 'Terjadi kesalahan.')
                .toString();
        final retryRaw = details['retry_at']?.toString();
        final field = details['field']?.toString();
        final canAppeal = details['canAppeal'] == true;
        final mapped = _fromStructuredCode(
          code: code,
          message: msg,
          retryAtIso: retryRaw,
          field: field,
          canAppeal: canAppeal,
        );
        if (mapped != null) return mapped;
      }
      final parsed = _tryParseHorasMessage(error.details?.toString() ?? '');
      if (parsed != null) return parsed;
      if (error.status == 429) {
        return RateLimitedError(
          message: 'Terlalu banyak permintaan. Coba lagi nanti.',
          retryAt: clock.now().toUtc().add(const Duration(minutes: 1)),
          retryAfter: const Duration(minutes: 1),
        );
      }
      return ServerError(
        message:
            error.reasonPhrase ?? 'Layanan fungsi server mengalami kendala.',
        referenceCode: ReferenceCode.generate(),
      );
    }

    if (error is AuthException) {
      final parsed = _tryParseHorasMessage(error.message);
      if (parsed != null) return parsed;
      final lower = error.message.toLowerCase();
      if (lower.contains('rate') || error.statusCode == '429') {
        return RateLimitedError(
          message: error.message,
          retryAt: clock.now().toUtc().add(const Duration(seconds: 60)),
          retryAfter: const Duration(seconds: 60),
        );
      }
      if (lower.contains('otp') ||
          lower.contains('token') ||
          lower.contains('phone')) {
        return ValidationError(message: error.message, field: 'otp');
      }
      if (lower.contains('network') ||
          lower.contains('socket') ||
          lower.contains('connection')) {
        return const OfflineError(message: AppStrings.stateOfflineTitle);
      }
      return PermissionDeniedError(
        message: error.message,
        permissionName: 'auth',
      );
    }

    if (error is StorageException) {
      if (error.statusCode == '403' || error.statusCode == '401') {
        return PermissionDeniedError(
          message: error.message,
          permissionName: 'storage',
        );
      }
      if (error.statusCode == '404') {
        return const UnavailableError(
          message: AppStrings.stateContentUnavailableTitle,
        );
      }
      return ServerError(
        message: error.message,
        referenceCode: ReferenceCode.generate(),
      );
    }

    final rawStr = error.toString();
    final parsed = _tryParseHorasMessage(rawStr);
    if (parsed != null) return parsed;
    if (rawStr.toLowerCase().contains('socketexception') ||
        rawStr.toLowerCase().contains('failed host lookup') ||
        rawStr.toLowerCase().contains('connection refused')) {
      return const OfflineError(message: AppStrings.stateOfflineTitle);
    }

    return ServerError(
      message: 'Terjadi kesalahan tidak terduga pada layanan.',
      referenceCode: ReferenceCode.generate(),
    );
  }

  static bool isOfflineFailure(Object error) {
    return error is OfflineError ||
        error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error.runtimeType.toString().contains('ClientException') ||
        map(error) is OfflineError;
  }

  /// Format server: `HORAS_ERR|<CODE>|<retry_at_iso>|<field>|<message>`
  static AppError? _tryParseHorasMessage(String raw) {
    final idx = raw.indexOf('HORAS_ERR|');
    if (idx < 0) return null;
    final segment = raw.substring(idx);
    final parts = segment.split('|');
    if (parts.length < 5) return null;
    final code = parts[1].trim();
    final retryRaw = parts[2].trim();
    final field = parts[3].trim();
    final message = parts.sublist(4).join('|').trim();
    return _fromStructuredCode(
      code: code,
      message: message,
      retryAtIso: retryRaw.isEmpty ? null : retryRaw,
      field: field.isEmpty ? null : field,
      canAppeal: field != 'false',
    );
  }

  static AppError? _fromStructuredCode({
    required String code,
    required String message,
    String? retryAtIso,
    String? field,
    bool canAppeal = true,
  }) {
    final now = clock.now().toUtc();
    switch (code.toUpperCase()) {
      case 'RATE_LIMITED':
        final retryAt =
            (retryAtIso != null ? DateTime.tryParse(retryAtIso) : null) ??
            now.add(const Duration(minutes: 1));
        final diff = retryAt.difference(now);
        return RateLimitedError(
          message: message,
          retryAt: retryAt,
          retryAfter: diff.isNegative ? Duration.zero : diff,
        );
      case 'VALIDATION_ERROR':
        return ValidationError(message: message, field: field);
      case 'SUSPENDED':
        return SuspendedError(message: message, canAppeal: canAppeal);
      case 'PERMISSION_DENIED':
        return PermissionDeniedError(
          message: message,
          permissionName: field ?? 'permission',
        );
      case 'CONTENT_UNAVAILABLE':
        return UnavailableError(message: message);
      case 'OFFLINE':
        return OfflineError(message: message);
      case 'SERVER_ERROR':
        return ServerError(
          message: message,
          referenceCode: ReferenceCode.generate(),
        );
      default:
        return null;
    }
  }
}
