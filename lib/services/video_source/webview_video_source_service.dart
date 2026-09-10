import 'dart:async';

import 'package:kazumi/services/video_source/video_source_service.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:kazumi/webview/video/video_webview_controller.dart';

class WebViewVideoSourceService implements IVideoSourceService {
  VideoWebviewController? _webview;
  StreamSubscription? _logSubscription;

  // Each service serializes access to its reusable WebView.
  final _resolves = AsyncSerialQueue();
  Future<void>? _disposeFuture;
  _ResolveRequest? _activeRequest;

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
    if (_disposeFuture != null) {
      throw const VideoSourceCancelledException();
    }

    _activeRequest?.cancel();
    final request = _ResolveRequest();
    _activeRequest = request;

    return _resolves.run(
      () => _runResolve(
        request,
        episodeUrl,
        useLegacyParser: useLegacyParser,
        offset: offset,
        timeout: timeout,
      ),
    );
  }

  Future<VideoSource> _runResolve(
    _ResolveRequest request,
    String episodeUrl, {
    required bool useLegacyParser,
    required int offset,
    required Duration timeout,
  }) async {
    request.throwIfNotCurrent(_activeRequest);

    if (_webview == null) {
      _webview = VideoWebviewControllerFactory.getController();
      await _webview!.init();

      _logSubscription = _webview!.onLog.listen((log) {
        if (!_logController.isClosed) {
          _logController.add(log);
        }
      });
    }

    var didStartLoad = false;
    try {
      request.throwIfNotCurrent(_activeRequest);
      didStartLoad = true;
      await _webview!.loadUrl(
        episodeUrl,
        useLegacyParser,
        offset: offset,
      );

      request.throwIfNotCurrent(_activeRequest);

      final parserFuture = _webview!.onVideoURLParser.first.timeout(
        timeout,
        onTimeout: () {
          request.throwIfNotCurrent(_activeRequest);
          throw VideoSourceTimeoutException(timeout);
        },
      );
      final cancelFuture = request.cancelled.then<VideoParserEvent>((_) {
        throw const VideoSourceCancelledException();
      });
      final event = await Future.any([parserFuture, cancelFuture]);

      request.throwIfNotCurrent(_activeRequest);

      return VideoSource(
        url: event.url,
        offset: event.offset,
        type: VideoSourceType.online,
        format: event.format,
      );
    } catch (e) {
      if (e is VideoSourceCancelledException) {
        rethrow;
      }
      request.throwIfNotCurrent(_activeRequest);
      rethrow;
    } finally {
      if (didStartLoad) {
        await _webview?.unloadPage();
      }
      if (identical(_activeRequest, request)) {
        _activeRequest = null;
      }
    }
  }

  @override
  void cancel() {
    _activeRequest?.cancel();
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() {
    cancel();
    // Release the WebView only after every queued request has settled.
    return _resolves.run(() async {
      _activeRequest = null;
      await _logSubscription?.cancel();
      _logSubscription = null;
      await _logController.close();
      await _webview?.dispose();
      _webview = null;
    });
  }
}

class _ResolveRequest {
  final Completer<void> _cancelled = Completer<void>();

  Future<void> get cancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

  void throwIfNotCurrent(_ResolveRequest? current) {
    if (_cancelled.isCompleted || !identical(current, this)) {
      throw const VideoSourceCancelledException();
    }
  }
}
