import 'package:cookie_jar/cookie_jar.dart';
import 'package:kazumi/services/logging/logger.dart';

/// 每条规则的 Cookie 管理器
///
/// 为每条规则维护一个独立的内存 [CookieJar]，
/// 通过 [saveFromWebView] 将 WebView 捕获的 document.cookie 字符串
/// 解析后存入对应规则的 jar。规则请求执行器按需读取并组装 Cookie 请求头。
/// 验证 Cookie 通常与 User-Agent 绑定，故同时记录 WebView 的 UA，
/// 供后续 dio 请求对齐指纹。
/// Cookie 仅在当前 App 会话内有效，重启后需重新验证。
class PluginCookieManager {
  PluginCookieManager._();
  static final PluginCookieManager instance = PluginCookieManager._();

  final Map<String, CookieJar> _jars = {};
  final Map<String, String> _userAgents = {};

  CookieJar _getJar(String pluginName) {
    return _jars.putIfAbsent(pluginName, () => CookieJar());
  }

  Future<void> saveFromWebView(
      String pluginName, String pageUrl, String cookieString,
      {String? userAgent}) async {
    if (userAgent != null && userAgent.trim().isNotEmpty) {
      _userAgents[pluginName] = userAgent.trim();
    }
    if (cookieString.trim().isEmpty) return;
    final uri = Uri.tryParse(pageUrl);
    if (uri == null) return;

    final jar = _getJar(pluginName);
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

  Future<List<Cookie>> loadForRequest(
    String pluginName,
    Uri uri,
  ) async {
    final jar = _jars[pluginName];
    if (jar == null) return <Cookie>[];
    return jar.loadForRequest(uri);
  }

  /// 验证时 WebView 使用的 User-Agent；未验证过的规则返回 null
  String? userAgentFor(String pluginName) => _userAgents[pluginName];
}
