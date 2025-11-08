import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

class TimelineController = _TimelineController with _$TimelineController;

abstract class _TimelineController with Store {
  late final CollectController collectController;

  _TimelineController() {
    collectController = Modular.get<CollectController>();
    _setupCollectiblesReaction();
  }

  late final ReactionDisposer _collectiblesReactionDisposer;

  void _setupCollectiblesReaction() {
    _collectiblesReactionDisposer = reaction(
      (_) => collectController.lastUpdateTime,
      (_) => filterCurrentCalendar(),
    );
  }

  void dispose() {
    _collectiblesReactionDisposer();
  }
  @observable
  ObservableList<List<BangumiItem>> bangumiCalendar =
      ObservableList<List<BangumiItem>>();

  @observable
  String seasonString = '';

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  int sortType = 1;

  late DateTime selectedDate;

  void init() {
    selectedDate = DateTime.now();
    seasonString = AnimeSeason(selectedDate).toString();
    getSchedules();
  }

  Future<void> getSchedules() async {
    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    final resBangumiCalendar = await BangumiHTTP.getCalendar();
    final filteredCalendar = resBangumiCalendar.map((dayList) {
      return collectController.filterBangumiByType(dayList, 5);
    }).toList();
    bangumiCalendar.clear();
    bangumiCalendar.addAll(filteredCalendar);
    changeSortType(sortType);
    isLoading = false;
    isTimeOut = bangumiCalendar.isEmpty;
  }

  Future<void> getSchedulesBySeason() async {
    // 4次获取，每次最多20部
    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    var time = 0;
    const maxTime = 4;
    const limit = 20;
    var resBangumiCalendar = List.generate(7, (_) => <BangumiItem>[]);
    for (time = 0; time < maxTime; time++) {
      final offset = time * limit;
      var newList = await BangumiHTTP.getCalendarBySearch(
          AnimeSeason(selectedDate).toSeasonStartAndEnd(), limit, offset);
      for (int i = 0; i < resBangumiCalendar.length; ++i) {
        final filteredDayList = collectController.filterBangumiByType(newList[i], 5);
        resBangumiCalendar[i].addAll(filteredDayList);
      }
      bangumiCalendar.clear();
      bangumiCalendar.addAll(resBangumiCalendar);
    }
    isLoading = false;
    if (bangumiCalendar.isEmpty) {
      isTimeOut = true;
    } else {
      isTimeOut = bangumiCalendar.every((innerList) => innerList.isEmpty);
    }
    if (!isTimeOut) {
      changeSortType(sortType);
    }
  }

  void tryEnterSeason(DateTime date) {
    selectedDate = date;
    seasonString = "加载中 ٩(◦`꒳´◦)۶";
  }

  /// 排序方式
  /// 1. default
  /// 2. score
  /// 3. heat
  void changeSortType(int type) {
    if (type < 1 || type > 3) {
      return;
    }
    sortType = type;
    var resBangumiCalendar = bangumiCalendar.toList();
    for (var dayList in resBangumiCalendar) {
      switch (sortType) {
        case 1:
          dayList.sort((a, b) => a.id.compareTo(b.id));
          break;
        case 2:
          dayList.sort((a, b) => (b.ratingScore).compareTo(a.ratingScore));
          break;
        case 3:
          dayList.sort((a, b) => (b.votes).compareTo(a.votes));
          break;
        default:
      }
    }
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
  }

  @action
  void filterCurrentCalendar() {
    final abandonedNames = collectController.getBangumiNamesByType(5);

    final filteredCalendar = bangumiCalendar.map((dayList) {
      dayList.removeWhere((item) => abandonedNames.contains(item.name));
      return dayList;
    }).toList();

    bangumiCalendar.clear();
    bangumiCalendar.addAll(filteredCalendar);
  }
}
