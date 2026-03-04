import 'dart:io';
import 'dart:async';

import 'package:kazumi/webview/captcha_webview_impel/captcha_inappwebview_impel.dart';
import 'package:kazumi/webview/captcha_webview_impel/captcha_windows_impel.dart';
import 'package:kazumi/webview/captcha_webview_impel/captcha_linux_impel.dart';

abstract class CaptchaWebviewController {
  final StreamController<String> captchaImageFoundController =
      StreamController<String>.broadcast();
  final StreamController<void> captchaDisappearedController =
      StreamController<void>.broadcast();
  final StreamController<bool> initEventController =
      StreamController<bool>.broadcast();
  final StreamController<String> logEventController =
      StreamController<String>.broadcast();

  /// WebView 初始化完成事件
  Stream<bool> get onInitialized => initEventController.stream;

  /// 验证码图片 src 找到时触发（携带图片绝对 URL）
  Stream<String> get onCaptchaImageFound => captchaImageFoundController.stream;

  /// 验证码图片从页面消失时触发
  Stream<void> get onCaptchaDisappeared => captchaDisappearedController.stream;

  /// 调试日志
  Stream<String> get onLog => logEventController.stream;

  /// 初始化 WebView
  Future<void> init();

  /// 加载指定 URL，并注入监听验证码图片的 JS 脚本
  ///
  /// [url] 要加载的页面地址（一般为搜索 URL）
  /// [captchaXpath] 验证码图片元素的 XPath 选择器
  Future<void> loadPage(String url, String captchaXpath);

  /// 在 WebView 内通过 JS 模拟输入验证码并模拟点击提交按钮
  ///
  /// [captchaCode] 用户输入的验证码文本
  /// [inputXpath]  验证码输入框元素的 XPath
  /// [buttonXpath] 提交按钮元素的 XPath
  Future<void> submitCaptchaInteract(
      String captchaCode, String inputXpath, String buttonXpath);

  /// 获取当前页面的 Cookie 字符串（"key1=val1; key2=val2"）
  ///
  /// [pageUrl] 当前加载的页面地址，部分平台用于精确过滤 Cookie
  Future<String> getCookieString(String pageUrl);

  /// 卸载当前页面（跳转到 about:blank）
  Future<void> unloadPage();

  /// 释放 WebView 资源
  void dispose();
}

class CaptchaWebviewControllerFactory {
  static CaptchaWebviewController getController() {
    if (Platform.isWindows) {
      return CaptchaWindowsImpel();
    }
    if (Platform.isLinux) {
      return CaptchaLinuxImpel();
    }
    // Android, iOS, macOS
    return CaptchaInAppWebviewImpel();
  }
}
