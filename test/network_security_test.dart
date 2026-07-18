import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/core/bangumi_request_security.dart';
import 'package:kazumi/services/logging/log_sanitizer.dart';

void main() {
  group('BangumiRequestSecurity', () {
    test('only attaches bearer tokens to explicit trusted auth requests', () {
      expect(
        BangumiRequestSecurity.canAttachAccessToken(
          url: 'https://api.bgm.tv/v0/me',
          requiresAuth: true,
        ),
        isTrue,
      );
      expect(
        BangumiRequestSecurity.canAttachAccessToken(
          url: 'https://api.bgm.tv/v0/subjects/1',
          requiresAuth: false,
        ),
        isFalse,
      );
      expect(
        BangumiRequestSecurity.canAttachAccessToken(
          url: 'https://api.kazumi.fyi/v0/me',
          requiresAuth: true,
        ),
        isFalse,
      );
      expect(
        BangumiRequestSecurity.canAttachAccessToken(
          url: 'https://api.bgmapi.com/v0/me',
          requiresAuth: true,
        ),
        isTrue,
      );
      expect(
        BangumiRequestSecurity.canAttachAccessToken(
          url: 'http://api.bgm.tv/v0/me',
          requiresAuth: true,
        ),
        isFalse,
      );
    });

    test('removes authorization headers case-insensitively', () {
      final headers = <String, dynamic>{
        'Authorization': 'Bearer secret',
        'proxy-authorization': 'Basic secret',
        'Accept': 'application/json',
      };

      BangumiRequestSecurity.removeAuthorizationHeaders(headers);

      expect(headers, {'Accept': 'application/json'});
    });
  });

  group('LogSanitizer', () {
    test('keeps only URL origins in log text', () {
      final sanitized = LogSanitizer.sanitizeText(
        'GET https://user:password@example.com/video.m3u8?token=secret#part',
      );

      expect(sanitized, 'GET https://example.com');
      expect(sanitized, isNot(contains('video.m3u8')));
      expect(sanitized, isNot(contains('password')));
      expect(sanitized, isNot(contains('secret')));
    });

    test('preserves a non-default port without exposing a private path', () {
      final sanitized = LogSanitizer.sanitizeUri(
        Uri.parse('https://media.example.com:8443/users/alice/library.m3u8'),
      );

      expect(sanitized, 'https://media.example.com:8443');
      expect(sanitized, isNot(contains('alice')));
      expect(sanitized, isNot(contains('library.m3u8')));
    });

    test('redacts headers, bearer values, cookies, and data URLs', () {
      final sanitized = LogSanitizer.sanitizeText(
        'Authorization: Bearer abc Cookie=session=xyz '
        'password=hunter2 data:image/png;base64,AAAA1234',
      );

      expect(sanitized, isNot(contains('abc')));
      expect(sanitized, isNot(contains('xyz')));
      expect(sanitized, isNot(contains('hunter2')));
      expect(sanitized, isNot(contains('AAAA1234')));
      expect(sanitized, contains('[REDACTED]'));
    });
  });
}
