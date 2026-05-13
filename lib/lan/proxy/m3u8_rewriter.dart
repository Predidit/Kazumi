import 'dart:convert';

/// 将 m3u8 文本中所有引用到其它资源的 URI 重写为通过本地代理访问。
///
/// 处理范围（覆盖绝大多数常见在线番剧 m3u8）：
/// - `#EXT-X-STREAM-INF` 后紧跟一行的子 playlist URI
/// - `#EXTINF:` 后紧跟一行的分片 URI
/// - `#EXT-X-KEY` 内的 `URI="..."` 属性（解密密钥）
/// - `#EXT-X-MAP` 内的 `URI="..."` 属性（初始化片段）
///
/// 所有 URI 会被解析为相对于 [baseUrl] 的绝对 URL，再以 `subUriBuilder(absUrl)`
/// 包装为本地代理 URL。
class M3u8Rewriter {
  const M3u8Rewriter({required this.baseUrl, required this.subUriBuilder});

  /// 当前 m3u8 自身的 URL，用于解析相对 URI。
  final Uri baseUrl;

  /// 给定一条绝对 URL，返回浏览器应该请求的本地代理 URL。
  final String Function(String absoluteUrl) subUriBuilder;

  String rewrite(String input) {
    final lines = const LineSplitter().convert(input);
    final out = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        out.writeln();
        continue;
      }

      if (line.startsWith('#')) {
        // 处理 EXT-X-KEY / EXT-X-MAP 等行内带 URI 属性的标签
        final rewritten = _rewriteUriAttributeInTag(line);
        out.writeln(rewritten);
        continue;
      }

      // 非注释行 = 资源 URI（playlist 或 分片）
      out.writeln(_wrap(line));
    }
    return out.toString();
  }

  String _rewriteUriAttributeInTag(String line) {
    // 匹配 URI="..." 属性，可能出现在 #EXT-X-KEY / #EXT-X-MAP / #EXT-X-SESSION-DATA 等
    final regex = RegExp(r'URI="([^"]+)"');
    return line.replaceAllMapped(regex, (match) {
      final original = match.group(1)!;
      final wrapped = _wrap(original);
      return 'URI="$wrapped"';
    });
  }

  String _wrap(String maybeRelativeUri) {
    final trimmed = maybeRelativeUri.trim();
    if (trimmed.isEmpty) return maybeRelativeUri;
    try {
      final resolved = baseUrl.resolve(trimmed);
      return subUriBuilder(resolved.toString());
    } catch (_) {
      // 解析失败就原样保留——播放器可能直接拉得到，也可能 404，但不能让重写本身崩溃
      return maybeRelativeUri;
    }
  }
}
