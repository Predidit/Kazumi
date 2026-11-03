import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/async_rate_limiter.dart';

void main() {
  group('AsyncRateLimiter', () {
    test('first acquire completes immediately without unnecessary delay', () async {
      final limiter = AsyncRateLimiter(const Duration(milliseconds: 50));
      final stopwatch = Stopwatch()..start();
      await limiter.acquire();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(30));
    });

    test('serial sequential calls maintain at least period spacing', () async {
      const period = Duration(milliseconds: 40);
      final limiter = AsyncRateLimiter(period);

      final timestamps = <int>[];
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 3; i++) {
        await limiter.acquire();
        timestamps.add(stopwatch.elapsedMilliseconds);
      }

      expect(timestamps.length, 3);
      for (var i = 1; i < timestamps.length; i++) {
        final diff = timestamps[i] - timestamps[i - 1];
        expect(diff, greaterThanOrEqualTo(35));
      }
    });

    test('concurrent callers are spaced apart into sequential time slots', () async {
      const period = Duration(milliseconds: 40);
      final limiter = AsyncRateLimiter(period);

      final completionTimes = <int>[];
      final stopwatch = Stopwatch()..start();

      await Future.wait(
        List.generate(4, (index) async {
          await limiter.acquire();
          completionTimes.add(stopwatch.elapsedMilliseconds);
        }),
      );

      expect(completionTimes.length, 4);
      for (var i = 1; i < completionTimes.length; i++) {
        final diff = completionTimes[i] - completionTimes[i - 1];
        expect(diff, greaterThanOrEqualTo(35));
      }
    });

    test('run passes return value and preserves rate limit on failure', () async {
      const period = Duration(milliseconds: 40);
      final limiter = AsyncRateLimiter(period);

      final stopwatch = Stopwatch()..start();

      final firstResult = await limiter.run(() async => 'success');
      expect(firstResult, 'success');

      await expectLater(
        limiter.run(() async => throw StateError('action error')),
        throwsStateError,
      );

      final secondResult = await limiter.run(() async => 'recovered');
      expect(secondResult, 'recovered');

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(70));
    });
  });
}
