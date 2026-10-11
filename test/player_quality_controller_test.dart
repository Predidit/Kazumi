import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/player_quality_controller.dart';

const _master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720
pl_720.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=854x480
pl_480.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=426x240
pl_240.m3u8
''';

void main() {
  late HttpServer server;
  late String masterUrl;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      final body = req.uri.path.endsWith('master.m3u8') ? _master : '#EXTM3U\n';
      req.response
        ..headers.contentType = ContentType('application', 'vnd.apple.mpegurl')
        ..write(body);
      req.response.close();
    });
    masterUrl = 'http://127.0.0.1:${server.port}/master.m3u8';
  });

  tearDownAll(() => server.close());

  test('parses variants, default is auto (highest via mpv)', () async {
    final q = PlayerQualityController();
    final start = await q.prepare(masterUrl, <String, String>{});

    expect(q.isAvailable, isTrue);
    expect(q.qualities.length, 4); // auto + 3 variants
    expect(q.qualities[1].label, '720P'); // sorted desc -> v0 highest
    expect(q.qualities[2].label, '480P');
    expect(q.qualities[3].label, '240P');
    expect(q.currentQualityId, autoQualityId);
    expect(start, masterUrl); // auto opens master; mpv hls-bitrate=max picks top
  });

  test('manual selection records height preference', () async {
    final q = PlayerQualityController();
    await q.prepare(masterUrl, <String, String>{});

    q.applyUserSelection('v1'); // 480P
    expect(q.preferredHeight, 480);
    expect(q.currentQualityId, 'v1');
    expect(q.targetUrlFor('v1')!.endsWith('pl_480.m3u8'), isTrue);
  });

  test('preference carries over to next episode', () async {
    final q = PlayerQualityController();
    await q.prepare(masterUrl, <String, String>{});
    q.applyUserSelection('v1'); // 480P

    // Switching to next episode calls prepare() again with a fresh master.
    final start = await q.prepare(masterUrl, <String, String>{});
    expect(start.endsWith('pl_480.m3u8'), isTrue);
    expect(q.currentQualityId, 'v1');
    expect(q.currentLabel, '480P');
  });

  test('back to auto opens master (highest)', () async {
    final q = PlayerQualityController();
    await q.prepare(masterUrl, <String, String>{});
    q.applyUserSelection('v1');
    q.applyUserSelection(autoQualityId);

    final start = await q.prepare(masterUrl, <String, String>{});
    expect(start, masterUrl);
    expect(q.preferredHeight, isNull);
  });

  test('non-HLS source offers no quality list', () async {
    final q = PlayerQualityController();
    final start = await q.prepare('http://127.0.0.1:${server.port}/video.mp4',
        <String, String>{});
    expect(start, 'http://127.0.0.1:${server.port}/video.mp4');
    expect(q.isAvailable, isFalse);
  });
}
