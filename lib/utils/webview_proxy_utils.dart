import 'dart:io';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:hive/hive.dart';

// Android-specific imports
import 'package:flutter_inappwebview_android/flutter_inappwebview_android.dart'
    as android_webview;
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

/// WebView 代理工具类
class WebviewProxyUtils {
  WebviewProxyUtils._();

  static Box setting = GStorage.setting;

  /// 设置 WebView 代理（仅 Android 支持）
  static Future<void> setProxy() async {
    if (!Platform.isAndroid) {
      return;
    }

    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (!proxyEnable) {
      await clearProxy();
      return;
    }

    final String proxyUrl =
        setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
    if (formattedProxy == null) {
      KazumiLogger().w('WebviewProxy: 代理地址格式错误或为空');
      return;
    }

    try {
      final proxyAvailable = await android_webview.AndroidWebViewFeature.instance()
          .isFeatureSupported(WebViewFeature.PROXY_OVERRIDE);
      if (!proxyAvailable) {
        KazumiLogger().w('WebviewProxy: 当前 Android 版本不支持代理');
        return;
      }

      final proxyController = android_webview.AndroidProxyController.instance();
      await proxyController.clearProxyOverride();
      await proxyController.setProxyOverride(
        settings: ProxySettings(
          proxyRules: [
            ProxyRule(url: formattedProxy),
          ],
        ),
      );
      KazumiLogger().i('WebviewProxy: 代理设置成功 $formattedProxy');
    } catch (e) {
      KazumiLogger().e('WebviewProxy: 设置代理失败 $e');
    }
  }

  /// 清除 WebView 代理（仅 Android 支持）
  static Future<void> clearProxy() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final proxyAvailable = await android_webview.AndroidWebViewFeature.instance()
          .isFeatureSupported(WebViewFeature.PROXY_OVERRIDE);
      if (!proxyAvailable) {
        return;
      }

      final proxyController = android_webview.AndroidProxyController.instance();
      await proxyController.clearProxyOverride();
      KazumiLogger().i('WebviewProxy: 代理已清除');
    } catch (e) {
      KazumiLogger().e('WebviewProxy: 清除代理失败 $e');
    }
  }
}
