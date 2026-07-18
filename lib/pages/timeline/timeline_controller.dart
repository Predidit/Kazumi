import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

typedef TimelineCalendarLoader = Future<List<List<BangumiItem>>> Function();
typedef TimelineMirrorSeasonLoader = Future<List<List<BangumiItem>>> Function(
  List<String> dateRange,
);
typedef TimelineSeasonPageLoader = Future<List<List<BangumiItem>>> Function(
  List<String> dateRange,
  int limit,
  int offset,
);

class TimelineController = TimelineControllerBase with _$TimelineController;

abstract class TimelineControllerBase with Store {
  TimelineControllerBase(
    this._collectRepository, {
    TimelineCalendarLoader? calendarLoader,
    TimelineMirrorSeasonLoader? mirrorSeasonLoader,
    TimelineSeasonPageLoader? seasonPageLoader,
    bool Function()? mirrorEnabled,
  })  : _calendarLoader = calendarLoader ?? BangumiApi.getCalendar,
        _mirrorSeasonLoader =
            mirrorSeasonLoader ?? BangumiApi.getBangumiMirrorSeasonCalendar,
        _seasonPageLoader = seasonPageLoader ?? BangumiApi.getCalendarBySearch,
        _mirrorEnabled = mirrorEnabled ?? _defaultMirrorEnabled;

  final ICollectRepository _collectRepository;
  final TimelineCalendarLoader _calendarLoader;
  final TimelineMirrorSeasonLoader _mirrorSeasonLoader;
  final TimelineSeasonPageLoader _seasonPageLoader;
  final bool Function() _mirrorEnabled;

  @observable
  ObservableList<List<BangumiItem>> bangumiCalendar =
      ObservableList<List<BangumiItem>>();

  @observable
  String seasonString = '';

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  /// The most recent recoverable load failure. Updates are paired with the
  /// observable loading flag to avoid changing generated MobX code.
  String? loadError;

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

  static bool _defaultMirrorEnabled() =>
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
    isLoading = true;
    isTimeOut = false;
    loadError = null;
    try {
      final resBangumiCalendar = await _calendarLoader();
      bangumiCalendar.clear();
      bangumiCalendar.addAll(resBangumiCalendar);
      changeSortType(sortType);
      isTimeOut = bangumiCalendar.isEmpty;
    } catch (error, stackTrace) {
      loadError = '加载时间表失败，请重试';
      isTimeOut = bangumiCalendar.isEmpty;
      KazumiLogger().w(
        'TimelineController: failed to load current schedule',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> getSchedulesBySeason() async {
    isLoading = true;
    isTimeOut = false;
    loadError = null;
    bangumiCalendar.clear();
    final dateRange = AnimeSeason(selectedDate).toSeasonStartAndEnd();
    try {
      if (_mirrorEnabled()) {
        final resBangumiCalendar = await _mirrorSeasonLoader(dateRange);
        bangumiCalendar.addAll(resBangumiCalendar);
      } else {
        const maxTime = 4;
        const limit = 20;
        final resBangumiCalendar = List.generate(7, (_) => <BangumiItem>[]);
        for (var time = 0; time < maxTime; time++) {
          final offset = time * limit;
          final newList = await _seasonPageLoader(dateRange, limit, offset);
          for (var i = 0; i < resBangumiCalendar.length; ++i) {
            resBangumiCalendar[i].addAll(newList[i]);
          }
          bangumiCalendar
            ..clear()
            ..addAll(resBangumiCalendar);
        }
      }
      isTimeOut = bangumiCalendar.isEmpty ||
          bangumiCalendar.every((innerList) => innerList.isEmpty);
      if (!isTimeOut) {
        changeSortType(sortType);
      }
    } catch (error, stackTrace) {
      loadError = '加载季度时间表失败，请重试';
      isTimeOut = bangumiCalendar.isEmpty ||
          bangumiCalendar.every((innerList) => innerList.isEmpty);
      KazumiLogger().w(
        'TimelineController: failed to load season schedule',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isLoading = false;
    }
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
