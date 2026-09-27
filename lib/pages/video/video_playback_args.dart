import 'package:kazumi/services/local_video/local_video_playback.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins.dart';

/// Route arguments for '/video/'. Entry points hand playback context over
/// through the route instead of pre-filling a shared controller, which lets
/// [VideoPageController] live and die with the route.
sealed class VideoPlaybackArgs {
  const VideoPlaybackArgs();
}

class OnlineVideoPlaybackArgs extends VideoPlaybackArgs {
  const OnlineVideoPlaybackArgs({
    required this.bangumiItem,
    required this.plugin,
    required this.title,
    required this.src,
    required this.roads,
  });

  final BangumiItem bangumiItem;

  final Plugin plugin;
  final String title;
  final String src;
  final List<Road> roads;
}

class OfflineVideoPlaybackArgs extends VideoPlaybackArgs {
  const OfflineVideoPlaybackArgs({
    required this.bangumiItem,
    required this.pluginName,
    required this.episodeNumber,
    required this.road,
    required this.downloadedEpisodes,
  });

  final BangumiItem bangumiItem;
  final String pluginName;
  final int episodeNumber;
  final int road;
  final List<DownloadEpisode> downloadedEpisodes;
}

class LocalVideoPlaybackArgs extends VideoPlaybackArgs {
  const LocalVideoPlaybackArgs(this.playback);
  final LocalVideoPlayback playback;
}
