import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins.dart';

sealed class VideoPlaybackArgs {
  const VideoPlaybackArgs({required this.bangumiItem});

  final BangumiItem bangumiItem;
}

class OnlineVideoPlaybackArgs extends VideoPlaybackArgs {
  const OnlineVideoPlaybackArgs({
    required super.bangumiItem,
    required this.plugin,
    required this.title,
    required this.src,
    required this.roads,
    this.episode,
    this.road,
  });

  final Plugin plugin;
  final String title;
  final String src;
  final List<Road> roads;
  final int? episode;
  final int? road;
}

class OfflineVideoPlaybackArgs extends VideoPlaybackArgs {
  const OfflineVideoPlaybackArgs({
    required super.bangumiItem,
    required this.pluginName,
    required this.episodeNumber,
    required this.road,
    required this.downloadedEpisodes,
  });

  factory OfflineVideoPlaybackArgs.fromRecord({
    required DownloadRecord record,
    required DownloadEpisode episode,
    required List<DownloadEpisode> downloadedEpisodes,
  }) =>
      OfflineVideoPlaybackArgs(
        bangumiItem: BangumiItem(
          id: record.bangumiId,
          type: 2,
          name: record.bangumiName,
          nameCn: record.bangumiName,
          summary: '',
          airDate: '',
          airWeekday: 0,
          rank: 0,
          images: {'large': record.bangumiCover},
          tags: [],
          alias: [],
          ratingScore: 0,
          votes: 0,
          votesCount: [],
          info: '',
        ),
        pluginName: record.pluginName,
        episodeNumber: episode.episodeNumber,
        road: episode.road,
        downloadedEpisodes: downloadedEpisodes,
      );

  final String pluginName;
  final int episodeNumber;
  final int road;
  final List<DownloadEpisode> downloadedEpisodes;
}
