import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
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
  _CollectRepository({Stream<void>? changes})
      : _changes = changes ?? const Stream<void>.empty();

  Set<int> watched = <int>{};
  Set<int> abandoned = <int>{};
  int watchedIdQueryCount = 0;
  final Stream<void> _changes;

  @override
  Stream<void> get onCollectiblesChanged => _changes;

  @override
  Set<int> getBangumiIdsByType(CollectType type) {
    if (type == CollectType.watched) {
      watchedIdQueryCount++;
      return watched;
    }
    if (type == CollectType.abandoned) return abandoned;
    return <int>{};
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
  return SearchPageController.withPageLoader(
    collect,
    _SearchHistoryRepository(),
    loader,
  );
}

void main() {
  test('is disposable for scoped routes', () {
    final controller = _controller(
      (keyword, filter, offset) =>
          Future.value(const BangumiSearchPage(items: [], rawCount: 0)),
      _CollectRepository(),
    );

    expect(controller, isA<Disposable>());
    controller.dispose();
  });

  test('page loader receives the parsed search keyword', () async {
    String? receivedKeyword;
    final controller = _controller((keyword, filter, offset) {
      receivedKeyword = keyword;
      expect(filter.tags, ['奇幻']);
      return Future.value(const BangumiSearchPage(items: [], rawCount: 0));
    }, _CollectRepository());

    await controller.searchBangumi('葬送的芙莉莲 tag:奇幻', type: 'init');

    expect(receivedKeyword, '葬送的芙莉莲');
  });

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

  test('a failed search started from hidden mode can retry in place', () async {
    var attempts = 0;
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      if (offset == 0) {
        return Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)));
      }
      attempts++;
      return attempts == 1
          ? Future<BangumiSearchPage?>.error(StateError('offline'))
          : Future.value(_page(Iterable<int>.generate(20, (i) => i + 21)));
    }, collect)
      ..selectedViewMode = SearchViewMode.hideWatched;

    await controller.searchBangumi('alpha', type: 'init');

    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.hiddenViewError, isA<StateError>());
    expect(controller.bangumiList, isEmpty);

    await controller.retryHiddenView();

    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.hiddenViewError, isNull);
    expect(controller.isTimeOut, isFalse);
    expect(controller.bangumiList.first.id, 20);
  });

  test('retry completion allows filters to prepare more hidden results',
      () async {
    var secondPageAttempts = 0;
    final calls = <int>[];
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return switch (offset) {
        0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
        20 => ++secondPageAttempts == 1
            ? Future<BangumiSearchPage?>.error(StateError('offline'))
            : Future.value(_page(Iterable<int>.generate(20, (i) => i + 21))),
        40 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 41))),
        _ => Future.value(null),
      };
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    await controller.waitForBackgroundPreparation();
    await controller.retryHiddenView();

    collect.abandoned = {for (var i = 20; i < 40; i++) i};
    await controller.setNotShowAbandonedBangumis(true);

    expect(calls, [0, 20, 20, 40]);
    expect(controller.bangumiList.length, 20);
    expect(controller.bangumiList.first.id, 40);
  });

  test('finishing a load more request preserves a newer view selection',
      () async {
    final secondPage = Completer<BangumiSearchPage?>();
    final controller = _controller(
      (keyword, filter, offset) => offset == 0
          ? Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)))
          : secondPage.future,
      _CollectRepository(),
    );

    await controller.searchBangumi('alpha', type: 'init');
    final loadMore = controller.searchBangumi('alpha', type: 'add');
    await Future<void>.delayed(Duration.zero);
    await controller.requestViewMode(SearchViewMode.hideWatched);
    secondPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await loadMore;

    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
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

  test('returning to hidden view restores its published result count',
      () async {
    final controller = _controller((keyword, filter, offset) {
      return switch (offset) {
        0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
        20 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 21))),
        _ => Future.value(null),
      };
    }, _CollectRepository());

    await controller.searchBangumi('alpha', type: 'init');
    await controller.waitForBackgroundPreparation();
    await controller.requestViewMode(SearchViewMode.hideWatched);
    await controller.searchBangumi('alpha', type: 'add');
    expect(controller.bangumiList.length, 40);

    await controller.requestViewMode(SearchViewMode.all);
    await controller.requestViewMode(SearchViewMode.hideWatched);

    expect(controller.bangumiList.length, 40);
  });

  test('restores hidden view depth after a collection update is reversed',
      () async {
    final changes = StreamController<void>.broadcast();
    final collect = _CollectRepository(changes: changes.stream);
    final controller = _controller((keyword, filter, offset) {
      return switch (offset) {
        0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
        20 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 21))),
        _ => Future.value(const BangumiSearchPage(items: [], rawCount: 0)),
      };
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);
    await controller.searchBangumi('alpha', type: 'add');
    expect(controller.bangumiList.length, 40);

    collect.watched = {for (var i = 1; i <= 25; i++) i};
    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.bangumiList.length, 15);

    collect.watched = <int>{};
    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.bangumiList.length, 40);

    controller.dispose();
    await changes.close();
  });

  test('changing a filter before a new search does not await old preparation',
      () async {
    final secondPage = Completer<BangumiSearchPage?>();
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i <= 40; i++) i};
    final controller = _controller((keyword, filter, offset) {
      if (keyword == 'old') {
        return switch (offset) {
          0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
          20 => secondPage.future,
          _ => Future.value(null),
        };
      }
      return Future.value(_page([100]));
    }, collect);

    await controller.searchBangumi('old', type: 'init');
    var filterApplied = false;
    controller
        .setNotShowAbandonedBangumis(true, prepare: false)
        .then((_) => filterApplied = true);
    await Future<void>.delayed(Duration.zero);

    expect(filterApplied, isTrue);
    await controller.searchBangumi('new', type: 'init');
    secondPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await Future<void>.delayed(Duration.zero);

    expect(controller.bangumiList.map((item) => item.id), [100]);
  });

  test('refreshes the active projection when collection state changes',
      () async {
    final changes = StreamController<void>.broadcast();
    final collect = _CollectRepository(changes: changes.stream);
    final controller = _controller(
      (keyword, filter, offset) => Future.value(
        offset == 0 ? _page(Iterable<int>.generate(20, (i) => i + 1)) : null,
      ),
      collect,
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.waitForBackgroundPreparation();
    await controller.requestViewMode(SearchViewMode.hideWatched);

    collect.watched = {1};
    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(controller.bangumiList.first.id, 2);
    controller.dispose();
    await changes.close();
  });

  test('coalesces rapid collection changes into one projection refresh',
      () async {
    final changes = StreamController<void>.broadcast();
    final collect = _CollectRepository(changes: changes.stream);
    final controller = _controller(
      (keyword, filter, offset) => Future.value(
        offset == 0 ? _page(Iterable<int>.generate(20, (i) => i + 1)) : null,
      ),
      collect,
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.waitForBackgroundPreparation();
    collect.watchedIdQueryCount = 0;

    changes
      ..add(null)
      ..add(null)
      ..add(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(collect.watchedIdQueryCount, 1);
    controller.dispose();
    await changes.close();
  });

  test('disposing the controller cancels old query pagination', () async {
    final secondPage = Completer<BangumiSearchPage?>();
    final offsets = <int>[];
    final controller = _controller((keyword, filter, offset) {
      offsets.add(offset);
      return switch (offset) {
        0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
        20 => secondPage.future,
        _ => Future.value(_page([100])),
      };
    }, _CollectRepository()..watched = {for (var i = 1; i <= 40; i++) i});

    await controller.searchBangumi('alpha', type: 'init');
    controller.dispose();
    secondPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await Future<void>.delayed(Duration.zero);

    expect(offsets, [0, 20]);
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

  test('new search begun in hidden mode can reveal all results', () async {
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      return switch (offset) {
        0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
        20 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 21))),
        _ => Future.value(null),
      };
    }, collect)
      ..selectedViewMode = SearchViewMode.hideWatched;

    await controller.searchBangumi('new', type: 'init');
    await controller.requestViewMode(SearchViewMode.all);

    expect(controller.selectedViewMode, SearchViewMode.all);
    expect(controller.bangumiList.map((item) => item.id),
        Iterable<int>.generate(20, (i) => i + 1));
  });

  test('hidden view can reveal cached final-page results after exhaustion',
      () async {
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 11; i++) i};
    final controller = _controller((keyword, filter, offset) {
      return switch (offset) {
        0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
        20 => Future.value(
            _page(Iterable<int>.generate(15, (i) => i + 21), rawCount: 15)),
        _ => Future.value(null),
      };
    }, collect)
      ..selectedViewMode = SearchViewMode.hideWatched;

    await controller.searchBangumi('alpha', type: 'init');

    expect(controller.bangumiList.length, 20);
    expect(controller.hasMoreSearchResults, isTrue);

    await controller.searchBangumi('alpha', type: 'add');

    expect(controller.bangumiList.length, 25);
    expect(controller.hasMoreSearchResults, isFalse);
  });

  test('successful background retry restores the selected all view', () async {
    var attempts = 0;
    final controller = _controller((keyword, filter, offset) async {
      attempts++;
      if (attempts == 1) throw StateError('temporary failure');
      return _page([1]);
    }, _CollectRepository());

    await controller.searchBangumi('alpha', type: 'init');
    await controller.waitForBackgroundPreparation();

    expect(controller.bangumiList.map((item) => item.id), [1]);
    expect(controller.isTimeOut, isFalse);
  });

  test('a replaced query stops the old hidden-view prefetch', () async {
    final secondOldPage = Completer<BangumiSearchPage?>();
    final oldOffsets = <int>[];
    final controller = _controller((keyword, filter, offset) {
      if (keyword == 'old') {
        oldOffsets.add(offset);
        return switch (offset) {
          0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
          20 => secondOldPage.future,
          _ => Future.value(const BangumiSearchPage(items: [], rawCount: 0)),
        };
      }
      return Future.value(_page([100]));
    }, _CollectRepository()..watched = {for (var i = 1; i < 41; i++) i});

    await controller.searchBangumi('old', type: 'init');
    expect(oldOffsets, [0, 20]);

    await controller.searchBangumi('new', type: 'init');
    secondOldPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await Future<void>.delayed(Duration.zero);

    expect(oldOffsets, [0, 20]);
  });
}
