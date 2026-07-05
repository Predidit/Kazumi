import 'dart:async';

/// Runs asynchronous operations one at a time in submission order.
class AsyncSerialQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final completer = Completer<T>();
    _tail = (() async {
      try {
        await previous;
      } catch (_) {}
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    })();
    return completer.future;
  }
}
