import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_relation.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';

void main() {
  group('BangumiRelation.fromJson', () {
    test('parses relation metadata into a lightweight BangumiItem', () {
      final relation = BangumiRelation.fromJson({
        'id': 123,
        'type': 2,
        'name': 'Original Name',
        'name_cn': '中文名',
        'relation': '续集',
        'images': {
          'large': 'https://example.com/large.jpg',
          'grid': 'https://example.com/grid.jpg',
        },
      });

      expect(relation.relation, '续集');
      expect(relation.bangumiItem.id, 123);
      expect(relation.bangumiItem.type, 2);
      expect(relation.bangumiItem.nameCn, '中文名');
      expect(
        relation.bangumiItem.images['large'],
        'https://example.com/large.jpg',
      );
      expect(relation.toBangumiItem(), same(relation.bangumiItem));
      expect(relation.bangumiItem.summary, isEmpty);
      expect(relation.bangumiItem.votesCount, isEmpty);
    });

    test('falls back to original name and tolerates missing images', () {
      final relation = BangumiRelation.fromJson({
        'id': '456',
        'type': '2',
        'name': 'Original Name',
        'name_cn': '',
        'relation': '前传',
      });

      expect(relation.bangumiItem.id, 456);
      expect(relation.bangumiItem.type, 2);
      expect(relation.bangumiItem.nameCn, 'Original Name');
      expect(relation.bangumiItem.images, isEmpty);
    });

    test('rejects entries without a valid subject id', () {
      expect(
        () => BangumiRelation.fromJson({'id': 'invalid'}),
        throwsFormatException,
      );
    });
  });

  test('selectRelatedAnime filters, excludes current item and deduplicates',
      () {
    final result = selectRelatedAnime(
      [
        _relation(100, relation: '当前'),
        _relation(1, type: 3, relation: '音乐'),
        _relation(2, relation: '前传'),
        _relation(2, relation: '重复'),
        _relation(3, relation: '续集'),
      ],
      currentSubjectId: 100,
    );

    expect(result.map((item) => item.bangumiItem.id), [2, 3]);
    expect(result.map((item) => item.relation), ['前传', '续集']);
  });

  group('resolveRelatedAnimeChain', () {
    test('loads every earlier season by following prequel relations', () async {
      final graph = <int, List<BangumiRelation>>{
        501963: [
          _relation(101114, type: 1, relation: '书籍'),
          _relation(444557, relation: '前传'),
        ],
        444557: [
          _relation(373247, relation: '前传'),
          _relation(501963, relation: '续集'),
        ],
        373247: [
          _relation(325585, relation: '前传'),
          _relation(444557, relation: '续集'),
        ],
        325585: [
          _relation(277554, relation: '前传'),
          _relation(373247, relation: '续集'),
        ],
        277554: [_relation(325585, relation: '续集')],
      };
      final requestedIds = <int>[];

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 501963,
        fetchRelations: (id) async {
          requestedIds.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(
        result.map((relation) => relation.bangumiItem.id),
        [277554, 325585, 373247, 444557],
      );
      expect(
        result.map((relation) => relation.relation),
        everyElement(bangumiPrequelRelation),
      );
      expect(requestedIds, [501963, 444557, 373247, 325585, 277554]);
    });

    test('loads every later season when starting from the first season',
        () async {
      final graph = <int, List<BangumiRelation>>{
        277554: [_relation(325585, relation: '续集')],
        325585: [
          _relation(277554, relation: '前传'),
          _relation(373247, relation: '续集'),
        ],
        373247: [
          _relation(325585, relation: '前传'),
          _relation(444557, relation: '续集'),
        ],
        444557: [
          _relation(373247, relation: '前传'),
          _relation(501963, relation: '续集'),
        ],
        501963: [_relation(444557, relation: '前传')],
      };
      final requestedIds = <int>[];

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 277554,
        fetchRelations: (id) async {
          requestedIds.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(
        result.map((relation) => relation.bangumiItem.id),
        [325585, 373247, 444557, 501963],
      );
      expect(
        result.map((relation) => relation.relation),
        everyElement(bangumiSequelRelation),
      );
      expect(requestedIds, [277554, 325585, 373247, 444557, 501963]);
    });

    test('loads both sides of the mainline from a middle season', () async {
      final graph = <int, List<BangumiRelation>>{
        3: [
          _relation(2, relation: '前传'),
          _relation(4, relation: '续集'),
        ],
        2: [
          _relation(1, relation: '前传'),
          _relation(3, relation: '续集'),
        ],
        1: [_relation(2, relation: '续集')],
        4: [
          _relation(3, relation: '前传'),
          _relation(5, relation: '续集'),
        ],
        5: [_relation(4, relation: '前传')],
      };
      final requestedIds = <int>[];

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 3,
        fetchRelations: (id) async {
          requestedIds.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(result.map((relation) => relation.bangumiItem.id), [1, 2, 4, 5]);
      expect(
        result.map((relation) => relation.relation),
        ['前传', '前传', '续集', '续集'],
      );
      expect(requestedIds, [3, 2, 4, 1, 5]);
    });

    test('keeps direct relations and only expands mainline branches', () async {
      final requestedIds = <int>[];
      final graph = <int, List<BangumiRelation>>{
        10: [
          _relation(9, relation: '前传'),
          _relation(11, relation: '续集'),
          _relation(12, relation: '番外篇'),
        ],
        9: const [],
        11: [_relation(13, relation: '续集')],
        13: const [],
      };

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 10,
        fetchRelations: (id) async {
          requestedIds.add(id);
          return graph[id] ??
              (throw StateError('relation $id must not be expanded'));
        },
      );

      expect(
        result.map((relation) => relation.bangumiItem.id),
        [9, 11, 13, 12],
      );
      expect(
        result.map((relation) => relation.relation),
        ['前传', '续集', '续集', '番外篇'],
      );
      expect(requestedIds, [10, 9, 11, 13]);
    });

    test('terminates cycles and keeps every subject id stable', () async {
      final requestedIds = <int>[];
      final graph = <int, List<BangumiRelation>>{
        3: [_relation(2, relation: '前传')],
        2: [
          _relation(1, relation: '前传'),
          _relation(1, relation: '前传'),
        ],
        1: [_relation(2, relation: '前传')],
      };

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 3,
        fetchRelations: (id) async {
          requestedIds.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(result.map((relation) => relation.bangumiItem.id), [1, 2]);
      expect(requestedIds, [3, 2, 1]);
    });

    test('keeps a direct label while still expanding a converged branch',
        () async {
      final requestedIds = <int>[];
      final graph = <int, List<BangumiRelation>>{
        3: [
          _relation(1, relation: '番外篇'),
          _relation(2, relation: '前传'),
        ],
        2: [_relation(1, relation: '前传')],
        1: [_relation(0, relation: '前传')],
        0: const [],
      };

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 3,
        fetchRelations: (id) async {
          requestedIds.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(result.map((relation) => relation.bangumiItem.id), [0, 1, 2]);
      expect(
        result.map((relation) => relation.relation),
        ['前传', '番外篇', '前传'],
      );
      expect(requestedIds, [3, 2, 1, 0]);
    });

    test('expands a duplicate direct id when any label marks it as a prequel',
        () async {
      final requestedIds = <int>[];
      final graph = <int, List<BangumiRelation>>{
        2: [
          _relation(1, relation: '番外篇'),
          _relation(1, relation: '前传'),
        ],
        1: const [],
      };

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 2,
        fetchRelations: (id) async {
          requestedIds.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(result.map((relation) => relation.bangumiItem.id), [1]);
      expect(result.single.relation, '番外篇');
      expect(requestedIds, [2, 1]);
    });

    test('filters current and non-anime entries at every depth', () async {
      final graph = <int, List<BangumiRelation>>{
        3: [_relation(2, relation: '前传')],
        2: [
          _relation(3, relation: '前传'),
          _relation(4, type: 3, relation: '前传'),
          _relation(1, relation: '前传'),
        ],
        1: const [],
      };

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 3,
        fetchRelations: (id) async => graph[id] ?? const [],
      );

      expect(result.map((relation) => relation.bangumiItem.id), [1, 2]);
    });

    test('preserves API order within the same prequel depth', () async {
      final graph = <int, List<BangumiRelation>>{
        5: [
          _relation(3, relation: '前传'),
          _relation(4, relation: '前传'),
        ],
        3: [_relation(1, relation: '前传')],
        4: [_relation(2, relation: '前传')],
        1: const [],
        2: const [],
      };

      final result = await resolveRelatedAnimeChain(
        currentSubjectId: 5,
        fetchRelations: (id) async => graph[id] ?? const [],
      );

      expect(result.map((relation) => relation.bangumiItem.id), [1, 2, 3, 4]);
    });

    test('honors depth and fetch count limits', () async {
      final graph = <int, List<BangumiRelation>>{
        4: [_relation(3, relation: '前传')],
        3: [_relation(2, relation: '前传')],
        2: [_relation(1, relation: '前传')],
        1: const [],
      };
      final depthLimitedRequests = <int>[];
      final depthLimited = await resolveRelatedAnimeChain(
        currentSubjectId: 4,
        maxDepth: 2,
        fetchRelations: (id) async {
          depthLimitedRequests.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(depthLimited.map((relation) => relation.bangumiItem.id), [2, 3]);
      expect(depthLimitedRequests, [4, 3]);

      final fetchLimitedRequests = <int>[];
      final fetchLimited = await resolveRelatedAnimeChain(
        currentSubjectId: 4,
        maxFetchCount: 2,
        fetchRelations: (id) async {
          fetchLimitedRequests.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(fetchLimited.map((relation) => relation.bangumiItem.id), [2, 3]);
      expect(fetchLimitedRequests, [4, 3]);

      final directOnlyRequests = <int>[];
      final directOnly = await resolveRelatedAnimeChain(
        currentSubjectId: 4,
        maxDepth: 1,
        maxFetchCount: 1,
        fetchRelations: (id) async {
          directOnlyRequests.add(id);
          return graph[id] ?? const [];
        },
      );

      expect(directOnly.map((relation) => relation.bangumiItem.id), [3]);
      expect(directOnlyRequests, [4]);
    });

    test('propagates a nested request failure without returning a partial list',
        () async {
      final future = resolveRelatedAnimeChain(
        currentSubjectId: 2,
        fetchRelations: (id) async {
          if (id == 2) return [_relation(1, relation: '前传')];
          throw StateError('network failed');
        },
      );

      await expectLater(future, throwsStateError);
    });
  });

  group('BangumiApi.buildBangumiRelationsUrl', () {
    test('uses the official API when mirror mode is disabled', () {
      expect(
        BangumiApi.buildBangumiRelationsUrl(501963, useMirror: false),
        'https://api.bgm.tv/v0/subjects/501963/subjects',
      );
    });

    test('uses the compatible mirror when mirror mode is enabled', () {
      expect(
        BangumiApi.buildBangumiRelationsUrl(501963, useMirror: true),
        'https://api.bgmapi.com/v0/subjects/501963/subjects',
      );
    });
  });
}

BangumiRelation _relation(
  int id, {
  int type = 2,
  required String relation,
}) {
  return BangumiRelation.fromJson({
    'id': id,
    'type': type,
    'name': 'Subject $id',
    'relation': relation,
  });
}
