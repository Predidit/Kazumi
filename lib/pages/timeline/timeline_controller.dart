import 'dart:async';

import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/anilist_api.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

class TimelineController = _TimelineController with _$TimelineController;

abstract class _TimelineController with Store {
  _TimelineController(this._collectRepository);

  final ICollectRepository _collectRepository;

  @observable
  ObservableList<List<BangumiItem>> bangumiCalendar =
      ObservableList<List<BangumiItem>>();

  final ObservableMap<int, DateTime> airingTimes = ObservableMap();

  @observable
  String seasonString = '';

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  @observable
  late bool notShowAbandonedBangumis =
      _collectRepository.getTimelineNotShowAbandonedBangumis();

  @observable
  late bool notShowWatchedBangumis =
      _collectRepository.getTimelineNotShowWatchedBangumis();

  @observable
  late bool onlyShowWatchingBangumis =
      _collectRepository.getTimelineOnlyShowWatchingBangumis();

  int _sortType = 3;
  int get sortType => _sortType;

  late DateTime _selectedDate;
  DateTime get selectedDate => _selectedDate;

  int _scheduleRequestId = 0;

  bool get _bangumiMirrorEnabled =>
      GStorage.getSetting(SettingsKeys.enableBangumiProxy);

  void init() {
    _selectedDate = DateTime.now();
    seasonString = AnimeSeason(_selectedDate).toString();
    getSchedules();
  }

  // Async actions commit each segment between awaits as one transaction, so
  // clear+addAll never shows observers an intermediate empty list.
  @action
  Future<void> getSchedules() async {
    final requestId = ++_scheduleRequestId;
    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    airingTimes.clear();
    unawaited(AniListApi.preloadSeason(_selectedDate));
    final resBangumiCalendar = await BangumiApi.getCalendar();
    if (requestId != _scheduleRequestId) return;
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
    changeSortType(sortType);
    isLoading = false;
    isTimeOut = bangumiCalendar.isEmpty;
    unawaited(_loadAiringTimes(resBangumiCalendar, requestId));
  }

  @action
  Future<void> getSchedulesBySeason() async {
    final requestId = ++_scheduleRequestId;
    unawaited(AniListApi.preloadSeason(selectedDate));
    if (_bangumiMirrorEnabled) {
      isLoading = true;
      isTimeOut = false;
      bangumiCalendar.clear();
      airingTimes.clear();
      final resBangumiCalendar =
          await BangumiApi.getBangumiMirrorSeasonCalendar(
              AnimeSeason(selectedDate).toSeasonStartAndEnd());
      if (requestId != _scheduleRequestId) return;
      bangumiCalendar.clear();
      bangumiCalendar.addAll(resBangumiCalendar);
      isLoading = false;
      isTimeOut = bangumiCalendar.every((innerList) => innerList.isEmpty);
      if (!isTimeOut) {
        changeSortType(sortType);
        unawaited(_loadAiringTimes(resBangumiCalendar, requestId));
      }
      return;
    }

    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    airingTimes.clear();
    var time = 0;
    const maxTime = 4;
    const limit = 20;
    var resBangumiCalendar = List.generate(7, (_) => <BangumiItem>[]);
    for (time = 0; time < maxTime; time++) {
      final offset = time * limit;
      var newList = await BangumiApi.getCalendarBySearch(
          AnimeSeason(selectedDate).toSeasonStartAndEnd(), limit, offset);
      if (requestId != _scheduleRequestId) return;
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
      unawaited(_loadAiringTimes(resBangumiCalendar, requestId));
    }
  }

  Future<void> _loadAiringTimes(
      List<List<BangumiItem>> calendar, int requestId) async {
    final airingTimesById = await AniListApi.getAiringTimes(
      calendar.expand((items) => items),
      selectedDate: selectedDate,
    );
    if (requestId != _scheduleRequestId) return;
    runInAction(() {
      airingTimes
        ..clear()
        ..addAll(airingTimesById);
    });
  }

  void tryEnterSeason(DateTime date) {
    _selectedDate = date;
    seasonString = "加载中 ٩(◦`꒳´◦)۶";
  }

  /// Sort type: 1 = default (id), 2 = score, 3 = heat (votes).
  @action
  void changeSortType(int type) {
    if (type < 1 || type > 3) {
      return;
    }
    _sortType = type;
    var resBangumiCalendar = bangumiCalendar.toList();
    for (var dayList in resBangumiCalendar) {
      switch (_sortType) {
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

  @action
  Future<void> setOnlyShowWatchingBangumis(bool value) async {
    onlyShowWatchingBangumis = value;
    await _collectRepository.updateTimelineOnlyShowWatchingBangumis(value);
  }

  Set<int> loadWatchingBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watching);
  }
}
