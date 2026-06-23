import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/utils/history_sync_service.dart';
import 'package:kazumi/utils/logger.dart';

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
  History? getHistory(
    String adapterName,
    BangumiItem bangumiItem, {
    String entryKind = HistoryEntryKind.online,
  });

  /// 更新或创建历史记录
  ///
  /// [identity] 播放历史身份
  /// [progress] 观看进度
  Future<void> updateHistory({
    required PlaybackHistoryIdentity identity,
    required Duration progress,
  });

  /// 获取上次观看的进度
  ///
  /// [bangumiItem] 番剧信息
  /// [adapterName] 适配器名称
  /// 返回观看进度，不存在返回null
  Progress? getLastWatchingProgress(
    BangumiItem bangumiItem,
    String adapterName, {
    String entryKind = HistoryEntryKind.online,
  });

  /// 查找特定集数的观看进度
  ///
  /// [bangumiItem] 番剧信息
  /// [adapterName] 适配器名称
  /// [episode] 集数
  /// 返回观看进度，不存在返回null
  Progress? findProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
  });

  /// 删除历史记录
  ///
  /// [history] 要删除的历史记录
  Future<void> deleteHistory(History history);

  /// 清空特定集数的观看进度
  ///
  /// [bangumiItem] 番剧信息
  /// [adapterName] 适配器名称
  /// [episode] 集数
  Future<void> clearProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
  });

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
      final byKey = <String, History>{};
      for (final history in _historiesBox.values) {
        history.entryKind = HistoryEntryKind.normalize(history.entryKind);
        final existing = byKey[history.key];
        if (existing == null ||
            existing.lastWatchTime.isBefore(history.lastWatchTime)) {
          byKey[history.key] = history;
        }
      }
      var histories = byKey.values.toList();
      histories.sort(
        (a, b) =>
            b.lastWatchTime.millisecondsSinceEpoch -
            a.lastWatchTime.millisecondsSinceEpoch,
      );
      return histories;
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: get all histories failed',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  History? getHistory(
    String adapterName,
    BangumiItem bangumiItem, {
    String entryKind = HistoryEntryKind.online,
  }) {
    try {
      return _findHistory(adapterName, bangumiItem, entryKind);
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: get history failed. bangumi=${bangumiItem.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> updateHistory({
    required PlaybackHistoryIdentity identity,
    required Duration progress,
  }) async {
    try {
      if (!identity.canRecord) {
        return;
      }
      // 检查隐私模式
      if (getPrivateMode()) {
        return;
      }

      final episode = identity.episodeNumber;
      final adapterName = identity.pluginName;
      final bangumiItem = identity.bangumiItem;

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;
      final legacyKey = History.legacyKey(adapterName, bangumiItem);
      final shouldMigrateLegacy =
          HistoryEntryKind.normalize(identity.entryKind) ==
              HistoryEntryKind.online;

      // 获取或创建历史记录
      var history = _findHistory(
            adapterName,
            bangumiItem,
            identity.entryKind,
          ) ??
          History(
            bangumiItem,
            episode,
            adapterName,
            now,
            identity.onlineBangumiSrc,
            identity.episodeTitle,
            entryKind: identity.entryKind,
            episodePageUrl: identity.episodePageUrl,
          );

      // 更新历史记录
      history.lastWatchEpisode = episode;
      history.lastWatchTime = now;
      history.entryKind = HistoryEntryKind.normalize(identity.entryKind);
      if (identity.onlineBangumiSrc.isNotEmpty) {
        history.lastSrc = identity.onlineBangumiSrc;
      }
      if (identity.episodeTitle.isNotEmpty) {
        history.lastWatchEpisodeName = identity.episodeTitle;
      }
      if (identity.episodePageUrl.isNotEmpty) {
        history.episodePageUrl = identity.episodePageUrl;
      }

      // 更新观看进度
      var prog = history.progresses[episode];
      if (prog == null) {
        history.progresses[episode] = Progress(
          episode,
          identity.road,
          progress.inMilliseconds,
          updatedAtMs: nowMs,
        );
      } else {
        prog.road = identity.road;
        prog.progress = progress;
        prog.updatedAtMs = nowMs;
      }

      // 保存到存储
      await _historiesBox.put(history.key, history);
      if (shouldMigrateLegacy && legacyKey != history.key) {
        await _historiesBox.delete(legacyKey);
      }
      await HistorySyncService().appendSafely(
        () => HistorySyncService().appendUpsertProgress(
          history: history,
          episode: episode,
          road: identity.road,
          progressMs: progress.inMilliseconds,
          updatedAt: nowMs,
        ),
      );
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: update history failed. bangumi=${identity.bangumiItem.name}, episode=${identity.episodeNumber}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Progress? getLastWatchingProgress(
    BangumiItem bangumiItem,
    String adapterName, {
    String entryKind = HistoryEntryKind.online,
  }) {
    try {
      var history = _findHistory(adapterName, bangumiItem, entryKind);
      return history?.progresses[history.lastWatchEpisode];
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: get last watching progress failed. bangumi=${bangumiItem.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Progress? findProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
  }) {
    try {
      var history = _findHistory(adapterName, bangumiItem, entryKind);
      return history?.progresses[episode];
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: find progress failed. bangumi=${bangumiItem.name}, episode=$episode',
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
      if (HistoryEntryKind.normalize(history.entryKind) ==
          HistoryEntryKind.online) {
        await _historiesBox.delete(
          History.legacyKey(history.adapterName, history.bangumiItem),
        );
      }
      await HistorySyncService().appendSafely(
        () => HistorySyncService().appendDeleteHistory(history),
      );
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: delete history failed. bangumi=${history.bangumiItem.name}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
  }) async {
    try {
      var history = _findHistory(adapterName, bangumiItem, entryKind);
      if (history != null && history.progresses[episode] != null) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        history.progresses[episode]!.progress = Duration.zero;
        history.progresses[episode]!.updatedAtMs = nowMs;
        await _historiesBox.put(history.key, history);
        await HistorySyncService().appendSafely(
          () => HistorySyncService().appendUpsertProgress(
            history: history,
            episode: episode,
            road: history.progresses[episode]!.road,
            progressMs: 0,
            updatedAt: nowMs,
          ),
        );
      }
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: clear progress failed. bangumi=${bangumiItem.name}, episode=$episode',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearAllHistories() async {
    try {
      await _historiesBox.clear();
      await HistorySyncService().appendSafely(
        () => HistorySyncService().appendClearAll(),
      );
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: clear all histories failed',
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
      KazumiLogger().e(
        'GStorage: get private mode setting failed, using default false',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  History? _findHistory(
    String adapterName,
    BangumiItem bangumiItem,
    String entryKind,
  ) {
    final normalizedEntryKind = HistoryEntryKind.normalize(entryKind);
    return _historiesBox.get(
          History.getKey(
            adapterName,
            bangumiItem,
            entryKind: normalizedEntryKind,
          ),
        ) ??
        (normalizedEntryKind == HistoryEntryKind.online
            ? _historiesBox.get(History.legacyKey(adapterName, bangumiItem))
            : null);
  }
}
