import 'package:kazumi/modules/bangumi/bangumi_item.dart';

typedef BangumiRelationFetcher = Future<List<BangumiRelation>> Function(int id);

const String bangumiPrequelRelation = '前传';
const String bangumiSequelRelation = '续集';

const Set<String> _bangumiMainlineRelations = {
  bangumiPrequelRelation,
  bangumiSequelRelation,
};

class _BangumiRelationTraversalNode {
  const _BangumiRelationTraversalNode({
    required this.subjectId,
    required this.direction,
  });

  final int subjectId;
  final String direction;
}

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

Future<List<BangumiRelation>> resolveRelatedAnimeChain({
  required int currentSubjectId,
  required BangumiRelationFetcher fetchRelations,
  int maxDepth = 12,
  int maxFetchCount = 20,
}) async {
  if (maxDepth < 1) {
    throw ArgumentError.value(maxDepth, 'maxDepth', 'must be at least 1');
  }
  if (maxFetchCount < 1) {
    throw ArgumentError.value(
      maxFetchCount,
      'maxFetchCount',
      'must be at least 1',
    );
  }

  var fetchCount = 1;
  final rootRelations = await fetchRelations(currentSubjectId);
  final directRelations = selectRelatedAnime(
    rootRelations,
    currentSubjectId: currentSubjectId,
  );
  final relationById = <int, BangumiRelation>{
    for (final relation in directRelations) relation.bangumiItem.id: relation,
  };
  final mainlineDirectionById = <int, String>{};
  final layersByDirection = <String, List<List<BangumiRelation>>>{
    bangumiPrequelRelation: <List<BangumiRelation>>[],
    bangumiSequelRelation: <List<BangumiRelation>>[],
  };
  final scheduledIds = <int>{currentSubjectId};
  var depth = 1;
  var frontier = <_BangumiRelationTraversalNode>[];
  final directLayers = <String, List<BangumiRelation>>{
    bangumiPrequelRelation: <BangumiRelation>[],
    bangumiSequelRelation: <BangumiRelation>[],
  };
  for (final relation in rootRelations) {
    final item = relation.bangumiItem;
    final direction = relation.relation;
    if (!_bangumiMainlineRelations.contains(direction) ||
        item.type != 2 ||
        item.id == currentSubjectId) {
      continue;
    }
    final displayRelation = relationById.putIfAbsent(
      item.id,
      () => BangumiRelation(
        relation: direction,
        bangumiItem: item,
      ),
    );
    if (!mainlineDirectionById.containsKey(item.id)) {
      mainlineDirectionById[item.id] = direction;
      directLayers[direction]!.add(displayRelation);
    }
    if (scheduledIds.add(item.id)) {
      frontier.add(
        _BangumiRelationTraversalNode(
          subjectId: item.id,
          direction: direction,
        ),
      );
    }
  }
  for (final direction in _bangumiMainlineRelations) {
    final layer = directLayers[direction]!;
    if (layer.isNotEmpty) {
      layersByDirection[direction]!.add(layer);
    }
  }

  while (
      frontier.isNotEmpty && depth < maxDepth && fetchCount < maxFetchCount) {
    final nextFrontier = <_BangumiRelationTraversalNode>[];
    final nextLayers = <String, List<BangumiRelation>>{
      bangumiPrequelRelation: <BangumiRelation>[],
      bangumiSequelRelation: <BangumiRelation>[],
    };
    final nodesToFetch =
        frontier.take(maxFetchCount - fetchCount).toList(growable: false);
    final relationLists = await Future.wait([
      for (final node in nodesToFetch)
        Future<List<BangumiRelation>>.sync(
          () => fetchRelations(node.subjectId),
        ),
    ]);
    fetchCount += nodesToFetch.length;
    for (var index = 0; index < nodesToFetch.length; index++) {
      final node = nodesToFetch[index];
      final relations = relationLists[index];
      for (final relation in relations) {
        final item = relation.bangumiItem;
        if (relation.relation != node.direction ||
            item.type != 2 ||
            item.id == currentSubjectId) {
          continue;
        }
        final displayRelation = relationById.putIfAbsent(
          item.id,
          () => BangumiRelation(
            relation: node.direction,
            bangumiItem: item,
          ),
        );
        if (!mainlineDirectionById.containsKey(item.id)) {
          mainlineDirectionById[item.id] = node.direction;
          nextLayers[node.direction]!.add(displayRelation);
        }
        if (scheduledIds.add(item.id)) {
          nextFrontier.add(
            _BangumiRelationTraversalNode(
              subjectId: item.id,
              direction: node.direction,
            ),
          );
        }
      }
    }
    for (final direction in _bangumiMainlineRelations) {
      final layer = nextLayers[direction]!;
      if (layer.isNotEmpty) {
        layersByDirection[direction]!.add(layer);
      }
    }
    frontier = nextFrontier;
    depth++;
  }

  final result = <BangumiRelation>[];
  for (final layer in layersByDirection[bangumiPrequelRelation]!.reversed) {
    result.addAll(layer);
  }
  for (final layer in layersByDirection[bangumiSequelRelation]!) {
    result.addAll(layer);
  }
  result.addAll(
    directRelations.where(
      (relation) => !mainlineDirectionById.containsKey(relation.bangumiItem.id),
    ),
  );
  return List.unmodifiable(result);
}
