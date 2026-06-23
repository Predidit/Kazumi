import 'package:flutter_test/flutter_test.dart';
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
      final syncPlayIdentity = episode.toSyncPlayEpisodeIdentity(1);
      expect(syncPlayIdentity.listIndex, 1);
      expect(syncPlayIdentity.episodeNumber, 13);
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
      final syncPlayIdentity = episode.toSyncPlayEpisodeIdentity(1);
      expect(syncPlayIdentity.listIndex, 2);
      expect(syncPlayIdentity.episodeNumber, 2);
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
      final syncPlayIdentity = episode.toSyncPlayEpisodeIdentity(1);
      expect(syncPlayIdentity.roadIndex, 2);
      expect(syncPlayIdentity.listIndex, 1);
      expect(syncPlayIdentity.episodeNumber, 13);
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
      syncPlayEpisodeIdentity: SyncPlayEpisodeIdentity(
        bangumiId: 1,
        roadIndex: 0,
        listIndex: 1,
        episodeNumber: 13,
      ),
    );

    expect(params.episode, 1);
    expect(params.danmakuEpisodeNumber, 13);
    expect(params.syncPlayEpisodeIdentity.episodeNumber, 13);
  });
}
