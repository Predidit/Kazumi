import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'package:kazumi/lan/proxy/m3u8_rewriter.dart';
import 'package:kazumi/lan/proxy/proxy_session_store.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/m3u8_ad_filter.dart';
import 'package:kazumi/utils/m3u8_parser.dart';

/// 处理 `/proxy/<token>` 与 `/proxy/<token>/<encodedSubUrl>` 的请求。
///
/// 设计：
/// - 浏览器请求 token 的根路径时，目标 URL 取 session.originalUrl
/// - 请求带子路径时，子路径是 base64url 编码的绝对 URL（由 m3u8 重写产出）
/// - 服务端用宿主的 HTTP client 拉取目标，注入 Referer/UA，透传 Range
/// - 若响应是 m3u8 文本，重写内部 URI 后再返回；否则原样转发
class VideoProxyHandler {
  VideoProxyHandler({required this.sessionStore, HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient() {
    _httpClient.autoUncompress = false;
    _httpClient.connectionTimeout = const Duration(seconds: 15);
  }

  final ProxySessionStore sessionStore;
  final HttpClient _httpClient;

  /// `/proxy/<token>` 路径前缀，外部构造代理 URL 时用作根。
  static const String pathPrefix = '/proxy';

  static String buildRootUrl(String token) => '$pathPrefix/$token';

  static String buildSubUrl(String token, String absoluteTargetUrl) {
    final encoded = base64Url.encode(utf8.encode(absoluteTargetUrl));
    return '$pathPrefix/$token/$encoded';
  }

  Future<Response> handle(Request request, String token,
      [String? subPath]) async {
    final session = sessionStore.lookup(token);
    if (session == null) {
      return Response(
        410,
        body: 'session expired or unknown',
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    }

    final String targetUrl;
    if (subPath == null || subPath.isEmpty) {
      targetUrl = session.originalUrl;
    } else {
      final decoded = _tryDecodeSubPath(subPath);
      if (decoded == null) {
        return Response(400, body: 'invalid sub url');
      }
      targetUrl = decoded;
    }

    Uri targetUri;
    try {
      targetUri = Uri.parse(targetUrl);
    } catch (_) {
      return Response(400, body: 'invalid target url');
    }

    try {
      return await _proxy(
        request: request,
        targetUri: targetUri,
        session: session,
        token: token,
      );
    } on TimeoutException {
      return Response(504, body: 'upstream timeout');
    } catch (e, st) {
      KazumiLogger()
          .w('VideoProxyHandler: proxy failed for $targetUri', error: e, stackTrace: st);
      return Response.internalServerError(body: 'proxy error: $e');
    }
  }

  Future<Response> _proxy({
    required Request request,
    required Uri targetUri,
    required ProxySession session,
    required String token,
  }) async {
    final upstreamRequest = await _httpClient.openUrl(request.method, targetUri);

    if (session.userAgent.isNotEmpty) {
      upstreamRequest.headers.set(HttpHeaders.userAgentHeader, session.userAgent);
    }
    if (session.referer.isNotEmpty) {
      upstreamRequest.headers.set('referer', session.referer);
    }
    // 透传 Range，让浏览器 video 元素拖动条工作
    final range = request.headers['range'];
    if (range != null && range.isNotEmpty) {
      upstreamRequest.headers.set('range', range);
    }
    upstreamRequest.headers.set('accept', '*/*');

    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 5;

    final upstreamResponse = await upstreamRequest.close();

    final contentType =
        upstreamResponse.headers.contentType?.mimeType.toLowerCase() ?? '';
    final isM3u8 = contentType.contains('mpegurl') ||
        contentType.contains('m3u8') ||
        targetUri.path.toLowerCase().endsWith('.m3u8');

    if (isM3u8) {
      return _rewriteM3u8Response(
        upstreamResponse: upstreamResponse,
        targetUri: targetUri,
        token: token,
      );
    }

    return _streamingResponse(upstreamResponse);
  }

  Future<Response> _rewriteM3u8Response({
    required HttpClientResponse upstreamResponse,
    required Uri targetUri,
    required String token,
  }) async {
    final bodyBytes = await _readAll(upstreamResponse);
    final bodyText = utf8.decode(bodyBytes, allowMalformed: true);

    // Media playlist 走"解析 + 广告过滤 + 重写"路径，浏览器拿到的是 clean m3u8。
    // Master playlist 不含 segment，没有可过滤的内容，用旧 rewriter 直接改写
    // variants URI。
    final String rewritten;
    if (M3u8Parser.detectType(bodyText) == M3u8Type.media) {
      rewritten = _buildFilteredMediaPlaylist(
        bodyText: bodyText,
        baseUri: targetUri,
        token: token,
      );
    } else {
      final rewriter = M3u8Rewriter(
        baseUrl: targetUri,
        subUriBuilder: (absUrl) => buildSubUrl(token, absUrl),
      );
      rewritten = rewriter.rewrite(bodyText);
    }

    return Response.ok(
      rewritten,
      headers: {
        'content-type': 'application/vnd.apple.mpegurl; charset=utf-8',
        'cache-control': 'no-store',
      },
    );
  }

  /// 用 [M3u8AdFilter] 去广告，再把每条 segment / EXT-X-KEY 的 URI 改写成
  /// 通过本服务代理的 `/proxy/<token>/<base64>` 形式。
  ///
  /// 安全降级：当源 m3u8 不含 #EXT-X-DISCONTINUITY 时 filterAds 直接返回原列表。
  /// 偶发解析异常时降级为旧的逐行 rewrite，至少能播。
  String _buildFilteredMediaPlaylist({
    required String bodyText,
    required Uri baseUri,
    required String token,
  }) {
    try {
      final playlist =
          M3u8Parser.parseMediaPlaylist(bodyText, baseUri.toString());
      final originalCount = playlist.segments.length;
      final filtered = M3u8AdFilter.filterAds(playlist.segments);
      final removed = originalCount - filtered.length;
      if (removed > 0) {
        KazumiLogger().i(
            'VideoProxyHandler: filtered $removed ad segment(s) from $baseUri');
      }

      final targetDuration = playlist.targetDuration > 0
          ? playlist.targetDuration
          : M3u8AdFilter.calculateTargetDuration(filtered);

      final sb = StringBuffer();
      sb.writeln('#EXTM3U');
      sb.writeln('#EXT-X-VERSION:3');
      sb.writeln('#EXT-X-TARGETDURATION:${targetDuration.ceil()}');
      sb.writeln('#EXT-X-MEDIA-SEQUENCE:0');
      if (playlist.isVod) {
        sb.writeln('#EXT-X-PLAYLIST-TYPE:VOD');
      }

      int lastDiscontinuityGroup =
          filtered.isNotEmpty ? filtered.first.discontinuityGroup : 0;
      M3u8Key? lastKey;
      // 强制首段也写一次 #EXT-X-KEY，避免遗漏；用一个哨兵触发首次差异检测。
      var firstSegment = true;

      for (int i = 0; i < filtered.length; i++) {
        final seg = filtered[i];

        if (i > 0 && seg.discontinuityGroup != lastDiscontinuityGroup) {
          sb.writeln('#EXT-X-DISCONTINUITY');
          lastDiscontinuityGroup = seg.discontinuityGroup;
        }

        if (firstSegment || seg.key != lastKey) {
          if (seg.key == null) {
            // 仅当上一段有 key 时显式声明 NONE 关闭加密
            if (lastKey != null) {
              sb.writeln('#EXT-X-KEY:METHOD=NONE');
            }
          } else {
            final proxiedKeyUri = buildSubUrl(token, seg.key!.uri);
            final keySb = StringBuffer(
                '#EXT-X-KEY:METHOD=${seg.key!.method},URI="$proxiedKeyUri"');
            if (seg.key!.iv != null) {
              keySb.write(',IV=${seg.key!.iv}');
            }
            sb.writeln(keySb.toString());
          }
          lastKey = seg.key;
          firstSegment = false;
        }

        sb.writeln('#EXTINF:${seg.duration.toStringAsFixed(6)},');
        sb.writeln(buildSubUrl(token, seg.uri));
      }

      if (playlist.isVod) {
        sb.writeln('#EXT-X-ENDLIST');
      }
      return sb.toString();
    } catch (e, st) {
      KazumiLogger().w(
          'VideoProxyHandler: media playlist filter failed, fallback to passthrough rewrite',
          error: e,
          stackTrace: st);
      final rewriter = M3u8Rewriter(
        baseUrl: baseUri,
        subUriBuilder: (absUrl) => buildSubUrl(token, absUrl),
      );
      return rewriter.rewrite(bodyText);
    }
  }

  Response _streamingResponse(HttpClientResponse upstreamResponse) {
    final headers = <String, String>{};
    upstreamResponse.headers.forEach((name, values) {
      // 跳过 hop-by-hop 头与可能干扰 shelf 的头
      final lower = name.toLowerCase();
      if (_hopByHopHeaders.contains(lower)) return;
      if (lower == 'content-encoding') return;
      headers[lower] = values.join(', ');
    });
    headers.putIfAbsent('cache-control', () => 'no-store');

    return Response(
      upstreamResponse.statusCode,
      body: upstreamResponse,
      headers: headers,
    );
  }

  Future<Uint8List> _readAll(HttpClientResponse response) async {
    final chunks = <List<int>>[];
    await for (final chunk in response) {
      chunks.add(chunk);
    }
    final total = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final bytes = Uint8List(total);
    var offset = 0;
    for (final chunk in chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return bytes;
  }

  String? _tryDecodeSubPath(String subPath) {
    try {
      final decoded = utf8.decode(base64Url.decode(subPath));
      // 简单校验是 http(s) URL
      final uri = Uri.parse(decoded);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return null;
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  void close() {
    _httpClient.close(force: true);
  }

  static const Set<String> _hopByHopHeaders = {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };
}
