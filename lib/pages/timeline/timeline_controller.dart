import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/storage/storage.dart';
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
  ObservableMap<int, int> episodeCounts = ObservableMap<int, int>();

  @observable
  bool isLoadingEpisodes = false;

  @observable
  late bool notShowAbandonedBangumis =
      _collectRepository.getTimelineNotShowAbandonedBangumis();

  @observable
  late bool notShowWatchedBangumis =
      _collectRepository.getTimelineNotShowWatchedBangumis();

  @observable
  late bool onlyShowWatchingBangumis =
      _collectRepository.getTimelineOnlyShowWatchingBangumis();

  int sortType = 3;

  late DateTime selectedDate;

  bool get _bangumiMirrorEnabled => GStorage.setting
      .get(SettingBoxKey.enableBangumiProxy, defaultValue: false);

  void init() {
    selectedDate = DateTime.now();
    seasonString = AnimeSeason(selectedDate).toString();
    getSchedules();
  }

  Future<void> getSchedules() async {
    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    final resBangumiCalendar = await BangumiApi.getCalendar();
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
    changeSortType(sortType);
    isLoading = false;
    isTimeOut = bangumiCalendar.isEmpty;
    fetchEpisodeCounts();
  }

  @action
  Future<void> fetchEpisodeCounts() async {
    isLoadingEpisodes = true;
    final ids = <int>{};
    for (final dayList in bangumiCalendar) {
      for (final item in dayList) {
        if (!episodeCounts.containsKey(item.id)) {
          ids.add(item.id);
        }
      }
    }
    
    // 并行加载，每10个一组以避免过多并发请求
    const batchSize = 10;
    final idList = ids.toList();
    
    for (var i = 0; i < idList.length; i += batchSize) {
      final end = (i + batchSize < idList.length) ? i + batchSize : idList.length;
      final batch = idList.sublist(i, end);
      
      await Future.wait(batch.map((id) async {
        try {
          final episodes = await BangumiApi.getBangumiEpisodesByID(id);
          final airedEpisodes = episodes.where((e) => e.type == 0 && e.isAired);
          if (airedEpisodes.isNotEmpty) {
            final latest = airedEpisodes.map((e) => e.episode).reduce(
                (a, b) => a > b ? a : b);
            episodeCounts[id] = latest.toInt();
          }
        } catch (_) {
          // skip failed fetches
        }
      }));
    }
    
    isLoadingEpisodes = false;
  }

  Future<void> getSchedulesBySeason() async {
    if (_bangumiMirrorEnabled) {
      isLoading = true;
      isTimeOut = false;
      bangumiCalendar.clear();
      final resBangumiCalendar =
          await BangumiApi.getBangumiMirrorSeasonCalendar(
              AnimeSeason(selectedDate).toSeasonStartAndEnd());
      bangumiCalendar.clear();
      bangumiCalendar.addAll(resBangumiCalendar);
      isLoading = false;
      isTimeOut = bangumiCalendar.every((innerList) => innerList.isEmpty);
      if (!isTimeOut) {
        changeSortType(sortType);
      }
      if (!isTimeOut) {
        fetchEpisodeCounts();
      }
      return;
    }

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
      var newList = await BangumiApi.getCalendarBySearch(
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
    if (!isTimeOut) {
      fetchEpisodeCounts();
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
  /// 4. air date
  void changeSortType(int type) {
    if (type < 1 || type > 4) {
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
        case 4:
          dayList.sort((a, b) => a.airDate.compareTo(b.airDate));
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
