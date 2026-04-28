class BangumiNetxItem {
  int id;
  String name;
  String nameCn;
  int type;
  String info;
  BangumiNetxRating rating;
  bool locked;
  bool nsfw;
  BangumiNetxImages images;

  BangumiNetxItem({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.type,
    required this.info,
    required this.rating,
    required this.locked,
    required this.nsfw,
    required this.images,
  });

  factory BangumiNetxItem.fromJson(Map<String, dynamic> json) {
    return BangumiNetxItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameCn: (json['nameCN'] ?? '').toString(),
      type: json['type'] ?? 2,
      info: json['info'] ?? '',
      rating: BangumiNetxRating.fromJson(json['rating'] ?? {}),
      locked: json['locked'] ?? false,
      nsfw: json['nsfw'] ?? false,
      images: BangumiNetxImages.fromJson(json['images'] ?? {}),
    );
  }
}

class BangumiNetxRating {
  int rank;
  List<int> count;
  double score;
  int total;

  BangumiNetxRating({
    required this.rank,
    required this.count,
    required this.score,
    required this.total,
  });

  factory BangumiNetxRating.fromJson(Map<String, dynamic> json) {
    final dynamic countData = json['count'];
    List<int> parsedCount = [];
    if (countData is List) {
      parsedCount = countData.map((e) => (e as num).toInt()).toList();
    } else if (countData is Map<String, dynamic>) {
      parsedCount = List<int>.generate(
        10,
        (i) => ((countData['${i + 1}'] ?? 0) as num).toInt(),
      );
    }

    return BangumiNetxRating(
      rank: (json['rank'] ?? 0) as int,
      count: parsedCount,
      score: ((json['score'] ?? 0.0) as num).toDouble(),
      total: (json['total'] ?? 0) as int,
    );
  }
}

class BangumiNetxImages {
  String large;
  String common;
  String medium;
  String small;
  String grid;

  BangumiNetxImages({
    required this.large,
    required this.common,
    required this.medium,
    required this.small,
    required this.grid,
  });

  factory BangumiNetxImages.fromJson(Map<String, dynamic> json) {
    return BangumiNetxImages(
      large: json['large'] ?? '',
      common: json['common'] ?? '',
      medium: json['medium'] ?? '',
      small: json['small'] ?? '',
      grid: json['grid'] ?? '',
    );
  }
}
