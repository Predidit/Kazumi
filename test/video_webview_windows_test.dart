import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/video_source/video_source_format.dart';
import 'package:kazumi/webview/video/impl/video_webview_windows_impl.dart';
import 'package:kazumi/webview/video/video_webview_controller.dart';
import 'package:webview_windows/webview_windows.dart';

void main() {
  late VideoWebviewWindowsImpl controller;
  late _Webview webview;
  late List<VideoParserEvent> results;

  setUp(() async {
    webview = _Webview();
    controller = VideoWebviewWindowsImpl()..headlessWebview = webview;
    results = [];
    controller.onVideoURLParser.listen(results.add);
    await controller.loadUrl('https://example.com/player', false, offset: 37);
  });

  tearDown(() async => controller.dispose());

  for (final mime in [
    'audio/mpeg',
    'application/octet-stream',
    '',
    ' Audio/MPEG; charset=binary ',
  ]) {
    test('resolves MP4 with MIME "$mime"', () async {
      webview.resources.add({
        'url': 'https://example.com/VIDEO.MP4?token=abc',
        'method': 'GET',
        'contentType': mime,
      });
      await Future<void>.delayed(Duration.zero);
      expect(results, [
        (
          url: 'https://example.com/VIDEO.MP4?token=abc',
          offset: 37,
          format: VideoSourceFormat.auto,
        ),
      ]);
    });
  }

  test('ignores unrelated resources and keeps waiting for video', () async {
    for (final resource in [
      ('https://example.com/music.mp3', 'audio/mpeg', 'GET'),
      ('https://example.com/image.mp4.png', 'application/octet-stream', 'GET'),
      ('https://example.com/player?url=movie.mp4', 'audio/mpeg', 'GET'),
      ('https://example.com/movie.mp4/preview', 'audio/mpeg', 'GET'),
      ('https://example.com/movie.mp4', 'text/html', 'GET'),
      ('https://example.com/movie.mp4', 'image/png', 'GET'),
      ('https://example.com/movie.mp4', 'audio/aac', 'GET'),
      ('https://example.com/movie.mp4', 'audio/mpeg', 'POST'),
      ('file:///movie.mp4', 'audio/mpeg', 'GET'),
      ('not a url', 'audio/mpeg', 'GET'),
    ]) {
      webview.resources.add({
        'url': resource.$1,
        'contentType': resource.$2,
        'method': resource.$3,
      });
    }
    await Future<void>.delayed(Duration.zero);
    expect(results, isEmpty);
    webview.videos.add({'url': 'https://example.com/play?id=1'});
    await Future<void>.delayed(Duration.zero);
    expect(results.single.url, 'https://example.com/play?id=1');
  });

  test('native HLS keeps format and playback offset', () async {
    webview.playlists.add({'url': 'https://example.com/playlist'});
    await Future<void>.delayed(Duration.zero);
    expect(results, [
      (
        url: 'https://example.com/playlist',
        offset: 37,
        format: VideoSourceFormat.hls,
      ),
    ]);
  });

  test(
    'overlapping source events resolve once and next load can resolve',
    () async {
      final data = {
        'url': 'https://example.com/movie.mp4',
        'method': 'GET',
        'contentType': 'audio/mpeg',
      };
      webview.resources.add(data);
      webview.videos.add(data);
      webview.resources.add(data);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(1));
      await controller.loadUrl('https://example.com/next', false, offset: 12);
      webview.resources.add({...data, 'url': 'https://example.com/next.mp4'});
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(2));
      expect(results.last, (
        url: 'https://example.com/next.mp4',
        offset: 12,
        format: VideoSourceFormat.auto,
      ));
    },
  );
}

class _Webview implements HeadlessWebview {
  final resources = StreamController<Map<String, String>>.broadcast();
  final videos = StreamController<Map<String, String>>.broadcast();
  final playlists = StreamController<Map<String, String>>.broadcast();

  @override
  Stream<Map<String, String>> get onSourceLoaded => resources.stream;
  @override
  Stream<Map<String, String>> get onVideoSourceLoaded => videos.stream;
  @override
  Stream<Map<String, String>> get onM3USourceLoaded => playlists.stream;
  @override
  Future<void> loadUrl(String url) async {}
  @override
  Future<dynamic> executeScript(String script) async => null;
  @override
  Future<void> dispose() async {
    await resources.close();
    await videos.close();
    await playlists.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
