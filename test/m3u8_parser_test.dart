import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/m3u8_parser.dart';

void main() {
  group('M3U8 Parser', () {
    // ── Master playlist ──────────────────────────────────────────────────────
    test('Test 1: Mux master playlist', () {
      const content = r'''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=246440,CODECS="avc1.42001e,mp4a.40.2",RESOLUTION=320x184
url_2/193039199_mp4_h264_aac_ld_2.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=460560,CODECS="avc1.42001e,mp4a.40.2",RESOLUTION=512x288
url_4/193039199_mp4_h264_aac_sd_4.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=836280,CODECS="avc1.42001f,mp4a.40.2",RESOLUTION=848x480
url_6/193039199_mp4_h264_aac_480p_6.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2149280,CODECS="avc1.64001f,mp4a.40.2",RESOLUTION=1280x720
url_0/193039199_mp4_h264_aac_hd_7.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=6221600,CODECS="avc1.640028,mp4a.40.2",RESOLUTION=1920x1080
url_8/193039199_mp4_h264_aac_fhd_8.m3u8
''';
      const baseUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

      expect(M3u8Parser.detectType(content), M3u8Type.master);

      final master = M3u8Parser.parseMasterPlaylist(content, baseUrl);
      expect(master.variants.length, 5);

      final best = master.bestVariant;
      expect(best.bandwidth, 6221600);
      expect(best.resolution, '1920x1080');
      expect(best.uri,
          'https://test-streams.mux.dev/x36xhzz/url_8/193039199_mp4_h264_aac_fhd_8.m3u8');
    });

    // ── Media playlist with VOD + ENDLIST ────────────────────────────────────
    test('Test 2: Mux media playlist (PLAYLIST-TYPE:VOD + ENDLIST) -> isVod=true', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
seg_00000.ts
#EXTINF:10.0,
seg_00001.ts
#EXTINF:10.0,
seg_00002.ts
#EXTINF:9.6,
seg_00003.ts
#EXT-X-ENDLIST
''';
      const baseUrl =
          'https://test-streams.mux.dev/x36xhzz/url_0/193039199_mp4_h264_aac_hd_7.m3u8';

      expect(M3u8Parser.detectType(content), M3u8Type.media);

      final playlist = M3u8Parser.parseMediaPlaylist(content, baseUrl);
      expect(playlist.isVod, isTrue);
      expect(playlist.targetDuration, 10.0);
      expect(playlist.segments.length, 4);
      expect(playlist.segments.first.uri,
          'https://test-streams.mux.dev/x36xhzz/url_0/seg_00000.ts');

      expect(content.contains('#EXT-X-PLAYLIST-TYPE:VOD'), isTrue);
      expect(content.contains('#EXT-X-ENDLIST'), isTrue);
    });

    // ── Apple-style: VOD tag present, no ENDLIST ─────────────────────────────
    test('Test 3: Apple media playlist (PLAYLIST-TYPE:VOD, no ENDLIST) -> isVod=true', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:8
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:7.975,
fileSequence0.mp4
#EXTINF:7.941,
fileSequence1.mp4
#EXTINF:7.975,
fileSequence2.mp4
''';
      const baseUrl =
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/v5/prog_index.m3u8';

      final playlist = M3u8Parser.parseMediaPlaylist(content, baseUrl);

      expect(content.contains('#EXT-X-PLAYLIST-TYPE:VOD'), isTrue);
      expect(content.contains('#EXT-X-ENDLIST'), isFalse);
      expect(playlist.isVod, isTrue);
      expect(playlist.segments.length, 3);
    });

    // ── No VOD tag, no ENDLIST ───────────────────────────────────────────────
    test('Test 4: no VOD tag no ENDLIST -> fallback isVod=true', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
https://example.com/seg_00000.ts
#EXTINF:10.0,
https://example.com/seg_00001.ts
#EXTINF:8.5,
https://example.com/seg_00002.ts
''';
      final playlist =
          M3u8Parser.parseMediaPlaylist(content, 'https://example.com/playlist.m3u8');

      expect(playlist.isVod, isTrue);
      expect(playlist.segments.length, 3);
    });

    // ── EVENT playlist without ENDLIST → not VOD ────────────────────────────
    test('Test 5: PLAYLIST-TYPE:EVENT no ENDLIST -> isVod=false', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:EVENT
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
https://example.com/seg_00000.ts
#EXTINF:10.0,
https://example.com/seg_00001.ts
''';
      final playlist =
          M3u8Parser.parseMediaPlaylist(content, 'https://example.com/event.m3u8');

      expect(playlist.isVod, isFalse);
    });

    // ── Explicit VOD tag, no ENDLIST ─────────────────────────────────────────
    test('Test 6: explicit PLAYLIST-TYPE:VOD no ENDLIST -> isVod=true', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
https://example.com/seg_00000.ts
#EXTINF:10.0,
https://example.com/seg_00001.ts
''';
      final playlist =
          M3u8Parser.parseMediaPlaylist(content, 'https://example.com/vod.m3u8');
      expect(playlist.isVod, isTrue);

      const emptyVod = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:10
''';
      final emptyPlaylist =
          M3u8Parser.parseMediaPlaylist(emptyVod, 'https://example.com/empty.m3u8');
      expect(emptyPlaylist.isVod, isTrue);
      expect(emptyPlaylist.segments.length, 0);
    });

    // ── Nested M3U8 expansion ────────────────────────────────────────────────
    test('Test 7: nested M3U8 segments are fully resolved', () async {
      const outerContent = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:30
#EXTINF:10.0,
https://example.com/seg_00000.ts
#EXTINF:30.0,
https://example.com/nested.m3u8
#EXTINF:10.0,
https://example.com/seg_00002.ts
#EXT-X-ENDLIST
''';

      const nestedContent = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:10.0,
seg_a.ts
#EXTINF:10.0,
seg_b.ts
#EXTINF:10.0,
seg_c.ts
#EXT-X-ENDLIST
''';

      final outer =
          M3u8Parser.parseMediaPlaylist(outerContent, 'https://example.com/main.m3u8');
      expect(outer.segments.length, 3);
      expect(outer.segments.where((s) => s.uri.endsWith('.m3u8')).length, 1);

      final resolved = await M3u8Parser.resolveNestedSegments(
        outer.segments,
        (url) async {
          if (url.contains('nested.m3u8')) return nestedContent;
          throw Exception('Unknown URL: $url');
        },
      );

      expect(resolved.length, 5);
      expect(resolved.any((s) => s.uri.endsWith('.m3u8')), isFalse);
      expect(resolved[0].uri, 'https://example.com/seg_00000.ts');
      expect(resolved[1].uri, 'https://example.com/seg_a.ts');
      expect(resolved[2].uri, 'https://example.com/seg_b.ts');
      expect(resolved[3].uri, 'https://example.com/seg_c.ts');
      expect(resolved[4].uri, 'https://example.com/seg_00002.ts');
    });
  });
}
