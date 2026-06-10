/// A discriminated union for operation results, replacing silent null/empty
/// returns so callers are forced by the compiler to handle both outcomes.
///
/// Usage:
/// ```dart
/// final result = await BangumiApi.getCalendar();
/// switch (result) {
///   case Success(:final value):
///     // use value (List<List<BangumiItem>>)
///   case Failure(:final error):
///     // handle error
/// }
/// ```
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}
