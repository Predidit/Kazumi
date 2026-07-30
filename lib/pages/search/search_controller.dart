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
  static const Duration _collectionRefreshDebounce = Duration(milliseconds: 50);

  _SearchPageController(
    ICollectRepository collectRepository,
    ISearchHistoryRepository searchHistoryRepository, {
    SearchPageRequestLoader? pageLoader,
  })  : _collectRepository = collectRepository,
        _searchHistoryRepository = searchHistoryRepository,
        _pageLoader = pageLoader ?? _defaultPageLoader {
    _collectiblesSubscription =
        _collectRepository.onCollectiblesChanged.listen((_) {
      _scheduleResultProjectionRefresh();
    });
  }

  final ICollectRepository _collectRepository;
  final ISearchHistoryRepository _searchHistoryRepository;
  final SearchPageRequestLoader _pageLoader;
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
  int _queryGeneration = 0;
  String _activeInput = '';
  bool _disposed = false;

  @observable
  bool hasMoreSearchResults = false;

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
          shouldContinue: () =>
              generation == _queryGeneration &&
              identical(_resultBuffer, buffer),
        );
        _resultBuffer = buffer;
        await buffer.loadNextPage();
        if (generation != _queryGeneration) return;
        _publishMode(requestedMode);
        isLoading = false;
        isTimeOut =
            bangumiList.isEmpty && (buffer.error != null || buffer.isExhausted);
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
      shouldContinue: () =>
          generation == _queryGeneration && identical(_resultBuffer, buffer),
    );
    _resultBuffer = buffer;
    await buffer.loadNextPage();
    if (generation != _queryGeneration) return;
    _publishMode(requestedMode);
    isLoading = false;
    isTimeOut =
        bangumiList.isEmpty && (buffer.error != null || buffer.isExhausted);
  }

  @action
  Future<void> requestViewMode(SearchViewMode mode) async {
    final buffer = _resultBuffer;
    if (buffer == null) return;
    if (mode == selectedViewMode) return;
    _publishMode(mode);
  }

  @action
  Future<void> loadMoreSearchResults() async {
    if (_disposed || isLoading) return;
    await _loadMoreSearchResults();
  }

  Future<void> _loadMoreSearchResults() async {
    final buffer = _resultBuffer;
    if (buffer == null) return;
    final generation = _queryGeneration;
    isLoading = true;
    await buffer.loadNextPage();
    if (generation != _queryGeneration) return;
    _publishMode(selectedViewMode);
    isLoading = false;
  }

  void _publishMode(SearchViewMode mode) {
    final buffer = _resultBuffer;
    if (buffer == null) return;
    final items =
        mode == SearchViewMode.all ? buffer.allItems : buffer.hideWatchedItems;
    bangumiList = ObservableList.of(items);
    selectedViewMode = mode;
    isTimeOut = false;
    _updateHasMoreSearchResults();
  }

  void _updateHasMoreSearchResults() {
    final buffer = _resultBuffer;
    if (buffer == null) {
      hasMoreSearchResults = false;
      return;
    }
    hasMoreSearchResults = !buffer.isExhausted;
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
  Future<void> setNotShowAbandonedBangumis(bool value) async {
    notShowAbandonedBangumis = value;
    final buffer = _resultBuffer;
    if (buffer == null) return;

    buffer.setHideAbandoned(value);
    _publishMode(selectedViewMode);
  }

  @action
  void refreshResultProjection() {
    if (_disposed) return;
    final buffer = _resultBuffer;
    if (buffer == null) return;
    _publishMode(selectedViewMode);
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
