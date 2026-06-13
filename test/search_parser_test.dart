import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/search_parser.dart';

void main() {
  group('SearchParser', () {
    test('parses tag containing full-width colon', () {
      final parser = SearchParser('tag:Re：從零開始的異世界生活');

      expect(parser.parseTags(), ['Re：從零開始的異世界生活']);
      expect(parser.parseKeywords(), isEmpty);
    });

    test('parses katakana tag', () {
      final parser = SearchParser('tag:ソワネ');

      expect(parser.parseTags(), ['ソワネ']);
      expect(parser.parseKeywords(), isEmpty);
    });

    test('parses tag containing parentheses', () {
      final parser = SearchParser('tag:最强的职业不是勇者也不是贤者好像是鉴定士(伪)的样子');

      expect(parser.parseTags(), ['最强的职业不是勇者也不是贤者好像是鉴定士(伪)的样子']);
      expect(parser.parseKeywords(), isEmpty);
    });

    test('parses tag and sort syntax together', () {
      final parser = SearchParser('tag:Re：從零開始的異世界生活 sort:rank');

      expect(parser.parseTags(), ['Re：從零開始的異世界生活']);
      expect(parser.parseSort(), 'rank');
      expect(parser.parseKeywords(), isEmpty);
    });

    test('keeps common tag behavior', () {
      final parser = SearchParser('tag:日本');

      expect(parser.parseTags(), ['日本']);
      expect(parser.parseKeywords(), isEmpty);
    });

    test('keeps normal keyword search behavior', () {
      final parser = SearchParser('葬送的芙莉莲 sort:match');

      expect(parser.parseTags(), isEmpty);
      expect(parser.parseSort(), 'match');
      expect(parser.parseKeywords(), '葬送的芙莉莲');
    });

    test('keeps id search behavior', () {
      final parser = SearchParser('id:12345');

      expect(parser.parseId(), '12345');
      expect(parser.parseTags(), isEmpty);
      expect(parser.parseKeywords(), isEmpty);
    });

    test('updates existing sort syntax', () {
      final parser = SearchParser('tag:日本 sort:heat');

      expect(parser.updateSort('rank'), 'tag:日本 sort:rank');
    });
  });
}
