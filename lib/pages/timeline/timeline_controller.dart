import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

class TimelineController = _TimelineController with _$TimelineController;

abstract class _TimelineController with Store {
  @observable
  ObservableList<List<BangumiItem>> bangumiCalendar = ObservableList<List<BangumiItem>>();

  @observable
  String seasonString = '';

  DateTime selectedDate = DateTime.now();

  Future<void> getSchedules() async {
    final resBangumiCalendar = await BangumiHTTP.getCalendar();
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
  }

  Future<void> getSchedulesBySeason() async {
    // 4次获取，每次最多20部
    var time = 0;
    const maxTime = 4;
    const limit = 20;
    var resBangumiCalendar = List.generate(7, (_) => <BangumiItem>[]);
    for (time = 0; time < maxTime; time++) {
      final offset = time * limit;
      var newList = await BangumiHTTP.getCalendarBySearch(
          AnimeSeason(selectedDate).toSeasonStartAndEnd(), limit, offset);
      for (int i = 0; i < bangumiCalendar.length; ++i) {
        bangumiCalendar[i].addAll(newList[i]);
      }
      bangumiCalendar.clear();
      bangumiCalendar.addAll(resBangumiCalendar);
    }
  }
}