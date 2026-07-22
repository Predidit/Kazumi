import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/video_source/remote_video_source_service.dart';
import 'package:kazumi/services/video_source/video_source_service.dart';

void main() {
  group('VideoSourceRequest', () {
    test('serializes only the explicit playback configuration', () {
      final request = VideoSourceRequest(
        episodeUrl: 'https://anime.example/play/1',
        pluginName: 'example',
        version: '2.1',
        useLegacyParser: true,
        userAgent: 'Kazumi Test UA',
        referer: 'https://anime.example/',
        adBlocker: true,
        playButtonSelector: '  #player-start  ',
        offset: 12,
        timeout: Duration(seconds: 20),
      );

      expect(request.toJson(), <String, Object?>{
        'episodeUrl': 'https://anime.example/play/1',
        'plugin': <String, Object?>{
          'name': 'example',
          'version': '2.1',
          'useLegacyParser': true,
          'userAgent': 'Kazumi Test UA',
          'referer': 'https://anime.example/',
          'adBlocker': true,
          'playButtonSelector': '#player-start',
        },
        'offset': 12,
        'timeoutMs': 20000,
      });
    });
  });

  group('RemoteVideoSourceService', () {
    test('posts to the fixed resolve endpoint and accepts gateway media URL',
        () async {
      final adapter = _FakeHttpClientAdapter((options, _, __) async {
        return _jsonResponse(
          200,
          <String, Object?>{
            'playbackUrl': '/media/session-1/master',
            'offset': 18,
            'media': <String, Object?>{
              'kind': 'hls',
              'contentType': 'application/vnd.apple.mpegurl',
            },
          },
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final service = RemoteVideoSourceService(
        gatewayBaseUrl: 'https://app.example/api/playback',
        clientUri: Uri.parse('https://app.example/watch/1'),
        dio: dio,
      );
      addTearDown(service.dispose);

      final source = await service.resolve(_request());

      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastOptions?.uri.toString(),
          'https://app.example/api/playback/resolve');
      expect(adapter.lastOptions?.followRedirects, isFalse);
      expect(adapter.lastOptions?.headers['X-Lunera-Request'],
          'bangumi-session-v1');
      expect(adapter.lastOptions?.data, isA<Map<String, Object?>>());
      expect(
        (adapter.lastOptions?.data as Map<String, Object?>)['timeoutMs'],
        30000,
      );
      expect(
        source.url,
        'https://app.example/media/session-1/master?kazumi-media=hls.m3u8',
      );
      expect(source.offset, 18);
      expect(source.type, VideoSourceType.online);
    });

    test('accepts an absolute playback URL on the web application origin',
        () async {
      final service = _serviceForResponse(
        200,
        <String, Object?>{
          'data': <String, Object?>{
            'playbackUrl': 'https://app.example/media/session-2/master',
            'media': <String, Object?>{
              'kind': 'mp4',
              'contentType': 'video/mp4',
            },
          },
        },
      );
      addTearDown(service.dispose);

      final source = await service.resolve(_request(offset: 9));

      expect(source.url, 'https://app.example/media/session-2/master');
      expect(source.offset, 9);
    });

    test('marks HLS by content type without changing existing query data',
        () async {
      final service = _serviceForResponse(
        200,
        <String, Object?>{
          'playbackUrl': '/media/session-3/master?generation=2',
          'media': <String, Object?>{
            'kind': 'other',
            'contentType': 'application/x-mpegURL; charset=utf-8',
          },
        },
      );
      addTearDown(service.dispose);

      final source = await service.resolve(_request());

      expect(
        source.url,
        'https://app.example/media/session-3/master?generation=2&kazumi-media=hls.m3u8',
      );
    });

    test('rejects a playback URL outside the app and gateway origins',
        () async {
      final service = _serviceForResponse(
        200,
        <String, Object?>{
          'playbackUrl': 'https://third-party.example/video/master.m3u8',
        },
      );
      addTearDown(service.dispose);

      await expectLater(
        service.resolve(_request()),
        throwsA(isA<VideoSourceGatewayException>()),
      );
    });

    test('maps gateway status and error codes to explicit exceptions',
        () async {
      final cases = <(int, String, Type)>[
        (401, 'UNAUTHORIZED', VideoSourceAuthorizationException),
        (404, 'VIDEO_SOURCE_NOT_FOUND', VideoSourceNotFoundException),
        (502, 'NO_MEDIA', VideoSourceNotFoundException),
        (410, 'SESSION_EXPIRED', VideoSourceSessionExpiredException),
        (429, 'RATE_LIMITED', VideoSourceRateLimitedException),
        (503, 'CONFIGURATION_ERROR', VideoSourceConfigurationException),
        (403, 'SSRF_BLOCKED', VideoSourceRequestRejectedException),
        (502, 'UPSTREAM_REJECTED', VideoSourceUpstreamException),
      ];

      for (final (status, code, exceptionType) in cases) {
        final service = _serviceForResponse(
          status,
          <String, Object?>{
            'error': <String, Object?>{
              'code': code,
              'message': 'controlled failure',
            },
          },
        );
        try {
          await expectLater(
            service.resolve(_request()),
            throwsA(
              predicate<Object>((error) => error.runtimeType == exceptionType),
            ),
          );
        } finally {
          await service.dispose();
        }
      }
    });

    test('maps transport timeout and cancellation separately', () async {
      final timeoutAdapter = _FakeHttpClientAdapter((options, _, __) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      });
      final timeoutService = _serviceWithAdapter(timeoutAdapter);
      addTearDown(timeoutService.dispose);

      await expectLater(
        timeoutService.resolve(_request()),
        throwsA(isA<VideoSourceTimeoutException>()),
      );

      final waitingAdapter = _FakeHttpClientAdapter((options, _, cancelFuture) {
        final completer = Completer<ResponseBody>();
        cancelFuture?.then((_) {
          if (!completer.isCompleted) {
            completer.completeError(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
              ),
            );
          }
        });
        return completer.future;
      });
      final cancelledService = _serviceWithAdapter(waitingAdapter);
      addTearDown(cancelledService.dispose);
      final resolution = cancelledService.resolve(_request());
      await Future<void>.delayed(Duration.zero);
      cancelledService.cancel();

      await expectLater(
        resolution,
        throwsA(isA<VideoSourceCancelledException>()),
      );
    });

    test('rejects invalid configuration and episode URL before networking',
        () async {
      final adapter = _FakeHttpClientAdapter((_, __, ___) async {
        fail('network must not be reached');
      });
      final missingConfig = RemoteVideoSourceService(
        gatewayBaseUrl: '',
        clientUri: Uri.parse('https://app.example/'),
        dio: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(missingConfig.dispose);
      await expectLater(
        missingConfig.resolve(_request()),
        throwsA(isA<VideoSourceConfigurationException>()),
      );

      final crossOriginGateway = RemoteVideoSourceService(
        gatewayBaseUrl: 'https://gateway.example/kazumi',
        clientUri: Uri.parse('https://app.example/'),
        dio: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(crossOriginGateway.dispose);
      await expectLater(
        crossOriginGateway.resolve(_request()),
        throwsA(isA<VideoSourceConfigurationException>()),
      );

      final service = _serviceWithAdapter(adapter);
      addTearDown(service.dispose);
      await expectLater(
        service.resolve(_request(episodeUrl: 'file:///private/video')),
        throwsA(isA<VideoSourceRequestRejectedException>()),
      );
      expect(adapter.lastOptions, isNull);
    });
  });
}

VideoSourceRequest _request({
  String episodeUrl = 'https://anime.example/play/1',
  int offset = 0,
}) {
  return VideoSourceRequest(
    episodeUrl: episodeUrl,
    pluginName: 'example',
    version: '2.1',
    useLegacyParser: false,
    userAgent: 'Kazumi Test UA',
    referer: 'https://anime.example/',
    adBlocker: true,
    offset: offset,
  );
}

RemoteVideoSourceService _serviceForResponse(
  int statusCode,
  Map<String, Object?> body,
) {
  return _serviceWithAdapter(
    _FakeHttpClientAdapter((_, __, ___) async {
      return _jsonResponse(statusCode, body);
    }),
  );
}

RemoteVideoSourceService _serviceWithAdapter(HttpClientAdapter adapter) {
  return RemoteVideoSourceService(
    gatewayBaseUrl: 'https://app.example/api/playback',
    clientUri: Uri.parse('https://app.example/watch/1'),
    dio: Dio()..httpClientAdapter = adapter,
  );
}

ResponseBody _jsonResponse(int statusCode, Map<String, Object?> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

typedef _AdapterHandler = Future<ResponseBody> Function(
  RequestOptions options,
  Stream<Uint8List>? requestStream,
  Future<void>? cancelFuture,
);

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.handler);

  final _AdapterHandler handler;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastOptions = options;
    return handler(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
