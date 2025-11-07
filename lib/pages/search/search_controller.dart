import 'package:mobx/mobx.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/search_parser.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:hive/hive.dart';

part 'search_controller.g.dart';

class SearchPageController = _SearchPageController with _$SearchPageController;

abstract class _SearchPageController with Store {
  final Box setting = GStorage.setting;
  final Box searchHistoryBox = GStorage.searchHistory;
  final Box collectiblesBox = GStorage.collectibles;

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  @observable
  late bool notShowWatchedBangumis =
      setting.get(SettingBoxKey.searchNotShowWatchedBangumis, defaultValue: false);

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  @observable
  ObservableList<SearchHistory> searchHistories = ObservableList.of([]);

  @action
  void loadSearchHistories() {
    var temp = searchHistoryBox.values.toList().cast<SearchHistory>();
    temp.sort(
      (a, b) => b.timestamp - a.timestamp,
    );
    searchHistories.clear();
    searchHistories.addAll(temp);
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
      bool privateMode =
          await setting.get(SettingBoxKey.privateMode, defaultValue: false);
      if (!privateMode) {
        if (searchHistories.length >= 10) {
          await searchHistoryBox.delete(searchHistories.last.key);
        }
        final historiesToDelete =
            searchHistories.where((element) => element.keyword == input);
        if (historiesToDelete.isNotEmpty) {
          for (var history in historiesToDelete) {
            await searchHistoryBox.delete(history.key);
          }
        }
        await searchHistoryBox.put(
            DateTime.now().millisecondsSinceEpoch.toString(),
            SearchHistory(input, DateTime.now().millisecondsSinceEpoch));
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
    await searchHistoryBox.delete(history.key);
    loadSearchHistories();
  }

  @action
  Future<void> clearSearchHistory() async {
    await searchHistoryBox.clear();
    loadSearchHistories();
  }

  @action
  Future<void> setNotShowWatchedBangumis(bool value) async {
    notShowWatchedBangumis = value;
    await setting.put(SettingBoxKey.searchNotShowWatchedBangumis, value);
  }

  @action
  Set<String> loadWatchedBangumiNames() {
    return collectiblesBox.values
        .where((item) => item.type == 4)
        .map((item) => item.bangumiItem.name.toString())
        .toSet();
  }
}
