import 'package:hive/hive.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';

part 'bangumi_item.g.dart';

@HiveType(typeId: 0)
class BangumiItem {
  @HiveField(0)
  int id;
  @HiveField(1)
  int type;
  @HiveField(2)
  String name;
  @HiveField(3)
  String nameCn;
  @HiveField(4)
  String summary;
  @HiveField(5)
  String airDate;
  @HiveField(6)
  int airWeekday;
  @HiveField(7)
  int rank;
  @HiveField(8)
  Map<String, String> images;
  @HiveField(9, defaultValue: [])
  List<BangumiTag> tags;
  @HiveField(10, defaultValue: [])
  List<String> alias;

  BangumiItem(
      {required this.id,
      required this.type,
      required this.name,
      required this.nameCn,
      required this.summary,
      required this.airDate,
      required this.airWeekday,
      required this.rank,
      required this.images,
      required this.tags,
      required this.alias});

  factory BangumiItem.fromJson(Map<String, dynamic> json) {
    List<String> parseBangumiAliases(Map<String, dynamic> jsonData) {
      if (jsonData.containsKey('infobox') && jsonData['infobox'] is List) {
        final List<dynamic> infobox = jsonData['infobox'];
        for (var item in infobox) {
          if (item is Map<String, dynamic> && item['key'] == '别名') {
            final dynamic value = item['value'];
            if (value is List) {
              return value
                  .map<String>((element) {
                    if (element is Map<String, dynamic> &&
                        element.containsKey('v')) {
                      return element['v'].toString();
                    }
                    return '';
                  })
                  .where((alias) => alias.isNotEmpty)
                  .toList();
            }
          }
        }
      }
      return [];
    }
    List list = json['tags'] ?? [];
    List<String> bangumiAlias = parseBangumiAliases(json);
    List<BangumiTag> tagList = list.map((i) => BangumiTag.fromJson(i)).toList();
    return BangumiItem(
        id: json['id'],
        type: json['type'] ?? 2,
        name: json['name'] ?? '',
        nameCn: (json['name_cn'] ?? '') == ''
            ? (((json['nameCN'] ?? '') == '') ? json['name'] : json['nameCN'])
            : json['name_cn'],
        summary: json['summary'] ?? '',
        airDate: json['air_date'] ?? json['date'] ?? '',
        airWeekday: json['air_weekday'] ??
            Utils.dateStringToWeekday(json['date'] ?? '2000-11-11'),
        rank: json['rating']['rank'] ?? json['rank'] ?? 0,
        images: Map<String, String>.from(
          json['images'] ??
              {
                "large": json['image'],
                "common": "",
                "medium": "",
                "small": "",
                "grid": ""
              },
        ),
        tags: tagList,
        alias: bangumiAlias);
  }
}
