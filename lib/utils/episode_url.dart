/// 集数源站 URL 归一化。
///
/// 把插件抓取到的原始 `href`（可能是相对路径、缺协议、带尾斜杠或多余噪声）
/// 转换为一个稳定一致的绝对 URL，使"同一集"在播放、下载、历史回填等不同入口
/// 始终得到同一个字符串，可作为身份匹配的主键（`pageUrl`）。
///
/// 归一化规则：
/// - 去除首尾空白；空输入返回空串（调用方据此判断"无 URL"）。
/// - 相对路径基于 [baseUrl] 补全为绝对 URL。
/// - 与 [baseUrl] 同站（同 host、同显式端口）的 URL，协议统一到 [baseUrl]
///   声明的协议，避免同一集因 `http`/`https` 混用产生两个 key；跨站或端口
///   不同的 URL 保持原协议不动——规则站点可能仅支持 http（如自建反代），
///   改写协议会导致无法访问。
/// - 去除 path 多余尾斜杠（根路径 `/` 保留）。
/// - 去除空 query。
/// - 幂等：`normalizeEpisodeUrl(b, normalizeEpisodeUrl(b, x))` 等于
///   `normalizeEpisodeUrl(b, x)`。
///
/// 归一化结果同时作为"身份 key"与可访问的"请求 URL"使用，因此归一化
/// 不得改变 URL 实际指向的端点，协议口径以规则中用户声明的 [baseUrl] 为准。
String normalizeEpisodeUrl(String baseUrl, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final rawUri = Uri.tryParse(trimmed);
  final baseUri = Uri.tryParse(baseUrl.trim());
  final hasValidBase =
      baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty;

  Uri? resolved;
  if (rawUri != null && rawUri.hasScheme && rawUri.host.isNotEmpty) {
    // 已是绝对 URL。
    resolved = rawUri;
  } else if (hasValidBase) {
    try {
      resolved = baseUri.resolve(trimmed);
    } catch (_) {
      resolved = null;
    }
  }

  // 无法解析为绝对 URL（baseUrl 缺失/非法），原样返回去空白后的输入。
  if (resolved == null || resolved.host.isEmpty) {
    return trimmed;
  }

  // 同站 URL 的协议统一到 baseUrl 声明的协议。
  if (hasValidBase &&
      _isHttpScheme(baseUri.scheme) &&
      _isHttpScheme(resolved.scheme) &&
      resolved.scheme != baseUri.scheme &&
      resolved.host == baseUri.host &&
      resolved.hasPort == baseUri.hasPort &&
      (!resolved.hasPort || resolved.port == baseUri.port)) {
    resolved = resolved.replace(scheme: baseUri.scheme);
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

bool _isHttpScheme(String scheme) => scheme == 'http' || scheme == 'https';
