import 'dart:async';

/// Immutable input shared by native and remote video-source resolvers.
///
/// The web implementation sends only this explicit playback subset to the
/// configured media gateway. It must not serialize the complete user supplied
/// plugin document because rule documents may contain unrelated request
/// configuration or future security-sensitive fields.
class VideoSourceRequest {
  VideoSourceRequest({
    required this.episodeUrl,
    required this.pluginName,
    required this.version,
    required this.useLegacyParser,
    required this.userAgent,
    required this.referer,
    required this.adBlocker,
    this.playButtonSelector,
    this.offset = 0,
    this.timeout = const Duration(seconds: 15),
  }) {
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative');
    }
    if (timeout.inMicroseconds <= 0) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
  }

  final String episodeUrl;
  final String pluginName;
  final String version;
  final bool useLegacyParser;
  final String userAgent;
  final String referer;
  final bool adBlocker;

  /// Optional, rule-owned selector for sites which require an explicit click
  /// before creating their player. The resolver must never click arbitrary
  /// page controls when this value is absent.
  final String? playButtonSelector;

  final int offset;
  final Duration timeout;

  Map<String, Object?> toJson() {
    final selector = playButtonSelector?.trim();
    return <String, Object?>{
      'episodeUrl': episodeUrl,
      'plugin': <String, Object?>{
        'name': pluginName,
        'version': version,
        'useLegacyParser': useLegacyParser,
        'userAgent': userAgent,
        'referer': referer,
        'adBlocker': adBlocker,
        if (selector != null && selector.isNotEmpty)
          'playButtonSelector': selector,
      },
      'offset': offset,
      'timeoutMs': timeout.inMilliseconds,
    };
  }
}

/// 视频源类型
enum VideoSourceType {
  /// 在线解析（WebView）
  online,

  /// 本地缓存
  cached,
}

/// 视频源解析结果
class VideoSource {
  /// 视频 URL (M3U8/MP4/本地路径)
  final String url;

  /// 播放偏移量（秒）
  final int offset;

  /// 视频源类型
  final VideoSourceType type;

  const VideoSource({
    required this.url,
    required this.offset,
    required this.type,
  });

  @override
  String toString() => 'VideoSource(url: $url, offset: $offset, type: $type)';
}

/// 视频源未找到异常
abstract class VideoSourceException implements Exception {
  const VideoSourceException(this.message);

  final String message;
}

class VideoSourceNotFoundException extends VideoSourceException {
  const VideoSourceNotFoundException(
      [super.message = 'Video source not found']);

  @override
  String toString() => 'VideoSourceNotFoundException: $message';
}

/// 视频源解析超时异常
class VideoSourceTimeoutException extends VideoSourceException {
  final Duration timeout;
  const VideoSourceTimeoutException(this.timeout)
      : super('Video source resolution timed out');

  @override
  String toString() =>
      'VideoSourceTimeoutException: Timed out after ${timeout.inSeconds}s';
}

/// 视频源解析取消异常
class VideoSourceCancelledException extends VideoSourceException {
  const VideoSourceCancelledException()
      : super('Video source resolution was cancelled');

  @override
  String toString() =>
      'VideoSourceCancelledException: Resolution was cancelled';
}

class VideoSourceConfigurationException extends VideoSourceException {
  const VideoSourceConfigurationException(super.message);

  @override
  String toString() => 'VideoSourceConfigurationException: $message';
}

class VideoSourceAuthorizationException extends VideoSourceException {
  const VideoSourceAuthorizationException(super.message, {this.statusCode});

  final int? statusCode;

  @override
  String toString() => 'VideoSourceAuthorizationException: $message';
}

class VideoSourceRequestRejectedException extends VideoSourceException {
  const VideoSourceRequestRejectedException(super.message, {this.statusCode});

  final int? statusCode;

  @override
  String toString() => 'VideoSourceRequestRejectedException: $message';
}

class VideoSourceSessionExpiredException extends VideoSourceException {
  const VideoSourceSessionExpiredException(super.message);

  @override
  String toString() => 'VideoSourceSessionExpiredException: $message';
}

class VideoSourceRateLimitedException extends VideoSourceException {
  const VideoSourceRateLimitedException(super.message);

  @override
  String toString() => 'VideoSourceRateLimitedException: $message';
}

class VideoSourceUpstreamException extends VideoSourceException {
  const VideoSourceUpstreamException(super.message, {this.statusCode});

  final int? statusCode;

  @override
  String toString() => 'VideoSourceUpstreamException: $message';
}

class VideoSourceGatewayException extends VideoSourceException {
  const VideoSourceGatewayException(super.message, {this.statusCode});

  final int? statusCode;

  @override
  String toString() => 'VideoSourceGatewayException: $message';
}

/// 视频源解析服务接口
///
/// 抽象视频源的获取方式，支持多种实现：
/// - WebView 解析（在线）
/// - 本地缓存读取
/// - 组合策略（优先缓存，回退 WebView）
abstract class IVideoSourceService {
  /// Sanitized resolver diagnostics suitable for the existing loading UI.
  Stream<String> get onLog;

  /// 解析视频源 URL
  ///
  /// [request] 包含集数页、规则播放配置、偏移量与超时。
  ///
  /// 返回 [VideoSource] 包含解析后的视频 URL 和元数据
  ///
  /// 可能抛出：
  /// - [VideoSourceNotFoundException] 未找到视频源
  /// - [VideoSourceTimeoutException] 解析超时
  /// - [VideoSourceCancelledException] 解析被取消
  Future<VideoSource> resolve(VideoSourceRequest request);

  /// 取消当前正在进行的解析
  ///
  /// 调用后，正在进行的 [resolve] 会抛出 [VideoSourceCancelledException]
  void cancel();

  /// 释放资源
  Future<void> dispose();
}
