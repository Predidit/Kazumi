import 'package:kazumi/modules/bangumi/bangumi_item.dart';

import 'bangumi_collection_type.dart';

/// NOTE: 该类仅用于解析 Bangumi API 返回的收藏数据，不适用本地收藏
class BangumiCollection {
  /// 最后更新时间
  DateTime updatedAt;

  /// Bangumi ID
  int bangumiId;

  /// Bangumi 收藏类型。
  BangumiCollectionType type;

  /// 上映日期
  String? date;

  /// 番剧名称
  String name;

  /// 番剧中文名称
  String nameCn;

  /// 简介
  String shortSummary;

  /// 平均评分
  double score;

  /// 总集数
  int eps;

  /// 排名
  int rank;

  /// 图片链接，包含 large、common、medium、small、grid 五种尺寸
  Map<String, String> images;

  /// 标签列表，每个标签包含 name 和 count 字段
  List<Map<String, dynamic>> tags;

  BangumiCollection(
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

  factory BangumiCollection.fromJson(Map json) {
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
    return BangumiCollection(
      subject['id'],
      subject['date'],
      DateTime.parse(json['updated_at']),
      BangumiCollectionType.fromValue(json['type']),
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
