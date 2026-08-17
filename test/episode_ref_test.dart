import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/pages/video/video_controller.dart';

void main() {
  group('EpisodeRef', () {
    test('online keeps list index for history and parses title for danmaku',
        () {
      final episode = EpisodeRef.online(
        listIndex: 1,
        roadIndex: 0,
        displayTitle: '第13话',
        pageUrl: '/episode/13',
      );

      expect(episode.historyEpisodeNumber, 1);
      expect(episode.danmakuEpisodeNumber, 13);
      expect(episode.sortNumber, 13);
      expect(episode.originalRoadIndex, 0);
      expect(episode.pageUrl, '/episode/13');
    });

    test('online falls back to list index when title has no episode number',
        () {
      final episode = EpisodeRef.online(
        listIndex: 2,
        roadIndex: 1,
        displayTitle: 'OVA',
        pageUrl: '/ova',
      );

      expect(episode.historyEpisodeNumber, 2);
      expect(episode.danmakuEpisodeNumber, 2);
      expect(episode.sortNumber, isNull);
      expect(episode.originalRoadIndex, 1);
    });

    test('offline uses downloaded episode number for history and danmaku', () {
      const episode = EpisodeRef.offline(
        listIndex: 1,
        roadIndex: 0,
        displayTitle: '第13话',
        pageUrl: '/episode/13',
        episodeNumber: 13,
        originalRoadIndex: 2,
      );

      expect(episode.historyEpisodeNumber, 13);
      expect(episode.danmakuEpisodeNumber, 13);
      expect(episode.sortNumber, 13);
      expect(episode.originalRoadIndex, 2);
      expect(episode.listIndex, 1);
      expect(episode.pageUrl, '/episode/13');
    });
  });

  group('adjacentEpisodeSelections', () {
    test('follows ascending episode numbers', () {
      final road = _road(['第1话', '第2话', '第3话']);
      const current = VideoEpisodeSelection(episode: 2, road: 0);
      final adjacent = adjacentEpisodeSelections(
        road: road,
        current: current,
      );

      expect(
        adjacent.next,
        const VideoEpisodeSelection(episode: 3, road: 0),
      );
      expect(
        adjacent.previous,
        const VideoEpisodeSelection(episode: 1, road: 0),
      );
    });

    test('reverses list traversal for descending episode numbers', () {
      final road = _road(['第3话', '第2话', '第1话']);
      const current = VideoEpisodeSelection(episode: 2, road: 1);
      final adjacent = adjacentEpisodeSelections(
        road: road,
        current: current,
      );

      expect(
        adjacent.next,
        const VideoEpisodeSelection(episode: 1, road: 1),
      );
      expect(
        adjacent.previous,
        const VideoEpisodeSelection(episode: 3, road: 1),
      );
    });

    test('ignores unnumbered entries when detecting descending order', () {
      final road = _road(['先导片', '第12话', '第11话']);

      expect(
        adjacentEpisodeSelections(
          road: road,
          current: const VideoEpisodeSelection(episode: 3, road: 0),
        ).next,
        const VideoEpisodeSelection(episode: 2, road: 0),
      );
    });

    test('keeps source order when episode numbers cannot be inferred', () {
      final road = _road(['OVA 上篇', 'OVA 下篇']);

      expect(
        adjacentEpisodeSelections(
          road: road,
          current: const VideoEpisodeSelection(episode: 1, road: 0),
        ).next,
        const VideoEpisodeSelection(episode: 2, road: 0),
      );
    });

    test('returns null at chronological boundaries', () {
      final ascending = _road(['第1话', '第2话', '第3话']);
      final descending = _road(['第3话', '第2话', '第1话']);

      expect(
        adjacentEpisodeSelections(
          road: ascending,
          current: const VideoEpisodeSelection(episode: 3, road: 0),
        ).next,
        isNull,
      );
      expect(
        adjacentEpisodeSelections(
          road: descending,
          current: const VideoEpisodeSelection(episode: 1, road: 0),
        ).next,
        isNull,
      );
    });
  });

  test('PlaybackInitParams carries danmaku episode independently', () {
    const params = PlaybackInitParams(
      videoUrl: 'file:///tmp/video.mp4',
      offset: 0,
      isLocalPlayback: true,
      bangumiId: 1,
      pluginName: 'plugin',
      episode: 1,
      danmakuEpisodeNumber: 13,
      httpHeaders: {},
      adBlockerEnabled: false,
      episodeTitle: '第13话',
      referer: '',
      currentRoad: 0,
    );

    expect(params.episode, 1);
    expect(params.danmakuEpisodeNumber, 13);
  });

  group('OfflineRoadListSnapshot', () {
    test('groups downloaded episodes by original road', () {
      final snapshot = buildOfflineRoadListSnapshot([
        _episode(2, '第二话', 2),
        _episode(1, '第一话', 0),
        _episode(4, '第四话', 2),
        _episode(3, '第三话', 0),
      ]);

      expect(snapshot.roads.length, 2);
      expect(snapshot.roads[0].name, '播放列表1');
      expect(snapshot.roads[0].data, ['1', '3']);
      expect(snapshot.roads[0].identifier, ['第一话', '第三话']);
      expect(snapshot.roads[1].name, '播放列表3');
      expect(snapshot.roads[1].data, ['2', '4']);
      expect(snapshot.displayRoadToOriginalRoad, {0: 0, 1: 2});
      expect(snapshot.originalRoadToDisplayRoad, {0: 0, 2: 1});
    });
  });
}

Road _road(List<String> identifiers) {
  return Road(
    name: '播放列表',
    data: List.generate(identifiers.length, (index) => '/episode/$index'),
    identifier: identifiers,
  );
}

DownloadEpisode _episode(int episodeNumber, String name, int road) {
  return DownloadEpisode(
    episodeNumber,
    name,
    road,
    DownloadStatus.completed,
    1.0,
    0,
    0,
    '',
    '',
    '',
    DateTime(2026),
    '',
    0,
    '/episode/$episodeNumber',
  );
}
