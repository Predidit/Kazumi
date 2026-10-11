import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/request/core/network_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'an unresponsive connectivity query cannot hide the original error',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) => Completer<Object?>().future,
      );
      final original = DioException(
        requestOptions: RequestOptions(
          path: 'https://mirror.example/update.zip',
        ),
        error: const SocketException('original stalled connection'),
        stackTrace: StackTrace.current,
      );

      final mapped = await NetworkErrorMapper.mapException(original);

      expect(mapped.type, NetworkExceptionType.unknown);
      expect(mapped.rawError, same(original));
      expect(mapped.stackTrace, same(original.stackTrace));
    },
  );

  for (final pluginError in <Object>[
    PlatformException(code: 'network_state_unavailable'),
    MissingPluginException('connectivity is unavailable'),
  ]) {
    test(
      'unknown preserves original error when ${pluginError.runtimeType} occurs',
      () async {
        var queryCount = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'check');
          queryCount++;
          throw pluginError;
        });
        final stack = StackTrace.fromString('original transport stack');
        const cause = SocketException('original socket failure');
        final original = DioException(
          requestOptions: RequestOptions(
            path: 'https://mirror.example/update.zip',
          ),
          error: cause,
          stackTrace: stack,
        );

        final mapped = await NetworkErrorMapper.mapException(original);

        expect(queryCount, 1);
        expect(mapped.type, NetworkExceptionType.unknown);
        expect(mapped.rawError, same(original));
        expect(mapped.stackTrace, same(stack));
        expect((mapped.rawError as DioException).error, same(cause));
      },
    );
  }

  test(
    'a normal connectivity label preserves original error and stack',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'check');
        return ['wifi'];
      });
      final stack = StackTrace.fromString('original download stack');
      const cause = SocketException('unexpected connection reset');
      final original = DioException(
        requestOptions: RequestOptions(
          path: 'https://mirror.example/update.zip',
        ),
        error: cause,
        stackTrace: stack,
      );

      final mapped = await NetworkErrorMapper.mapException(original);

      expect(mapped.type, NetworkExceptionType.unknown);
      expect(mapped.message, contains('wifi'));
      expect(mapped.rawError, same(original));
      expect(mapped.stackTrace, same(stack));
      expect((mapped.rawError as DioException).error, same(cause));
    },
  );
}
