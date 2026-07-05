/// Shares one in-flight operation and clears it after success or failure.
class AsyncSingleFlight<T> {
  Future<T>? _active;

  bool get isRunning => _active != null;

  Future<T> run(Future<T> Function() action) {
    final active = _active;
    if (active != null) {
      return active;
    }

    final future = Future.sync(action);
    _active = future;
    future.then<void>(
      (_) => _clear(future),
      onError: (Object _, StackTrace __) => _clear(future),
    );
    return future;
  }

  void _clear(Future<T> future) {
    if (identical(_active, future)) {
      _active = null;
    }
  }
}
