import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/search_parser.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/modules/collect/collect_type.dart';

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
  late bool notShowWatchedBangumis = _collectRepository.getSearchNotShowWatchedBangumis();

  @observable
  late bool notShowAbandonedBangumis = _collectRepository.getSearchNotShowAbandonedBangumis();

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  @observable
  ObservableList<SearchHistory> searchHistories = ObservableList.of([]);

  @action
  void loadSearchHistories() {
    final histories = _searchHistoryRepository.getAllHistories();
    searchHistories.clear();
    searchHistories.addAll(histories);
  }

  /// Avaliable sort parameters:
  /// 1. heat
  /// 2. match
  /// 3. rank
  /// 4. score
  String attachSortParams(String input, String sort) {
    SearchParser parser = SearchParser(input);
    String newInput = parser.updateSort(sort);
    return newInput;
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
    String? idString = parser.parseId();
    String? tag = parser.parseTag();
    String? sort = parser.parseSort();
    String keywords = parser.parseKeywords();
    if (idString != null) {
      final id = int.tryParse(idString);
      if (id != null) {
        final BangumiItem? item = await BangumiHTTP.getBangumiInfoByID(id);
        if (item != null) {
          bangumiList.add(item);
        }
        return;
      }
    }
    var result = await BangumiHTTP.bangumiSearch(keywords,
        tags: [if (tag != null) tag],
        offset: bangumiList.length,
        sort: sort ?? 'heat');
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
  Future<void> setNotShowWatchedBangumis(bool value) async {
    notShowWatchedBangumis = value;
    await _collectRepository.updateSearchNotShowWatchedBangumis(value);
  }

  @action
  Future<void> setNotShowAbandonedBangumis(bool value) async {
    notShowAbandonedBangumis = value;
    await _collectRepository.updateSearchNotShowAbandonedBangumis(value);
  }

  Set<int> loadWatchedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watched);
  }

  Set<int> loadAbandonedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.abandoned);
  }
}
