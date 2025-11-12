import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

class TimelineController = _TimelineController with _$TimelineController;

abstract class _TimelineController with Store {
  final _collectRepository = Modular.get<ICollectRepository>();

  @observable
  ObservableList<List<BangumiItem>> bangumiCalendar =
      ObservableList<List<BangumiItem>>();

  @observable
  String seasonString = '';

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  @observable
  late bool notShowAbandonedBangumis = _collectRepository.getTimelineNotShowAbandonedBangumis();

  @observable
  late bool notShowWatchedBangumis = _collectRepository.getTimelineNotShowWatchedBangumis();

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
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
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
        resBangumiCalendar[i].addAll(newList[i]);
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
  Future<void> setNotShowAbandonedBangumis(bool value) async {
    notShowAbandonedBangumis = value;
    await _collectRepository.updateTimelineNotShowAbandonedBangumis(value);
  }

  @action
  Future<void> setNotShowWatchedBangumis(bool value) async {
    notShowWatchedBangumis = value;
    await _collectRepository.updateTimelineNotShowWatchedBangumis(value);
  }

  Set<int> loadAbandonedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.abandoned);
  }

  Set<int> loadWatchedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watched);
  }
}
