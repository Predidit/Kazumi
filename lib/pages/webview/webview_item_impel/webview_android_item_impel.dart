import 'package:flutter/material.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/webview/webview_controller_impel/webview_android_controller_impel.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

class WebviewAndroidItemImpel extends StatefulWidget {
  const WebviewAndroidItemImpel({super.key});

  @override
  State<WebviewAndroidItemImpel> createState() =>
      _WebviewAndroidItemImpelState();
}

class _WebviewAndroidItemImpelState extends State<WebviewAndroidItemImpel> {
  final webviewAndroidItemController =
      Modular.get<WebviewItemController>() as WebviewAndroidItemControllerImpel;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    webviewAndroidItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams(
      initialSettings: InAppWebViewSettings(
        userAgent: Utils.getRandomUA(),
        mediaPlaybackRequiresUserGesture: true,
        cacheEnabled: false,
        blockNetworkImage: true,
        loadsImagesAutomatically: false,
        upgradeKnownHostsToHTTPS: false,
        safeBrowsingEnabled: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
        geolocationEnabled: false,
      ),
      onWebViewCreated: (controller) {
        debugPrint('[WebView] Created');
        webviewAndroidItemController.webviewController = controller;
        webviewAndroidItemController.init();
      },
      onLoadStart: (controller, url) async {
        debugPrint('[WebView] Started loading: $url');
        if (url.toString() != 'about:blank') {
          await webviewAndroidItemController.onLoadStart();
        }
      },
      onLoadStop: (controller, url) {
        debugPrint('[WebView] Loading completed: $url');
      },
    )).build(context);
  }
}
