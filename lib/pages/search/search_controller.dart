import 'dart:io';

import 'package:flutter/foundation.dart';
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

abstract class _SearchPageController with Store {
  static const int _searchPageSize = 20;

  _SearchPageController(
    ICollectRepository collectRepository,
    ISearchHistoryRepository searchHistoryRepository, {
    SearchPageRequestLoader? pageLoader,
  })  : _collectRepository = collectRepository,
        _searchHistoryRepository = searchHistoryRepository,
        _pageLoader = pageLoader ?? _defaultPageLoader;

  final ICollectRepository _collectRepository;
  final ISearchHistoryRepository _searchHistoryRepository;
  final SearchPageRequestLoader _pageLoader;

  static Future<BangumiSearchPage?> _defaultPageLoader(
    String keyword,
    SearchFilterState filterState,
    int offset,
  ) {
    return BangumiApi.bangumiSearch(
      filterState.keyword,
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
  final Map<SearchViewMode, int> _publishedCounts = {
    SearchViewMode.all: 0,
    SearchViewMode.hideWatched: 0,
  };

  bool hasMoreSearchResults = true;

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  @observable
  bool notShowWatchedBangumis = false;

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
    _publishedCounts
      ..[SearchViewMode.all] = 0
      ..[SearchViewMode.hideWatched] = 0;
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
        final buffer = SearchResultBuffer(
          pageLoader: (offset) async => offset == 0 && item != null
              ? BangumiSearchPage(items: [item], rawCount: 1)
              : const BangumiSearchPage(items: [], rawCount: 0),
          watchedIds: loadWatchedBangumiIds,
          abandonedIds: loadAbandonedBangumiIds,
          hideAbandoned: notShowAbandonedBangumis,
        );
        _resultBuffer = buffer;
        await buffer.ensureReadyFor(SearchViewMode.all);
        if (generation != _queryGeneration) return;
        if (requestedMode == SearchViewMode.hideWatched) {
          pendingViewMode = SearchViewMode.hideWatched;
          await _startHiddenPreparation(generation);
          if (generation != _queryGeneration) return;
          isLoading = false;
          hasMoreSearchResults = !buffer.isExhausted;
          isTimeOut = hiddenViewError != null;
        } else {
          _publishMode(SearchViewMode.all, minimumItems: _searchPageSize);
          isLoading = false;
          hasMoreSearchResults = !buffer.isExhausted;
          isTimeOut = bangumiList.isEmpty;
          _startHiddenPreparation(generation);
        }
        return;
      }
    }

    final buffer = SearchResultBuffer(
      pageLoader: (offset) => _pageLoader(input, filterState, offset),
      watchedIds: loadWatchedBangumiIds,
      abandonedIds: loadAbandonedBangumiIds,
      hideAbandoned: notShowAbandonedBangumis,
    );
    _resultBuffer = buffer;
    await buffer.ensureReadyFor(SearchViewMode.all);
    if (generation != _queryGeneration) return;
    if (requestedMode == SearchViewMode.hideWatched) {
      pendingViewMode = SearchViewMode.hideWatched;
      await _startHiddenPreparation(generation);
      if (generation != _queryGeneration) return;
      isLoading = false;
      hasMoreSearchResults = !buffer.isExhausted;
      isTimeOut = hiddenViewError != null;
    } else {
      _publishMode(SearchViewMode.all, minimumItems: _searchPageSize);
      isLoading = false;
      hasMoreSearchResults = !buffer.isExhausted;
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
        minimumItems: _publishedCounts[SearchViewMode.all] ?? _searchPageSize,
      );
      pendingViewMode = null;
      return;
    }

    isHiddenViewReady = buffer.isReady(SearchViewMode.hideWatched);
    if (isHiddenViewReady && hiddenViewError == null) {
      _publishMode(SearchViewMode.hideWatched, minimumItems: _searchPageSize);
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
    await future;
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
    if (existing != null) {
      return existing.whenComplete(() {
        if (generation == _queryGeneration &&
            (!buffer.isReady(SearchViewMode.all) ||
                !buffer.isReady(SearchViewMode.hideWatched))) {
          return _startHiddenPreparation(generation);
        }
      });
    }
    if (buffer.isReady(SearchViewMode.all) &&
        buffer.isReady(SearchViewMode.hideWatched) &&
        buffer.error == null) {
      _finishHiddenPreparation(generation);
      return Future<void>.value();
    }

    isHiddenViewPreparing = true;
    hiddenViewError = null;
    final future = buffer.ensureReady(minimumItems: _searchPageSize);
    _backgroundPreparation = future;
    future.whenComplete(() {
      if (generation == _queryGeneration) {
        _finishHiddenPreparation(generation);
      }
    });
    return future;
  }

  void _finishHiddenPreparation(int generation) {
    final buffer = _resultBuffer;
    if (buffer == null || generation != _queryGeneration) return;
    isHiddenViewPreparing = false;
    hiddenViewError = buffer.error;
    isHiddenViewReady = buffer.isReady(SearchViewMode.hideWatched);
    _backgroundPreparation = null;
    if (hiddenViewError == null &&
        pendingViewMode == SearchViewMode.hideWatched &&
        isHiddenViewReady) {
      _publishMode(SearchViewMode.hideWatched, minimumItems: _searchPageSize);
      pendingViewMode = null;
    }
  }

  Future<void> _loadMoreSearchResults() async {
    final buffer = _resultBuffer;
    if (buffer == null) return;
    final generation = _queryGeneration;
    final mode = selectedViewMode;
    final published = _publishedCounts[mode] ?? 0;
    final target = published + _searchPageSize;
    isLoading = true;
    final items =
        mode == SearchViewMode.all ? buffer.allItems : buffer.hideWatchedItems;
    if (items.length < target && !buffer.isExhausted) {
      await buffer.ensureReadyFor(mode, minimumItems: target);
    }
    if (generation != _queryGeneration) return;
    final activeMode = selectedViewMode;
    final activeMinimumItems = activeMode == mode
        ? target
        : _publishedCounts[activeMode] ?? _searchPageSize;
    _publishMode(activeMode, minimumItems: activeMinimumItems);
    isLoading = false;
    hasMoreSearchResults = !buffer.isExhausted;
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
    _publishedCounts[mode] = visibleCount;
    bangumiList = ObservableList.of(items.take(visibleCount));
    selectedViewMode = mode;
    hasMoreSearchResults = !buffer.isExhausted;
    isHiddenViewReady = buffer.isReady(SearchViewMode.hideWatched);
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
  Future<void> setNotShowWatchedBangumis(bool value) async {
    notShowWatchedBangumis = value;
    if (value) {
      await requestViewMode(SearchViewMode.hideWatched);
    } else {
      await requestViewMode(SearchViewMode.all);
    }
  }

  @action
  Future<void> setNotShowAbandonedBangumis(bool value) async {
    notShowAbandonedBangumis = value;
    final buffer = _resultBuffer;
    if (buffer == null) return;

    final mode = selectedViewMode;
    final generation = _queryGeneration;
    buffer.setHideAbandoned(value);
    _publishMode(
      mode,
      minimumItems: _publishedCounts[mode] ?? _searchPageSize,
    );
    if (buffer.isReady(SearchViewMode.all) &&
        buffer.isReady(SearchViewMode.hideWatched)) {
      return;
    }

    await _startHiddenPreparation(generation);
    if (generation != _queryGeneration || mode != selectedViewMode) return;
    final minimumItems = _publishedCounts[mode] ?? _searchPageSize;
    _publishMode(
      mode,
      minimumItems:
          minimumItems < _searchPageSize ? _searchPageSize : minimumItems,
    );
  }

  Set<int> loadWatchedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watched);
  }

  Set<int> loadAbandonedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.abandoned);
  }
}
