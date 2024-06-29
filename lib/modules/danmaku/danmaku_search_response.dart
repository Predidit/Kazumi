class DanmakuAnime {
  int animeId;
  String animeTitle;
  String type;
  String typeDescription;
  String imageUrl;
  DateTime startDate;
  int episodeCount;
  double rating;
  bool isFavorited;

  DanmakuAnime({
    required this.animeId,
    required this.animeTitle,
    required this.type,
    required this.typeDescription,
    required this.imageUrl,
    required this.startDate,
    required this.episodeCount,
    required this.rating,
    required this.isFavorited,
  });

  factory DanmakuAnime.fromJson(Map<String, dynamic> json) {
    return DanmakuAnime(
      animeId: json['animeId'],
      animeTitle: json['animeTitle'],
      type: json['type'],
      typeDescription: json['typeDescription'],
      imageUrl: json['imageUrl'],
      startDate: DateTime.parse(json['startDate']),
      episodeCount: json['episodeCount'],
      rating: json['rating'].toDouble(),
      isFavorited: json['isFavorited'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'animeId': animeId,
      'animeTitle': animeTitle,
      'type': type,
      'typeDescription': typeDescription,
      'imageUrl': imageUrl,
      'startDate': startDate.toIso8601String(),
      'episodeCount': episodeCount,
      'rating': rating,
      'isFavorited': isFavorited,
    };
  }
}

class DanmakuSearchResponse {
  List<DanmakuAnime> animes;
  int errorCode;
  bool success;
  String errorMessage;

  DanmakuSearchResponse({
    required this.animes,
    required this.errorCode,
    required this.success,
    required this.errorMessage,
  });

  factory DanmakuSearchResponse.fromJson(Map<String, dynamic> json) {
    var list = json['animes'] as List;
    List<DanmakuAnime> animeList = list.map((i) => DanmakuAnime.fromJson(i)).toList();

    return DanmakuSearchResponse(
      animes: animeList,
      errorCode: json['errorCode'],
      success: json['success'],
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'animes': animes.map((anime) => anime.toJson()).toList(),
      'errorCode': errorCode,
      'success': success,
      'errorMessage': errorMessage,
    };
  }
}