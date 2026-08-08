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

  test('initial search requests only the first page', () async {
    final calls = <int>[];
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)));
    }, _CollectRepository()..watched = {for (var i = 1; i < 20; i++) i});

    await controller.searchBangumi('alpha', type: 'init');
    await Future<void>.delayed(Duration.zero);

    expect(calls, [0]);
    expect(controller.bangumiList.length, 20);
  });

  test('switching views reuses the current cache without a request', () async {
    final calls = <int>[];
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)));
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);
    await controller.requestViewMode(SearchViewMode.all);

    expect(calls, [0]);
    expect(controller.selectedViewMode, SearchViewMode.all);
    expect(controller.bangumiList.length, 20);
  });

  test('one load-more action requests only one page in hidden mode', () async {
    final calls = <int>[];
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i <= 40; i++) i};
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return Future.value(
        _page(Iterable<int>.generate(20, (i) => offset + i + 1)),
      );
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);
    await controller.searchBangumi('alpha', type: 'add');

    expect(calls, [0, 20]);
    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList, isEmpty);
  });

  test('a loaded page supplements both cached views', () async {
    final calls = <int>[];
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return Future.value(
        _page(Iterable<int>.generate(20, (i) => offset + i + 1)),
      );
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);
    await controller.searchBangumi('alpha', type: 'add');

    expect(controller.bangumiList.length, 21);
    await controller.requestViewMode(SearchViewMode.all);

    expect(calls, [0, 20]);
    expect(controller.bangumiList.length, 40);
  });

  test('finishing a load-more request preserves a newer view selection',
      () async {
    final secondPage = Completer<BangumiSearchPage?>();
    final controller = _controller(
      (keyword, filter, offset) => offset == 0
          ? Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)))
          : secondPage.future,
      _CollectRepository()..watched = {1},
    );

    await controller.searchBangumi('alpha', type: 'init');
    final loadMore = controller.searchBangumi('alpha', type: 'add');
    await Future<void>.delayed(Duration.zero);
    await controller.requestViewMode(SearchViewMode.hideWatched);
    secondPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));
    await loadMore;

    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList.first.id, 2);
  });

  test('late pages from an old query cannot replace a new query', () async {
    final oldPage = Completer<BangumiSearchPage?>();
    final controller = _controller((keyword, filter, offset) {
      if (keyword == 'old') return oldPage.future;
      return Future.value(_page([99]));
    }, _CollectRepository());

    final oldSearch = controller.searchBangumi('old', type: 'init');
    await Future<void>.delayed(Duration.zero);
    await controller.searchBangumi('new', type: 'init');
    oldPage.complete(_page([1]));
    await oldSearch;

    expect(controller.bangumiList.map((item) => item.id), [99]);
  });

  test('collection changes refresh the active projection from cache', () async {
    final changes = StreamController<void>.broadcast();
    final collect = _CollectRepository(changes: changes.stream);
    final controller = _controller(
      (keyword, filter, offset) => Future.value(_page([1, 2, 3])),
      collect,
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);
    collect.watched = {1};
    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(controller.bangumiList.map((item) => item.id), [2, 3]);
    controller.dispose();
    await changes.close();
  });

  test('coalesces rapid collection changes into one projection refresh',
      () async {
    final changes = StreamController<void>.broadcast();
    final collect = _CollectRepository(changes: changes.stream);
    final controller = _controller(
      (keyword, filter, offset) => Future.value(_page([1, 2, 3])),
      collect,
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);
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

  test('hide-abandoned updates both projections without loading another page',
      () async {
    final calls = <int>[];
    final collect = _CollectRepository()
      ..watched = {2}
      ..abandoned = {1};
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return Future.value(_page([1, 2, 3]));
    }, collect);

    await controller.searchBangumi('alpha', type: 'init');
    await controller.setNotShowAbandonedBangumis(true);
    expect(controller.bangumiList.map((item) => item.id), [2, 3]);

    await controller.requestViewMode(SearchViewMode.hideWatched);
    expect(controller.bangumiList.map((item) => item.id), [3]);
    expect(calls, [0]);
  });

  test('an empty hidden view can switch back to all cached results', () async {
    final collect = _CollectRepository()..watched = {1, 2, 3};
    final controller = _controller(
      (keyword, filter, offset) => Future.value(_page([1, 2, 3])),
      collect,
    );

    await controller.searchBangumi('alpha', type: 'init');
    await controller.requestViewMode(SearchViewMode.hideWatched);
    expect(controller.bangumiList, isEmpty);

    await controller.requestViewMode(SearchViewMode.all);

    expect(controller.bangumiList.map((item) => item.id), [1, 2, 3]);
  });

  test('a new search begun in hidden mode projects its first page only',
      () async {
    final calls = <int>[];
    final collect = _CollectRepository()
      ..watched = {for (var i = 1; i < 20; i++) i};
    final controller = _controller((keyword, filter, offset) {
      calls.add(offset);
      return Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)));
    }, collect)
      ..selectedViewMode = SearchViewMode.hideWatched;

    await controller.searchBangumi('alpha', type: 'init');

    expect(calls, [0]);
    expect(controller.selectedViewMode, SearchViewMode.hideWatched);
    expect(controller.bangumiList.map((item) => item.id), [20]);
  });

  test('a short first page disables load more', () async {
    final controller = _controller(
      (keyword, filter, offset) => Future.value(_page([1, 2, 3])),
      _CollectRepository(),
    );

    await controller.searchBangumi('alpha', type: 'init');

    expect(controller.hasMoreSearchResults, isFalse);
  });

  test('a failed load-more request can retry the same page', () async {
    var secondPageAttempts = 0;
    final offsets = <int>[];
    final controller = _controller((keyword, filter, offset) {
      offsets.add(offset);
      if (offset == 0) {
        return Future.value(_page(Iterable<int>.generate(20, (i) => i + 1)));
      }
      secondPageAttempts++;
      if (secondPageAttempts == 1) {
        return Future<BangumiSearchPage?>.error(StateError('offline'));
      }
      return Future.value(_page([21]));
    }, _CollectRepository());

    await controller.searchBangumi('alpha', type: 'init');
    await controller.searchBangumi('alpha', type: 'add');
    expect(controller.bangumiList.length, 20);
    expect(controller.hasMoreSearchResults, isTrue);

    await controller.searchBangumi('alpha', type: 'add');

    expect(offsets, [0, 20, 20]);
    expect(controller.bangumiList.last.id, 21);
    expect(controller.hasMoreSearchResults, isFalse);
  });

  test('disposing the controller discards an in-flight page', () async {
    final firstPage = Completer<BangumiSearchPage?>();
    final controller = _controller(
      (keyword, filter, offset) => firstPage.future,
      _CollectRepository(),
    );

    final search = controller.searchBangumi('alpha', type: 'init');
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    firstPage.complete(_page([1]));
    await search;

    expect(controller.bangumiList, isEmpty);
  });
}
