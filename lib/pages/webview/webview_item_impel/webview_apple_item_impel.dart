import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

class WebviewAppleItemImpel extends StatefulWidget {
  const WebviewAppleItemImpel({super.key});

  @override
  State<WebviewAppleItemImpel> createState() => _WebviewAppleItemImpelState();
}

class _WebviewAppleItemImpelState extends State<WebviewAppleItemImpel> {
  final webviewAppleItemController = Modular.get<WebviewItemController>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    webviewAppleItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams(
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: '''
            function removeLazyLoading() {
              document.querySelectorAll('iframe[loading="lazy"]').forEach(iframe => {
                console.log('Removing lazy loading from:', iframe.src);
                iframe.removeAttribute('loading');
              });
            }
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', removeLazyLoading);
            } else {
              removeLazyLoading();
            }
          ''',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        userAgent: Utils.getRandomUA(),
        mediaPlaybackRequiresUserGesture: true,
        useOnLoadResource: false,
        cacheEnabled: false,
        isInspectable: false,
        contentBlockers: [
          ContentBlocker(
            trigger: ContentBlockerTrigger(
                urlFilter: r"^https?://.+?devtools-detector\.js",
                resourceType: [
                  ContentBlockerTriggerResourceType.SCRIPT,
                ]),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*', resourceType: [
              ContentBlockerTriggerResourceType.IMAGE,
            ]),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(
                urlFilter: r"^https?://.+?googleads",
                resourceType: [
                  ContentBlockerTriggerResourceType.DOCUMENT,
                ]),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(
                urlFilter: r"^https?://.+?googlesyndication\.com",
                resourceType: [
                  ContentBlockerTriggerResourceType.DOCUMENT,
                ]),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(
                urlFilter: r"^https?://.+?prestrain\.html",
                resourceType: [
                  ContentBlockerTriggerResourceType.DOCUMENT,
                ]),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(
                urlFilter: r"^https?://.+?prestrain%2Ehtml",
                resourceType: [
                  ContentBlockerTriggerResourceType.DOCUMENT,
                ]),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(
                urlFilter: r"^https?://.+?adtrafficquality",
                resourceType: [
                  ContentBlockerTriggerResourceType.DOCUMENT,
                ]),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
        ],
      ),
      onWebViewCreated: (controller) {
        debugPrint('[WebView] Created');
        webviewAppleItemController.webviewController = controller;
        webviewAppleItemController.init();
      },
      onLoadStart: (controller, url) {
        debugPrint('[WebView] Started loading: $url');
      },
      onLoadStop: (controller, url) {
        debugPrint('[WebView] Loading completed: $url');
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint(
            '[WebView] Console.${consoleMessage.messageLevel}: ${consoleMessage.message}');
      },
      onLoadResource: (controller, resource) {
        debugPrint(
            '[WebView] Resource: ${resource.url} - ${resource.initiatorType}');
      },
      onReceivedError: (controller, request, error) {
        debugPrint(
            '[WebView] Error: ${error.toString()} - Request: ${request.url}');
      },
    )).build(context);
  }
}
