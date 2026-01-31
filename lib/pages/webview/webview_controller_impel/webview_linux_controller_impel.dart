import 'dart:async';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

class WebviewLinuxItemControllerImpel extends WebviewItemController<Webview> {
  bool bridgeInited = false;

  @override
  Future<void> init() async {
    final proxyConfig = _getProxyConfiguration();
    webviewController ??= await WebviewWindow.create(
      configuration: CreateConfiguration(
        headless: true,
        proxy: proxyConfig,
        userScripts: const [
          UserScript(
              source: blobScript,
              injectionTime: UserScriptInjectionTime.documentStart,
              forAllFrames: true),
          UserScript(
              source: iframeScript,
              injectionTime: UserScriptInjectionTime.documentEnd,
              forAllFrames: true),
          UserScript(
              source: videoScript,
              injectionTime: UserScriptInjectionTime.documentEnd,
              forAllFrames: true)
        ],
      ),
    );
    bridgeInited = false;
    initEventController.add(true);
  }

  ProxyConfiguration? _getProxyConfiguration() {
    final setting = GStorage.setting;
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (!proxyEnable) {
      return null;
    }

    final String proxyUrl =
        setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    final parsed = ProxyUtils.parseProxyUrl(proxyUrl);
    if (parsed == null) {
      return null;
    }

    final (host, port) = parsed;
    KazumiLogger().i('WebView: 代理设置成功 $host:$port');
    return ProxyConfiguration(host: host, port: port);
  }

  Future<void> initBridge(bool useNativePlayer, bool useLegacyParser) async {
    await initJSBridge(useNativePlayer, useLegacyParser);
    bridgeInited = true;
  }

  @override
  Future<void> loadUrl(String url, bool useNativePlayer, bool useLegacyParser,
      {int offset = 0}) async {
    await unloadPage();
    if (!bridgeInited) {
      await initBridge(useNativePlayer, useLegacyParser);
    }
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoLoadingEventController.add(true);
    webviewController!.launch(url);
  }

  @override
  Future<void> unloadPage() async {
    await redirect2Blank();
  }

  @override
  void dispose() {
    webviewController!.close();
    bridgeInited = false;
  }

  Future<void> initJSBridge(bool useNativePlayer, bool useLegacyParser) async {
    webviewController!.addOnWebMessageReceivedCallback((message) async {
      if (message.contains('iframeMessage:')) {
        String messageItem =
            Uri.encodeFull(message.replaceFirst('iframeMessage:', ''));
        logEventController
            .add('Callback received: [iframe] ${Uri.decodeFull(messageItem)}');
        if ((messageItem.contains('http') || messageItem.startsWith('//')) &&
            !messageItem.contains('googleads') &&
            !messageItem.contains('googlesyndication.com') &&
            !messageItem.contains('prestrain.html') &&
            !messageItem.contains('prestrain%2Ehtml') &&
            !messageItem.contains('adtrafficquality')) {
          if (Utils.decodeVideoSource(messageItem) !=
                  Uri.encodeFull(messageItem) &&
              useNativePlayer &&
              useLegacyParser) {
            logEventController.add('Parsing video source $messageItem');
            isIframeLoaded = true;
            isVideoSourceLoaded = true;
            videoLoadingEventController.add(false);
            logEventController.add(
                'Loading video source ${Utils.decodeVideoSource(messageItem)}');
            unloadPage();
            videoParserEventController
                .add((Utils.decodeVideoSource(messageItem), offset));
          }
        }
      }
      if (message.contains('videoMessage:')) {
        String messageItem =
            Uri.encodeFull(message.replaceFirst('videoMessage:', ''));
        logEventController
            .add('Callback received: [video] ${Uri.decodeFull(messageItem)}');
        if (messageItem.contains('http')) {
          String videoUrl = Uri.decodeFull(messageItem);
          logEventController.add('Loading video source: $videoUrl');
          isIframeLoaded = true;
          isVideoSourceLoaded = true;
          videoLoadingEventController.add(false);
          if (useNativePlayer) {
            unloadPage();
            videoParserEventController.add((videoUrl, offset));
          }
        }
      }
    });
  }

  static const String iframeScript = """
    var iframes = document.getElementsByTagName('iframe');
    for (var i = 0; i < iframes.length; i++) {
        var iframe = iframes[i];
        var src = iframe.getAttribute('src');
        if (src) {
          window.webkit.messageHandlers.msgToNative.postMessage('iframeMessage:' + src);
        }
    }
  """;

  static const String videoScript = """
    function processVideoElement(video) {
      let src = video.getAttribute('src');
      if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
        window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + src);
        return;
      }
      const sources = video.getElementsByTagName('source');
      for (let source of sources) {
        src = source.getAttribute('src');
        if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
          window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + src);
          return;
        }
      }
    }

    document.querySelectorAll('video').forEach(processVideoElement);

    const _observer = new MutationObserver((mutations) => {
      mutations.forEach(mutation => {
        if (mutation.type === 'attributes' && mutation.target.nodeName === 'VIDEO') {
          processVideoElement(mutation.target);
        }
        mutation.addedNodes.forEach(node => {
          if (node.nodeName === 'VIDEO') processVideoElement(node);
          if (node.querySelectorAll) {
            node.querySelectorAll('video').forEach(processVideoElement);
          }
        });
      });  
    });

    _observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src']
    });
  """;

  static const String blobScript = """
    const _r_text = window.Response.prototype.text;
    window.Response.prototype.text = function () {
        return new Promise((resolve, reject) => {
            _r_text.call(this).then((text) => {
                resolve(text);
                if (text.trim().startsWith("#EXTM3U")) {
                    window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + this.url);
                }
            }).catch(reject);
        });
    }

    const _open = window.XMLHttpRequest.prototype.open;
    window.XMLHttpRequest.prototype.open = function (...args) {
        this.addEventListener("load", () => {
            try {
                let content = this.responseText;
                if (content.trim().startsWith("#EXTM3U")) {
                    window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + args[1]);
                };
            } catch { }
        });
        return _open.apply(this, args);
    }
  """;

  Future<void> redirect2Blank() async {
     webviewController?.launch("about:blank");
  }
}
