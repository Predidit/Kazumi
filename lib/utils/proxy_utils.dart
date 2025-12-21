/// 代理相关的工具函数
class ProxyUtils {
  // 防止实例化
  ProxyUtils._();

  /// 解析代理 URL，返回 (协议, 主机, 端口)
  ///
  /// 支持的格式:
  /// - http://127.0.0.1:7890
  /// - https://127.0.0.1:7890
  /// - socks5://127.0.0.1:7890
  /// - socks://127.0.0.1:7890
  /// - 127.0.0.1:7890 (默认 HTTP)
  static (String, String, int)? parseProxyUrl(String url) {
    url = url.trim();
    if (url.isEmpty) return null;

    String protocol = 'HTTP';
    String hostPort = url;

    if (url.toLowerCase().startsWith('http://')) {
      protocol = 'HTTP';
      hostPort = url.substring(7);
    } else if (url.toLowerCase().startsWith('https://')) {
      protocol = 'HTTP';
      hostPort = url.substring(8);
    } else if (url.toLowerCase().startsWith('socks5://')) {
      protocol = 'SOCKS5';
      hostPort = url.substring(9);
    } else if (url.toLowerCase().startsWith('socks://')) {
      protocol = 'SOCKS5';
      hostPort = url.substring(8);
    }

    // 解析主机和端口
    final parts = hostPort.split(':');
    if (parts.length != 2) return null;

    final host = parts[0];
    final port = int.tryParse(parts[1]);
    if (host.isEmpty || port == null) return null;

    return (protocol, host, port);
  }

  /// 获取代理类型的显示文本
  static String getProxyTypeHint(String proxyUrl) {
    if (proxyUrl.isEmpty) return '';
    final parsed = parseProxyUrl(proxyUrl);
    if (parsed == null) return '格式错误';
    return '${parsed.$1} 代理';
  }

  /// 验证代理 URL 是否有效
  static bool isValidProxyUrl(String url) {
    return parseProxyUrl(url) != null;
  }
}
