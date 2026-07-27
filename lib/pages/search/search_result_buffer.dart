import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';

enum SearchViewMode {
  all,
  hideWatched,
}

typedef SearchPageLoader = Future<BangumiSearchPage?> Function(int offset);

class SearchResultBuffer {
  SearchResultBuffer({
    required SearchPageLoader pageLoader,
    required Set<int> Function() watchedIds,
    required Set<int> Function() abandonedIds,
    this.hideAbandoned = false,
    this.pageSize = 20,
  })  : _pageLoader = pageLoader,
        _watchedIds = watchedIds,
        _abandonedIds = abandonedIds;

  final SearchPageLoader _pageLoader;
  final Set<int> Function() _watchedIds;
  final Set<int> Function() _abandonedIds;

  final int pageSize;
  bool hideAbandoned;

  final List<BangumiItem> _rawItems = [];
  final Set<int> _rawIds = <int>{};
  int _offset = 0;
  bool _isExhausted = false;
  bool _isPreparing = false;
  Object? _error;
  Future<void>? _preparationFuture;

  List<BangumiItem> get allItems => List.unmodifiable(_projectAll());

  List<BangumiItem> get hideWatchedItems =>
      List.unmodifiable(_projectHideWatched());

  bool get isExhausted => _isExhausted;

  bool get isPreparing => _isPreparing;

  Object? get error => _error;

  int get offset => _offset;

  bool isReady(SearchViewMode mode, {int minimumItems = 20}) {
    if (_isExhausted) return true;
    final items = mode == SearchViewMode.all ? allItems : hideWatchedItems;
    return items.length >= minimumItems;
  }

  Future<void> ensureReady({int minimumItems = 20}) async {
    await ensureReadyFor(SearchViewMode.all, minimumItems: minimumItems);
    if (_error != null) return;
    await ensureReadyFor(SearchViewMode.hideWatched,
        minimumItems: minimumItems);
  }

  Future<void> ensureReadyFor(
    SearchViewMode mode, {
    int minimumItems = 20,
  }) {
    final existing = _preparationFuture;
    if (existing != null) return existing;

    final future = _prepare(mode, minimumItems);
    _preparationFuture = future;
    return future.whenComplete(() {
      if (identical(_preparationFuture, future)) {
        _preparationFuture = null;
      }
    });
  }

  Future<void> ensureNextBatch(
    SearchViewMode mode, {
    int batchSize = 20,
  }) async {
    final currentCount =
        mode == SearchViewMode.all ? allItems.length : hideWatchedItems.length;
    await ensureReadyFor(mode, minimumItems: currentCount + batchSize);
  }

  Future<void> retry({int minimumItems = 20}) async {
    if (_error == null) return;
    await ensureReady(minimumItems: minimumItems);
  }

  void setHideAbandoned(bool value) {
    hideAbandoned = value;
  }

  List<BangumiItem> _projectAll() {
    final abandoned = _abandonedIds();
    return _rawItems
        .where((item) => !hideAbandoned || !abandoned.contains(item.id))
        .toList(growable: false);
  }

  List<BangumiItem> _projectHideWatched() {
    final watched = _watchedIds();
    return _projectAll()
        .where((item) => !watched.contains(item.id))
        .toList(growable: false);
  }

  bool _hasEnough(List<BangumiItem> items, int minimumItems) {
    return items.length >= minimumItems;
  }

  Future<void> _prepare(SearchViewMode mode, int minimumItems) async {
    _isPreparing = true;
    _error = null;
    try {
      while (!_isExhausted) {
        final items =
            mode == SearchViewMode.all ? _projectAll() : _projectHideWatched();
        if (_hasEnough(items, minimumItems)) break;
        final page = await _loadNextPage();
        if (page == null) break;
      }
    } finally {
      _isPreparing = false;
    }
  }

  Future<BangumiSearchPage?> _loadNextPage() async {
    final requestedOffset = _offset;
    try {
      final page = await _pageLoader(requestedOffset);
      if (page == null) {
        _error = StateError('Search page request failed');
        return null;
      }

      _offset += page.rawCount;
      if (page.rawCount < pageSize || page.rawCount == 0) {
        _isExhausted = true;
      }

      final previousCount = _rawIds.length;
      for (final item in page.items) {
        if (_rawIds.add(item.id)) {
          _rawItems.add(item);
        }
      }
      if (_rawIds.length == previousCount) {
        _isExhausted = true;
      }
      return page;
    } catch (error) {
      _error = error;
      return null;
    }
  }
}
