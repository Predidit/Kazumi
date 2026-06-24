/// 集数源站 URL 归一化。
///
/// 把插件抓取到的原始 `href`（可能是相对路径、缺协议、带尾斜杠或多余噪声）
/// 转换为一个稳定一致的绝对 URL，使"同一集"在播放、下载、历史回填等不同入口
/// 始终得到同一个字符串，可作为身份匹配的主键（`pageUrl`）。
///
/// 归一化规则：
/// - 去除首尾空白；空输入返回空串（调用方据此判断"无 URL"）。
/// - 相对路径基于 [baseUrl] 补全为绝对 URL。
/// - 统一协议口径到 `https`，避免 `http`/`https` 造成的失配
///   （与既有抓取逻辑一致：源页抓取时本就强制 https）。
/// - 去除 path 多余尾斜杠（根路径 `/` 保留）。
/// - 去除空 query。
/// - 幂等：`normalizeEpisodeUrl(b, normalizeEpisodeUrl(b, x))` 等于
///   `normalizeEpisodeUrl(b, x)`。
///
/// 归一化结果同时作为"身份 key"与可访问的"请求 URL"使用。由于既有抓取逻辑
/// 已强制将源页 URL 升级为 https，这里统一到 https 不会改变实际可访问性。
String normalizeEpisodeUrl(String baseUrl, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final rawUri = Uri.tryParse(trimmed);

  Uri? resolved;
  if (rawUri != null && rawUri.hasScheme && rawUri.host.isNotEmpty) {
    // 已是绝对 URL。
    resolved = rawUri;
  } else {
    final baseUri = Uri.tryParse(baseUrl.trim());
    if (baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty) {
      try {
        resolved = baseUri.resolve(trimmed);
      } catch (_) {
        resolved = null;
      }
    }
  }

  // 无法解析为绝对 URL（baseUrl 缺失/非法），原样返回去空白后的输入。
  if (resolved == null || resolved.host.isEmpty) {
    return trimmed;
  }

  // 统一协议到 https。
  if (resolved.scheme == 'http') {
    resolved = resolved.replace(scheme: 'https');
  }

  // 去除 path 尾斜杠（根路径除外）。
  String path = resolved.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  final bool hasQuery = resolved.hasQuery && resolved.query.isNotEmpty;
  final bool hasFragment =
      resolved.hasFragment && resolved.fragment.isNotEmpty;

  final normalized = Uri(
    scheme: resolved.scheme,
    host: resolved.host,
    port: resolved.hasPort ? resolved.port : null,
    path: path,
    query: hasQuery ? resolved.query : null,
    fragment: hasFragment ? resolved.fragment : null,
  );

  return normalized.toString();
}
