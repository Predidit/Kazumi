import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/crypto.dart';

void main() {
  group('generateDandanSignature', () {
    test('same input produces same output (deterministic)', () {
      const path = '/api/v2/search/episodes';
      const timestamp = 1700000000;

      final sig1 = generateDandanSignature(path, timestamp);
      final sig2 = generateDandanSignature(path, timestamp);

      expect(sig1, sig2);
      expect(sig1.length, greaterThan(0));
    });

    test('different path produces different signature', () {
      const ts = 1700000000;
      final a = generateDandanSignature('/api/v2/search/episodes', ts);
      final b = generateDandanSignature('/api/v2/comment/1', ts);

      expect(a, isNot(b));
    });

    test('different timestamp produces different signature', () {
      const path = '/api/v2/search/episodes';
      final a = generateDandanSignature(path, 1700000000);
      final b = generateDandanSignature(path, 1700000001);

      expect(a, isNot(b));
    });
  });

  group('generateBangumiMirrorSearchSignature', () {
    test('same input produces same output (deterministic)', () {
      const method = 'POST';
      const path = '/kazumi/v1/search';
      const body = '{"keyword":"test"}';
      const timestamp = 1700000000;

      final sig1 = generateBangumiMirrorSearchSignature(
        method: method,
        path: path,
        body: body,
        timestamp: timestamp,
      );
      final sig2 = generateBangumiMirrorSearchSignature(
        method: method,
        path: path,
        body: body,
        timestamp: timestamp,
      );

      expect(sig1, sig2);
      expect(sig1.length, greaterThan(0));
    });

    test('body change produces different signature', () {
      const method = 'POST';
      const path = '/kazumi/v1/search';
      const ts = 1700000000;

      final a = generateBangumiMirrorSearchSignature(
        method: method,
        path: path,
        body: '{"keyword":"a"}',
        timestamp: ts,
      );
      final b = generateBangumiMirrorSearchSignature(
        method: method,
        path: path,
        body: '{"keyword":"b"}',
        timestamp: ts,
      );

      expect(a, isNot(b));
    });

    test('method change produces different signature', () {
      const path = '/kazumi/v1/search';
      const body = '';
      const ts = 1700000000;

      final a = generateBangumiMirrorSearchSignature(
        method: 'GET', path: path, body: body, timestamp: ts);
      final b = generateBangumiMirrorSearchSignature(
        method: 'POST', path: path, body: body, timestamp: ts);

      expect(a, isNot(b));
    });

    test('empty body handled correctly', () {
      final sig = generateBangumiMirrorSearchSignature(
        method: 'GET',
        path: '/test',
        body: '',
        timestamp: 1700000000,
      );

      expect(sig.length, greaterThan(0));
    });
  });
}
