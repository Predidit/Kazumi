import 'package:kazumi/modules/bangumi/rating_item.dart';

class BangumiItem {
  int? id;
  String? url;
  int? type;
  String? name;
  String? nameCn;
  String? summary;
  String? airDate;
  int? airWeekday;
  // Rating? rating;
  // int? rank;
  Map<String, String>? images;
  // Map<String, int>? collection;

  BangumiItem({
    this.id,
    this.url,
    this.type,
    this.name,
    this.nameCn,
    this.summary,
    this.airDate,
    this.airWeekday,
    // this.rating,
    // this.rank,
    this.images,
    // this.collection,
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
      // rating: Rating.fromJson(json['rating']),
      // rank: json['rank'],
      images: Map<String, String>.from(json['images']),
      // collection: Map<String, int>.from(json['collection']),
    );
  }
}
