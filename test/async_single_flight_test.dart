import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/async_single_flight.dart';

void main() {
  group('AsyncSingleFlight', () {
    test('shares one active operation across concurrent callers', () async {
      final singleFlight = AsyncSingleFlight<void>();
      final operation = Completer<void>();
      var callCount = 0;

      Future<void> action() {
        callCount++;
        return operation.future;
      }

      final first = singleFlight.run(action);
      final second = singleFlight.run(action);

      expect(identical(first, second), isTrue);
      expect(callCount, 1);
      expect(singleFlight.isRunning, isTrue);

      operation.complete();
      await Future.wait([first, second]);
      await Future<void>.delayed(Duration.zero);

      expect(singleFlight.isRunning, isFalse);
      await singleFlight.run(action);
      expect(callCount, 2);
    });

    test('shares errors and allows a later retry', () async {
      final singleFlight = AsyncSingleFlight<void>();
      final operation = Completer<void>();
      var callCount = 0;

      Future<void> action() {
        callCount++;
        return operation.future;
      }

      final first = singleFlight.run(action);
      final second = singleFlight.run(action);
      operation.completeError(StateError('failed'));

      await expectLater(first, throwsStateError);
      await expectLater(second, throwsStateError);
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 1);
      expect(singleFlight.isRunning, isFalse);

      await singleFlight.run(() async {
        callCount++;
      });
      expect(callCount, 2);
    });
  });
}
