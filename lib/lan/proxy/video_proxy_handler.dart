import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'package:kazumi/lan/proxy/m3u8_rewriter.dart';
import 'package:kazumi/lan/proxy/proxy_session_store.dart';
import 'package:kazumi/utils/logger.dart';

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
    final rewriter = M3u8Rewriter(
      baseUrl: targetUri,
      subUriBuilder: (absUrl) => buildSubUrl(token, absUrl),
    );
    final rewritten = rewriter.rewrite(bodyText);
    return Response.ok(
      rewritten,
      headers: {
        'content-type': 'application/vnd.apple.mpegurl; charset=utf-8',
        'cache-control': 'no-store',
      },
    );
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
