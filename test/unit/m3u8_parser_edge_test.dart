import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/m3u8_parser.dart';

void main() {
  group('M3U8 Parser edge cases', () {
    test('empty input returns media type (default)', () {
      expect(M3u8Parser.detectType(''), M3u8Type.media);
    });

    test('whitespace-only input returns media type (default)', () {
      expect(M3u8Parser.detectType('   \n  \n  '), M3u8Type.media);
    });

    test('valid header with no variants', () {
      const content = '#EXTM3U\n#EXT-X-VERSION:3\n';
      final master =
          M3u8Parser.parseMasterPlaylist(content, 'http://example.com');
      expect(master.variants, isEmpty);
    });

    test('variant with missing bandwidth uses default zero', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:RESOLUTION=640x360
video.m3u8''';
      final master =
          M3u8Parser.parseMasterPlaylist(content, 'http://example.com/base/');
      expect(master.variants.length, 1);
      expect(master.variants.first.bandwidth, 0);
    });

    test('URLs with special characters are preserved', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000
video%20with%20spaces.m3u8''';
      final master =
          M3u8Parser.parseMasterPlaylist(content, 'http://example.com');
      expect(master.variants.length, 1);
      expect(master.variants.first.uri,
          contains('video%20with%20spaces.m3u8'));
    });

    test('media playlist EXTINF with extreme float duration', () {
      const content = '''
#EXTM3U
#EXTINF:9999.999,
segment.ts
#EXT-X-ENDLIST''';
      final media = M3u8Parser.parseMediaPlaylist(
        content,
        'http://example.com/playlist.m3u8',
      );
      expect(media.segments.length, 1);
      expect(media.segments.first.duration, closeTo(9999.999, 0.001));
    });

    test('unicode in comments does not break parsing', () {
      const content = '''
#EXTM3U
# 动漫视频源
#EXTINF:5.0,
segment.ts
#EXT-X-ENDLIST''';
      final media = M3u8Parser.parseMediaPlaylist(
        content,
        'http://example.com/playlist.m3u8',
      );
      expect(media.segments.length, 1);
    });

    test('malformed EXTINF without comma still parses duration', () {
      const content = '''
#EXTM3U
#EXTINF:5.0
segment.ts
#EXT-X-ENDLIST''';
      final media = M3u8Parser.parseMediaPlaylist(
        content,
        'http://example.com/playlist.m3u8',
      );
      expect(media.segments.length, 1);
      expect(media.segments.first.duration, closeTo(5.0, 0.01));
    });

    test('playlist with only comments and no segments', () {
      const content = '''
#EXTM3U
# Comment
# Another comment
#EXT-X-ENDLIST''';
      final media = M3u8Parser.parseMediaPlaylist(
        content,
        'http://example.com/playlist.m3u8',
      );
      expect(media.segments, isEmpty);
    });

    test('segments with KEY tag carry key info', () {
      const content = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin",IV=0x1234
#EXTINF:5.0,
segment.ts
#EXT-X-ENDLIST''';
      final media = M3u8Parser.parseMediaPlaylist(
        content,
        'http://example.com/playlist.m3u8',
      );
      expect(media.segments.length, 1);
      expect(media.segments.first.key, isNotNull);
      expect(media.segments.first.key!.method, 'AES-128');
    });
  });
}
