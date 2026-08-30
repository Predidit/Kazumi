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
        'count': <int>[],
      },
      'info': '',
    });
  }

  factory BangumiCollection.fromJson(Map json) {
    final subject = json['subject'] as Map? ?? const <String, dynamic>{};
    final subjectImages = Map<String, String>.from(
      (subject['images'] as Map?) ??
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
    DateTime updatedAt;
    try {
      final updatedAtStr = json['updated_at'] as String?;
      updatedAt = updatedAtStr != null
          ? DateTime.parse(updatedAtStr)
          : DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return BangumiCollection(
      subject['id'] as int? ?? json['subject_id'] as int? ?? 0,
      subject['date'] as String?,
      updatedAt,
      BangumiCollectionType.fromValue(json['type'] as int? ?? 0),
      subject['name'] as String? ?? '',
      subject['name_cn'] as String? ?? '',
      subject['short_summary'] as String? ?? '',
      (subject['score'] as num?)?.toDouble() ?? 0.0,
      subject['eps'] as int? ?? 0,
      subject['rank'] as int? ?? 0,
      subjectImages,
      subjectTags,
    );
  }
}
