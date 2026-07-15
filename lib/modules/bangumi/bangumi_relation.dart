import 'package:kazumi/modules/bangumi/bangumi_item.dart';

class BangumiRelation {
  const BangumiRelation({
    required this.relation,
    required this.bangumiItem,
  });

  final String relation;
  final BangumiItem bangumiItem;

  factory BangumiRelation.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    if (id == null) {
      throw const FormatException('Bangumi relation is missing a valid id');
    }

    final type = _parseInt(json['type']) ?? 0;
    final name = (json['name'] ?? '').toString().trim();
    final nameCn = (json['name_cn'] ?? '').toString().trim();
    final imagesRaw = json['images'];
    final images = imagesRaw is Map
        ? imagesRaw.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          )
        : <String, String>{};

    final relation = (json['relation'] ?? '').toString().trim();
    return BangumiRelation(
      relation: relation.isEmpty ? '关联' : relation,
      bangumiItem: BangumiItem(
        id: id,
        type: type,
        name: name,
        nameCn: nameCn.isEmpty ? name : nameCn,
        summary: '',
        airDate: '',
        airWeekday: 0,
        rank: 0,
        images: images,
        tags: [],
        alias: [],
        ratingScore: 0,
        votes: 0,
        votesCount: [],
        info: '',
      ),
    );
  }

  BangumiItem toBangumiItem() => bangumiItem;

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

List<BangumiRelation> selectRelatedAnime(
  Iterable<BangumiRelation> relations, {
  required int currentSubjectId,
}) {
  final seenIds = <int>{};
  return relations.where((relation) {
    final item = relation.bangumiItem;
    return item.type == 2 &&
        item.id != currentSubjectId &&
        seenIds.add(item.id);
  }).toList(growable: false);
}
