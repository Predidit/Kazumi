import 'dart:io';
import 'dart:async';

import 'package:kazumi/webview/captcha/impl/captcha_webview_inappwebview_impl.dart';
import 'package:kazumi/webview/captcha/impl/captcha_webview_windows_impl.dart';
import 'package:kazumi/webview/captcha/impl/captcha_webview_linux_impl.dart';

abstract class CaptchaWebviewController<T> {
  /// Webview controller
  T? webviewController;

  /// For type-1 (captcha image), whether a captcha image has been detected,
  /// used to determine if verification is successful after page navigation
  bool captchaWasFound = false;

  /// For type-2 (auto-click button), we set this flag when the button click is triggered.
  /// Then on page navigation or DOM change, if this flag is set,
  /// we can confirm verification success without relying solely on captcha disappearance.
  bool buttonWasClicked = false;

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

  /// 加载指定 URL，并注入监听验证码图片的 JS 脚本（类型1：图片验证码）
  ///
  /// [url] 要加载的页面地址（一般为搜索 URL）
  /// [captchaXpath] 验证码图片元素的 XPath 选择器
  /// [inputXpath] 可选，验证码输入框的 XPath。如果提供，会在检测验证码前先触发输入框的 focus 事件（某些站点需要）
  Future<void> loadPage(String url, String captchaXpath, {String? inputXpath});

  /// 加载指定 URL，并注入监听验证按钮的 JS 脚本（类型2：自动点击验证按钮）
  ///
  /// 检测到 [buttonXpath] 元素后立即模拟点击；按钮消失时触发 [onCaptchaDisappeared]。
  /// [url] 要加载的页面地址
  /// [buttonXpath] 验证按钮元素的 XPath 选择器
  Future<void> loadPageForButtonClick(String url, String buttonXpath);

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
      return CaptchaWebviewWindowsImpl();
    }
    if (Platform.isLinux) {
      return CaptchaWebviewLinuxImpl();
    }
    // Android, iOS, macOS
    return CaptchaWebviewInAppWebviewImpl();
  }
}
