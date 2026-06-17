import 'dart:io';

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

part 'search_controller.g.dart';

class SearchPageController = _SearchPageController with _$SearchPageController;

abstract class _SearchPageController with Store {
  final _collectRepository = Modular.get<ICollectRepository>();
  final _searchHistoryRepository = Modular.get<ISearchHistoryRepository>();

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

  @action
  void loadSearchHistories() {
    final histories = _searchHistoryRepository.getAllHistories();
    searchHistories.clear();
    searchHistories.addAll(histories);
  }

  @action
  Future<void> searchBangumi(String input, {String type = 'add'}) async {
    if (type != 'add') {
      bangumiList.clear();
      bool privateMode = _collectRepository.getPrivateMode();
      if (!privateMode) {
        // 检查是否已满，删除最旧的记录
        if (_searchHistoryRepository.isHistoryFull(10)) {
          await _searchHistoryRepository.deleteOldest();
        }
        // 删除重复的历史记录
        await _searchHistoryRepository.deleteDuplicates(input);
        // 保存新的搜索历史
        await _searchHistoryRepository.saveHistory(input);
        // 重新加载历史记录
        loadSearchHistories();
      }
    }
    isLoading = true;
    isTimeOut = false;
    SearchParser parser = SearchParser(input);
    final filterState = parser.toFilterState();
    String? idString = filterState.id.isEmpty ? null : filterState.id;
    if (idString != null) {
      final id = int.tryParse(idString);
      if (id != null) {
        final BangumiItem? item = await BangumiApi.getBangumiInfoByID(id);
        if (item != null) {
          bangumiList.add(item);
        }
        isLoading = false;
        isTimeOut = bangumiList.isEmpty;
        return;
      }
    }
    var result = await BangumiApi.bangumiSearch(filterState.keyword,
        tags: filterState.tags,
        offset: bangumiList.length,
        sort: filterState.sort,
        dateRange: filterState.effectiveDateRange,
        rankRange: filterState.rankRange,
        scoreRange: filterState.scoreRange,
        weekdays: filterState.weekdays);
    if (filterState.weekdays.isNotEmpty) {
      final weekdays = filterState.weekdays.toSet();
      result =
          result.where((item) => weekdays.contains(item.airWeekday)).toList();
    }
    bangumiList.addAll(result);
    isLoading = false;
    isTimeOut = bangumiList.isEmpty;
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
