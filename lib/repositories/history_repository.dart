import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// 历史记录数据访问接口
///
/// 提供观看历史相关的数据访问抽象
abstract class IHistoryRepository {
  /// 获取所有历史记录（按时间倒序）
  List<History> getAllHistories();

  /// 获取特定番剧的历史记录
  ///
  /// [adapterName] 适配器名称
  /// [bangumiItem] 番剧信息
  /// 返回历史记录，不存在返回null
  History? getHistory(String adapterName, BangumiItem bangumiItem);

  /// 更新或创建历史记录
  ///
  /// [episode] 集数
  /// [road] 线路
  /// [adapterName] 适配器名称
  /// [bangumiItem] 番剧信息
  /// [progress] 观看进度
  /// [lastSrc] 最后观看源
  /// [lastWatchEpisodeName] 最后观看集名称
  Future<void> updateHistory({
    required int episode,
    required int road,
    required String adapterName,
    required BangumiItem bangumiItem,
    required Duration progress,
    required String lastSrc,
    required String lastWatchEpisodeName,
  });

  /// 获取上次观看的进度
  ///
  /// [bangumiItem] 番剧信息
  /// [adapterName] 适配器名称
  /// 返回观看进度，不存在返回null
  Progress? getLastWatchingProgress(BangumiItem bangumiItem, String adapterName);

  /// 查找特定集数的观看进度
  ///
  /// [bangumiItem] 番剧信息
  /// [adapterName] 适配器名称
  /// [episode] 集数
  /// 返回观看进度，不存在返回null
  Progress? findProgress(BangumiItem bangumiItem, String adapterName, int episode);

  /// 删除历史记录
  ///
  /// [history] 要删除的历史记录
  Future<void> deleteHistory(History history);

  /// 清空特定集数的观看进度
  ///
  /// [bangumiItem] 番剧信息
  /// [adapterName] 适配器名称
  /// [episode] 集数
  Future<void> clearProgress(BangumiItem bangumiItem, String adapterName, int episode);

  /// 清空所有历史记录
  Future<void> clearAllHistories();

  /// 获取隐私模式设置
  bool getPrivateMode();
}

/// 历史记录数据访问实现类
///
/// 基于Hive实现的历史记录数据访问层
class HistoryRepository implements IHistoryRepository {
  final _historiesBox = GStorage.histories;
  final _settingBox = GStorage.setting;

  @override
  List<History> getAllHistories() {
    try {
      var histories = _historiesBox.values.toList();
      histories.sort(
        (a, b) =>
            b.lastWatchTime.millisecondsSinceEpoch -
            a.lastWatchTime.millisecondsSinceEpoch,
      );
      return histories;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取历史记录列表失败',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  History? getHistory(String adapterName, BangumiItem bangumiItem) {
    try {
      return _historiesBox.get(History.getKey(adapterName, bangumiItem));
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取历史记录失败: ${bangumiItem.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> updateHistory({
    required int episode,
    required int road,
    required String adapterName,
    required BangumiItem bangumiItem,
    required Duration progress,
    required String lastSrc,
    required String lastWatchEpisodeName,
  }) async {
    try {
      // 检查隐私模式
      if (getPrivateMode()) {
        return;
      }

      // 获取或创建历史记录
      var history = _historiesBox.get(History.getKey(adapterName, bangumiItem)) ??
          History(bangumiItem, episode, adapterName, DateTime.now(), lastSrc, lastWatchEpisodeName);

      // 更新历史记录
      history.lastWatchEpisode = episode;
      history.lastWatchTime = DateTime.now();
      if (lastSrc.isNotEmpty) {
        history.lastSrc = lastSrc;
      }
      if (lastWatchEpisodeName.isNotEmpty) {
        history.lastWatchEpisodeName = lastWatchEpisodeName;
      }

      // 更新观看进度
      var prog = history.progresses[episode];
      if (prog == null) {
        history.progresses[episode] =
            Progress(episode, road, progress.inMilliseconds);
      } else {
        prog.progress = progress;
      }

      // 保存到存储
      await _historiesBox.put(history.key, history);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '更新历史记录失败: ${bangumiItem.name}, episode=$episode',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Progress? getLastWatchingProgress(BangumiItem bangumiItem, String adapterName) {
    try {
      var history = _historiesBox.get(History.getKey(adapterName, bangumiItem));
      return history?.progresses[history.lastWatchEpisode];
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取上次观看进度失败: ${bangumiItem.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Progress? findProgress(BangumiItem bangumiItem, String adapterName, int episode) {
    try {
      var history = _historiesBox.get(History.getKey(adapterName, bangumiItem));
      return history?.progresses[episode];
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '查找观看进度失败: ${bangumiItem.name}, episode=$episode',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> deleteHistory(History history) async {
    try {
      await _historiesBox.delete(history.key);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '删除历史记录失败: ${history.bangumiItem.name}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearProgress(BangumiItem bangumiItem, String adapterName, int episode) async {
    try {
      var history = _historiesBox.get(History.getKey(adapterName, bangumiItem));
      if (history != null && history.progresses[episode] != null) {
        history.progresses[episode]!.progress = Duration.zero;
        await _historiesBox.put(history.key, history);
      }
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '清空观看进度失败: ${bangumiItem.name}, episode=$episode',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearAllHistories() async {
    try {
      await _historiesBox.clear();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '清空所有历史记录失败',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool getPrivateMode() {
    try {
      final value = _settingBox.get(
        SettingBoxKey.privateMode,
        defaultValue: false,
      );
      return value is bool ? value : false;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取隐私模式设置失败，使用默认值false',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
