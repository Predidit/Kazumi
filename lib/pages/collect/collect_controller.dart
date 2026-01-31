import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/logger.dart';

part 'collect_controller.g.dart';

class CollectController = _CollectController with _$CollectController;

abstract class _CollectController with Store {
  final _collectCrudRepository = Modular.get<ICollectCrudRepository>();
  final _collectRepository = Modular.get<ICollectRepository>();

  // 时间表缓存：key=番剧ID, value=星期(0-6)
  @observable
  ObservableMap<int, int> _watchingCalendarWeekdayById = ObservableMap<int, int>();

  // 构造函数：初始化时从缓存加载时间表数据
  _CollectController() {
    _loadCachedCalendar();
  }

  @observable
  bool isWatchingCalendarLoading = false;

  @observable
  bool isWatchingCalendarReady = false;

  Box setting = GStorage.setting;
  List<BangumiItem> get favorites => _collectCrudRepository.getFavorites();

  @observable
  ObservableList<CollectedBangumi> collectibles =
      ObservableList<CollectedBangumi>();

  void loadCollectibles() {
    collectibles.clear();
    collectibles.addAll(_collectCrudRepository.getAllCollectibles());
  }

  /// 从缓存加载时间表数据
  void _loadCachedCalendar() {
    try {
      final cachedData = setting.get(SettingBoxKey.cachedWatchingCalendar);
      if (cachedData != null && cachedData is Map) {
        _watchingCalendarWeekdayById = ObservableMap<int, int>.of(
          Map<int, int>.from(cachedData),
        );
        if (_watchingCalendarWeekdayById.isNotEmpty) {
          isWatchingCalendarReady = true;
          KazumiLogger().d('Loaded cached watching calendar with ${_watchingCalendarWeekdayById.length} items');
        }
      }
    } catch (e) {
      KazumiLogger().e('Failed to load cached calendar', error: e);
    }
  }

  /// 缓存时间表数据到本地
  Future<void> _saveCachedCalendar() async {
    try {
      await setting.put(
        SettingBoxKey.cachedWatchingCalendar,
        Map<int, int>.from(_watchingCalendarWeekdayById),
      );
      KazumiLogger().d('Saved watching calendar cache with ${_watchingCalendarWeekdayById.length} items');
    } catch (e) {
      KazumiLogger().e('Failed to save calendar cache', error: e);
    }
  }

  @action
  Future<void> loadWatchingCalendar() async {
    if (isWatchingCalendarLoading) {
      return;
    }
    isWatchingCalendarLoading = true;
    try {
      final calendar = await BangumiHTTP.getCalendar();
      if (calendar.isEmpty) {
        KazumiLogger().w('Resolve watching calendar failed: empty calendar');
        return;
      }
      final map = <int, int>{};
      for (int weekdayIndex = 0;
          weekdayIndex < calendar.length && weekdayIndex < 7;
          weekdayIndex++) {
        for (final item in calendar[weekdayIndex]) {
          map[item.id] = weekdayIndex;
        }
      }
      if (map.isEmpty) {
        KazumiLogger().w('Resolve watching calendar failed: empty map');
        return;
      }
      _watchingCalendarWeekdayById = ObservableMap<int, int>.of(map);
      isWatchingCalendarReady = true;
      // 加载成功后缓存到本地
      await _saveCachedCalendar();
    } catch (e) {
      KazumiLogger().e('Resolve watching calendar failed', error: e);
      // 失败时不阻塞 UI：继续使用 airWeekday 的降级分组
      isWatchingCalendarReady = false;
      _watchingCalendarWeekdayById = ObservableMap<int, int>();
    } finally {
      isWatchingCalendarLoading = false;
    }
  }

  /// 确保时间表已加载（用于刷新缓存）
  Future<void> ensureWatchingCalendarLoaded() async {
    if (isWatchingCalendarLoading) {
      return;
    }
    if (isWatchingCalendarReady && _watchingCalendarWeekdayById.isNotEmpty) {
      return;
    }
    await loadWatchingCalendar();
  }

  int getCollectType(BangumiItem bangumiItem) {
    return _collectCrudRepository.getCollectType(bangumiItem.id);
  }

  @action
  Future<void> addCollect(BangumiItem bangumiItem, {type = 1}) async {
    if (type == 0) {
      await deleteCollect(bangumiItem);
      return;
    }
    await _collectCrudRepository.addCollectible(bangumiItem, type);
    final int collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final CollectedBangumiChange collectChange = CollectedBangumiChange(
        collectChangeId,
        bangumiItem.id,
        1,
        type,
        (DateTime.now().millisecondsSinceEpoch ~/ 1000));
    await _collectCrudRepository.addCollectChange(collectChange);
    loadCollectibles();
  }

  @action
  Future<void> deleteCollect(BangumiItem bangumiItem) async {
    await _collectCrudRepository.deleteCollectible(bangumiItem.id);
    final int collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final CollectedBangumiChange collectChange = CollectedBangumiChange(
        collectChangeId,
        bangumiItem.id,
        3,
        5,
        (DateTime.now().millisecondsSinceEpoch ~/ 1000));
    await _collectCrudRepository.addCollectChange(collectChange);
    loadCollectibles();
  }

  Future<void> updateLocalCollect(BangumiItem bangumiItem) async {
    await _collectCrudRepository.updateCollectible(bangumiItem);
    loadCollectibles();
  }

  Future<void> syncCollectibles() async {
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
      return;
    }
    bool flag = true;
    try {
      await WebDav().ping();
    } catch (e) {
      KazumiLogger().e('WebDav: WebDav connection failed', error: e);
      KazumiDialog.showToast(message: 'WebDav连接失败: $e');
      flag = false;
    }
    if (!flag) {
      return;
    }
    try {
      await WebDav().syncCollectibles();
    } catch (e){
      KazumiDialog.showToast(message: 'WebDav同步失败 $e');
    }
    loadCollectibles();
  }

  // migrate collect from old version (favorites)
  Future<void> migrateCollect() async {
    if (favorites.isNotEmpty) {
      int count = 0;
      for (BangumiItem bangumiItem in favorites) {
        await addCollect(bangumiItem, type: 1);
        count++;
      }
      await _collectCrudRepository.clearFavorites();
      KazumiLogger().d('GStorage: detected $count uncategorized favorites, migrated to collectibles');
    }
  }

  /// 根据收藏类型获取番剧ID集合
  ///
  /// [type] 收藏类型
  /// 返回番剧ID集合
  Set<int> getBangumiIdsByType(CollectType type) {
    return _collectRepository.getBangumiIdsByType(type);
  }

  /// 过滤掉指定收藏类型的番剧
  ///
  /// [bangumiList] 原始番剧列表
  /// [excludeType] 要排除的收藏类型
  /// 返回过滤后的番剧列表
  List<BangumiItem> filterBangumiByType(
      List<BangumiItem> bangumiList, CollectType excludeType) {
    final excludeIds = getBangumiIdsByType(excludeType);
    return bangumiList
        .where((item) => !excludeIds.contains(item.id))
        .toList();
  }

  /// 将"在看"番剧按周数分组
  ///
  /// 返回 Map<int, List<CollectedBangumi>>
  /// key: 0-6 代表周一到周日, 7 代表老番(不在时间表中)
  Map<int, List<CollectedBangumi>> getWatchingBangumiByWeekday() {
    // 初始化 8 个分组 (周一到周日 + 老番)
    Map<int, List<CollectedBangumi>> weekdayGroups = {
      0: [], // 周一
      1: [], // 周二
      2: [], // 周三
      3: [], // 周四
      4: [], // 周五
      5: [], // 周六
      6: [], // 周日
      7: [], // 老番
    };

    // 过滤出"在看"类型的番剧
    final watchingList = collectibles.where((item) => item.type == 1).toList();

    // 按周数分组：优先使用时间表匹配；不在时间表的统一归为老番
    for (var collected in watchingList) {
      final id = collected.bangumiItem.id;
      final calendarWeekdayIndex = _watchingCalendarWeekdayById[id];
      if (calendarWeekdayIndex != null && calendarWeekdayIndex >= 0 && calendarWeekdayIndex <= 6) {
        weekdayGroups[calendarWeekdayIndex]!.add(collected);
      } else {
        // 降级：时间表未就绪时，先按 airWeekday 分组；否则视为老番
        if (!isWatchingCalendarReady && _watchingCalendarWeekdayById.isEmpty) {
          final weekday = collected.bangumiItem.airWeekday;
          if (weekday >= 1 && weekday <= 7) {
            weekdayGroups[weekday - 1]!.add(collected);
          } else {
            weekdayGroups[7]!.add(collected);
          }
        } else {
          weekdayGroups[7]!.add(collected);
        }
      }
    }

    // 对每个分组按时间排序
    for (var group in weekdayGroups.values) {
      group.sort((a, b) => b.time.millisecondsSinceEpoch
          .compareTo(a.time.millisecondsSinceEpoch));
    }

    return weekdayGroups;
  }
}
