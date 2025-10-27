import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/pages/webview/webview_item_impel/webview_android_item_impel.dart';
import 'package:kazumi/pages/webview/webview_item_impel/webview_item_impel.dart';
import 'package:kazumi/pages/webview/webview_item_impel/webview_windows_item_impel.dart';
import 'package:kazumi/pages/webview/webview_item_impel/webview_linux_item_impel.dart';
import 'package:kazumi/pages/webview/webview_item_impel/webview_apple_item_impel.dart';
import 'package:kazumi/utils/utils.dart';

class WebviewItem extends StatefulWidget {
  const WebviewItem({super.key});

  @override
  State<WebviewItem> createState() => _WebviewItemState();
}

class _WebviewItemState extends State<WebviewItem> {
  @override
  Widget build(BuildContext context) {
    return webviewUniversal;
  }
}

Widget get webviewUniversal {
  if (Platform.isWindows) {
    return const WebviewWindowsItemImpel();
  }
  if (Platform.isLinux) {
    return const WebviewLinuxItemImpel();
  }
  if (Platform.isMacOS || Platform.isIOS) {
    return const WebviewAppleItemImpel();
  }
  if (Platform.isAndroid && Utils.isDocumentStartScriptSupported) {
    return const WebviewAndroidItemImpel();
  }
  return const WebviewItemImpel();
}
