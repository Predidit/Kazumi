import 'dart:io';

import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/search/image_search_module.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/apis/trace_api.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/async_session.dart';
import 'package:kazumi/utils/search_parser.dart';
import 'package:mobx/mobx.dart';

part 'search_controller.g.dart';

class SearchPageController = _SearchPageController with _$SearchPageController;

abstract class _SearchPageController with Store {
  static const int _searchPageSize = 20;
  static const int _maxPagesPerSearch = 3;

  _SearchPageController(
    this._collectRepository,
    this._searchHistoryRepository,
  );

  final ICollectRepository _collectRepository;
  final ISearchHistoryRepository _searchHistoryRepository;

  int _searchOffset = 0;
  final _searchSessions = AsyncSessionOwner();
  final _imageSessions = AsyncSessionOwner();
  AsyncSession? _search;

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
  ObservableList<SearchHistory> searchHistories = ObservableList.of([]);

  @observable
  bool isImageSearching = false;

  @observable
  String imageSearchError = '';

  @observable
  ObservableList<ResultItem> imageSearchResults = ObservableList.of([]);

  void dispose() {
    _searchSessions.close();
    _imageSessions.close();
  }

  @action
  void loadSearchHistories() {
    if (_searchSessions.isClosed) return;
    final histories = _searchHistoryRepository.getAllHistories();
    searchHistories.clear();
    searchHistories.addAll(histories);
  }

  @action
  Future<void> searchBangumi(String input, {String type = 'add'}) async {
    if (_searchSessions.isClosed) return;
    if (type == 'add' && (isLoading || !hasMoreSearchResults)) return;
    final search = type == 'add'
        ? _search ??= _searchSessions.begin()
        : _search = _searchSessions.begin();
    isLoading = true;
    isTimeOut = false;
    if (type != 'add') {
      bangumiList.clear();
      _searchOffset = 0;
      hasMoreSearchResults = true;
      if (!GStorage.getSetting(SettingsKeys.privateMode) &&
          input.trim().isNotEmpty) {
        if (_searchHistoryRepository.isHistoryFull(10)) {
          await _searchHistoryRepository.deleteOldest();
        }
        await _searchHistoryRepository.deleteDuplicates(input);
        await _searchHistoryRepository.saveHistory(input);
        loadSearchHistories();
      }
    }
    if (search.isStale) return;
    final filterState = SearchParser(input).toFilterState();
    final id = int.tryParse(filterState.id);
    if (id != null) {
      final item = await BangumiApi.getBangumiInfoByID(id);
      if (search.isStale) return;
      if (item != null) {
        bangumiList.add(item);
      }
      hasMoreSearchResults = false;
      isLoading = false;
      isTimeOut = bangumiList.isEmpty;
      return;
    }
    var pagesFetched = 0;
    do {
      final page = await BangumiApi.bangumiSearch(filterState.keyword,
          tags: filterState.tags,
          limit: _searchPageSize,
          offset: _searchOffset,
          sort: filterState.sort,
          dateRange: filterState.effectiveDateRange,
          rankRange: filterState.rankRange,
          scoreRange: filterState.scoreRange,
          weekdays: filterState.weekdays);
      if (search.isStale) return;
      if (page == null) {
        break;
      }
      pagesFetched++;
      _searchOffset += page.rawCount;
      hasMoreSearchResults = page.rawCount == _searchPageSize;
      final existingIds = bangumiList.map((item) => item.id).toSet();
      final newItems =
          page.items.where((item) => existingIds.add(item.id)).toList();
      if (newItems.isNotEmpty) {
        bangumiList.addAll(newItems);
        break;
      }
    } while (hasMoreSearchResults && pagesFetched < _maxPagesPerSearch);
    isLoading = false;
    isTimeOut =
        bangumiList.isEmpty && (pagesFetched == 0 || !hasMoreSearchResults);
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
    if (_imageSessions.isClosed) return;
    _imageSessions.cancel();
    isImageSearching = false;
    imageSearchError = '';
    imageSearchResults.clear();
  }

  @action
  Future<void> searchImageByFile(File imageFile) async {
    await _searchImage(
      () => TraceApi.searchAnimeByImageFile(imageFile),
      errorMessage: '图片搜索失败，请稍后重试',
    );
  }

  @action
  Future<void> searchImageByUrl(String imageUrl) async {
    await _searchImage(
      () => TraceApi.searchAnimeByImageUrl(imageUrl),
      errorMessage: '图片搜索失败，请检查图片地址或稍后重试',
    );
  }

  Future<void> _searchImage(
    Future<ImageSearchItem> Function() load, {
    required String errorMessage,
  }) async {
    if (_imageSessions.isClosed) return;
    final image = _imageSessions.begin();
    isImageSearching = true;
    imageSearchError = '';
    imageSearchResults.clear();
    try {
      final result = await load();
      if (image.isStale) return;
      imageSearchResults.addAll(result.result ?? []);
      if (result.error != null && result.error!.isNotEmpty) {
        imageSearchError = result.error!;
      } else if (imageSearchResults.isEmpty) {
        imageSearchError = '未找到匹配结果';
      }
    } catch (_) {
      if (image.isStale) return;
      imageSearchError = errorMessage;
    } finally {
      if (image.isActive) isImageSearching = false;
    }
  }

  @action
  Future<void> setNotShowWatchedBangumis(bool value) async {
    notShowWatchedBangumis = value;
  }

  @action
  Future<void> setNotShowAbandonedBangumis(bool value) async {
    notShowAbandonedBangumis = value;
  }

  Set<int> loadWatchedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watched);
  }

  Set<int> loadAbandonedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.abandoned);
  }
}
