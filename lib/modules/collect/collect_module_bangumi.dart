
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

/// Bangumi 远程收藏信息（包含最后更新时间）
class BangumiRemoteCollection {
  /// 最后更新时间，秒级
  DateTime updatedAt;

  int bangumiId;

  // Bangumi 收藏类型
  // via: http://bangumi.github.io/api/#/model-CollectionType
  // 与 CollectedBangumi.type 的数值不完全一致，注意区分
  // 1. 想看
  // 2. 看过
  // 3. 在看
  // 4. 搁置
  // 5: 抛弃
  int type;

  // 上映日期 "2025-04-12"
  String? date;

  String name;

  String nameCn;

  String shortSummary;

  // 平均评分
  double score;

  // 总集数
  int eps;

  // 排名
  int rank;

  Map<String, String> images;

  List<Map<String, dynamic>> tags;

  BangumiRemoteCollection(
      this.bangumiId,
      this.date,
      this.updatedAt,
      this.type,
      this.name,
      this.nameCn,
      this.shortSummary,
      this.score,
      this.eps,
      this.rank,
      this.images,
      this.tags);

  int getUpdateAtToInt() {
    return updatedAt.millisecondsSinceEpoch ~/ 1000;
  }

  BangumiItem toBangumiItem() {
    return BangumiItem.fromJson({
      'id': bangumiId,
      'type': 2,
      'name': name,
      'name_cn': nameCn,
      'summary': shortSummary,
      'date': date ?? '',
      'images': images,
      'tags': tags,
      'rating': {
        'rank': rank,
        'score': score,
        'total': 0,
        'count': List<int>.filled(10, 0),
      },
      'info': '',
    });
  }

  factory BangumiRemoteCollection.fromJson(Map json) {
    final subject = json['subject'];
    final subjectImages = Map<String, String>.from(
      subject['images'] ??
          const <String, String>{
            'large': '',
            'common': '',
            'medium': '',
            'small': '',
            'grid': '',
          },
    );
    final subjectTags = ((subject['tags'] ?? const <dynamic>[]) as List)
        .whereType<Map>()
        .map((tag) => Map<String, dynamic>.from(tag))
        .toList();
    return BangumiRemoteCollection(
      subject['id'],
      subject['date'],
      DateTime.parse(json['updated_at']),
      CollectType.fromBangumi(json['type']).value,
      subject['name'],
      subject['name_cn'],
      subject['short_summary'],
      (subject['score'] as num).toDouble(),
      subject['eps'],
      subject['rank'],
      subjectImages,
      subjectTags,
    );
  }
}
