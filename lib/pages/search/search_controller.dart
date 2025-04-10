import 'package:mobx/mobx.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/search_parser.dart';

part 'search_controller.g.dart';

class SearchPageController = _SearchPageController with _$SearchPageController;

abstract class _SearchPageController with Store {
  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  @observable
  String searchKeyword = '';

  @observable
  ObservableList<BangumiItem> bangumiList = ObservableList.of([]);

  Future<void> searchBangumi(String input, {String type = 'add'}) async {
    if (type != 'add') {
      bangumiList.clear();
    }
    isLoading = true;
    isTimeOut = false;
    SearchParser parser = SearchParser(input);
    String? idString = parser.parseId();
    String? tag = parser.parseTag();
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
    var result =
        await BangumiHTTP.bangumiSearch(keywords, tags: [if (tag != null) tag], offset: bangumiList.length);
    bangumiList.addAll(result);
    isLoading = false;
    isTimeOut = bangumiList.isEmpty;
  }
}
