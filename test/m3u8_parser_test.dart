import 'dart:io';
import 'package:kazumi/utils/m3u8_parser.dart';

void main() {
  print('=== M3U8 Parser 验证测试 ===\n');

  // Test 1: Mux master playlist
  testMasterPlaylist();

  // Test 2: Mux media playlist (有 PLAYLIST-TYPE:VOD + ENDLIST)
  testMuxMediaPlaylist();

  // Test 3: Apple media playlist (有 PLAYLIST-TYPE:VOD, 无 ENDLIST)
  testAppleMediaPlaylist();

  // Test 4: 模拟无 PLAYLIST-TYPE:VOD 也无 ENDLIST 的 playlist
  testNoVodNoEndlist();

  // Test 5: EVENT 类型的 playlist
  testEventPlaylist();

  // Test 6: 显式 PLAYLIST-TYPE:VOD（无 ENDLIST）
  testExplicitVodTag();

  // Test 7: 嵌套 M3U8 展开
  testNestedM3u8();

  print('\n=== 所有测试完成 ===');
}

void testMasterPlaylist() {
  print('--- Test 1: Mux Master Playlist ---');
  final content = File('/tmp/mux_master.m3u8').readAsStringSync();
  final type = M3u8Parser.detectType(content);
  print('类型检测: ${type == M3u8Type.master ? "✓ master" : "✗ 预期 master, 实际 $type"}');

  final master = M3u8Parser.parseMasterPlaylist(content, 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');
  print('变体数量: ${master.variants.length}');
  final best = master.bestVariant;
  print('最佳变体: ${best.resolution ?? "unknown"} @ ${best.bandwidth} bps');
  print('最佳变体 URI: ${best.uri}');
  print('');
}

void testMuxMediaPlaylist() {
  print('--- Test 2: Mux Media Playlist (VOD + ENDLIST) ---');
  final content = File('/tmp/mux_media.m3u8').readAsStringSync();
  final type = M3u8Parser.detectType(content);
  print('类型检测: ${type == M3u8Type.media ? "✓ media" : "✗ 预期 media, 实际 $type"}');

  final playlist = M3u8Parser.parseMediaPlaylist(
    content, 'https://test-streams.mux.dev/x36xhzz/url_0/193039199_mp4_h264_aac_hd_7.m3u8',
  );
  print('isVod: ${playlist.isVod ? "✓ true" : "✗ false (应为 true)"}');
  print('targetDuration: ${playlist.targetDuration}');
  print('分片数量: ${playlist.segments.length}');
  print('首个分片 URI: ${playlist.segments.first.uri}');

  // 检查是否有 PLAYLIST-TYPE:VOD 标签
  final hasVodTag = content.contains('#EXT-X-PLAYLIST-TYPE:VOD');
  final hasEndList = content.contains('#EXT-X-ENDLIST');
  print('原始内容包含 PLAYLIST-TYPE:VOD: $hasVodTag');
  print('原始内容包含 ENDLIST: $hasEndList');
  print('');
}

void testAppleMediaPlaylist() {
  print('--- Test 3: Apple Media Playlist (VOD, 检查 ENDLIST) ---');
  final content = File('/tmp/apple_media.m3u8').readAsStringSync();
  final playlist = M3u8Parser.parseMediaPlaylist(
    content, 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/v5/prog_index.m3u8',
  );

  final hasVodTag = content.contains('#EXT-X-PLAYLIST-TYPE:VOD');
  final hasEndList = content.contains('#EXT-X-ENDLIST');
  print('原始内容包含 PLAYLIST-TYPE:VOD: $hasVodTag');
  print('原始内容包含 ENDLIST: $hasEndList');
  print('isVod: ${playlist.isVod ? "✓ true" : "✗ false (应为 true)"}');
  print('分片数量: ${playlist.segments.length}');
  print('');
}

void testNoVodNoEndlist() {
  print('--- Test 4: 无 VOD 标签、无 ENDLIST（模拟野生源） ---');
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

  final playlist = M3u8Parser.parseMediaPlaylist(content, 'https://example.com/playlist.m3u8');
  // 当前逻辑: !isLiveEvent && segments.isNotEmpty → true
  print('isVod: ${playlist.isVod} (当前逻辑: 兜底判定为 VOD)');
  print('分片数量: ${playlist.segments.length}');
  print('');
}

void testEventPlaylist() {
  print('--- Test 5: EVENT 类型 Playlist ---');
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

  final playlist = M3u8Parser.parseMediaPlaylist(content, 'https://example.com/event.m3u8');
  // EVENT 且无 ENDLIST → 应该判定为非 VOD（直播追赶流）
  print('isVod: ${!playlist.isVod ? "✓ false (正确拒绝 EVENT 流)" : "✗ true (不应判定为 VOD)"}');
  print('');
}

void testExplicitVodTag() {
  print('--- Test 6: 显式 PLAYLIST-TYPE:VOD（无 ENDLIST） ---');
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

  final playlist = M3u8Parser.parseMediaPlaylist(content, 'https://example.com/vod.m3u8');
  print('isVod: ${playlist.isVod ? "✓ true (显式 VOD 标签生效)" : "✗ false (未识别 VOD 标签)"}');

  // 边界情况: 有 VOD 标签但无分片（不应崩溃）
  const emptyVod = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:10
''';
  final emptyPlaylist = M3u8Parser.parseMediaPlaylist(emptyVod, 'https://example.com/empty.m3u8');
  print('空分片 VOD: isVod=${emptyPlaylist.isVod ? "✓ true (仅靠 VOD 标签判定)" : "✗ false"}, segments=${emptyPlaylist.segments.length}');
  print('');
}

void testNestedM3u8() async {
  print('--- Test 7: 嵌套 M3U8 展开 ---');

  // 模拟: 外层 playlist 中有一个 segment 指向另一个 m3u8
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

  final outer = M3u8Parser.parseMediaPlaylist(outerContent, 'https://example.com/main.m3u8');
  print('展开前分片数: ${outer.segments.length}');
  print('其中 m3u8 引用: ${outer.segments.where((s) => s.uri.endsWith(".m3u8")).length}');

  final resolved = await M3u8Parser.resolveNestedSegments(
    outer.segments,
    (url) async {
      if (url.contains('nested.m3u8')) return nestedContent;
      throw Exception('Unknown URL: $url');
    },
  );

  print('展开后分片数: ${resolved.length}');
  print('展开后 URI 列表:');
  for (final seg in resolved) {
    print('  [group=${seg.discontinuityGroup}] ${seg.uri}');
  }
  final hasM3u8Ref = resolved.any((s) => s.uri.endsWith('.m3u8'));
  print('展开后仍有 m3u8 引用: ${!hasM3u8Ref ? "✓ 无 (全部展开)" : "✗ 有 (未完全展开)"}');
  print('');
}
