import 'package:cached_network_image/cached_network_image.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/proxy_aware_image_cache_manager.dart';

class ProxyManager {
  ProxyManager._();

  static void applyProxy() {
    DioFactory.reset();
    _applyImageCacheManager();
    KazumiLogger().i('Proxy: 网络客户端配置已刷新');
  }

  static void clearProxy() {
    DioFactory.reset();
    _applyImageCacheManager();
    KazumiLogger().i('Proxy: 网络客户端代理已清除');
  }

  static void _applyImageCacheManager() {
    CachedNetworkImageProvider.defaultCacheManager =
        ProxyAwareImageCacheManager.instance;
  }
}
