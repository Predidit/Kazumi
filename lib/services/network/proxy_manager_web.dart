import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/logging/logger.dart';

class ProxyManager {
  ProxyManager._();

  static void applyProxy() {
    DioFactory.reset();
    KazumiLogger().i('Proxy: Web 网络客户端配置已刷新');
  }

  static void clearProxy() => applyProxy();
}
