import 'dart:async';

/// Ensures asynchronous operations are spaced apart by at least a minimum interval.
class AsyncRateLimiter {
  AsyncRateLimiter(this.period);

  final Duration period;
  DateTime _nextAllowedTime = DateTime.now();

  /// Waits until the next allowed time slot and reserves the following slot.
  Future<void> acquire() async {
    final now = DateTime.now();
    final scheduledTime =
        _nextAllowedTime.isAfter(now) ? _nextAllowedTime : now;
    _nextAllowedTime = scheduledTime.add(period);
    final waitDuration = scheduledTime.difference(now);
    if (waitDuration > Duration.zero) {
      await Future.delayed(waitDuration);
    }
  }

  /// Runs [action] after acquiring a rate-limited time slot.
  Future<T> run<T>(Future<T> Function() action) async {
    await acquire();
    return await action();
  }
}
