import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/pages/search/search_result_buffer.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';

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

BangumiSearchPage _page(Iterable<int> ids, {int? rawCount}) {
  final items = ids.map(_item).toList();
  return BangumiSearchPage(items: items, rawCount: rawCount ?? items.length);
}

class _CollectRepository implements ICollectRepository {
  Set<int> watched = <int>{};
  Set<int> abandoned = <int>{};

  @override
  Set<int> getBangumiIdsByType(CollectType type) {
    return switch (type) {
      CollectType.watched => watched,
      CollectType.abandoned => abandoned,
      _ => <int>{},
    };
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

SearchPageController _controller(
  SearchPageRequestLoader loader,
  _CollectRepository collect,
) {
  return SearchPageController(
    collect,
    _SearchHistoryRepository(),
    pageLoader: loader,
  );
}

void main() {
  test('initial search exposes all items before hidden view finishes',
      () async {
    final secondPage = Completer<BangumiSearchPage?>();
    final calls = <int>[];
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return offset == 0
          ? Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)))
          : secondPage.future;
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');

    expect(controller.selectedViewMode, SearchViewMode.all);
    expect(controller.bangumiList.map((item) => item.id),
        Iterable<int>.generate(20, (i) => i + 1));
    expect(controller.isHiddenViewPreparing, isTrue);
    expect(calls, [0, 20]);

    secondPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await controller.waitForBackgroundPreparation();
  });

  test('requesting hidden view while preparing preserves all mode', () async {
    final secondPage = Completer<BangumiSearchPage?>();
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller(
      (keyword, filter, offset) => offset == 0
          ? Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)))
          : secondPage.future,
      collect,
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);

    expect(controller.selectedViewMode, SearchViewMode.all);
    expect(controller.pendingViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList.map((item) => item.id),
        Iterable<int>.generate(20, (i) => i + 1));

    secondPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await controller.waitForBackgroundPreparation();
    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList.length, 20);
    expect(controller.bangumiList.first.id, 20);
  });

  test('failed hidden prefetch exposes retry state without clearing all items',
      () async {
    var attempts = 0;
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      if (offset == 0) {
        return Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)));
      }
      attempts++;
      if (attempts == 1) {
        return Future<BangumiSearchPage?>.error(StateError('offline'));
      }
      return Future.value(_page(Iterable<int>.generate(20, (i) => i + 21)));
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    await controller.waitForBackgroundPreparation();

    expect(controller.selectedViewMode, SearchViewMode.all);
    expect(controller.hiddenViewError, isA<StateError>());
    expect(controller.isHiddenViewPreparing, isFalse);
    expect(controller.bangumiList.length, 20);

    await controller.retryHiddenView();

    expect(controller.hiddenViewError, isNull);
    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList.first.id, 20);
  });

  test('late pages from an old query cannot replace the new query', () async {
    final oldPage = Completer<BangumiSearchPage?>();
    final collect = _CollectRepository();
    final controller = _controller((keyword, filter, offset) {
      if (keyword == 'old') return oldPage.future;
      return Future.value(_page([99]));
    }, collect);

    final oldSearch = controller.searchBangumi('old', type: 'init');
    await Future<void>.delayed(Duration.zero);
    await controller.searchBangumi('new', type: 'init');
    oldPage.complete(_page([1]));
    await oldSearch;

    expect(controller.bangumiList.map((item) => item.id), [99]);
  });

  test('cached raw pages are reused when revealing the next all batch',
      () async {
    final calls = <int>[];
    final secondPage = Completer<BangumiSearchPage?>();
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return switch (offset) {
        0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
        20 => secondPage.future,
        _ => Future.value(null),
      };
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    secondPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await controller.waitForBackgroundPreparation();
    await controller.searchBangumi('alpha', type: 'add');

    expect(controller.bangumiList.length, 40);
    expect(calls, [0, 20]);
  });

  test('changing hide abandoned rebuilds both projections from raw order',
      () async {
    final collect = _CollectRepository()..abandoned = {1};
    final controller = _controller(
      (keyword, filter, offset) =>
          offset == 0 ? Future.value(_page([1, 2, 3])) : Future.value(null),
      collect,
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.setNotShowAbandonedBangumis(true);

    expect(controller.bangumiList.map((item) => item.id), [2, 3]);
    await controller.requestViewMode(SearchViewMode.hideWatched);
    expect(controller.bangumiList.map((item) => item.id), [2, 3]);
  });

  test('hiding abandoned items refills the prepared views', () async {
    final collect = _CollectRepository()
      ..abandoned = {for (var i = 1; i < 20; i++) i};
    final calls = <int>[];
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return switch (offset) {
        0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
        20 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 21))),
        _ => Future.value(null),
      };
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    await controller.setNotShowAbandonedBangumis(true);

    expect(calls, [0, 20]);
    expect(controller.bangumiList.length, 20);
    expect(controller.bangumiList.first.id, 20);
  });

  test('an empty hidden view can switch back to all results', () async {
    final collect = _CollectRepository()..watched = {1, 2, 3};
    final controller = _controller(
      (keyword, filter, offset) =>
          offset == 0 ? Future.value(_page([1, 2, 3])) : Future.value(null),
      collect,
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.waitForBackgroundPreparation();
    await controller.requestViewMode(SearchViewMode.hideWatched);

    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList, isEmpty);

    await controller.requestViewMode(SearchViewMode.all);

    expect(controller.selectedViewMode, SearchViewMode.all);
    expect(controller.bangumiList.map((item) => item.id), [1, 2, 3]);
  });

  test('new search from hidden mode never publishes watched items first',
      () async {
    final hiddenPage = Completer<BangumiSearchPage?>();
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      if (offset == 0) {
        return Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)));
      }
      return hiddenPage.future;
    }, collect);
    controller.selectedViewMode = SearchViewMode.hideWatched;

    final search = controller.searchBangumi('new', type: 'init');
    await Future<void>.delayed(Duration.zero);
    expect(controller.bangumiList, isEmpty);
    expect(controller.selectedViewMode, SearchViewMode.hideWatched);

    hiddenPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await search;
    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList.first.id, 20);
  });
}
