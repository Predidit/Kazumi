import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/pages/search/search_result_buffer.dart';

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

void main() {
  test(
      'fills hidden view from later raw pages when first page is mostly watched',
      () async {
    final offsets = <int>[];
    Future<BangumiSearchPage?> loader(int offset) async {
      offsets.add(offset);
      return switch (offset) {
        0 => _page(Iterable<int>.generate(20, (index) => index + 1)),
        20 => _page(Iterable<int>.generate(20, (index) => index + 21)),
        _ => null,
      };
    }

    final buffer = SearchResultBuffer(
      pageLoader: loader,
      watchedIds: () => Set<int>.from(Iterable<int>.generate(19, (i) => i + 1)),
      abandonedIds: () => <int>{},
    );

    await buffer.ensureReady();

    expect(buffer.allItems.take(20).map((item) => item.id),
        Iterable<int>.generate(20, (index) => index + 1));
    expect(buffer.hideWatchedItems.take(20).map((item) => item.id),
        [20, ...Iterable<int>.generate(19, (index) => index + 21)]);
    expect(offsets, [0, 20]);
    expect(buffer.isReady(SearchViewMode.hideWatched), isTrue);
  });

  test('advances offset by raw count instead of filtered item count', () async {
    final offsets = <int>[];
    Future<BangumiSearchPage?> loader(int offset) async {
      offsets.add(offset);
      return switch (offset) {
        0 => _page([1, 2], rawCount: 5),
        5 => _page([3, 4], rawCount: 2),
        _ => null,
      };
    }

    final buffer = SearchResultBuffer(
      pageLoader: loader,
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
      pageSize: 5,
    );

    await buffer.ensureReady();

    expect(offsets, [0, 5]);
    expect(buffer.allItems.map((item) => item.id), [1, 2, 3, 4]);
  });

  test('continues after a full page adds no new item', () async {
    final offsets = <int>[];
    Future<BangumiSearchPage?> loader(int offset) async {
      offsets.add(offset);
      return switch (offset) {
        0 => _page([1, 2], rawCount: 20),
        20 => _page([1, 2], rawCount: 20),
        40 => _page([3], rawCount: 1),
        _ => null,
      };
    }

    final buffer = SearchResultBuffer(
      pageLoader: loader,
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
    );

    await buffer.ensureReady();

    expect(offsets, [0, 20, 40]);
    expect(buffer.allItems.map((item) => item.id), [1, 2, 3]);
    expect(buffer.isExhausted, isTrue);
  });

  test('reports a retryable error after consecutive full pages add no new item',
      () async {
    final offsets = <int>[];
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async {
        offsets.add(offset);
        return switch (offset) {
          0 || 20 || 40 || 60 => _page([1, 2], rawCount: 20),
          80 => _page(Iterable<int>.generate(18, (index) => index + 3)),
          _ => _page([], rawCount: 0),
        };
      },
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
    );

    await buffer.ensureReady(minimumItems: 20);

    expect(offsets, [0, 20, 40, 60]);
    expect(buffer.allItems.map((item) => item.id), [1, 2]);
    expect(buffer.error, isA<SearchPreparationLimitReached>());
    expect(buffer.isExhausted, isFalse);

    await buffer.retry();

    expect(offsets, [0, 20, 40, 60, 80]);
    expect(buffer.allItems.length, 20);
    expect(buffer.error, isNull);
  });

  test('treats a short duplicate page as exhausted instead of retryable',
      () async {
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async {
        return switch (offset) {
          0 || 20 || 40 => _page([1, 2], rawCount: 20),
          60 => _page([1, 2], rawCount: 1),
          _ => _page([], rawCount: 0),
        };
      },
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
    );

    await buffer.ensureReady(minimumItems: 20);

    expect(buffer.isExhausted, isTrue);
    expect(buffer.error, isNull);
  });

  test(
      'marks filtered view ready with fewer items when raw results are exhausted',
      () async {
    final buffer = SearchResultBuffer(
      pageLoader: (int offset) async => offset == 0 ? _page([1, 2]) : null,
      watchedIds: () => <int>{1},
      abandonedIds: () => <int>{},
    );

    await buffer.ensureReady();

    expect(buffer.hideWatchedItems.map((item) => item.id), [2]);
    expect(buffer.isReady(SearchViewMode.hideWatched), isTrue);
  });

  test('retries a failed page without discarding existing results', () async {
    var attempts = 0;
    final buffer = SearchResultBuffer(
      pageLoader: (int offset) async {
        attempts++;
        if (attempts == 1) throw StateError('temporary failure');
        return _page([1]);
      },
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
    );

    await buffer.ensureReady();
    expect(buffer.error, isA<StateError>());
    expect(buffer.allItems, isEmpty);

    await buffer.retry();

    expect(buffer.error, isNull);
    expect(buffer.allItems.map((item) => item.id), [1]);
  });

  test('applies hide abandoned to both views before hide watched', () async {
    final buffer = SearchResultBuffer(
      pageLoader: (int offset) async => offset == 0 ? _page([1, 2, 3]) : null,
      watchedIds: () => <int>{2},
      abandonedIds: () => <int>{1},
      hideAbandoned: true,
    );

    await buffer.ensureReady();

    expect(buffer.allItems.map((item) => item.id), [2, 3]);
    expect(buffer.hideWatchedItems.map((item) => item.id), [3]);
  });

  test('waits for a larger concurrent preparation target', () async {
    final secondPage = Completer<BangumiSearchPage?>();
    final offsets = <int>[];
    final buffer = SearchResultBuffer(
      pageLoader: (offset) {
        offsets.add(offset);
        return switch (offset) {
          0 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 1))),
          20 => secondPage.future,
          40 => Future.value(_page(Iterable<int>.generate(20, (i) => i + 41))),
          _ => Future.value(null),
        };
      },
      watchedIds: () => {for (var i = 1; i < 11; i++) i},
      abandonedIds: () => <int>{},
    );

    await buffer.ensureReadyFor(SearchViewMode.all);
    final initialPreparation =
        buffer.ensureReadyFor(SearchViewMode.hideWatched, minimumItems: 20);
    final largerPreparation =
        buffer.ensureReadyFor(SearchViewMode.hideWatched, minimumItems: 40);
    secondPage.complete(_page(Iterable<int>.generate(20, (i) => i + 21)));

    await Future.wait([initialPreparation, largerPreparation]);

    expect(offsets, [0, 20, 40]);
    expect(buffer.hideWatchedItems.length, 50);
  });

  test('caps one preparation batch and can continue on retry', () async {
    final offsets = <int>[];
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async {
        offsets.add(offset);
        return _page(Iterable<int>.generate(20, (i) => offset + i + 1));
      },
      watchedIds: () => {for (var i = 1; i <= 200; i++) i},
      abandonedIds: () => <int>{},
    );

    await buffer.ensureReadyFor(SearchViewMode.hideWatched);

    expect(offsets, Iterable<int>.generate(10, (i) => i * 20));
    expect(buffer.error, isNotNull);
    expect(buffer.isReady(SearchViewMode.hideWatched), isFalse);

    await buffer.retry();

    expect(offsets.last, 200);
    expect(buffer.error, isNull);
    expect(buffer.isReady(SearchViewMode.hideWatched), isTrue);
  });
}
