import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_page.dart';
import 'package:kazumi/pages/search/search_result_buffer.dart';
import 'package:kazumi/pages/search/search_result_grid.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/storage/storage.dart';

class _CollectRepository implements ICollectRepository {
  @override
  Stream<void> get onCollectiblesChanged => const Stream<void>.empty();

  Set<int> watched = <int>{};

  @override
  Set<int> getBangumiIdsByType(CollectType type) {
    return type == CollectType.watched ? watched : <int>{};
  }

  @override
  Set<int> getBangumiIdsByTypes(List<CollectType> types) => <int>{};

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

class _SearchHistoryRepository implements ISearchHistoryRepository {
  @override
  Future<void> clearAllHistories() async {}

  @override
  Future<void> deleteHistory(SearchHistory history) async {}

  @override
  Future<void> deleteDuplicates(String keyword) async {}

  @override
  Future<void> deleteOldest() async {}

  @override
  List<SearchHistory> getAllHistories() => <SearchHistory>[];

  @override
  bool isHistoryFull(int maxCount) => false;

  @override
  Future<bool> saveHistory(String keyword) async => true;
}

BangumiItem _item(int id) {
  return BangumiItem(
    id: id,
    type: 2,
    name: 'name-$id',
    nameCn: 'name-$id',
    summary: '',
    airDate: '',
    airWeekday: 0,
    rank: id,
    images: const {},
    tags: const [],
    alias: const [],
    ratingScore: 0,
    votes: 0,
    votesCount: const [],
    info: '',
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kazumi_search_page_test_');
    Hive.init(tempDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    await GStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('opens with an empty result state without a framework exception',
      (tester) async {
    final controller = SearchPageController(
      _CollectRepository(),
      _SearchHistoryRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('搜索'), findsOneWidget);
  });

  testWidgets('opens when the hidden view is selected before it has results',
      (tester) async {
    final controller = SearchPageController(
      _CollectRepository(),
      _SearchHistoryRepository(),
    )..selectedViewMode = SearchViewMode.hideWatched;

    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('隐藏已看'), findsOneWidget);
  });

  testWidgets('view control switches cached results without loading a page',
      (tester) async {
    final offsets = <int>[];
    final controller = SearchPageController.withPageLoader(
      _CollectRepository()..watched = {1},
      _SearchHistoryRepository(),
      (keyword, filter, offset) {
        offsets.add(offset);
        return Future.value(
          BangumiSearchPage(
            items: List<BangumiItem>.generate(3, (i) => _item(i + 1)),
            rawCount: 3,
          ),
        );
      },
    );

    await controller.searchBangumi('alpha', type: 'init');
    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.text('隐藏已看'));
    await tester.pumpAndSettle();

    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList.map((item) => item.id), [2, 3]);
    expect(offsets, [0]);
    expect(find.text('name-1'), findsNothing);
    expect(find.text('name-2'), findsOneWidget);
  });

  testWidgets('load-more control requests one page per tap', (tester) async {
    final offsets = <int>[];
    final controller = SearchPageController.withPageLoader(
      _CollectRepository()..watched = {for (var i = 1; i < 20; i++) i},
      _SearchHistoryRepository(),
      (keyword, filter, offset) {
        offsets.add(offset);
        return Future.value(
          BangumiSearchPage(
            items: List<BangumiItem>.generate(
              20,
              (i) => _item(offset + i + 1),
            ),
            rawCount: 20,
          ),
        );
      },
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);
    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.pump();

    expect(offsets, [0]);
    expect(find.text('加载更多'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('加载更多'),
        matching: find.byType(SearchResultGrid),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();

    expect(offsets, [0, 20]);
    expect(controller.bangumiList.length, 21);
  });

  testWidgets('scrolling to the grid bottom loads the next page',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final offsets = <int>[];
    final secondPage = Completer<BangumiSearchPage?>();
    final controller = SearchPageController.withPageLoader(
      _CollectRepository(),
      _SearchHistoryRepository(),
      (keyword, filter, offset) {
        offsets.add(offset);
        if (offset == 0) {
          return Future.value(
            BangumiSearchPage(
              items: List<BangumiItem>.generate(60, (i) => _item(i + 1)),
              rawCount: 20,
            ),
          );
        }
        return secondPage.future;
      },
    );

    await controller.searchBangumi('alpha', type: 'init');
    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.pump();

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -5000),
    );
    await tester.pump();

    expect(offsets, [0, 20]);

    secondPage.complete(
      BangumiSearchPage(items: [_item(61)], rawCount: 1),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('opens a populated result grid without a framework exception',
      (tester) async {
    final controller = SearchPageController(
      _CollectRepository(),
      _SearchHistoryRepository(),
    )..bangumiList.addAll([_item(1), _item(2), _item(3)]);

    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('name-1'), findsOneWidget);
  });

  testWidgets('opens the search input view without a framework exception',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final controller = SearchPageController(
      _CollectRepository(),
      _SearchHistoryRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(home: SearchPage(controller: controller)),
    );
    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
