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
    bool Function()? shouldContinue,
    this.hideAbandoned = false,
    this.pageSize = 20,
  })  : _pageLoader = pageLoader,
        _watchedIds = watchedIds,
        _abandonedIds = abandonedIds,
        _shouldContinue = shouldContinue ?? _alwaysContinue;

  final SearchPageLoader _pageLoader;
  final Set<int> Function() _watchedIds;
  final Set<int> Function() _abandonedIds;
  final bool Function() _shouldContinue;

  final int pageSize;
  bool hideAbandoned;

  final List<BangumiItem> _rawItems = [];
  final Set<int> _rawIds = <int>{};
  int _offset = 0;
  bool _isExhausted = false;
  Object? _error;
  Future<void>? _loadFuture;

  static bool _alwaysContinue() => true;

  List<BangumiItem> get allItems => List.unmodifiable(_projectAll());

  List<BangumiItem> get hideWatchedItems =>
      List.unmodifiable(_projectHideWatched());

  bool get isExhausted => _isExhausted;

  Object? get error => _error;

  int get offset => _offset;

  /// Loads at most one remote page. Concurrent callers share the same request.
  Future<void> loadNextPage() {
    if (!_shouldContinue() || _isExhausted) return Future<void>.value();
    final existing = _loadFuture;
    if (existing != null) return existing;

    final load = _loadNextPage();
    _loadFuture = load;
    return load.whenComplete(() {
      if (identical(_loadFuture, load)) {
        _loadFuture = null;
      }
    });
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

  Future<void> _loadNextPage() async {
    if (!_shouldContinue()) return;
    final requestedOffset = _offset;
    try {
      final page = await _pageLoader(requestedOffset);
      if (!_shouldContinue()) return;
      if (page == null) {
        _error = StateError('Search page request failed');
        return;
      }

      _error = null;
      _offset += page.rawCount;
      if (page.rawCount < pageSize || page.rawCount == 0) {
        _isExhausted = true;
      }
      for (final item in page.items) {
        if (_rawIds.add(item.id)) {
          _rawItems.add(item);
        }
      }
    } catch (error) {
      if (_shouldContinue()) {
        _error = error;
      }
    }
  }
}
