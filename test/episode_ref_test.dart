import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/pages/video/video_controller.dart';

EpisodeIdentity _identity(
  String stableId,
  String title, {
  int? ordinal,
  int roadIndex = 0,
  String? pageUrl,
}) {
  return EpisodeIdentity(
    stableId: stableId,
    pageUrl: pageUrl ?? stableId,
    title: title,
    ordinal: ordinal,
    roadIndex: roadIndex,
  );
}

void main() {
  group('EpisodeRef', () {
    test('online keeps list index for history and uses ordinal for danmaku',
        () {
      final episode = EpisodeRef.online(
        listIndex: 1,
        identity: _identity('/episode/13', '第13话', ordinal: 13, roadIndex: 0),
      );

      expect(episode.historyEpisodeNumber, 1);
      expect(episode.danmakuEpisodeNumber, 13);
      expect(episode.sortNumber, 13);
      expect(episode.originalRoadIndex, 0);
      expect(episode.pageUrl, '/episode/13');
      expect(episode.stableId, '/episode/13');
    });

    test('online falls back to list index when rule provides no ordinal', () {
      final episode = EpisodeRef.online(
        listIndex: 2,
        identity: _identity('/ova', 'OVA', ordinal: null, roadIndex: 1),
      );

      expect(episode.historyEpisodeNumber, 2);
      expect(episode.danmakuEpisodeNumber, 2);
      expect(episode.sortNumber, isNull);
      expect(episode.originalRoadIndex, 1);
    });

    test('offline uses downloaded episode number for history and danmaku', () {
      final episode = EpisodeRef.offline(
        listIndex: 1,
        identity: _identity('/episode/13', '第13话', ordinal: 13, roadIndex: 0),
        originalRoadIndex: 2,
      );

      expect(episode.historyEpisodeNumber, 13);
      expect(episode.danmakuEpisodeNumber, 13);
      expect(episode.sortNumber, 13);
      expect(episode.originalRoadIndex, 2);
      expect(episode.listIndex, 1);
      expect(episode.pageUrl, '/episode/13');
      expect(episode.stableId, '/episode/13');
    });
  });

  group('findEpisodeSelectionByStableId', () {
    test('locates the current road position after source reorder', () {
      final roads = [
        Road(
          name: '播放线路1',
          data: [
            _identity('/episode/3', '第三话', ordinal: 3),
            _identity('/episode/1', '第一话', ordinal: 1),
          ],
        ),
        Road(
          name: '播放线路2',
          data: [
            _identity('/episode/2', '第二话', ordinal: 2, roadIndex: 1),
          ],
        ),
      ];

      final selection = findEpisodeSelectionByStableId(roads, '/episode/1');

      expect(selection, isNotNull);
      expect(selection!.road, 0);
      expect(selection.episode, 2);
      expect(findEpisodeSelectionByStableId(roads, ''), isNull);
      expect(findEpisodeSelectionByStableId(roads, '/missing'), isNull);
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
      expect(snapshot.roads[0].data.map((e) => e.ordinal).toList(), [1, 3]);
      expect(snapshot.roads[0].data.map((e) => e.title).toList(),
          ['第一话', '第三话']);
      expect(snapshot.roads[0].data.map((e) => e.stableId).toList(),
          ['/episode/1', '/episode/3']);
      expect(snapshot.roads[1].name, '播放列表3');
      expect(snapshot.roads[1].data.map((e) => e.ordinal).toList(), [2, 4]);
      expect(snapshot.roads[1].data.map((e) => e.title).toList(),
          ['第二话', '第四话']);
      expect(snapshot.displayRoadToOriginalRoad, {0: 0, 1: 2});
      expect(snapshot.originalRoadToDisplayRoad, {0: 0, 2: 1});
    });
  });
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
