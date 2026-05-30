import 'package:cached_network_image/cached_network_image.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/proxy_aware_image_cache_manager.dart';

/// 代理管理器
/// 统一管理 Dio HTTP 请求和 cached_network_image 的代理设置
/// 注意：WebView 代理在各平台 controller 初始化时单独处理
class ProxyManager {
  ProxyManager._();

  /// 应用代理设置
  static void applyProxy() {
    DioFactory.reset();
    _applyImageCacheManager();
    KazumiLogger().i('Proxy: network client configuration refreshed');
  }

  /// 清除代理设置
  static void clearProxy() {
    DioFactory.reset();
    _applyImageCacheManager();
    KazumiLogger().i('Proxy: network client proxy cleared');
  }

  static void _applyImageCacheManager() {
    CachedNetworkImageProvider.defaultCacheManager =
        ProxyAwareImageCacheManager.instance;
  }
}
