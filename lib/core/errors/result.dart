import 'package:horas/core/errors/app_failure.dart';

/// Pembungkus hasil operasi secara fungsional tanpa lempar eksepsi liar.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  R fold<R>({
    required R Function(T value) onOk,
    required R Function(AppFailure failure) onErr,
  }) {
    final self = this;
    return switch (self) {
      Ok<T>(:final value) => onOk(value),
      Err<T>(:final failure) => onErr(failure),
    };
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ok<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Err<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
