import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_interest.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';

void main() {
  group('InfoController rating refresh', () {
    test('constructs through modular DI with the optional test loader omitted',
        () {
      final cached = _bangumiItem();
      final collectController = CollectController(
        _FakeCollectCrudRepository(cached),
        _FakeCollectRepository(),
      );
      final module = createModule(
        register: (context) {
          context
            ..addInstance<CollectController>(collectController)
            ..add<InfoController>(InfoController.new);
        },
      );

      final controller = bootstrapModule(module).injector.get<InfoController>();

      expect(controller.collectController, same(collectController));
    });

    test(
      'refreshes complete cached ratings and persists the collectible',
      () async {
        final cached = _bangumiItem(
          ratingScore: 7.1,
          votes: 120,
          votesCount: List<int>.filled(10, 12),
        );
        final current = _bangumiItem(
          ratingScore: 8.3,
          votes: 1250,
          votesCount: List<int>.generate(10, (index) => index + 20),
        );
        final crudRepository = _FakeCollectCrudRepository(cached);
        final collectController = CollectController(
          crudRepository,
          _FakeCollectRepository(),
        )..loadCollectibles();
        final requestedIds = <int>[];
        final controller = InfoController(
          collectController,
          bangumiInfoLoader: (id) async {
            requestedIds.add(id);
            return current;
          },
        )..bangumiItem = cached;

        await controller.refreshBangumiInfoByID(cached.id);

        expect(requestedIds, [cached.id]);
        expect(controller.bangumiItem.ratingScore, 8.3);
        expect(controller.bangumiItem.votes, 1250);
        expect(
          controller.bangumiItem.votesCount,
          List<int>.generate(10, (index) => index + 20),
        );
        expect(crudRepository.updateCount, 1);
        expect(
          crudRepository.getCollectible(cached.id)!.bangumiItem.ratingScore,
          8.3,
        );
        expect(collectController.collectibles.single.bangumiItem.votes, 1250);
      },
    );

    test(
      'keeps cached ratings when the detail request has no result',
      () async {
        final cached = _bangumiItem(
          ratingScore: 7.1,
          votes: 120,
          votesCount: List<int>.filled(10, 12),
        );
        final crudRepository = _FakeCollectCrudRepository(cached);
        final collectController = CollectController(
          crudRepository,
          _FakeCollectRepository(),
        );
        final controller = InfoController(
          collectController,
          bangumiInfoLoader: (_) async => null,
        )..bangumiItem = cached;

        await controller.refreshBangumiInfoByID(cached.id);

        expect(controller.bangumiItem.ratingScore, 7.1);
        expect(controller.bangumiItem.votes, 120);
        expect(crudRepository.updateCount, 0);
      },
    );

    test(
      'preserves a local review when a silent response omits interest',
      () async {
        final cached = _bangumiItem(
          ratingScore: 7.1,
          votes: 120,
          votesCount: List<int>.filled(10, 12),
          interest: BangumiInterest(
            id: 1,
            rate: 8,
            type: 1,
            comment: '我的评价',
            tags: const ['推荐'],
            epStatus: 0,
            volStatus: 0,
            updatedAt: 1,
          ),
        );
        final current = _bangumiItem(
          ratingScore: 8.3,
          votes: 1250,
          votesCount: List<int>.generate(10, (index) => index + 20),
        );
        final crudRepository = _FakeCollectCrudRepository(cached);
        final collectController = CollectController(
          crudRepository,
          _FakeCollectRepository(),
        );
        final controller = InfoController(
          collectController,
          bangumiInfoLoader: (_) async => current,
        )..bangumiItem = cached;

        await controller.refreshBangumiInfoByID(
          cached.id,
          preserveInterestWhenMissing: true,
        );

        expect(controller.bangumiItem.ratingScore, 8.3);
        expect(controller.bangumiItem.interest?.rate, 8);
        expect(controller.bangumiItem.interest?.comment, '我的评价');
        expect(
          crudRepository.getCollectible(cached.id)!.bangumiItem.interest?.rate,
          8,
        );
      },
    );

    test(
      'ignores a response for a detail page that is no longer active',
      () async {
        final first = _bangumiItem(id: 1872, ratingScore: 7.1, votes: 120);
        final second = _bangumiItem(id: 2000, ratingScore: 6.5, votes: 80);
        final current = _bangumiItem(id: 1872, ratingScore: 8.3, votes: 1250);
        final crudRepository = _FakeCollectCrudRepository(first);
        final collectController = CollectController(
          crudRepository,
          _FakeCollectRepository(),
        );
        final controller = InfoController(
          collectController,
          bangumiInfoLoader: (_) async => current,
        )..bangumiItem = first;

        controller.bangumiItem = second;
        await controller.refreshBangumiInfoByID(first.id);

        expect(controller.bangumiItem.id, second.id);
        expect(controller.bangumiItem.ratingScore, 6.5);
        expect(crudRepository.updateCount, 0);
      },
    );
  });
}

BangumiItem _bangumiItem({
  int id = 1872,
  double ratingScore = 7.0,
  int votes = 100,
  List<int>? votesCount,
  BangumiInterest? interest,
}) {
  return BangumiItem(
    id: id,
    type: 2,
    name: 'Test Anime',
    nameCn: '测试动画',
    summary: 'summary',
    airDate: '2026-01-01',
    airWeekday: 4,
    rank: 100,
    images: const <String, String>{},
    tags: const [],
    alias: const [],
    ratingScore: ratingScore,
    votes: votes,
    votesCount: votesCount ?? List<int>.filled(10, 10),
    info: '',
    interest: interest,
  );
}

class _FakeCollectCrudRepository implements ICollectCrudRepository {
  _FakeCollectCrudRepository(BangumiItem item) {
    collectibles[item.id] = CollectedBangumi(item, DateTime(2026), 1);
  }

  final Map<int, CollectedBangumi> collectibles = {};
  int updateCount = 0;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<void> addCollectChange(CollectedBangumiChange change) async {}

  @override
  Future<void> addCollectible(BangumiItem bangumiItem, int type) async {
    collectibles[bangumiItem.id] = CollectedBangumi(
      bangumiItem,
      DateTime(2026),
      type,
    );
  }

  @override
  Future<void> clearFavorites() async {}

  @override
  Future<void> deleteCollectible(int id) async {
    collectibles.remove(id);
  }

  @override
  List<CollectedBangumi> getAllCollectibles() => collectibles.values.toList();

  @override
  CollectedBangumi? getCollectible(int id) => collectibles[id];

  @override
  int getCollectType(int id) => collectibles[id]?.type ?? 0;

  @override
  List<BangumiItem> getFavorites() => const [];

  @override
  Future<void> updateCollectible(BangumiItem bangumiItem) async {
    final collectible = collectibles[bangumiItem.id];
    if (collectible == null) {
      return;
    }
    updateCount++;
    collectible.bangumiItem = bangumiItem;
  }
}

class _FakeCollectRepository implements ICollectRepository {
  @override
  Set<int> getBangumiIdsByType(CollectType type) => const {};

  @override
  Set<int> getBangumiIdsByTypes(List<CollectType> types) => const {};

  @override
  bool getPrivateMode() => false;

  @override
  bool getTimelineNotShowAbandonedBangumis() => false;

  @override
  bool getTimelineNotShowWatchedBangumis() => false;

  @override
  bool getTimelineOnlyShowWatchingBangumis() => false;

  @override
  Future<void> updateTimelineNotShowAbandonedBangumis(bool value) async {}

  @override
  Future<void> updateTimelineNotShowWatchedBangumis(bool value) async {}

  @override
  Future<void> updateTimelineOnlyShowWatchingBangumis(bool value) async {}
}
