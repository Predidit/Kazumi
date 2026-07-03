import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/media.dart';

void main() {
  group('video source URL extraction', () {
    test('extracts nested mp4 URL from parser request query', () {
      const parserUrl =
          'https://player.moedot.net/player/ec.php?code=xfdm1&from=cf&url=https://play.xfvod.pro:8088/G/foo%20bar.mp4';

      expect(
        extractVideoSourceUrl(parserUrl),
        'https://play.xfvod.pro:8088/G/foo%20bar.mp4',
      );
    });

    test('extracts xfdm-style encoded file names from parser request query',
        () {
      const parserUrl =
          'https://player.moedot.net/player/ec.php?code=xfdm1&from=cf&url=https://play.xfvod.pro:8088/G/G-%E6%94%BB%E5%A3%B3/%5BSHANA%5D%5BStand_Alone_Complex%5D%5B13%5D%5B1080P%5D.mp4';

      expect(
        extractVideoSourceUrl(parserUrl),
        'https://play.xfvod.pro:8088/G/G-%E6%94%BB%E5%A3%B3/%5BSHANA%5D%5BStand_Alone_Complex%5D%5B13%5D%5B1080P%5D.mp4',
      );
    });

    test('extracts nested m3u8 URL from parser request query', () {
      const parserUrl =
          'https://example.com/player.php?url=https://cdn.example.com/live/index.m3u8';

      expect(
        extractVideoSourceUrl(parserUrl),
        'https://cdn.example.com/live/index.m3u8',
      );
    });

    test('extracts nested media URL with query tokens', () {
      const parserUrl =
          'https://example.com/player.php?url=https://cdn.example.com/video.mp4?token=abc';

      expect(
        extractVideoSourceUrl(parserUrl),
        'https://cdn.example.com/video.mp4?token=abc',
      );
    });

    test('extracts percent-encoded nested media URL', () {
      const parserUrl =
          'https://example.com/player.php?url=https%3A%2F%2Fcdn.example.com%2Fvideo.mp4%3Ftoken%3Dabc';

      expect(
        extractVideoSourceUrl(parserUrl),
        'https://cdn.example.com/video.mp4?token=abc',
      );
    });

    test('returns direct media URLs unchanged', () {
      expect(
        extractVideoSourceUrl('https://example.com/video.m3u8'),
        'https://example.com/video.m3u8',
      );
      expect(
        extractVideoSourceUrl('https://example.com/video.mp4'),
        'https://example.com/video.mp4',
      );
      expect(
        extractVideoSourceUrl('//cdn.example.com/video.mp4'),
        '//cdn.example.com/video.mp4',
      );
    });

    test('nested extraction ignores direct media URLs', () {
      expect(
        extractNestedVideoSourceUrl('https://example.com/video.m3u8'),
        isNull,
      );
      expect(
        extractNestedVideoSourceUrl('https://example.com/video.mp4?token=abc'),
        isNull,
      );
    });

    test('nested extraction ignores direct media URLs with media fallback query',
        () {
      const directUrl =
          'https://cdn.example.com/video.mp4?fallback=https%3A%2F%2Fcdn.example.com%2Fbackup.mp4';

      expect(extractNestedVideoSourceUrl(directUrl), isNull);
      expect(extractVideoSourceUrl(directUrl), directUrl);
    });

    test('ignores ordinary page and asset URLs', () {
      expect(
        extractVideoSourceUrl('https://dm1.xfdm.pro/watch/907/1/13.html'),
        isNull,
      );
      expect(
        extractVideoSourceUrl('https://dm1.xfdm.pro/static/player.js'),
        isNull,
      );
    });

    test('decodeVideoSource preserves legacy no-match encoding behavior', () {
      expect(
        decodeVideoSource('https://example.com/watch/foo bar.html'),
        'https://example.com/watch/foo%20bar.html',
      );
    });

    test('decodeVideoSource still extracts nested media URLs', () {
      const parserUrl =
          'https://example.com/player.php?url=https://cdn.example.com/video.mp4?token=abc';

      expect(
        decodeVideoSource(parserUrl),
        'https://cdn.example.com/video.mp4?token=abc',
      );
    });
  });
}
