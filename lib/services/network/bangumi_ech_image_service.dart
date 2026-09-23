import 'package:ech_http/ech_http.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:kazumi/services/network/image_file_response.dart';
import 'package:kazumi/utils/constants.dart' show bangumiHTTPHeader;

class BangumiEchImageService extends FileService {
  BangumiEchImageService({
    required Uri? Function(Uri) proxyForUrl,
    http.Client Function(Uri? proxy, EchResolver? resolver)? clientFactory,
  }) : _proxyForUrl = proxyForUrl,
       _clientFactory = clientFactory ?? _createClient;

  static final _dohEndpoint = Uri.https('dns.alidns.com', '/resolve');

  final Uri? Function(Uri) _proxyForUrl;
  final http.Client Function(Uri?, EchResolver?) _clientFactory;
  final _current = <(Uri?, Uri?), _EchSession>{};
  final _sessions = <_EchSession>{};
  bool _closed = false;

  static http.Client _createClient(Uri? proxy, EchResolver? resolver) =>
      EchClient(proxy: proxy, resolver: resolver);

  _EchSession _sessionFor(Uri uri) {
    final proxies = (_proxyForUrl(uri), _proxyForUrl(_dohEndpoint));
    return _current.putIfAbsent(proxies, () {
      final bootstrap = _clientFactory(proxies.$2, null);
      try {
        final images = _clientFactory(
          proxies.$1,
          DohEchResolver(
            client: bootstrap,
            endpoint: _dohEndpoint,
            // This client only handles images. Protect both the API image
            // redirect and its CDN destination; API JSON still uses Dio.
            hosts: {'api.bgm.tv', 'lain.bgm.tv'},
            // Bangumi currently shares Cloudflare's ECH config. Pin its CDN
            // addresses to bypass polluted A records; revisit on CDN changes.
            configDomains: {
              'api.bgm.tv': 'crypto.cloudflare.com',
              'lain.bgm.tv': 'crypto.cloudflare.com',
            },
            addressOverrides: {
              'api.bgm.tv': ['172.67.134.140', '104.21.6.61', '172.67.73.67'],
              'lain.bgm.tv': ['172.67.134.140', '104.21.6.61', '172.67.73.67'],
            },
          ),
        );
        final session = _EchSession(bootstrap, images);
        _sessions.add(session);
        return session;
      } catch (_) {
        bootstrap.close();
        rethrow;
      }
    });
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    if (_closed) throw StateError('ECH image service is closed');
    final uri = Uri.parse(url);
    final session = _sessionFor(uri);
    session.active++;
    final http.StreamedResponse response;
    try {
      final request = http.Request('GET', uri);
      // Bangumi image endpoints can reject requests without an application UA.
      request.headers['user-agent'] = bangumiHTTPHeader['user-agent']!;
      if (headers != null) request.headers.addAll(headers);
      // ech_http does not decompress HTTP content encodings.
      request.headers['accept-encoding'] = 'identity';
      response = await session.images.send(request);
    } catch (_) {
      _release(session);
      rethrow;
    }
    return createImageFileResponse(
      response,
      onComplete: () => _release(session),
    );
  }

  void _release(_EchSession session) {
    session.active--;
    if (session.retired && session.active == 0 && _sessions.remove(session)) {
      session.close();
    }
  }

  /// New requests use fresh connections; in-flight image streams can finish.
  void reset() {
    _current.clear();
    for (final session in _sessions.toList()) {
      session.retired = true;
      if (session.active == 0) {
        _sessions.remove(session);
        session.close();
      }
    }
  }

  void close() {
    _closed = true;
    _current.clear();
    for (final session in _sessions) {
      session.close();
    }
    _sessions.clear();
  }
}

class _EchSession {
  _EchSession(this.bootstrap, this.images);

  final http.Client bootstrap;
  final http.Client images;
  int active = 0;
  bool retired = false;

  void close() {
    images.close();
    bootstrap.close();
  }
}
