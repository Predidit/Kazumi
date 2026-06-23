import 'dart:convert';

class PlaybackInitParams {
  final String videoUrl;
  final int offset;
  final bool isLocalPlayback;
  final int bangumiId;
  final String pluginName;
  final int episode;
  final int danmakuEpisodeNumber;
  final Map<String, String> httpHeaders;
  final bool adBlockerEnabled;
  final String episodeTitle;
  final String referer;
  final int currentRoad;
  final SyncPlayEpisodeIdentity syncPlayEpisodeIdentity;
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
    required this.syncPlayEpisodeIdentity,
    this.coverUrl,
    this.bangumiName,
  });
}

class SyncPlayEpisodeIdentity {
  final int bangumiId;
  final int roadIndex;
  final int listIndex;
  final int episodeNumber;
  final bool isLegacy;

  const SyncPlayEpisodeIdentity({
    required this.bangumiId,
    required this.roadIndex,
    required this.listIndex,
    required this.episodeNumber,
    this.isLegacy = false,
  });

  bool get isValid =>
      bangumiId > 0 && roadIndex >= 0 && listIndex > 0 && episodeNumber > 0;

  bool isSameEpisode(SyncPlayEpisodeIdentity other) =>
      bangumiId == other.bangumiId && episodeNumber == other.episodeNumber;

  bool isSameSyncPlayTarget(SyncPlayEpisodeIdentity other) {
    if (isLegacy || other.isLegacy) {
      return bangumiId == other.bangumiId && listIndex == other.listIndex;
    }
    return isSameEpisode(other);
  }
}

class SyncPlayEpisodeCodec {
  static const String prefix = 'kazumi:v2:';

  static String encode(SyncPlayEpisodeIdentity identity) {
    return '$prefix${jsonEncode({
          'bangumiId': identity.bangumiId,
          'roadIndex': identity.roadIndex,
          'listIndex': identity.listIndex,
          'episodeNumber': identity.episodeNumber,
        })}';
  }

  static SyncPlayEpisodeIdentity? decode(
    String? fileName, {
    int fallbackRoadIndex = 0,
  }) {
    if (fileName == null || fileName.isEmpty) {
      return null;
    }
    if (fileName.startsWith(prefix)) {
      return _decodeV2(fileName.substring(prefix.length));
    }
    return _decodeLegacy(fileName, fallbackRoadIndex: fallbackRoadIndex);
  }

  static SyncPlayEpisodeIdentity? _decodeV2(String payload) {
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      final identity = SyncPlayEpisodeIdentity(
        bangumiId: _readInt(json['bangumiId']),
        roadIndex: _readInt(json['roadIndex']),
        listIndex: _readInt(json['listIndex']),
        episodeNumber: _readInt(json['episodeNumber']),
      );
      return identity.isValid ? identity : null;
    } catch (_) {
      return null;
    }
  }

  static SyncPlayEpisodeIdentity? _decodeLegacy(
    String fileName, {
    required int fallbackRoadIndex,
  }) {
    final match = RegExp(r'^(\d+)\[(\d+)\]$').firstMatch(fileName);
    if (match == null) {
      return null;
    }
    final bangumiId = int.tryParse(match.group(1) ?? '') ?? 0;
    final episode = int.tryParse(match.group(2) ?? '') ?? 0;
    final identity = SyncPlayEpisodeIdentity(
      bangumiId: bangumiId,
      roadIndex: fallbackRoadIndex < 0 ? 0 : fallbackRoadIndex,
      listIndex: episode,
      episodeNumber: episode,
      isLegacy: true,
    );
    return identity.isValid ? identity : null;
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
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
