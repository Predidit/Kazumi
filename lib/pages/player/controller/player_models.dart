class PlaybackInitParams {
  final String videoUrl;
  final int offset;
  final bool isLocalPlayback;
  final int bangumiId;
  final String pluginName;
  final int episode;
  final Map<String, String> httpHeaders;
  final bool adBlockerEnabled;
  final String episodeTitle;
  final String referer;
  final int currentRoad;
  final String? coverUrl;
  final String? bangumiName;

  const PlaybackInitParams({
    required this.videoUrl,
    required this.offset,
    required this.isLocalPlayback,
    required this.bangumiId,
    required this.pluginName,
    required this.episode,
    required this.httpHeaders,
    required this.adBlockerEnabled,
    required this.episodeTitle,
    required this.referer,
    required this.currentRoad,
    this.coverUrl,
    this.bangumiName,
  });
}

enum DanmakuDestination {
  chatRoom,
  remoteDanmaku,
}

class SyncPlayChatMessage {
  final String username;
  final String message;
  final bool fromRemote;
  final DateTime time;

  SyncPlayChatMessage({
    required this.username,
    required this.message,
    this.fromRemote = true,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}
