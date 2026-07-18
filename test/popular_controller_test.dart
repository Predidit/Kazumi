import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';

void main() {
  group('PopularController trend pagination', () {
    test('advances by the requested page size when a page is short', () async {
      final requestedOffsets = <int>[];
      final controller = PopularController(
        trendPageLoader: (offset) async {
          requestedOffsets.add(offset);
          return offset == 0
              ? List.generate(22, (index) => _bangumi(index + 1))
              : [_bangumi(25)];
        },
      );

      await controller.queryBangumiByTrend(type: 'init');
      await controller.queryBangumiByTrend();

      expect(requestedOffsets, [0, 24]);
    });

    test('does not add duplicate subjects from overlapping pages', () async {
      final pages = <int, List<BangumiItem>>{
        0: [_bangumi(1), _bangumi(2), _bangumi(3)],
        24: [_bangumi(3), _bangumi(4)],
      };
      final controller = PopularController(
        trendPageLoader: (offset) async => pages[offset] ?? [],
      );

      await controller.queryBangumiByTrend(type: 'init');
      await controller.queryBangumiByTrend();

      expect(controller.trendList.map((item) => item.id), [1, 2, 3, 4]);
    });

    test('resets the request offset when recommendations are refreshed',
        () async {
      final requestedOffsets = <int>[];
      final controller = PopularController(
        trendPageLoader: (offset) async {
          requestedOffsets.add(offset);
          return [_bangumi(offset + 1)];
        },
      );

      await controller.queryBangumiByTrend(type: 'init');
      await controller.queryBangumiByTrend();
      await controller.queryBangumiByTrend(type: 'init');

      expect(requestedOffsets, [0, 24, 0]);
      expect(controller.trendList.map((item) => item.id), [1]);
    });
  });
}

BangumiItem _bangumi(int id) {
  return BangumiItem(
    id: id,
    type: 2,
    name: 'subject-$id',
    nameCn: 'subject-$id',
    summary: '',
    airDate: '',
    airWeekday: 0,
    rank: 0,
    images: const {},
    tags: const [],
    alias: const [],
    ratingScore: 0,
    votes: 0,
    votesCount: const [],
    info: '',
  );
}
