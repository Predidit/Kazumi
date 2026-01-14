import 'package:kazumi/request/request.dart';

/// 代理管理器
/// 统一管理 Dio HTTP 请求的代理设置
/// 注意：WebView 代理在各平台 controller 初始化时单独处理
class ProxyManager {
  ProxyManager._();

  /// 应用代理设置
  static void applyProxy() {
    Request.setProxy();
  }

  /// 清除代理设置
  static void clearProxy() {
    Request.disableProxy();
  }
}
