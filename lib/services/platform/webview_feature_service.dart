import 'dart:io';

import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

class WebViewFeatureService {
  WebViewFeatureService._();

  static bool? _isDocumentStartScriptSupported;

  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      _isDocumentStartScriptSupported = await PlatformWebViewFeature.static()
          .isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT);
    }
  }

  static bool get isDocumentStartScriptSupported =>
      _isDocumentStartScriptSupported ?? false;
}
