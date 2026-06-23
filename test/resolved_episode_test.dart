import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/pages/video/video_controller.dart';

void main() {
  group('ResolvedEpisode', () {
    test('online keeps list index for history and parses title for danmaku',
        () {
      final episode = ResolvedEpisode.online(
        listIndex: 1,
        roadIndex: 0,
        displayTitle: '第13话',
        episodePageUrl: '/episode/13',
      );

      expect(episode.historyEpisodeNumber, 1);
      expect(episode.danmakuEpisodeNumber, 13);
      expect(episode.originalRoadIndex, 0);
      expect(episode.episodePageUrl, '/episode/13');
    });

    test('online falls back to list index when title has no episode number',
        () {
      final episode = ResolvedEpisode.online(
        listIndex: 2,
        roadIndex: 1,
        displayTitle: 'OVA',
        episodePageUrl: '/ova',
      );

      expect(episode.historyEpisodeNumber, 2);
      expect(episode.danmakuEpisodeNumber, 2);
      expect(episode.originalRoadIndex, 1);
    });

    test('offline uses downloaded episode number for history and danmaku', () {
      const episode = ResolvedEpisode.offline(
        listIndex: 1,
        roadIndex: 0,
        displayTitle: '第13话',
        episodePageUrl: '/episode/13',
        episodeNumber: 13,
        originalRoadIndex: 2,
      );

      expect(episode.historyEpisodeNumber, 13);
      expect(episode.danmakuEpisodeNumber, 13);
      expect(episode.originalRoadIndex, 2);
      expect(episode.listIndex, 1);
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

    test('finds episode by preferred original road before number fallback', () {
      final snapshot = buildOfflineRoadListSnapshot([
        _episode(1, '线路1 第1话', 0),
        _episode(2, '线路1 第2话', 0),
        _episode(3, '线路3 第3话', 2),
      ]);

      final preferred = snapshot.findEpisodeByNumber(
        3,
        preferredOriginalRoad: 2,
      );
      expect(preferred?.roadIndex, 1);
      expect(preferred?.listIndex, 1);

      final fallback = snapshot.findEpisodeByNumber(
        2,
        preferredOriginalRoad: 2,
      );
      expect(fallback?.roadIndex, 0);
      expect(fallback?.listIndex, 2);
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
