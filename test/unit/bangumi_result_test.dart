import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/apis/bangumi_result.dart';

void main() {
  group('Result<T>', () {
    test('Success stores and exposes value', () {
      const result = Success<int>(42);
      expect(result.value, 42);
    });

    test('Failure stores error and optional stack trace', () {
      final error = Exception('test error');
      final stack = StackTrace.current;
      final result = Failure<String>(error, stack);
      expect(result.error, error);
      expect(result.stackTrace, stack);
    });

    test('Failure without stack trace has null stackTrace', () {
      final result = Failure<double>(StateError('boom'));
      expect(result.error, isA<StateError>());
      expect(result.stackTrace, isNull);
    });

    test('pattern matching with switch expression', () {
      final Result<int> success = Success(99);
      final value = switch (success) {
        Success(:final value) => value,
        Failure(:final error) => throw error,
      };
      expect(value, 99);
    });

    test('pattern matching with if-case', () {
      final Result<String> failure = Failure(Exception('nope'));
      var handled = false;
      if (failure case Failure(:final error)) {
        handled = true;
        expect(error, isA<Exception>());
      }
      expect(handled, isTrue);
    });

    test('generic type parameter preserved', () {
      final Result<List<int>> result = Success([1, 2, 3]);
      expect(result, isA<Success<List<int>>>());
      // Value is correctly typed List<int>
      final list = (result as Success<List<int>>).value;
      expect(list.length, 3);
    });

    test('Success with null value', () {
      const Result<String?> result = Success<String?>(null);
      expect(result, isA<Success<String?>>());
      expect((result as Success<String?>).value, isNull);
    });

    test('const constructor works', () {
      const r1 = Success(42);
      const r2 = Success(42);
      expect(identical(r1, r2), isTrue);
    });
  });
}
