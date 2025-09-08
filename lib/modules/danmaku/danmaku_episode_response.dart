class DanmakuEpisode {
  int episodeId;
  String episodeTitle;

  DanmakuEpisode({
    required this.episodeId,
    required this.episodeTitle,
  });

  factory DanmakuEpisode.fromJson(Map<String, dynamic> json) {
    return DanmakuEpisode(
      episodeId: json['episodeId'],
      episodeTitle: json['episodeTitle'],
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
    var list = json['bangumi']['episodes'] as List;
    List<DanmakuEpisode> episodeList =
        list.map((i) => DanmakuEpisode.fromJson(i)).toList();

    return DanmakuEpisodeResponse(
      bangumiId: json['bangumi']['animeId'],
      episodes: episodeList,
      errorCode: json['errorCode'],
      success: json['success'],
      errorMessage: json['errorMessage'],
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
    return {
      'bangumi': episodes.map((episode) => episode.toJson()).toList(),
      'errorCode': errorCode,
      'success': success,
      'errorMessage': errorMessage,
    };
  }
}
