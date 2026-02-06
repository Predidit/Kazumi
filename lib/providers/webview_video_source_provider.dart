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
  
  /// 单个 Provider 实例不能实现并发解析，单个 Provider 实例只能持有一个 Webview
  /// 但是 Provider 可以在正在进行的解析未完成时，取消该解析并开始新的解析
  /// 通过递增 ID 标识最新请求，取消旧请求
  int resolveId = 0;

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
    resolveId++;
    final currentResolveId = resolveId;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(const VideoSourceCancelledException());
    }
    await _subscription?.cancel();
    _subscription = null;

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

    _completer = Completer<VideoSource>();

    try {
      // 订阅视频源解析结果
      _subscription = _webview!.onVideoURLParser.listen((event) {
        if (currentResolveId == resolveId && _completer != null && !_completer!.isCompleted) {
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
      if (currentResolveId != resolveId) {
        throw const VideoSourceCancelledException();
      }
      rethrow;
    } finally {
      if (currentResolveId == resolveId) {
        await _subscription?.cancel();
        _subscription = null;
        _completer = null;
        await _webview?.unloadPage();
      }
    }
  }

  @override
  void cancel() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(const VideoSourceCancelledException());
    }
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    cancel();
    _completer = null;
    _logSubscription?.cancel();
    _logSubscription = null;
    _logController.close();
    _webview?.dispose();
    _webview = null;
  }
}
