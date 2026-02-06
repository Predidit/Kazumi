import 'dart:async';

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
class VideoSourceNotFoundException implements Exception {
  final String message;
  const VideoSourceNotFoundException([this.message = 'Video source not found']);

  @override
  String toString() => 'VideoSourceNotFoundException: $message';
}

/// 视频源解析超时异常
class VideoSourceTimeoutException implements Exception {
  final Duration timeout;
  const VideoSourceTimeoutException(this.timeout);

  @override
  String toString() => 'VideoSourceTimeoutException: Timed out after ${timeout.inSeconds}s';
}

/// 视频源提供者接口
///
/// 抽象视频源的获取方式，支持多种实现：
/// - WebView 解析（在线）
/// - 本地缓存读取
/// - 组合策略（优先缓存，回退 WebView）
abstract class IVideoSourceProvider {
  /// 解析视频源 URL
  ///
  /// [episodeUrl] 集数页面 URL
  /// [useLegacyParser] 是否使用旧版解析器（iframe 监听）
  /// [offset] 播放偏移量（秒）
  /// [timeout] 解析超时时间
  ///
  /// 返回 [VideoSource] 包含解析后的视频 URL 和元数据
  ///
  /// 可能抛出：
  /// - [VideoSourceNotFoundException] 未找到视频源
  /// - [VideoSourceTimeoutException] 解析超时
  Future<VideoSource> resolve(
    String episodeUrl, {
    required bool useLegacyParser,
    int offset = 0,
    Duration timeout = const Duration(seconds: 30),
  });

  /// 取消当前正在进行的解析
  void cancel();

  /// 释放资源
  void dispose();
}
