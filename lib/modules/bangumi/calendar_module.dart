class Weekday {
  String? en;
  String? cn;
  String? ja;
  int? id;

  Weekday({this.en, this.cn, this.ja, this.id});

  factory Weekday.fromJson(Map<String, dynamic> json) {
    return Weekday(
      en: json['en'],
      cn: json['cn'],
      ja: json['ja'],
      id: json['id'],
    );
  }
}

class RatingCount {
  int? count1;
  int? count2;
  int? count3;
  int? count4;
  int? count5;
  int? count6;
  int? count7;
  int? count8;
  int? count9;
  int? count10;

  RatingCount({
    this.count1,
    this.count2,
    this.count3,
    this.count4,
    this.count5,
    this.count6,
    this.count7,
    this.count8,
    this.count9,
    this.count10,
  });

  factory RatingCount.fromJson(Map<String, dynamic> json) {
    return RatingCount(
      count1: json['1'],
      count2: json['2'],
      count3: json['3'],
      count4: json['4'],
      count5: json['5'],
      count6: json['6'],
      count7: json['7'],
      count8: json['8'],
      count9: json['9'],
      count10: json['10'],
    );
  }
}

class Rating {
  int total;
  RatingCount count;
  double score;

  Rating({required this.total, required this.count, required this.score});

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      total: json['total'],
      count: RatingCount.fromJson(json['count']),
      score: json['score'].toDouble(),
    );
  }
}

class BangumiItem {
  int? id;
  String? url;
  int? type;
  String? name;
  String? nameCn;
  String? summary;
  String? airDate;
  int? airWeekday;
  Rating? rating;
  int? rank;
  Map<String, String>? images;
  Map<String, int>? collection;

  BangumiItem({
    this.id,
    this.url,
    this.type,
    this.name,
    this.nameCn,
    this.summary,
    this.airDate,
    this.airWeekday,
    this.rating,
    this.rank,
    this.images,
    this.collection,
  });

  factory BangumiItem.fromJson(Map<String, dynamic> json) {
    return BangumiItem(
      id: json['id'],
      url: json['url'],
      type: json['type'],
      name: json['name'],
      nameCn: json['name_cn'] == '' ? json['name'] : json['name_cn'],
      summary: json['summary'],
      airDate: json['air_date'],
      airWeekday: json['air_weekday'],
      rating: Rating.fromJson(json['rating']),
      rank: json['rank'],
      images: Map<String, String>.from(json['images']),
      collection: Map<String, int>.from(json['collection']),
    );
  }
}

