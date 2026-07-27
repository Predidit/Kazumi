import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/search/image_search_module.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/apis/trace_api.dart';
import 'package:kazumi/utils/search_parser.dart';
import 'package:kazumi/pages/search/search_result_buffer.dart';

part 'search_controller.g.dart';

typedef SearchPageRequestLoader = Future<BangumiSearchPage?> Function(
  String keyword,
  SearchFilterState filterState,
  int offset,
);

class SearchPageController extends _SearchPageController
    with _$SearchPageController {
  SearchPageController(
    super.collectRepository,
    super.searchHistoryRepository,
  );

  @visibleForTesting
  SearchPageController.withPageLoader(
    super.collectRepository,
    super.searchHistoryRepository,
    SearchPageRequestLoader pageLoader,
  ) : super(pageLoader: pageLoader);
}

abstract class _SearchPageController with Store implements Disposable {
  static const int _searchPageSize = 20;
  static const Duration _defaultPageRequestInterval =
      Duration(milliseconds: 250);
  static const Duration _collectionRefreshDebounce = Duration(milliseconds: 50);

  _SearchPageController(
    ICollectRepository collectRepository,
    ISearchHistoryRepository searchHistoryRepository, {
    SearchPageRequestLoader? pageLoader,
  })  : _collectRepository = collectRepository,
        _searchHistoryRepository = searchHistoryRepository,
        _pageLoader = pageLoader ?? _defaultPageLoader,
        _searchPageRequestInterval =
            pageLoader == null ? _defaultPageRequestInterval : Duration.zero {
    _collectiblesSubscription =
        _collectRepository.onCollectiblesChanged.listen((_) {
      _scheduleResultProjectionRefresh();
    });
  }

  final ICollectRepository _collectRepository;
  final ISearchHistoryRepository _searchHistoryRepository;
  final SearchPageRequestLoader _pageLoader;
  final Duration _searchPageRequestInterval;
  late final StreamSubscription<void> _collectiblesSubscription;
  Timer? _collectiblesRefreshTimer;

  static Future<BangumiSearchPage?> _defaultPageLoader(
    String keyword,
    SearchFilterState filterState,
    int offset,
  ) {
    return BangumiApi.bangumiSearch(
      keyword,
      tags: filterState.tags,
      limit: _searchPageSize,
      offset: offset,
      sort: filterState.sort,
      dateRange: filterState.effectiveDateRange,
      rankRange: filterState.rankRange,
      scoreRange: filterState.scoreRange,
      weekdays: filterState.weekdays,
    );
  }

  SearchResultBuffer? _resultBuffer;
  Future<void>? _backgroundPreparation;
  int _queryGeneration = 0;
  String _activeInput = '';
  bool _disposed = false;
  final Map<SearchViewMode, int> _publishedCounts = {};

  bool hasMoreSearchResults = true;

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  @observable
  bool notShowAbandonedBangumis = false;

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  @observable
  SearchViewMode selectedViewMode = SearchViewMode.all;

  @observable
  SearchViewMode? pendingViewMode;

  @observable
  bool isHiddenViewPreparing = false;

  @observable
  bool isHiddenViewReady = false;

  @observable
  Object? hiddenViewError;

  @observable
  ObservableList<SearchHistory> searchHistories = ObservableList.of([]);

  @observable
  bool isImageSearching = false;

  @observable
  String imageSearchError = '';

  @observable
  ObservableList<ResultItem> imageSearchResults = ObservableList.of([]);

  @action
  void loadSearchHistories() {
    final histories = _searchHistoryRepository.getAllHistories();
    searchHistories.clear();
    searchHistories.addAll(histories);
  }

  @action
  Future<void> searchBangumi(String input, {String type = 'add'}) async {
    if (_disposed) return;
    final filterState = SearchParser(input).toFilterState();
    final normalizedInput = SearchParser.fromFilterState(filterState);
    final isNewQuery = type != 'add' ||
        _resultBuffer == null ||
        _activeInput != normalizedInput;

    if (!isNewQuery) {
      await _loadMoreSearchResults();
      return;
    }

    final requestedMode = selectedViewMode;
    final generation = ++_queryGeneration;
    _activeInput = normalizedInput;
    _resultBuffer = null;
    _backgroundPreparation = null;
    _publishedCounts.clear();
    pendingViewMode = null;
    isHiddenViewPreparing = false;
    isHiddenViewReady = false;
    hiddenViewError = null;
    hasMoreSearchResults = true;
    bangumiList.clear();
    isLoading = true;
    isTimeOut = false;

    if (!_collectRepository.getPrivateMode()) {
      if (_searchHistoryRepository.isHistoryFull(10)) {
        await _searchHistoryRepository.deleteOldest();
      }
      await _searchHistoryRepository.deleteDuplicates(input);
      await _searchHistoryRepository.saveHistory(input);
      loadSearchHistories();
    }
    if (generation != _queryGeneration) return;

    final idString = filterState.id.isEmpty ? null : filterState.id;
    if (idString != null) {
      final id = int.tryParse(idString);
      if (id != null) {
        final item = await BangumiApi.getBangumiInfoByID(id);
        if (generation != _queryGeneration) return;
        late final SearchResultBuffer buffer;
        buffer = SearchResultBuffer(
          pageLoader: (offset) async => offset == 0 && item != null
              ? BangumiSearchPage(items: [item], rawCount: 1)
              : const BangumiSearchPage(items: [], rawCount: 0),
          watchedIds: loadWatchedBangumiIds,
          abandonedIds: loadAbandonedBangumiIds,
          hideAbandoned: notShowAbandonedBangumis,
          pageRequestInterval: _searchPageRequestInterval,
          shouldContinue: () =>
              generation == _queryGeneration &&
              identical(_resultBuffer, buffer),
        );
        _resultBuffer = buffer;
        await buffer.ensureReadyFor(SearchViewMode.all);
        if (generation != _queryGeneration) return;
        if (requestedMode == SearchViewMode.hideWatched) {
          pendingViewMode = SearchViewMode.hideWatched;
          await _startHiddenPreparation(generation);
          if (generation != _queryGeneration) return;
          isLoading = false;
          isTimeOut = hiddenViewError != null;
        } else {
          _publishMode(SearchViewMode.all, minimumItems: _searchPageSize);
          isLoading = false;
          isTimeOut = bangumiList.isEmpty;
          _startHiddenPreparation(generation);
        }
        return;
      }
    }

    late final SearchResultBuffer buffer;
    buffer = SearchResultBuffer(
      pageLoader: (offset) =>
          _pageLoader(filterState.keyword, filterState, offset),
      watchedIds: loadWatchedBangumiIds,
      abandonedIds: loadAbandonedBangumiIds,
      hideAbandoned: notShowAbandonedBangumis,
      pageRequestInterval: _searchPageRequestInterval,
      shouldContinue: () =>
          generation == _queryGeneration && identical(_resultBuffer, buffer),
    );
    _resultBuffer = buffer;
    await buffer.ensureReadyFor(SearchViewMode.all);
    if (generation != _queryGeneration) return;
    if (requestedMode == SearchViewMode.hideWatched) {
      pendingViewMode = SearchViewMode.hideWatched;
      await _startHiddenPreparation(generation);
      if (generation != _queryGeneration) return;
      isLoading = false;
      isTimeOut = hiddenViewError != null;
    } else {
      _publishMode(SearchViewMode.all, minimumItems: _searchPageSize);
      isLoading = false;
      isTimeOut =
          bangumiList.isEmpty && (buffer.error != null || buffer.isExhausted);
      _startHiddenPreparation(generation);
    }
  }

  @action
  Future<void> requestViewMode(SearchViewMode mode) async {
    final buffer = _resultBuffer;
    if (buffer == null) return;
    if (mode == selectedViewMode && pendingViewMode == null) return;

    pendingViewMode = mode;
    if (mode == SearchViewMode.all) {
      _publishMode(
        SearchViewMode.all,
        minimumItems: _minimumPublishedItems(SearchViewMode.all),
      );
      pendingViewMode = null;
      return;
    }

    isHiddenViewReady = buffer.isReady(SearchViewMode.hideWatched);
    if (isHiddenViewReady && hiddenViewError == null) {
      _publishMode(
        SearchViewMode.hideWatched,
        minimumItems: _minimumPublishedItems(SearchViewMode.hideWatched),
      );
      pendingViewMode = null;
      return;
    }
    if (hiddenViewError == null) {
      _startHiddenPreparation(_queryGeneration);
    }
  }

  @action
  Future<void> retryHiddenView() async {
    final buffer = _resultBuffer;
    if (buffer == null) return;
    final retryingSelectedHiddenView =
        selectedViewMode == SearchViewMode.hideWatched;
    pendingViewMode = SearchViewMode.hideWatched;
    hiddenViewError = null;
    isHiddenViewPreparing = true;
    if (retryingSelectedHiddenView) {
      isLoading = true;
      isTimeOut = false;
    }
    final generation = _queryGeneration;
    final future = buffer.retry(minimumItems: _searchPageSize);
    _backgroundPreparation = future;
    try {
      await future;
    } finally {
      if (identical(_backgroundPreparation, future)) {
        _backgroundPreparation = null;
      }
    }
    if (generation != _queryGeneration) return;
    _finishHiddenPreparation(generation);
    if (retryingSelectedHiddenView) {
      isLoading = false;
      isTimeOut = hiddenViewError != null;
    }
  }

  Future<void> waitForBackgroundPreparation() async {
    final preparation = _backgroundPreparation;
    if (preparation == null) return;
    await preparation;
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _startHiddenPreparation(int generation) {
    final buffer = _resultBuffer;
    if (buffer == null || generation != _queryGeneration) {
      return Future<void>.value();
    }
    final existing = _backgroundPreparation;
    if (existing != null) return existing;
    if (buffer.isReady(SearchViewMode.all) &&
        buffer.isReady(SearchViewMode.hideWatched) &&
        buffer.error == null) {
      _finishHiddenPreparation(generation);
      return Future<void>.value();
    }

    isHiddenViewPreparing = true;
    hiddenViewError = null;
    late final Future<void> preparation;
    preparation =
        buffer.ensureReady(minimumItems: _searchPageSize).whenComplete(() {
      if (generation == _queryGeneration) {
        _finishHiddenPreparation(generation);
      }
      if (identical(_backgroundPreparation, preparation)) {
        _backgroundPreparation = null;
      }
    });
    _backgroundPreparation = preparation;
    return preparation;
  }

  void _finishHiddenPreparation(int generation) {
    final buffer = _resultBuffer;
    if (buffer == null || generation != _queryGeneration) return;
    isHiddenViewPreparing = false;
    hiddenViewError = buffer.error;
    isHiddenViewReady = buffer.isReady(SearchViewMode.hideWatched);
    if (hiddenViewError == null &&
        pendingViewMode == SearchViewMode.hideWatched &&
        isHiddenViewReady) {
      _publishMode(
        SearchViewMode.hideWatched,
        minimumItems: _minimumPublishedItems(SearchViewMode.hideWatched),
      );
      pendingViewMode = null;
    } else if (hiddenViewError == null &&
        selectedViewMode == SearchViewMode.all &&
        bangumiList.isEmpty &&
        buffer.allItems.isNotEmpty) {
      _publishMode(
        SearchViewMode.all,
        minimumItems: _minimumPublishedItems(SearchViewMode.all),
      );
      isTimeOut = false;
    }
    _updateHasMoreSearchResults();
  }

  Future<void> _loadMoreSearchResults() async {
    final buffer = _resultBuffer;
    if (buffer == null) return;
    final generation = _queryGeneration;
    final mode = selectedViewMode;
    final published = _minimumPublishedItems(mode);
    final target = published + _searchPageSize;
    isLoading = true;
    final items =
        mode == SearchViewMode.all ? buffer.allItems : buffer.hideWatchedItems;
    if (items.length < target && !buffer.isExhausted) {
      await buffer.ensureReadyFor(mode, minimumItems: target);
    }
    if (generation != _queryGeneration) return;
    final activeMode = selectedViewMode;
    final activeMinimumItems =
        activeMode == mode ? target : _minimumPublishedItems(activeMode);
    _publishMode(activeMode, minimumItems: activeMinimumItems);
    isLoading = false;
    if (!isHiddenViewReady && !isHiddenViewPreparing) {
      _startHiddenPreparation(generation);
    }
  }

  void _publishMode(SearchViewMode mode, {required int minimumItems}) {
    final buffer = _resultBuffer;
    if (buffer == null) return;
    final items =
        mode == SearchViewMode.all ? buffer.allItems : buffer.hideWatchedItems;
    final visibleCount =
        items.length < minimumItems ? items.length : minimumItems;
    _publishedCounts[mode] = minimumItems;
    bangumiList = ObservableList.of(items.take(visibleCount));
    selectedViewMode = mode;
    isTimeOut = false;
    _updateHasMoreSearchResults();
    isHiddenViewReady = buffer.isReady(SearchViewMode.hideWatched);
  }

  int _minimumPublishedItems(SearchViewMode mode) {
    final published = _publishedCounts[mode];
    if (published == null || published < _searchPageSize) {
      return _searchPageSize;
    }
    return published;
  }

  void _updateHasMoreSearchResults() {
    final buffer = _resultBuffer;
    if (buffer == null) {
      hasMoreSearchResults = false;
      return;
    }
    final items = selectedViewMode == SearchViewMode.all
        ? buffer.allItems
        : buffer.hideWatchedItems;
    final published = _publishedCounts[selectedViewMode] ?? 0;
    hasMoreSearchResults = published < items.length || !buffer.isExhausted;
  }

  @action
  Future<void> deleteSearchHistory(SearchHistory history) async {
    await _searchHistoryRepository.deleteHistory(history);
    loadSearchHistories();
  }

  @action
  Future<void> clearSearchHistory() async {
    await _searchHistoryRepository.clearAllHistories();
    loadSearchHistories();
  }

  @action
  void clearImageSearchState() {
    isImageSearching = false;
    imageSearchError = '';
    imageSearchResults.clear();
  }

  @action
  Future<void> searchImageByFile(File imageFile) async {
    isImageSearching = true;
    imageSearchError = '';
    imageSearchResults.clear();
    try {
      final result = await TraceApi.searchAnimeByImageFile(imageFile);
      imageSearchResults.addAll(result.result ?? []);
      if (result.error != null && result.error!.isNotEmpty) {
        imageSearchError = result.error!;
      } else if (imageSearchResults.isEmpty) {
        imageSearchError = '未找到匹配结果';
      }
    } catch (e) {
      imageSearchError = '图片搜索失败，请稍后重试';
    } finally {
      isImageSearching = false;
    }
  }

  @action
  Future<void> searchImageByUrl(String imageUrl) async {
    isImageSearching = true;
    imageSearchError = '';
    imageSearchResults.clear();
    try {
      final result = await TraceApi.searchAnimeByImageUrl(imageUrl);
      imageSearchResults.addAll(result.result ?? []);
      if (result.error != null && result.error!.isNotEmpty) {
        imageSearchError = result.error!;
      } else if (imageSearchResults.isEmpty) {
        imageSearchError = '未找到匹配结果';
      }
    } catch (e) {
      imageSearchError = '图片搜索失败，请检查图片地址或稍后重试';
    } finally {
      isImageSearching = false;
    }
  }

  @action
  Future<void> setNotShowAbandonedBangumis(
    bool value, {
    bool prepare = true,
  }) async {
    notShowAbandonedBangumis = value;
    final buffer = _resultBuffer;
    if (buffer == null) return;

    final mode = selectedViewMode;
    final generation = _queryGeneration;
    buffer.setHideAbandoned(value);
    _publishMode(
      mode,
      minimumItems: _minimumPublishedItems(mode),
    );
    if (buffer.isReady(SearchViewMode.all) &&
        buffer.isReady(SearchViewMode.hideWatched)) {
      return;
    }
    if (!prepare) return;

    await _startHiddenPreparation(generation);
    if (generation != _queryGeneration || mode != selectedViewMode) return;
    final minimumItems = _minimumPublishedItems(mode);
    _publishMode(
      mode,
      minimumItems:
          minimumItems < _searchPageSize ? _searchPageSize : minimumItems,
    );
  }

  @action
  void refreshResultProjection() {
    if (_disposed) return;
    final buffer = _resultBuffer;
    if (buffer == null) return;
    final generation = _queryGeneration;
    _publishMode(
      selectedViewMode,
      minimumItems: _minimumPublishedItems(selectedViewMode),
    );
    if (!isHiddenViewReady && !isHiddenViewPreparing) {
      _startHiddenPreparation(generation);
    }
  }

  void _scheduleResultProjectionRefresh() {
    if (_disposed) return;
    _collectiblesRefreshTimer?.cancel();
    _collectiblesRefreshTimer = Timer(_collectionRefreshDebounce, () {
      _collectiblesRefreshTimer = null;
      refreshResultProjection();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _queryGeneration++;
    _resultBuffer = null;
    _backgroundPreparation = null;
    _collectiblesRefreshTimer?.cancel();
    _collectiblesRefreshTimer = null;
    bangumiList.clear();
    _collectiblesSubscription.cancel();
  }

  Set<int> loadWatchedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watched);
  }

  Set<int> loadAbandonedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.abandoned);
  }
}
