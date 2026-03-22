/// Error types for service failures
enum ServiceErrorType {
  network,
  notFound,
  rateLimited,
  parseError,
  authFailed,
  unknown,
}

/// A result type for service operations that can succeed or fail.
sealed class ServiceResult<T> {
  const ServiceResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        final Success<T> s => s.value,
        Failure<T> _ => null,
      };

  /// Unwrap the value or throw
  T get value => switch (this) {
        final Success<T> s => s.value,
        final Failure<T> f => throw Exception('${f.errorType}: ${f.message}'),
      };
}

class Success<T> extends ServiceResult<T> {
  @override
  final T value;
  const Success(this.value);
}

class Failure<T> extends ServiceResult<T> {
  final ServiceErrorType errorType;
  final String message;
  const Failure(this.errorType, this.message);
}
