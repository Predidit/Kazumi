import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/search/search_result_buffer.dart';
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

void main() {
  test('loads exactly one raw page per explicit call', () async {
    final offsets = <int>[];
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async {
        offsets.add(offset);
        return _page(Iterable<int>.generate(20, (i) => offset + i + 1));
      },
      watchedIds: () => {for (var i = 1; i < 20; i++) i},
      abandonedIds: () => <int>{},
    );

    await buffer.loadNextPage();

    expect(offsets, [0]);
    expect(buffer.allItems.length, 20);
    expect(buffer.hideWatchedItems.map((item) => item.id), [20]);

    await buffer.loadNextPage();

    expect(offsets, [0, 20]);
    expect(buffer.allItems.length, 40);
    expect(buffer.hideWatchedItems.length, 21);
  });

  test('advances offset by raw count instead of projected item count',
      () async {
    final offsets = <int>[];
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async {
        offsets.add(offset);
        return switch (offset) {
          0 => _page([1, 2], rawCount: 5),
          5 => _page([3], rawCount: 1),
          _ => null,
        };
      },
      watchedIds: () => <int>{1},
      abandonedIds: () => <int>{},
      pageSize: 5,
    );

    await buffer.loadNextPage();
    await buffer.loadNextPage();

    expect(offsets, [0, 5]);
    expect(buffer.allItems.map((item) => item.id), [1, 2, 3]);
    expect(buffer.hideWatchedItems.map((item) => item.id), [2, 3]);
  });

  test('marks a short page as exhausted', () async {
    var calls = 0;
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async {
        calls++;
        return _page([1, 2]);
      },
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
    );

    await buffer.loadNextPage();
    await buffer.loadNextPage();

    expect(calls, 1);
    expect(buffer.isExhausted, isTrue);
  });

  test('deduplicates items while preserving raw pagination offsets', () async {
    final offsets = <int>[];
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async {
        offsets.add(offset);
        return switch (offset) {
          0 => _page([1, 2], rawCount: 20),
          20 => _page([2, 3], rawCount: 20),
          _ => null,
        };
      },
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
    );

    await buffer.loadNextPage();
    await buffer.loadNextPage();

    expect(offsets, [0, 20]);
    expect(buffer.offset, 40);
    expect(buffer.allItems.map((item) => item.id), [1, 2, 3]);
  });

  test('applies hide abandoned to both cached projections', () async {
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async => _page([1, 2, 3]),
      watchedIds: () => <int>{2},
      abandonedIds: () => <int>{1},
    );

    await buffer.loadNextPage();
    buffer.setHideAbandoned(true);

    expect(buffer.allItems.map((item) => item.id), [2, 3]);
    expect(buffer.hideWatchedItems.map((item) => item.id), [3]);
  });

  test('retries a failed page at the same offset without clearing cache',
      () async {
    var attemptsAtTwenty = 0;
    final offsets = <int>[];
    final buffer = SearchResultBuffer(
      pageLoader: (offset) async {
        offsets.add(offset);
        if (offset == 0) {
          return _page(Iterable<int>.generate(20, (i) => i + 1));
        }
        attemptsAtTwenty++;
        if (attemptsAtTwenty == 1) throw StateError('temporary failure');
        return _page([21]);
      },
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
    );

    await buffer.loadNextPage();
    await buffer.loadNextPage();

    expect(buffer.error, isA<StateError>());
    expect(buffer.offset, 20);
    expect(buffer.allItems.length, 20);

    await buffer.loadNextPage();

    expect(offsets, [0, 20, 20]);
    expect(buffer.error, isNull);
    expect(buffer.allItems.last.id, 21);
  });

  test('coalesces concurrent next-page calls into one request', () async {
    final page = Completer<BangumiSearchPage?>();
    var calls = 0;
    final buffer = SearchResultBuffer(
      pageLoader: (offset) {
        calls++;
        return page.future;
      },
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
    );

    final first = buffer.loadNextPage();
    final second = buffer.loadNextPage();
    page.complete(_page([1]));
    await Future.wait([first, second]);

    expect(calls, 1);
    expect(buffer.allItems.single.id, 1);
  });

  test('discards a response after its query is replaced', () async {
    final page = Completer<BangumiSearchPage?>();
    var active = true;
    final buffer = SearchResultBuffer(
      pageLoader: (offset) => page.future,
      watchedIds: () => <int>{},
      abandonedIds: () => <int>{},
      shouldContinue: () => active,
    );

    final load = buffer.loadNextPage();
    active = false;
    page.complete(_page([1]));
    await load;

    expect(buffer.allItems, isEmpty);
    expect(buffer.offset, 0);
  });
}
