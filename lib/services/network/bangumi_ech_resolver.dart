import 'package:ech_http/ech_http.dart';
import 'package:http/http.dart' as http;
import 'package:kazumi/request/config/api_endpoints.dart';

class BangumiEchResolver {
  BangumiEchResolver._();

  static final endpoint = Uri.https('dns.alidns.com', '/resolve');
  static const _hosts = {...ApiEndpoints.bangumiPublicApiHosts, 'lain.bgm.tv'};
  static const _addresses = ['172.67.134.140', '104.21.6.61', '172.67.73.67'];

  static DohEchResolver create(http.Client bootstrap) => DohEchResolver(
    client: bootstrap,
    endpoint: endpoint,
    hosts: _hosts,
    // Shared Cloudflare ECH config and pinned IPs bypass polluted Bangumi DNS.
    configDomains: {for (final host in _hosts) host: 'crypto.cloudflare.com'},
    addressOverrides: {for (final host in _hosts) host: _addresses},
  );
}
