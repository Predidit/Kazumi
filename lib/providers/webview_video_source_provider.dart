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
  StreamSubscription? _logSubscription;

  /// 单个 Provider 实例不能实现并发解析，单个 Provider 实例只能持有一个 Webview
  /// 但是 Provider 可以在正在进行的解析未完成时，取消该解析并开始新的解析
  /// 通过递增 ID 标识最新请求，取消旧请求
  int _resolveId = 0;

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
    _resolveId++;
    final currentResolveId = _resolveId;

    if (_webview == null) {
      _webview = WebviewItemControllerFactory.getController();
      await _webview!.init();

      _logSubscription = _webview!.onLog.listen((log) {
        if (!_logController.isClosed) {
          _logController.add(log);
        }
      });
    }

    try {
      await _webview!.loadUrl(
        episodeUrl,
        useLegacyParser,
        offset: offset,
      );

      if (currentResolveId != _resolveId) {
        throw const VideoSourceCancelledException();
      }

      final event = await _webview!.onVideoURLParser.first.timeout(
        timeout,
        onTimeout: () {
          if (currentResolveId != _resolveId) {
            throw const VideoSourceCancelledException();
          }
          throw VideoSourceTimeoutException(timeout);
        },
      );

      if (currentResolveId != _resolveId) {
        throw const VideoSourceCancelledException();
      }

      return VideoSource(
        url: event.$1,
        offset: event.$2,
        type: VideoSourceType.online,
      );
    } catch (e) {
      if (e is VideoSourceCancelledException) {
        rethrow;
      }
      if (currentResolveId != _resolveId) {
        throw const VideoSourceCancelledException();
      }
      rethrow;
    } finally {
      if (currentResolveId == _resolveId) {
        await _webview?.unloadPage();
      }
    }
  }

  @override
  void cancel() {
    _resolveId++;
  }

  @override
  void dispose() {
    cancel();
    _logSubscription?.cancel();
    _logSubscription = null;
    _logController.close();
    _webview?.dispose();
    _webview = null;
  }
}
