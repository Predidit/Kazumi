import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/episode_url.dart';

void main() {
  group('normalizeEpisodeUrl', () {
    const baseUrl = 'https://www.example.com';

    test('相对路径 + baseUrl → 绝对 URL', () {
      expect(
        normalizeEpisodeUrl(baseUrl, '/play/123.html'),
        'https://www.example.com/play/123.html',
      );
    });

    test('相对路径（无前导斜杠）基于 baseUrl 补全', () {
      expect(
        normalizeEpisodeUrl('https://www.example.com/', 'play/123.html'),
        'https://www.example.com/play/123.html',
      );
    });

    test('绝对路径原样（幂等）', () {
      const absolute = 'https://www.example.com/play/123.html';
      expect(normalizeEpisodeUrl(baseUrl, absolute), absolute);
    });

    test('http 与 https 同站归一到同一 key', () {
      final viaHttp =
          normalizeEpisodeUrl(baseUrl, 'http://www.example.com/play/123.html');
      final viaHttps =
          normalizeEpisodeUrl(baseUrl, 'https://www.example.com/play/123.html');
      expect(viaHttp, viaHttps);
      expect(viaHttp, 'https://www.example.com/play/123.html');
    });

    test('http baseUrl 下相对路径也归一到 https', () {
      expect(
        normalizeEpisodeUrl('http://www.example.com', '/play/123.html'),
        'https://www.example.com/play/123.html',
      );
    });

    test('保留显式端口', () {
      expect(
        normalizeEpisodeUrl(baseUrl, 'https://www.example.com:8080/play/123'),
        'https://www.example.com:8080/play/123',
      );
    });

    test('protocol-relative URL 基于 baseUrl 补全协议', () {
      expect(
        normalizeEpisodeUrl(baseUrl, '//cdn.example.com/play/123'),
        'https://cdn.example.com/play/123',
      );
    });

    test('去除多余尾斜杠', () {
      expect(
        normalizeEpisodeUrl(baseUrl, '/play/123/'),
        'https://www.example.com/play/123',
      );
      expect(
        normalizeEpisodeUrl(baseUrl, 'https://www.example.com/play/123///'),
        'https://www.example.com/play/123',
      );
    });

    test('根路径尾斜杠保留', () {
      expect(
        normalizeEpisodeUrl(baseUrl, 'https://www.example.com/'),
        'https://www.example.com/',
      );
    });

    test('去除首尾空白', () {
      expect(
        normalizeEpisodeUrl(baseUrl, '  /play/123.html  '),
        'https://www.example.com/play/123.html',
      );
    });

    test('保留有意义的 query', () {
      expect(
        normalizeEpisodeUrl(baseUrl, '/play?id=123&ep=4'),
        'https://www.example.com/play?id=123&ep=4',
      );
    });

    test('空输入返回空串', () {
      expect(normalizeEpisodeUrl(baseUrl, ''), '');
      expect(normalizeEpisodeUrl(baseUrl, '   '), '');
    });

    test('baseUrl 缺失且为相对路径时原样返回去空白输入', () {
      expect(normalizeEpisodeUrl('', '/play/123.html'), '/play/123.html');
    });

    test('幂等性: normalize(normalize(x)) == normalize(x)', () {
      final cases = <String>[
        '/play/123.html',
        'play/123.html',
        'http://www.example.com/play/123/',
        'https://www.example.com/play/123.html',
        '  /play/123/  ',
        '/play?id=123&ep=4',
        'https://www.example.com/',
        '',
      ];
      for (final raw in cases) {
        final once = normalizeEpisodeUrl(baseUrl, raw);
        final twice = normalizeEpisodeUrl(baseUrl, once);
        expect(twice, once, reason: 'not idempotent for: "$raw"');
      }
    });
  });
}
