import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_relation.dart';

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
    BangumiRelation relation(int id, int type, String label) {
      return BangumiRelation.fromJson({
        'id': id,
        'type': type,
        'name': 'Subject $id',
        'relation': label,
      });
    }

    final result = selectRelatedAnime(
      [
        relation(100, 2, '当前'),
        relation(1, 3, '音乐'),
        relation(2, 2, '前传'),
        relation(2, 2, '重复'),
        relation(3, 2, '续集'),
      ],
      currentSubjectId: 100,
    );

    expect(result.map((item) => item.bangumiItem.id), [2, 3]);
    expect(result.map((item) => item.relation), ['前传', '续集']);
  });
}
