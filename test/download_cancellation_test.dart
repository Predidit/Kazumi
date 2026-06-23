import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/utils/download_manager.dart';

void main() {
  group('isDownloadCancellation', () {
    test('recognizes mapped network cancellation', () {
      const error = NetworkException(
        type: NetworkExceptionType.cancel,
        message: 'paused',
      );

      expect(isDownloadCancellation(error), isTrue);
    });

    test('recognizes Dio cancellation', () {
      final error = DioException(
        requestOptions: RequestOptions(path: 'https://example.com/video.ts'),
        type: DioExceptionType.cancel,
        error: 'paused',
      );

      expect(isDownloadCancellation(error), isTrue);
    });

    test('does not treat ordinary network errors as cancellation', () {
      const error = NetworkException(
        type: NetworkExceptionType.connectionError,
        message: 'connection failed',
      );

      expect(isDownloadCancellation(error), isFalse);
    });
  });
}
