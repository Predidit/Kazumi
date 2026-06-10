import 'dart:async';

import 'package:kazumi/webview/video/video_webview_controller.dart';
import 'package:kazumi/services/video_source/video_source_service.dart';

/// WebView 视频源解析服务
///
/// 使用 WebView 解析视频页面，提取视频源 URL。
/// WebView 实例在服务生命周期内复用，切换集数时调用 unloadPage 释放页面资源，
/// 仅在 [dispose] 时才真正销毁 WebView。
class WebViewVideoSourceService implements IVideoSourceService {
  VideoWebviewController? _webview;
  StreamSubscription? _logSubscription;
  Completer<void>? _cancelCompleter;

  /// 单个服务实例不能实现并发解析，单个服务实例只能持有一个 WebView。
  /// 服务可以在正在进行的解析未完成时，取消该解析并开始新的解析。
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
    final previousCancelCompleter = _cancelCompleter;
    if (previousCancelCompleter != null &&
        !previousCancelCompleter.isCompleted) {
      previousCancelCompleter.complete();
    }
    _resolveId++;
    final currentResolveId = _resolveId;
    final cancelCompleter = Completer<void>();
    _cancelCompleter = cancelCompleter;

    if (_webview == null) {
      _webview = VideoWebviewControllerFactory.getController();
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

      final parserFuture = _webview!.onVideoURLParser.first.timeout(
        timeout,
        onTimeout: () {
          if (currentResolveId != _resolveId) {
            throw const VideoSourceCancelledException();
          }
          throw VideoSourceTimeoutException(timeout);
        },
      );
      final cancelFuture = cancelCompleter.future.then<(String, int)>((_) {
        throw const VideoSourceCancelledException();
      });
      final event = await Future.any([parserFuture, cancelFuture]);

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
      if (currentResolveId == _resolveId ||
          identical(_cancelCompleter, cancelCompleter)) {
        await _webview?.unloadPage();
      }
      if (identical(_cancelCompleter, cancelCompleter)) {
        _cancelCompleter = null;
      }
    }
  }

  @override
  void cancel() {
    _resolveId++;
    final cancelCompleter = _cancelCompleter;
    if (cancelCompleter != null && !cancelCompleter.isCompleted) {
      cancelCompleter.complete();
    }
  }

  @override
  Future<void> dispose() async {
    cancel();
    await _logSubscription?.cancel();
    _logSubscription = null;
    if (!_logController.isClosed) {
      await _logController.close();
    }
    await _webview?.dispose();
    _webview = null;
  }
}
