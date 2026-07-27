import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';

enum SearchViewMode {
  all,
  hideWatched,
}

typedef SearchPageLoader = Future<BangumiSearchPage?> Function(int offset);

class SearchPreparationLimitReached implements Exception {
  const SearchPreparationLimitReached();

  @override
  String toString() => 'Search result preparation reached its request limit';
}

class SearchResultBuffer {
  SearchResultBuffer({
    required SearchPageLoader pageLoader,
    required Set<int> Function() watchedIds,
    required Set<int> Function() abandonedIds,
    bool Function()? shouldContinue,
    this.hideAbandoned = false,
    this.pageSize = 20,
    this.pageRequestInterval = Duration.zero,
  })  : _pageLoader = pageLoader,
        _watchedIds = watchedIds,
        _abandonedIds = abandonedIds,
        _shouldContinue = shouldContinue ?? _alwaysContinue;

  final SearchPageLoader _pageLoader;
  final Set<int> Function() _watchedIds;
  final Set<int> Function() _abandonedIds;
  final bool Function() _shouldContinue;

  static bool _alwaysContinue() => true;

  final int pageSize;
  final Duration pageRequestInterval;
  bool hideAbandoned;

  static const int _maxPagesPerPreparation = 10;
  static const int _maxConsecutiveDuplicatePages = 3;

  final List<BangumiItem> _rawItems = [];
  final Set<int> _rawIds = <int>{};
  int _offset = 0;
  bool _isExhausted = false;
  bool _isPreparing = false;
  Object? _error;
  Future<void>? _preparationFuture;
  DateTime? _lastPageRequestAt;
  int _consecutiveDuplicatePages = 0;

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
  }) async {
    while (_shouldContinue() && !isReady(mode, minimumItems: minimumItems)) {
      final existing = _preparationFuture;
      if (existing != null) {
        await existing;
      } else {
        final preparation = _prepare(mode, minimumItems);
        _preparationFuture = preparation;
        try {
          await preparation;
        } finally {
          if (identical(_preparationFuture, preparation)) {
            _preparationFuture = null;
          }
        }
        return;
      }
      if (_error != null) return;
    }
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
    _error = null;
    _consecutiveDuplicatePages = 0;
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
    var requestedPages = 0;
    try {
      while (_shouldContinue() && !_isExhausted) {
        final items =
            mode == SearchViewMode.all ? _projectAll() : _projectHideWatched();
        if (_hasEnough(items, minimumItems)) break;
        if (requestedPages >= _maxPagesPerPreparation) {
          _error = const SearchPreparationLimitReached();
          break;
        }
        final page = await _loadNextPage();
        requestedPages++;
        if (page == null || !_shouldContinue()) break;
      }
    } finally {
      _isPreparing = false;
    }
  }

  Future<BangumiSearchPage?> _loadNextPage() async {
    if (!_shouldContinue()) return null;
    final requestedOffset = _offset;
    try {
      final lastRequestAt = _lastPageRequestAt;
      if (lastRequestAt != null && pageRequestInterval > Duration.zero) {
        final elapsed = DateTime.now().difference(lastRequestAt);
        final remaining = pageRequestInterval - elapsed;
        if (remaining > Duration.zero) {
          await Future<void>.delayed(remaining);
        }
      }
      if (!_shouldContinue()) return null;
      _lastPageRequestAt = DateTime.now();
      final page = await _pageLoader(requestedOffset);
      if (!_shouldContinue()) return null;
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
        _consecutiveDuplicatePages++;
      } else {
        _consecutiveDuplicatePages = 0;
      }
      if (!_isExhausted &&
          _consecutiveDuplicatePages >= _maxConsecutiveDuplicatePages) {
        _error = const SearchPreparationLimitReached();
        return null;
      }
      return page;
    } catch (error) {
      _error = error;
      return null;
    }
  }
}
