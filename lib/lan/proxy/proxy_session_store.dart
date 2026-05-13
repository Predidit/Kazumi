import 'dart:math';

/// 一次成功的视频源解析产生一个 [ProxySession]：浏览器拿着 token 通过
/// `/proxy/<token>` 与 `/proxy/<token>/<encodedSubUrl>` 请求视频流，
/// 服务端根据 session 注入正确的 Referer/User-Agent / Cookie。
class ProxySession {
  ProxySession({
    required this.originalUrl,
    required this.referer,
    required this.userAgent,
    required this.pluginName,
    required this.createdAt,
  });

  /// 解析得到的主资源 URL（通常是一个 m3u8 或 mp4 的直链）。
  final String originalUrl;

  /// 源站要求的 Referer，用 plugin 的 referer 字段。
  final String referer;

  /// 模拟桌面端发请求时的 UA，用 plugin 的 userAgent 字段（空则随机一个常见 UA）。
  final String userAgent;

  /// 解析时使用的插件名，便于日志与排错。
  final String pluginName;

  /// 创建时间，用于 TTL。
  final DateTime createdAt;
}

class ProxySessionStore {
  ProxySessionStore({this.ttl = const Duration(hours: 2)});

  final Duration ttl;
  final Map<String, ProxySession> _sessions = {};
  final Random _random = Random.secure();

  /// 创建新 session 并返回它的 token。
  String register(ProxySession session) {
    _purgeExpired();
    final token = _generateToken();
    _sessions[token] = session;
    return token;
  }

  ProxySession? lookup(String token) {
    final session = _sessions[token];
    if (session == null) return null;
    if (_isExpired(session)) {
      _sessions.remove(token);
      return null;
    }
    return session;
  }

  void clear() {
    _sessions.clear();
  }

  void _purgeExpired() {
    final now = DateTime.now();
    _sessions.removeWhere((_, session) => now.difference(session.createdAt) > ttl);
  }

  bool _isExpired(ProxySession session) {
    return DateTime.now().difference(session.createdAt) > ttl;
  }

  String _generateToken() {
    // 16 字节随机，约 128 bit 熵。URL safe Base64。
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return _urlBase64Encode(bytes);
  }

  static String _urlBase64Encode(List<int> bytes) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final sb = StringBuffer();
    var buffer = 0;
    var bitsInBuffer = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bitsInBuffer += 8;
      while (bitsInBuffer >= 6) {
        bitsInBuffer -= 6;
        sb.write(alphabet[(buffer >> bitsInBuffer) & 0x3F]);
      }
    }
    if (bitsInBuffer > 0) {
      sb.write(alphabet[(buffer << (6 - bitsInBuffer)) & 0x3F]);
    }
    return sb.toString();
  }
}
