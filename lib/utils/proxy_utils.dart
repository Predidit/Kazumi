/// 代理相关的工具函数
class ProxyUtils {
  // 防止实例化
  ProxyUtils._();

  /// 解析代理 URL，返回 (主机, 端口)
  ///
  /// 支持的格式:
  /// - http://127.0.0.1:7890
  /// - 127.0.0.1:7890
  static (String, int)? parseProxyUrl(String url) {
    url = url.trim();
    if (url.isEmpty) return null;

    String hostPort = url;

    // 移除 http:// 前缀
    if (url.toLowerCase().startsWith('http://')) {
      hostPort = url.substring(7);
    } else if (url.toLowerCase().startsWith('https://')) {
      hostPort = url.substring(8);
    }

    // 解析主机和端口
    final parts = hostPort.split(':');
    if (parts.length != 2) return null;

    final host = parts[0];
    final port = int.tryParse(parts[1]);
    if (host.isEmpty || port == null) return null;

    return (host, port);
  }

  /// 获取格式化的代理 URL（用于 mpv）
  static String? getFormattedProxyUrl(String url) {
    final parsed = parseProxyUrl(url);
    if (parsed == null) return null;
    return 'http://${parsed.$1}:${parsed.$2}';
  }

  /// 验证代理 URL 是否有效
  static bool isValidProxyUrl(String url) {
    return parseProxyUrl(url) != null;
  }
}
