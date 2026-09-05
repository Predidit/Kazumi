import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/network/bangumi_image_url_rewriter.dart';

void main() {
  group('BangumiImageUrlRewriter', () {
    test('keeps URLs unchanged when disabled', () {
      const url = 'https://api.bgm.tv/v0/subjects/590353/image?type=large';

      expect(BangumiImageUrlRewriter.rewrite(url, enabled: false), url);
    });

    test('rewrites lain images and preserves GIF animation', () {
      expect(
        BangumiImageUrlRewriter.rewrite(
          'https://lain.bgm.tv/pic/cover/l/cover.jpg',
          enabled: true,
        ),
        'https://wsrv.nl/?url=lain.bgm.tv%2Fpic%2Fcover%2Fl%2Fcover.jpg',
      );
      expect(
        BangumiImageUrlRewriter.rewrite(
          'https://lain.bgm.tv/pic/cover/l/animated.gif',
          enabled: true,
        ),
        'https://wsrv.nl/?url=lain.bgm.tv%2Fpic%2Fcover%2Fl%2Fanimated.gif&n=-1',
      );
    });

    test('rewrites synthetic API image endpoints', () {
      for (final type in ['subjects', 'characters', 'persons']) {
        final source = 'https://api.bgm.tv/v0/$type/590353/image?type=large';
        expect(
          BangumiImageUrlRewriter.rewrite(source, enabled: true),
          'https://wsrv.nl/?url=api.bgm.tv%2Fv0%2F$type%2F590353%2Fimage%3Ftype%3Dlarge',
        );
      }
    });

    test('rejects URLs outside the image boundary', () {
      for (final url in [
        'ftp://lain.bgm.tv/pic/cover/l/cover.jpg',
        'https://api.bgm.tv/v0/subjects/590353',
        'https://api.bgm.tv/v0/subjects/not-an-id/image?type=large',
        'https://api.bgm.tv/v0/episodes/1/image?type=large',
        'https://example.com/v0/subjects/590353/image?type=large',
      ]) {
        expect(BangumiImageUrlRewriter.rewrite(url, enabled: true), url);
      }
    });
  });
}
