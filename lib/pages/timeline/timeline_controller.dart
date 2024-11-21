import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

class TimelineController = _TimelineController with _$TimelineController;

abstract class _TimelineController with Store {
  @observable
  List<List<BangumiItem>> bangumiCalendar = [];

  @observable
  String seasonString = '';

  DateTime selectedDate = DateTime.now();

  Future<void> getSchedules() async {
    bangumiCalendar = await BangumiHTTP.getCalendar();
  }

  Future<void> getSchedulesBySeason() async {
    bangumiCalendar = await BangumiHTTP.getCalendarBySearch(AnimeSeason(selectedDate).toSeasonStartAndEnd());
  }
}