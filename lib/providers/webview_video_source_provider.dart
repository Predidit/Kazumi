import 'dart:async';

import 'package:kazumi/webview/webview_controller.dart';
import 'package:kazumi/providers/video_source_provider.dart';

/// WebView 视频源提供者
///
/// 使用 WebView 解析视频页面，提取视频源 URL。
/// WebView 实例在 Provider 生命周期内复用，切换集数时调用 unloadPage 释放页面资源，
/// 仅在 [dispose] 时才真正销毁 WebView。
class WebViewVideoSourceProvider implements IVideoSourceProvider {
  WebviewItemController? _webview;
  StreamSubscription? _subscription;
  StreamSubscription? _logSubscription;
  Completer<VideoSource>? _completer;
  bool _isCancelled = false;

  final StreamController<String> _logController = 
      StreamController<String>.broadcast();
  Stream<String> get onLog => _logController.stream;

  @override
  Future<VideoSource> resolve(
    String episodeUrl, {
    required bool useLegacyParser,
    int offset = 0,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // 取消之前的解析（如果正在进行）
    _cancelCurrentResolve();
    _isCancelled = false;

    // 复用或初始化 WebView
    if (_webview == null) {
      _webview = WebviewItemControllerFactory.getController();
      await _webview!.init();
      
      _logSubscription = _webview!.onLog.listen((log) {
        if (!_logController.isClosed) {
          _logController.add(log);
        }
      });
    }

    if (_isCancelled) {
      throw const VideoSourceCancelledException();
    }

    _completer = Completer<VideoSource>();

    try {
      // 订阅视频源解析结果
      _subscription = _webview!.onVideoURLParser.listen((event) {
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(VideoSource(
            url: event.$1,
            offset: event.$2,
            type: VideoSourceType.online,
          ));
        }
      });

      // 加载 URL 并等待解析结果
      // Provider 层始终以原生播放器模式解析（WebView 仅用于 URL 提取）
      await _webview!.loadUrl(
        episodeUrl,
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
      // 解析完成：取消订阅并卸载页面，但保留 WebView 实例
      await _subscription?.cancel();
      _subscription = null;
      _completer = null;
      await _webview?.unloadPage();
    }
  }

  /// 取消当前正在进行的解析，但不销毁 WebView
  void _cancelCurrentResolve() {
    _isCancelled = true;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(const VideoSourceCancelledException());
    }
    _subscription?.cancel();
    _subscription = null;
    _completer = null;
  }

  @override
  void cancel() {
    _cancelCurrentResolve();
  }

  @override
  void dispose() {
    _cancelCurrentResolve();
    _logSubscription?.cancel();
    _logSubscription = null;
    _logController.close();
    _webview?.dispose();
    _webview = null;
  }
}
