import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/webview_proxy_utils.dart';

/// 代理管理器
/// 统一管理所有组件的代理设置，便于未来扩展
class ProxyManager {
  ProxyManager._();

  /// 应用代理设置到所有组件
  static Future<void> applyProxy() async {
    // Dio HTTP 请求代理
    Request.setProxy();
    // Android WebView 代理
    await WebviewProxyUtils.setProxy();
    // 未来新增组件在此添加
  }

  /// 清除所有组件的代理设置
  static Future<void> clearProxy() async {
    // Dio HTTP 请求代理
    Request.disableProxy();
    // Android WebView 代理
    await WebviewProxyUtils.clearProxy();
    // 未来新增组件在此添加
  }
}
