import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

enum TimelineSort { popularity, rating, defaultOrder }

class TimelineController = _TimelineController with _$TimelineController;

abstract class _TimelineController with Store {
  _TimelineController(this._collectRepository);

  final ICollectRepository _collectRepository;

  @observable
  ObservableList<List<BangumiItem>> bangumiCalendar =
      ObservableList<List<BangumiItem>>();

  @readonly
  DateTime _selectedDate = DateTime.now();

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

  @readonly
  TimelineSort _sort = TimelineSort.popularity;

  bool get _bangumiMirrorEnabled =>
      GStorage.getSetting(SettingsKeys.enableBangumiProxy);

  @action
  Future<void> loadSeason(DateTime date) async {
    if (isLoading) return;
    isLoading = true;
    isTimeOut = false;
    try {
      _selectedDate = date;
      bangumiCalendar.clear();
      if (isSameSeason(date, DateTime.now())) {
        bangumiCalendar.addAll(await BangumiApi.getCalendar());
        isTimeOut = bangumiCalendar.isEmpty;
      } else {
        await _getSchedulesBySeason(date);
        isTimeOut = bangumiCalendar.every((day) => day.isEmpty);
      }
      if (!isTimeOut) changeSort(_sort);
    } catch (error, stackTrace) {
      isTimeOut = true;
      KazumiLogger().e('Timeline: loading season failed',
          error: error, stackTrace: stackTrace);
    } finally {
      isLoading = false;
    }
  }

  // MobX batches clear/addAll between awaits so observers never see a partial update.
  @action
  Future<void> _getSchedulesBySeason(DateTime date) async {
    final dateRange = AnimeSeason(date).toSeasonStartAndEnd();
    if (_bangumiMirrorEnabled) {
      bangumiCalendar
          .addAll(await BangumiApi.getBangumiMirrorSeasonCalendar(dateRange));
      return;
    }

    const pageCount = 4;
    const limit = 20;
    final resBangumiCalendar = List.generate(7, (_) => <BangumiItem>[]);
    for (var page = 0; page < pageCount; page++) {
      final newList =
          await BangumiApi.getCalendarBySearch(dateRange, limit, page * limit);
      for (int i = 0; i < resBangumiCalendar.length; ++i) {
        resBangumiCalendar[i].addAll(newList[i]);
      }
      bangumiCalendar.clear();
      bangumiCalendar.addAll(resBangumiCalendar);
    }
  }

  @action
  void changeSort(TimelineSort sort) {
    _sort = sort;
    final Comparator<BangumiItem> compare = switch (sort) {
      TimelineSort.popularity => (a, b) => b.votes.compareTo(a.votes),
      TimelineSort.rating => (a, b) => b.ratingScore.compareTo(a.ratingScore),
      TimelineSort.defaultOrder => (a, b) => a.id.compareTo(b.id),
    };
    final resBangumiCalendar = bangumiCalendar.toList();
    for (final dayList in resBangumiCalendar) {
      dayList.sort(compare);
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

  @action
  Future<void> setOnlyShowWatchingBangumis(bool value) async {
    onlyShowWatchingBangumis = value;
    await _collectRepository.updateTimelineOnlyShowWatchingBangumis(value);
  }

  Set<int> loadWatchingBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watching);
  }

  int get activeFilterCount => [
        onlyShowWatchingBangumis,
        notShowWatchedBangumis,
        notShowAbandonedBangumis,
      ].where((enabled) => enabled).length;

  List<List<BangumiItem>> filterCalendar(Set<int> watchingIds) {
    final abandonedIds = notShowAbandonedBangumis
        ? _collectRepository.getBangumiIdsByType(CollectType.abandoned)
        : <int>{};
    final watchedIds = notShowWatchedBangumis
        ? _collectRepository.getBangumiIdsByType(CollectType.watched)
        : <int>{};
    final onlyWatching = onlyShowWatchingBangumis;
    return List.generate(7, (day) {
      if (day >= bangumiCalendar.length) return <BangumiItem>[];
      return bangumiCalendar[day]
          .where((item) =>
              !abandonedIds.contains(item.id) &&
              !watchedIds.contains(item.id) &&
              (!onlyWatching || watchingIds.contains(item.id)))
          .toList();
    });
  }

  @action
  Future<void> clearFilters() async {
    await Future.wait([
      setNotShowAbandonedBangumis(false),
      setNotShowWatchedBangumis(false),
      setOnlyShowWatchingBangumis(false),
    ]);
  }
}
