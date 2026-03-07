import 'package:cookie_jar/cookie_jar.dart';
import 'package:kazumi/utils/logger.dart';

/// 每条规则的 Cookie 管理器
///
/// 为每条规则维护一个独立的内存 [CookieJar]，
/// 通过 [saveFromWebView] 将 WebView 捕获的 document.cookie 字符串
/// 解析后存入对应规则的 jar，用于后续 HTTP 请求的 CookieManager 拦截器。
/// Cookie 仅在当前 App 会话内有效，重启后需重新验证。
class PluginCookieManager {
  PluginCookieManager._();
  static final PluginCookieManager instance = PluginCookieManager._();

  final Map<String, CookieJar> _jars = {};

  CookieJar getJar(String pluginName) {
    return _jars.putIfAbsent(pluginName, () => CookieJar());
  }

  Future<void> saveFromWebView(
      String pluginName, String pageUrl, String cookieString) async {
    if (cookieString.trim().isEmpty) return;
    final uri = Uri.tryParse(pageUrl);
    if (uri == null) return;

    final jar = getJar(pluginName);
    final cookies = _parseCookieString(cookieString, uri);
    if (cookies.isEmpty) return;

    await jar.saveFromResponse(uri, cookies);
    KazumiLogger().i(
        '[PluginCookieManager] Saved ${cookies.length} cookies for $pluginName');
  }

  /// 解析字符串为 [Cookie] 列表
  List<Cookie> _parseCookieString(String raw, Uri uri) {
    final cookies = <Cookie>[];
    for (final part in raw.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex <= 0) continue;
      final name = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();
      try {
        final cookie = Cookie(name, value)
          ..domain = uri.host
          ..path = '/';
        cookies.add(cookie);
      } catch (_) {}
    }
    return cookies;
  }

  void clearCookies(String pluginName) {
    _jars.remove(pluginName);
  }

  bool hasCookies(String pluginName) {
    return _jars.containsKey(pluginName);
  }
}
