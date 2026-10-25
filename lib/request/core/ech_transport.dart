import 'package:ech_http/ech_http.dart';
import 'package:http/http.dart' as http;
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/network_config.dart';

final _dohEndpoint = Uri.https('dns.alidns.com', '/resolve');
const _hosts = {
  ...ApiEndpoints.bangumiPublicApiHosts,
  'lain.bgm.tv',
  ApiEndpoints.ghProxyHost,
};
const _addresses = ['172.67.134.140', '104.21.6.61', '172.67.73.67'];

class EchTransport {
  EchTransport._();

  static _EchPool? _pool;

  static EchLease lease(
    Uri url, {
    Duration connectTimeout = const Duration(seconds: 10),
    Duration timeout = const Duration(seconds: 30),
  }) => (_pool ??= _EchPool()).lease(url, connectTimeout, timeout);

  /// New requests use fresh clients; in-flight responses can finish.
  static void reset() {
    _pool?.retire();
    _pool = null;
  }
}

class EchLease {
  EchLease._(this._client, this._pool);

  final EchClient _client;
  final _EchPool _pool;
  bool _released = false;

  Future<EchResponse> send(http.BaseRequest request) => _client.send(request);

  /// Call once the response body is consumed or abandoned.
  void release() {
    if (_released) return;
    _released = true;
    _pool._release();
  }
}

class _EchPool {
  final _config = NetworkConfig.fromSettings();
  final _resolvers = <Uri?, DohEchResolver>{};
  final _clients = <(Uri?, Uri?, Duration, Duration), EchClient>{};
  int _active = 0;
  bool _retired = false;

  EchLease lease(Uri url, Duration connectTimeout, Duration timeout) {
    final proxy = _config.proxyForUri(url);
    final dohProxy = _config.proxyForUri(_dohEndpoint);
    // Native timeouts are client-wide; only matching settings share a pool.
    final client = _clients.putIfAbsent(
      (proxy, dohProxy, connectTimeout, timeout),
      () => EchClient(
        proxy: proxy,
        resolver: _resolvers.putIfAbsent(dohProxy, () => _resolver(dohProxy)),
        connectTimeout: connectTimeout,
        timeout: timeout,
      ),
    );
    _active++;
    return EchLease._(client, this);
  }

  // Shared Cloudflare ECH config and pinned IPs bypass polluted DNS.
  static DohEchResolver _resolver(Uri? proxy) => DohEchResolver(
    client: EchClient(proxy: proxy),
    endpoint: _dohEndpoint,
    hosts: _hosts,
    configDomains: {for (final host in _hosts) host: 'crypto.cloudflare.com'},
    addressOverrides: {for (final host in _hosts) host: _addresses},
  );

  void _release() {
    _active--;
    if (_retired && _active == 0) _close();
  }

  void retire() {
    _retired = true;
    if (_active == 0) _close();
  }

  void _close() {
    for (final client in _clients.values) {
      client.close();
    }
    for (final resolver in _resolvers.values) {
      resolver.client.close();
    }
    _clients.clear();
    _resolvers.clear();
  }
}
