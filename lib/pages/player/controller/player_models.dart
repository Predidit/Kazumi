class PlaybackInitParams {
  final String videoUrl;
  final int offset;
  final bool isLocalPlayback;
  final int bangumiId;
  final String pluginName;
  final int episode;
  final int danmakuEpisodeNumber;
  final String pageUrl;
  final String stableId;

  /// 集数排序号，语义同 EpisodeRef.sortNumber（在线优先 Bangumi sort，离线为 episodeNumber）。
  final int? sortNumber;
  final Map<String, String> httpHeaders;
  final bool adBlockerEnabled;
  final String episodeTitle;
  final String referer;
  final int currentRoad;
  final int? downloadRoad;
  final String? coverUrl;
  final String? bangumiName;

  const PlaybackInitParams({
    required this.videoUrl,
    required this.offset,
    required this.isLocalPlayback,
    required this.bangumiId,
    required this.pluginName,
    required this.episode,
    required this.danmakuEpisodeNumber,
    required this.httpHeaders,
    required this.adBlockerEnabled,
    required this.episodeTitle,
    required this.referer,
    required this.currentRoad,
    this.downloadRoad,
    this.pageUrl = '',
    this.stableId = '',
    this.sortNumber,
    this.coverUrl,
    this.bangumiName,
  });
}

class SyncPlayEpisodeIdentity {
  const SyncPlayEpisodeIdentity({
    required this.bangumiId,
    this.road,
    this.episode,
    this.stableId = '',
  });

  final int bangumiId;
  final int? road;
  final int? episode;
  final String stableId;

  bool get hasStableId => stableId.isNotEmpty;

  static String fileNameFor({
    required int bangumiId,
    required int road,
    required int episode,
    required String stableId,
  }) {
    final id = stableId.trim();
    if (id.isEmpty) {
      return legacyFileNameFor(bangumiId: bangumiId, episode: episode);
    }
    return 'kazumi-v2:$bangumiId:$road:${Uri.encodeComponent(id)}';
  }

  static String legacyFileNameFor({
    required int bangumiId,
    required int episode,
  }) {
    return '$bangumiId[$episode]';
  }

  static SyncPlayEpisodeIdentity? parse(String name) {
    final stableMatch =
        RegExp(r'^kazumi-v2:(\d+):(-?\d+):(.+)$').firstMatch(name);
    if (stableMatch != null) {
      try {
        return SyncPlayEpisodeIdentity(
          bangumiId: int.parse(stableMatch.group(1)!),
          road: int.parse(stableMatch.group(2)!),
          stableId: Uri.decodeComponent(stableMatch.group(3)!),
        );
      } catch (_) {
        return null;
      }
    }

    final legacyMatch = RegExp(r'^(\d+)\[(\d+)\]$').firstMatch(name);
    if (legacyMatch == null) {
      return null;
    }
    try {
      return SyncPlayEpisodeIdentity(
        bangumiId: int.parse(legacyMatch.group(1)!),
        episode: int.parse(legacyMatch.group(2)!),
      );
    } catch (_) {
      return null;
    }
  }
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
