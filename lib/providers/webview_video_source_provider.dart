import 'dart:async';

import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/providers/video_source_provider.dart';

/// WebView 视频源提供者
///
/// 使用 WebView 解析视频页面，提取视频源 URL。
/// 每次 [resolve] 调用创建新的 WebView 实例，确保状态隔离。
class WebViewVideoSourceProvider implements IVideoSourceProvider {
  WebviewItemController? _webview;
  StreamSubscription? _subscription;
  Completer<VideoSource>? _completer;
  bool _isCancelled = false;

  @override
  Future<VideoSource> resolve(
    String episodeUrl, {
    required bool useNativePlayer,
    required bool useLegacyParser,
    int offset = 0,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // 清理之前的状态
    await _cleanup();
    _isCancelled = false;

    // 创建新的 WebView 实例
    _webview = WebviewItemControllerFactory.getController();
    _completer = Completer<VideoSource>();

    try {
      // 初始化 WebView
      await _webview!.init();

      if (_isCancelled) {
        throw const VideoSourceCancelledException();
      }

      // 订阅视频源解析结果
      _subscription = _webview!.onVideoURLParser.listen((event) {
        if (!_completer!.isCompleted) {
          _completer!.complete(VideoSource(
            url: event.$1,
            offset: event.$2,
            type: VideoSourceType.online,
          ));
        }
      });

      // 加载 URL 并等待解析结果
      await _webview!.loadUrl(
        episodeUrl,
        useNativePlayer,
        useLegacyParser,
        offset: offset,
      );

      // 等待结果或超时
      final result = await _completer!.future.timeout(
        timeout,
        onTimeout: () {
          throw VideoSourceTimeoutException(timeout);
        },
      );

      return result;
    } catch (e) {
      if (_isCancelled) {
        throw const VideoSourceCancelledException();
      }
      rethrow;
    } finally {
      await _cleanup();
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(const VideoSourceCancelledException());
    }
    _cleanup();
  }

  @override
  void dispose() {
    cancel();
  }

  Future<void> _cleanup() async {
    await _subscription?.cancel();
    _subscription = null;

    _webview?.dispose();
    _webview = null;

    _completer = null;
  }
}
