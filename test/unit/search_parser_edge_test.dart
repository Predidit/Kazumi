import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/search_parser.dart';

void main() {
  group('SearchParser edge cases', () {
    test('empty string returns null for all parsers', () {
      final parser = SearchParser('');
      expect(parser.parseId(), isNull);
      expect(parser.parseTag(), isNull);
      expect(parser.parseSort(), isNull);
      expect(parser.parseKeywords(), isEmpty);
    });

    test('whitespace only returns empty keywords', () {
      final parser = SearchParser('   ');
      expect(parser.parseId(), isNull);
      expect(parser.parseKeywords(), isEmpty);
    });

    test('plain keywords without syntax', () {
      final parser = SearchParser('进击的巨人');
      expect(parser.parseId(), isNull);
      expect(parser.parseTag(), isNull);
      expect(parser.parseKeywords(), '进击的巨人');
    });

    test('id syntax with decimal value', () {
      final parser = SearchParser('id:12345');
      expect(parser.parseId(), '12345');
      expect(parser.parseKeywords(), isEmpty);
    });

    test('tag with katakana', () {
      final parser = SearchParser('tag:アニメ');
      expect(parser.parseTag(), 'アニメ');
      expect(parser.parseKeywords(), isEmpty);
    });

    test('sort syntax', () {
      final parser = SearchParser('sort:rank');
      expect(parser.parseSort(), 'rank');
      expect(parser.parseKeywords(), isEmpty);
    });

    test('combined id, tag, sort, and keywords', () {
      final parser = SearchParser('id:42 tag:日本 sort:heat 鬼灭之刃');
      expect(parser.parseId(), '42');
      expect(parser.parseTag(), '日本');
      expect(parser.parseSort(), 'heat');
      expect(parser.parseKeywords(), '鬼灭之刃');
    });

    test('SQL injection payload treated as literal text', () {
      const payload = "'; DROP TABLE users; --";
      final parser = SearchParser(payload);
      // Should not match any syntax
      expect(parser.parseId(), isNull);
      expect(parser.parseTag(), isNull);
      // Keywords should contain the literal payload text
      expect(parser.parseKeywords(), contains('DROP TABLE'));
    });

    test('XSS payload treated as literal text', () {
      const payload = '<script>alert("xss")</script>';
      final parser = SearchParser(payload);
      expect(parser.parseId(), isNull);
      expect(parser.parseTag(), isNull);
      expect(parser.parseKeywords(), contains('script'));
    });

    test('tag containing full-width colon is parsed', () {
      // The search parser uses a regex for tag:xxx — full-width colon
      // is NOT the standard colon, so it should be treated as literal text.
      final parser = SearchParser('tag：日本'); // full-width colon
      expect(parser.parseTag(), isNull);
    });

    test('very long input does not cause performance issue', () {
      final longInput = 'a' * 10000;
      final stopwatch = Stopwatch()..start();
      final parser = SearchParser(longInput);
      parser.parseKeywords(); // triggers regex replace
      stopwatch.stop();
      // Should complete in reasonable time (well under 1 second for 10k chars)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('updateSort appends when no existing sort', () {
      final parser = SearchParser('keyword');
      expect(parser.updateSort('rank'), 'keyword sort:rank');
    });

    test('updateSort replaces existing sort', () {
      final parser = SearchParser('keyword sort:heat');
      expect(parser.updateSort('rank'), 'keyword sort:rank');
    });
  });
}
