import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kazumi/services/video_source/video_source_service.dart';

const String _configuredGatewayUrl = String.fromEnvironment(
  'KAZUMI_MEDIA_GATEWAY_URL',
  defaultValue: '/api/playback',
);
const Duration _minimumRemoteResolveTimeout = Duration(seconds: 30);
const String _hlsMarkerKey = 'kazumi-media';
const String _hlsMarkerValue = 'hls.m3u8';
final RegExp _hlsContentType = RegExp(
  r'^(?:application|audio)/(?:vnd\.apple\.|x-)?mpegurl$',
  caseSensitive: false,
);

/// Web video-source resolver backed by the configured Kazumi media gateway.
///
/// The gateway, rather than Safari, owns the browser context used to resolve a
/// playback page. A successful response contains only a same-origin gateway
/// playback URL; third-party media URLs are rejected before reaching the
/// player.
class RemoteVideoSourceService implements IVideoSourceService {
  RemoteVideoSourceService({
    String? gatewayBaseUrl,
    Uri? clientUri,
    Dio? dio,
  })  : _gatewayBaseUrl = gatewayBaseUrl ?? _configuredGatewayUrl,
        _clientUri = clientUri ?? Uri.base,
        _dio = dio ?? Dio(),
        _ownsDio = dio == null;

  final String _gatewayBaseUrl;
  final Uri _clientUri;
  final Dio _dio;
  final bool _ownsDio;

  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  CancelToken? _activeCancelToken;
  bool _disposed = false;

  @override
  Stream<String> get onLog => _logController.stream;

  @override
  Future<VideoSource> resolve(VideoSourceRequest request) async {
    if (_disposed) {
      throw const VideoSourceCancelledException();
    }

    final gatewayBase = _parseGatewayBase();
    final endpoint = _resolveEndpoint(gatewayBase);
    _validateEpisodeUrl(request.episodeUrl);
    final remoteTimeout = request.timeout < _minimumRemoteResolveTimeout
        ? _minimumRemoteResolveTimeout
        : request.timeout;
    final requestPayload = request.toJson()
      ..['timeoutMs'] = remoteTimeout.inMilliseconds;

    _activeCancelToken?.cancel('Superseded by a newer resolution request');
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    _log('正在通过远程媒体网关解析视频源');

    try {
      final response = await _dio
          .post<Object?>(
        endpoint.toString(),
        data: requestPayload,
        cancelToken: cancelToken,
        options: Options(
          contentType: Headers.jsonContentType,
          headers: const <String, String>{
            'X-Lunera-Request': 'bangumi-session-v1',
          },
          responseType: ResponseType.json,
          followRedirects: false,
          maxRedirects: 0,
          sendTimeout: remoteTimeout,
          receiveTimeout: remoteTimeout,
          validateStatus: (_) => true,
        ),
      )
          .timeout(
        remoteTimeout,
        onTimeout: () {
          cancelToken.cancel('Media gateway request timed out');
          throw VideoSourceTimeoutException(remoteTimeout);
        },
      );

      if (cancelToken.isCancelled) {
        throw const VideoSourceCancelledException();
      }

      final payload = _decodeObject(response.data);
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        _throwGatewayFailure(statusCode, payload, remoteTimeout);
      }

      final result = _resultObject(payload);
      final rawPlaybackUrl = result['playbackUrl'];
      if (rawPlaybackUrl is! String || rawPlaybackUrl.trim().isEmpty) {
        throw const VideoSourceGatewayException(
          'Media gateway response did not include a playback URL',
        );
      }
      var playbackUrl = _validatePlaybackUrl(
        rawPlaybackUrl,
        gatewayBase: gatewayBase,
      );
      if (_isHlsResult(result)) {
        playbackUrl = _withHlsPlaybackMarker(playbackUrl);
      }
      final responseOffset = result['offset'];
      final offset = responseOffset is num && responseOffset >= 0
          ? responseOffset.toInt()
          : request.offset;

      _log('媒体会话已创建');
      return VideoSource(
        url: playbackUrl.toString(),
        offset: offset,
        type: VideoSourceType.online,
      );
    } on VideoSourceException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || cancelToken.isCancelled) {
        throw const VideoSourceCancelledException();
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw VideoSourceTimeoutException(remoteTimeout);
        case DioExceptionType.badCertificate:
        case DioExceptionType.connectionError:
          throw const VideoSourceGatewayException(
            'Unable to connect to the configured media gateway',
          );
        case DioExceptionType.badResponse:
          _throwGatewayFailure(
            error.response?.statusCode ?? 0,
            _decodeObject(error.response?.data),
            remoteTimeout,
          );
        case DioExceptionType.cancel:
          throw const VideoSourceCancelledException();
        case DioExceptionType.unknown:
          throw const VideoSourceGatewayException(
            'Media gateway request failed',
          );
      }
    } on FormatException {
      throw const VideoSourceGatewayException(
        'Media gateway returned an invalid response',
      );
    } finally {
      if (identical(_activeCancelToken, cancelToken)) {
        _activeCancelToken = null;
      }
    }
  }

  Uri _parseGatewayBase() {
    final configured = _gatewayBaseUrl.trim();
    if (configured.isEmpty) {
      throw const VideoSourceConfigurationException(
        'KAZUMI_MEDIA_GATEWAY_URL is not configured',
      );
    }

    final parsed = Uri.tryParse(configured);
    if (parsed == null) {
      throw const VideoSourceConfigurationException(
        'KAZUMI_MEDIA_GATEWAY_URL is invalid',
      );
    }
    final Uri absolute;
    if (parsed.hasScheme) {
      absolute = parsed;
    } else {
      if (!configured.startsWith('/') || !_isHttpUri(_clientUri)) {
        throw const VideoSourceConfigurationException(
          'KAZUMI_MEDIA_GATEWAY_URL must be absolute or root-relative',
        );
      }
      absolute = _clientUri.resolveUri(parsed);
    }
    if (!_isHttpUri(absolute) ||
        absolute.userInfo.isNotEmpty ||
        absolute.hasQuery ||
        absolute.hasFragment ||
        !_sameOrigin(absolute, _clientUri)) {
      throw const VideoSourceConfigurationException(
        'KAZUMI_MEDIA_GATEWAY_URL must resolve to a same-origin HTTP(S) base path',
      );
    }
    return absolute;
  }

  Uri _resolveEndpoint(Uri gatewayBase) {
    final basePath = gatewayBase.path.endsWith('/')
        ? gatewayBase.path.substring(0, gatewayBase.path.length - 1)
        : gatewayBase.path;
    return gatewayBase.replace(path: '$basePath/resolve');
  }

  void _validateEpisodeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !_isHttpUri(uri) || uri.userInfo.isNotEmpty) {
      throw const VideoSourceRequestRejectedException(
        'Episode URL must be an absolute HTTP(S) URL',
      );
    }
  }

  Uri _validatePlaybackUrl(
    String value, {
    required Uri gatewayBase,
  }) {
    final raw = Uri.tryParse(value.trim());
    if (raw == null || raw.userInfo.isNotEmpty) {
      throw const VideoSourceGatewayException(
        'Media gateway returned an invalid playback URL',
      );
    }
    final baseDirectory = gatewayBase.replace(
      path: gatewayBase.path.endsWith('/')
          ? gatewayBase.path
          : '${gatewayBase.path}/',
    );
    final resolved = raw.hasScheme ? raw : baseDirectory.resolveUri(raw);
    if (!_isHttpUri(resolved) || !_sameOrigin(resolved, _clientUri)) {
      throw const VideoSourceGatewayException(
        'Media gateway returned a playback URL outside an allowed origin',
      );
    }
    return resolved;
  }

  bool _isHlsResult(Map<String, Object?> result) {
    final media = result['media'];
    if (media is! Map) return false;

    final kind = media['kind']?.toString().trim().toLowerCase();
    if (kind == 'hls') return true;
    if (kind == 'mp4') return false;

    final contentType =
        media['contentType']?.toString().split(';').first.trim();
    return contentType != null && _hlsContentType.hasMatch(contentType);
  }

  Uri _withHlsPlaybackMarker(Uri playbackUrl) {
    if (playbackUrl.queryParametersAll.containsKey(_hlsMarkerKey)) {
      return playbackUrl;
    }
    final marker = '${Uri.encodeQueryComponent(_hlsMarkerKey)}='
        '${Uri.encodeQueryComponent(_hlsMarkerValue)}';
    final query =
        playbackUrl.hasQuery ? '${playbackUrl.query}&$marker' : marker;
    return playbackUrl.replace(query: query);
  }

  Map<String, Object?> _decodeObject(Object? value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map(
          (key, item) => MapEntry(key.toString(), item),
        );
      }
    }
    return const <String, Object?>{};
  }

  Map<String, Object?> _resultObject(Map<String, Object?> payload) {
    final data = payload['data'];
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return payload;
  }

  Never _throwGatewayFailure(
    int statusCode,
    Map<String, Object?> payload,
    Duration timeout,
  ) {
    final error = payload['error'];
    final errorObject = error is Map
        ? error.map((key, value) => MapEntry(key.toString(), value))
        : payload;
    final code = errorObject['code']?.toString().toUpperCase() ?? '';
    final message = _safeMessage(errorObject['message']);

    if (statusCode == 408 ||
        statusCode == 504 ||
        code == 'RESOLVE_TIMEOUT' ||
        code == 'TIMEOUT') {
      throw VideoSourceTimeoutException(timeout);
    }
    if (code == 'CONFIGURATION_ERROR') {
      throw VideoSourceConfigurationException(
        message ?? 'Media gateway is not configured for playback',
      );
    }
    if (code == 'SSRF_BLOCKED' ||
        code == 'INVALID_REQUEST' ||
        code == 'RULE_NOT_ALLOWED') {
      throw VideoSourceRequestRejectedException(
        message ?? 'Media gateway rejected the resolution request',
        statusCode: statusCode,
      );
    }
    if (statusCode == 401 ||
        statusCode == 403 ||
        code == 'AUTH_REQUIRED' ||
        code == 'OWNER_MISMATCH' ||
        code == 'UNAUTHORIZED' ||
        code == 'FORBIDDEN') {
      throw VideoSourceAuthorizationException(
        message ?? 'Media gateway rejected the current user',
        statusCode: statusCode,
      );
    }
    if (statusCode == 410 || code == 'SESSION_EXPIRED') {
      throw VideoSourceSessionExpiredException(
        message ?? 'Media session expired and must be resolved again',
      );
    }
    if (statusCode == 404 ||
        code == 'NO_MEDIA' ||
        code == 'RESOURCE_NOT_FOUND' ||
        code == 'VIDEO_SOURCE_NOT_FOUND') {
      throw VideoSourceNotFoundException(
        message ?? 'Media gateway could not find a playable source',
      );
    }
    if (statusCode == 429 || code == 'RATE_LIMITED') {
      throw VideoSourceRateLimitedException(
        message ?? 'Media gateway rate limit reached',
      );
    }
    if (statusCode == 400 || statusCode == 422 || code == 'INVALID_REQUEST') {
      throw VideoSourceRequestRejectedException(
        message ?? 'Media gateway rejected the resolution request',
        statusCode: statusCode,
      );
    }
    if (statusCode == 502 ||
        statusCode == 503 ||
        code == 'UPSTREAM_REJECTED' ||
        code == 'UPSTREAM_UNAVAILABLE') {
      throw VideoSourceUpstreamException(
        message ?? 'Upstream media site rejected the request',
        statusCode: statusCode,
      );
    }
    throw VideoSourceGatewayException(
      message ?? 'Media gateway returned an unexpected response',
      statusCode: statusCode,
    );
  }

  String? _safeMessage(Object? value) {
    if (value is! String) return null;
    final normalized = value.replaceAll(RegExp(r'[\r\n\u0000]+'), ' ').trim();
    if (normalized.isEmpty) return null;
    return normalized.length <= 256 ? normalized : normalized.substring(0, 256);
  }

  bool _isHttpUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') &&
        uri.hasAuthority &&
        uri.host.isNotEmpty;
  }

  bool _sameOrigin(Uri left, Uri right) {
    if (!_isHttpUri(left) || !_isHttpUri(right)) return false;
    return left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
        left.host.toLowerCase() == right.host.toLowerCase() &&
        _effectivePort(left) == _effectivePort(right);
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
  }

  void _log(String message) {
    if (!_logController.isClosed) {
      _logController.add(message);
    }
  }

  @override
  void cancel() {
    _activeCancelToken?.cancel('Video source resolution cancelled');
    _activeCancelToken = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    cancel();
    if (_ownsDio) {
      _dio.close(force: true);
    }
    await _logController.close();
  }
}
