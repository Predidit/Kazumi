/// Raised when the danmaku backend answers with a well-formed error payload
/// instead of the requested data.
///
/// dandanplay reports rate limiting and other failures as a `success: false`
/// body carrying `errorCode` / `errorMessage`, and omits the usual data keys
/// entirely. Following the data keys unconditionally turned every such answer
/// into `NoSuchMethodError: The method '[]' was called on null`, which threw
/// away the server's own explanation and left the UI showing a generic failure.
class DanmakuApiException implements Exception {
  const DanmakuApiException({
    required this.errorCode,
    required this.errorMessage,
  });

  final int errorCode;
  final String errorMessage;

  @override
  String toString() {
    final detail = errorMessage.isEmpty ? '无错误信息' : errorMessage;
    return 'DanmakuApiException($errorCode): $detail';
  }
}

class DanmakuEpisode {
  int episodeId;
  String episodeTitle;

  DanmakuEpisode({
    required this.episodeId,
    required this.episodeTitle,
  });

  factory DanmakuEpisode.fromJson(Map<String, dynamic> json) {
    return DanmakuEpisode(
      episodeId: json['episodeId'] as int? ?? 0,
      episodeTitle: json['episodeTitle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'episodeId': episodeId,
      'episodeTitle': episodeTitle,
    };
  }
}

class DanmakuEpisodeResponse {
  int bangumiId;
  List<DanmakuEpisode> episodes;
  int errorCode;
  bool success;
  String errorMessage;

  DanmakuEpisodeResponse({
    required this.bangumiId,
    required this.episodes,
    required this.errorCode,
    required this.success,
    required this.errorMessage,
  });

  factory DanmakuEpisodeResponse.fromJson(Map<String, dynamic> json) {
    final errorCode = json['errorCode'] as int? ?? 0;
    final errorMessage = json['errorMessage'] as String? ?? '';
    final success = json['success'] as bool? ?? false;

    final bangumi = json['bangumi'];
    if (bangumi is! Map) {
      // No usable payload. Surface the server's own error instead of failing
      // with an opaque null error somewhere further down.
      throw DanmakuApiException(
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
    }

    final rawEpisodes = bangumi['episodes'];
    final episodeList = rawEpisodes is List
        ? [
            for (final episode in rawEpisodes)
              if (episode is Map<String, dynamic>)
                DanmakuEpisode.fromJson(episode),
          ]
        : <DanmakuEpisode>[];

    return DanmakuEpisodeResponse(
      bangumiId: bangumi['animeId'] as int? ?? 0,
      episodes: episodeList,
      errorCode: errorCode,
      success: success,
      errorMessage: errorMessage,
    );
  }

  factory DanmakuEpisodeResponse.fromTemplate() {
    return DanmakuEpisodeResponse(
      bangumiId: 0,
      episodes: [],
      errorCode: 0,
      success: false,
      errorMessage: '',
    );
  }

  Map<String, dynamic> toJson() {
    // Must mirror fromJson: `bangumi` is an object holding `animeId` and
    // `episodes`, not the episode list itself. The previous shape could not be
    // read back by fromJson.
    return {
      'bangumi': {
        'animeId': bangumiId,
        'episodes': episodes.map((episode) => episode.toJson()).toList(),
      },
      'errorCode': errorCode,
      'success': success,
      'errorMessage': errorMessage,
    };
  }
}
