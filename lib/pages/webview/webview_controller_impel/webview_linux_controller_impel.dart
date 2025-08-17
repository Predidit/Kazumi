import 'dart:async';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

class WebviewLinuxItemControllerImpel extends WebviewItemController<Webview> {
  
  bool bridgeInited = false;

  @override
  Future<void> init() async {
    webviewController ??= await WebviewWindow.create(
      configuration: const CreateConfiguration(userScripts: [
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
      ]),
    );
    bridgeInited = false;
    initEventController.add(true);
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
        logEventController.add(
            'If there is audio but no video, please report it to the rule developer.');
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
    window.webkit.messageHandlers.msgToNative.postMessage('iframeMessage:' + 'The number of iframe tags is' + iframes.length);
    for (var i = 0; i < iframes.length; i++) {
        var iframe = iframes[i];
        var src = iframe.getAttribute('src');
        if (src) {
          window.webkit.messageHandlers.msgToNative.postMessage('iframeMessage:' + src);
        }
    }
  """;

  static const String videoScript = """
    var videos = document.querySelectorAll('video');
    window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + 'The number of video tags is' + videos.length);
    for (var i = 0; i < videos.length; i++) {
      var src = videos[i].getAttribute('src');
      if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
        window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + src);
      } 
    }

    document.querySelectorAll('iframe').forEach((iframe) => {
      try {
        iframe.contentWindow.eval(`
          var videos = document.querySelectorAll('video');
          window.parent.postMessage({ message: 'videoMessage:' + 'The number of video tags is' + videos.length }, "*");
          for (var i = 0; i < videos.length; i++) {
            var src = videos[i].getAttribute('src');
            if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
              window.parent.postMessage({ message: 'videoMessage:' + src }, "*");
            } 
          }
                `);
      } catch { }
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
    await webviewController!.evaluateJavaScript('''
      window.location.href = 'about:blank';
    ''');
  }
}
