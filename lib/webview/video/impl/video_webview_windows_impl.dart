import 'dart:async';
import 'package:webview_windows/webview_windows.dart';
import 'package:kazumi/webview/video/video_webview_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/network/proxy_utils.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/media.dart';

class VideoWebviewWindowsImpl
    extends VideoWebviewController<WebviewController> {
  final List<StreamSubscription> subscriptions = [];

  HeadlessWebview? headlessWebview;

  @override
  Future<void> init() async {
    await _setupProxy();
    headlessWebview ??= HeadlessWebview();
    await headlessWebview!.run();
    await headlessWebview!.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    initEventController.add(true);
  }

  Future<void> _setupProxy() async {
    final bool proxyEnable = GStorage.getSetting(SettingsKeys.proxyEnable);
    if (!proxyEnable) {
      return;
    }

    final String proxyUrl = GStorage.getSetting(SettingsKeys.proxyUrl);
    final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
    if (formattedProxy == null) {
      return;
    }

    try {
      await WebviewController.initializeEnvironment(
        additionalArguments: '--proxy-server=$formattedProxy',
      );
      KazumiLogger().i('WebView: 代理设置成功 $formattedProxy');
    } catch (e) {
      KazumiLogger().e('WebView: 设置代理失败 $e');
    }
  }

  @override
  Future<void> loadUrl(String url, bool useLegacyParser,
      {int offset = 0}) async {
    await unloadPage();
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoLoadingEventController.add(true);
    subscriptions.add(headlessWebview!.onSourceLoaded.listen((data) async {
      final sourceUrl = data['url'] ?? '';
      final videoSourceUrl = extractNestedVideoSourceUrl(sourceUrl);
      if (videoSourceUrl == null) {
        return;
      }
      await _completeVideoSource(
        videoSourceUrl,
        offset,
        'Loading nested video source: $videoSourceUrl',
      );
    }));
    subscriptions.add(headlessWebview!.onM3USourceLoaded.listen((data) async {
      final url = data['url'] ?? '';
      await _completeVideoSource(url, offset, 'Loading m3u8 source: $url');
    }));
    subscriptions.add(headlessWebview!.onVideoSourceLoaded.listen((data) async {
      final url = data['url'] ?? '';
      await _completeVideoSource(url, offset, 'Loading video source: $url');
    }));
    await headlessWebview!.loadUrl(url);
  }

  Future<void> _completeVideoSource(
    String url,
    int offset,
    String logMessage,
  ) async {
    if (headlessWebview == null || isVideoSourceLoaded || url.isEmpty) {
      return;
    }
    isIframeLoaded = true;
    isVideoSourceLoaded = true;
    videoLoadingEventController.add(false);
    logEventController.add(logMessage);
    videoParserEventController.add((url, offset));
    await unloadPage();
  }

  @override
  Future<void> unloadPage() async {
    for (final s in subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    subscriptions.clear();
    await redirect2Blank();
  }

  @override
  Future<void> dispose() async {
    for (final s in subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    subscriptions.clear();
    await headlessWebview?.dispose();
    headlessWebview = null;
    disposeEventControllers();
  }

  // The webview_windows package does not have a method to unload the current page.
  // The loadUrl method opens a new tab, which can lead to memory leaks.
  // Directly disposing of the webview controller would require reinitialization when switching episodes, which is costly.
  // Therefore, this method is used to redirect to a blank page instead.
  Future<void> redirect2Blank() async {
    if (headlessWebview == null) return;
    try {
      await headlessWebview!.executeScript('''
        window.location.href = 'about:blank';
      ''');
    } catch (e) {
      KazumiLogger().d('WebView: redirect2Blank skipped (likely disposed): $e');
    }
  }
}
