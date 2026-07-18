import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/network/proxy_utils.dart';
import 'package:kazumi/services/sync/webdav_endpoint_policy.dart';

void main() {
  group('proxy input policy', () {
    test('accepts existing host-port and HTTP(S) proxy forms', () {
      expect(ProxyUtils.parseProxyUrl('127.0.0.1:7890'), ('127.0.0.1', 7890));
      expect(
        ProxyUtils.parseProxyUrl('http://proxy.example:8080'),
        ('proxy.example', 8080),
      );
      expect(
        ProxyUtils.parseProxyUrl('https://[::1]:7890/'),
        ('::1', 7890),
      );
      expect(
        ProxyUtils.getFormattedProxyUrl('[::1]:7890'),
        'http://[::1]:7890',
      );
    });

    test('rejects credentials, paths, controls, and invalid ports', () {
      for (final value in [
        'http://user:pass@proxy.example:8080',
        'http://proxy.example:8080/private',
        'http://proxy.example:8080?target=private',
        'proxy.example:0',
        'proxy.example:65536',
        'proxy.example:8080\r\nInjected: yes',
        'socks5://proxy.example:1080',
      ]) {
        expect(ProxyUtils.parseProxyUrl(value), isNull, reason: value);
      }
    });
  });

  group('WebDAV endpoint policy', () {
    test('preserves valid remote and local HTTP(S) base paths', () {
      expect(
        validateWebDavEndpoint(
          'https://dav.example/remote.php/dav/files/user/',
        ),
        'https://dav.example/remote.php/dav/files/user/',
      );
      expect(
        validateWebDavEndpoint('http://192.168.1.10:8080/webdav'),
        'http://192.168.1.10:8080/webdav',
      );
    });

    test('rejects non-network URLs and embedded credentials', () {
      for (final value in [
        'file:///C:/private',
        'https://user:pass@dav.example/webdav',
        'https://dav.example/webdav#fragment',
        '//dav.example/webdav',
        'https://dav.example/webdav\nnext',
      ]) {
        expect(
          () => validateWebDavEndpoint(value),
          throwsA(isA<WebDavEndpointPolicyException>()),
          reason: value,
        );
      }
    });
  });
}
