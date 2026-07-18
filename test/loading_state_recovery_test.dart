import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/pages/info/character_page.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';

void main() {
  group('recoverable page loading state', () {
    test('popular loading resets after an exception and can retry', () async {
      var attempts = 0;
      final controller = PopularController(
        trendLoader: (_) async {
          attempts++;
          if (attempts == 1) {
            throw Exception('offline');
          }
          return [];
        },
        tagLoader: (_, __) async => [],
      );

      await controller.queryBangumiByTrend(type: 'init');

      expect(controller.isLoadingMore, isFalse);
      expect(controller.isTimeOut, isTrue);
      expect(controller.loadError, isNotNull);

      await controller.queryBangumiByTrend(type: 'init');

      expect(attempts, 2);
      expect(controller.isLoadingMore, isFalse);
      expect(controller.loadError, isNull);
    });

    test('timeline loading resets after an exception and can retry', () async {
      var attempts = 0;
      final controller = TimelineController(
        _FakeCollectRepository(),
        calendarLoader: () async {
          attempts++;
          if (attempts == 1) {
            throw Exception('offline');
          }
          return [];
        },
      );

      await controller.getSchedules();

      expect(controller.isLoading, isFalse);
      expect(controller.isTimeOut, isTrue);
      expect(controller.loadError, isNotNull);

      await controller.getSchedules();

      expect(attempts, 2);
      expect(controller.isLoading, isFalse);
      expect(controller.loadError, isNull);
    });

    test('text search loading resets after an exception and can retry',
        () async {
      var attempts = 0;
      final controller = SearchPageController(
        _FakeCollectRepository(),
        _FakeSearchHistoryRepository(),
        searchLoader: (_, __) async {
          attempts++;
          if (attempts == 1) {
            throw Exception('offline');
          }
          return [];
        },
      );

      await controller.searchBangumi('test', type: 'init');

      expect(controller.isLoading, isFalse);
      expect(controller.isTimeOut, isTrue);
      expect(controller.loadError, isNotNull);

      await controller.searchBangumi('test', type: 'init');

      expect(attempts, 2);
      expect(controller.isLoading, isFalse);
      expect(controller.loadError, isNull);
    });

    test('search pagination failure preserves already loaded results',
        () async {
      final controller = SearchPageController(
        _FakeCollectRepository(),
        _FakeSearchHistoryRepository(),
        searchLoader: (_, __) async => throw Exception('offline'),
      );
      controller.bangumiList.add(_bangumiItem());

      await controller.searchBangumi('test', type: 'add');

      expect(controller.bangumiList, hasLength(1));
      expect(controller.isTimeOut, isFalse);
      expect(controller.loadError, isNotNull);
      expect(controller.isLoading, isFalse);
    });
  });

  testWidgets('character failure leaves loading state and exposes retry',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterPage(
          characterID: 1,
          characterName: '测试人物',
          characterLoader: (_) async {
            attempts++;
            throw Exception('offline');
          },
          commentsLoader: (_) async => throw Exception('offline'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('人物资料加载失败，请重试'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('点击重试').first);
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('人物资料加载失败，请重试'), findsOneWidget);
  });
}

BangumiItem _bangumiItem() {
  return BangumiItem(
    id: 1,
    type: 2,
    name: 'test',
    nameCn: 'test',
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

class _FakeCollectRepository implements ICollectRepository {
  @override
  Set<int> getBangumiIdsByType(CollectType type) => {};

  @override
  Set<int> getBangumiIdsByTypes(List<CollectType> types) => {};

  @override
  bool getPrivateMode() => true;

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

class _FakeSearchHistoryRepository implements ISearchHistoryRepository {
  @override
  Future<void> clearAllHistories() async {}

  @override
  Future<void> deleteDuplicates(String keyword) async {}

  @override
  Future<void> deleteHistory(SearchHistory history) async {}

  @override
  Future<void> deleteOldest() async {}

  @override
  List<SearchHistory> getAllHistories() => [];

  @override
  bool isHistoryFull(int maxCount) => false;

  @override
  Future<bool> saveHistory(String keyword) async => true;
}
