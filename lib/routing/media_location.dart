import 'package:kazumi/pages/video/video_playback_args.dart';

String infoLocation(int id) => '/info/$id';

class VideoLocation {
  const VideoLocation._({
    required this.id,
    required this.plugin,
    this.src,
    this.offline = false,
    this.episode,
    this.road,
  });

  final int id;
  final String plugin;
  final String? src;
  final bool offline;
  final int? episode;
  final int? road;

  factory VideoLocation.fromArgs(VideoPlaybackArgs args) => switch (args) {
        OnlineVideoPlaybackArgs() => VideoLocation._(
            id: args.bangumiItem.id,
            plugin: args.plugin.name,
            src: args.src,
            episode: args.episode,
            road: args.road,
          ),
        OfflineVideoPlaybackArgs() => VideoLocation._(
            id: args.bangumiItem.id,
            plugin: args.pluginName,
            offline: true,
            episode: args.episodeNumber,
            road: args.road,
          ),
      };

  factory VideoLocation.parse(Uri uri) {
    final segments = uri.pathSegments;
    final id = segments.length == 2 && segments.first == 'video'
        ? int.tryParse(segments.last)
        : null;
    final query = uri.queryParameters;
    final plugin = query['plugin'];
    final offline = query['mode'] == 'offline';
    final episode = int.tryParse(query['episode'] ?? '');
    final road = int.tryParse(query['road'] ?? '');
    final src = query['src'];
    final sourceUri = Uri.tryParse(src ?? '');
    if (id == null ||
        id <= 0 ||
        plugin == null ||
        plugin.trim().isEmpty ||
        (query.containsKey('mode') && !offline) ||
        (query.containsKey('episode') && (episode == null || episode < 1)) ||
        (query.containsKey('road') && (road == null || road < 0)) ||
        (episode == null) != (road == null) ||
        (offline && episode == null) ||
        (!offline &&
            (sourceUri == null ||
                !['http', 'https'].contains(sourceUri.scheme) ||
                sourceUri.host.isEmpty))) {
      throw const FormatException('播放链接无效，请重新选择播放源。');
    }
    return VideoLocation._(
        id: id,
        plugin: plugin,
        src: src,
        offline: offline,
        episode: episode,
        road: road);
  }

  String get location => Uri(
        path: '/video/$id',
        queryParameters: {
          'plugin': plugin,
          if (offline) 'mode': 'offline' else 'src': src!,
          if (episode != null) 'episode': '$episode',
          if (road != null) 'road': '$road',
        },
      ).toString();

  bool matches(VideoPlaybackArgs args) =>
      location == VideoLocation.fromArgs(args).location;
}
