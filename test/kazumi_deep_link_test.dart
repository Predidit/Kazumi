import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/deep_links/kazumi_deep_link.dart';

void main() {
  group('KazumiDeepLink.parse', () {
    test('parses a positive Bangumi subject ID', () {
      expect(
        KazumiDeepLink.parse(Uri.parse('kazumi://bangumi/123456')),
        isA<BangumiDeepLink>().having((link) => link.id, 'id', 123456),
      );
    });

    test('accepts the smallest positive subject ID', () {
      expect(
        KazumiDeepLink.parse(Uri.parse('kazumi://bangumi/1')),
        isA<BangumiDeepLink>().having((link) => link.id, 'id', 1),
      );
    });

    for (final path in [
      '',
      '/0',
      '/-1',
      '/+1',
      '/01',
      '/1.0',
      '/abc',
      '/%201',
      '/1%20',
      '/1/2',
    ]) {
      test('rejects invalid subject path "$path"', () {
        expect(
          KazumiDeepLink.parse(Uri.parse('kazumi://bangumi$path')),
          isNull,
        );
      });
    }

    test('decodes and trims a search query', () {
      final uri = Uri(
        scheme: 'kazumi',
        host: 'search',
        queryParameters: {'query': '  葬送的芙莉莲 & A+B  '},
      );

      expect(
        KazumiDeepLink.parse(Uri.parse(uri.toString())),
        isA<SearchDeepLink>().having(
          (link) => link.query,
          'query',
          '葬送的芙莉莲 & A+B',
        ),
      );
    });

    test('decodes form-encoded spaces in a search query', () {
      expect(
        KazumiDeepLink.parse(Uri.parse('kazumi://search?query=A+B')),
        isA<SearchDeepLink>().having((link) => link.query, 'query', 'A B'),
      );
    });

    for (final url in [
      'kazumi://search',
      'kazumi://search?query=',
      'kazumi://search?query=%20%20',
      'kazumi://search?other=anime',
      'https://bangumi/123456',
      'https://search?query=anime',
      'kazumi://unknown/123456',
    ]) {
      test('ignores unsupported or empty link "$url"', () {
        expect(KazumiDeepLink.parse(Uri.parse(url)), isNull);
      });
    }

    for (final url in ['kazumi://bangumi/%FF', 'kazumi://search?query=%FF']) {
      test('ignores invalid UTF-8 in "$url" without throwing', () {
        expect(KazumiDeepLink.parse(Uri.parse(url)), isNull);
      });
    }
  });
}
