import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/services/sync/history_sync_service.dart';
import 'package:kazumi/services/logging/logger.dart';

typedef HistoryProgressSyncAppender = Future<void> Function({
  required History history,
  required int episode,
  required int road,
  required int progressMs,
  required int updatedAt,
  required String episodePageUrl,
});

typedef HistoryDeleteSyncAppender = Future<void> Function(History history);

typedef HistoryClearSyncAppender = Future<void> Function();

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
    String episodePageUrl = '',
    String stableId = '',
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
    String episodePageUrl = '',
    String stableId = '',
  });

  /// 清空所有历史记录
  Future<void> clearAllHistories();

  /// 迁移历史进度中过期的 pageURL。
  ///
  /// 当规则的 baseURL 变更后，历史记录里基于旧 baseURL 归一化得到的
  /// [Progress.episodePageUrl] 不再与当前 roadList 中的 URL 匹配，
  /// 进而在下次写入时被当作新条目，产生重复进度。
  ///
  /// [resolveCurrentPageUrl] 根据存储的 `(road, episode)` 返回当前 roadList
  /// 中对应的最新 URL（无法解析返回空串）。命中后就地把旧 URL 迁移为新 URL，
  /// 使后续写入复用既有条目而非新建。
  void migrateProgressPageUrls({
    required String adapterName,
    required BangumiItem bangumiItem,
    String entryKind = HistoryEntryKind.online,
    required String Function(int road, int episode) resolveCurrentPageUrl,
  });

  /// 获取隐私模式设置
  bool getPrivateMode();
}

/// 历史记录数据访问实现类
///
/// 基于Hive实现的历史记录数据访问层
class HistoryRepository implements IHistoryRepository {
  HistoryRepository({
    Box<History>? historiesBox,
    bool Function()? privateModeReader,
    HistoryProgressSyncAppender? progressSyncAppender,
    HistoryDeleteSyncAppender? deleteSyncAppender,
    HistoryClearSyncAppender? clearSyncAppender,
  })  : _historiesBox = historiesBox ?? GStorage.histories,
        _privateModeReader = privateModeReader ??
            (() => GStorage.getSetting(SettingsKeys.privateMode)),
        _progressSyncAppender = progressSyncAppender ?? _appendProgressSync,
        _deleteSyncAppender = deleteSyncAppender ?? _appendDeleteSync,
        _clearSyncAppender = clearSyncAppender ?? _appendClearSync;

  final Box<History> _historiesBox;
  final bool Function() _privateModeReader;
  final HistoryProgressSyncAppender _progressSyncAppender;
  final HistoryDeleteSyncAppender _deleteSyncAppender;
  final HistoryClearSyncAppender _clearSyncAppender;

  static Future<void> _appendProgressSync({
    required History history,
    required int episode,
    required int road,
    required int progressMs,
    required int updatedAt,
    required String episodePageUrl,
  }) async {
    final historySyncService = HistorySyncService();
    await historySyncService.appendSafely(
      () => historySyncService.appendUpsertProgress(
        history: history,
        episode: episode,
        road: road,
        progressMs: progressMs,
        updatedAt: updatedAt,
        episodePageUrl: episodePageUrl,
      ),
    );
  }

  static Future<void> _appendDeleteSync(History history) async {
    final historySyncService = HistorySyncService();
    await historySyncService.appendSafely(
      () => historySyncService.appendDeleteHistory(history),
    );
  }

  static Future<void> _appendClearSync() async {
    final historySyncService = HistorySyncService();
    await historySyncService.appendSafely(
      () => historySyncService.appendClearAll(),
    );
  }

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
      history.episodePageUrl = identity.episodePageUrl;

      // 更新观看进度
      final progressMatch = _HistoryEpisodeMatcher.find(
        history,
        episode: episode,
        stableId: identity.stableId,
        episodePageUrl: identity.episodePageUrl,
      );
      final progressBucket = progressMatch?.bucket ??
          _HistoryEpisodeMatcher.bucketForNewProgress(
            history,
            episode: episode,
            stableId: identity.stableId,
            episodePageUrl: identity.episodePageUrl,
          );
      final prog = progressMatch?.progress ??
          Progress(
            episode,
            identity.road,
            progress.inMilliseconds,
            updatedAtMs: nowMs,
            episodePageUrl: identity.episodePageUrl,
            stableId: identity.stableId,
          );
      prog.episode = episode;
      prog.road = identity.road;
      prog.progress = progress;
      prog.updatedAtMs = nowMs;
      prog.episodePageUrl = identity.episodePageUrl;
      if (identity.stableId.isNotEmpty) {
        prog.stableId = identity.stableId;
      }
      history.progresses[progressBucket] = prog;

      // 保存到存储
      await _historiesBox.put(history.key, history);
      if (shouldMigrateLegacy && legacyKey != history.key) {
        await _historiesBox.delete(legacyKey);
      }
      await _progressSyncAppender(
        history: history,
        episode: episode,
        road: identity.road,
        progressMs: progress.inMilliseconds,
        updatedAt: nowMs,
        episodePageUrl: prog.episodePageUrl,
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
      final history = _findHistory(adapterName, bangumiItem, entryKind);
      if (history == null) {
        return null;
      }
      final progressMatch = _HistoryEpisodeMatcher.find(
        history,
        episode: history.lastWatchEpisode,
        episodePageUrl: history.episodePageUrl,
      );
      final resolvedMatch =
          progressMatch?.progress.episode == history.lastWatchEpisode
              ? progressMatch
              : _HistoryEpisodeMatcher.find(
                  history,
                  episode: history.lastWatchEpisode,
                );
      _backfillProgressIdentity(
        history,
        resolvedMatch,
        episodePageUrl: history.episodePageUrl,
      );
      return resolvedMatch?.progress;
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
    String episodePageUrl = '',
    String stableId = '',
  }) {
    try {
      final history = _findHistory(adapterName, bangumiItem, entryKind);
      if (history == null) {
        return null;
      }
      final progressMatch = _HistoryEpisodeMatcher.find(
        history,
        episode: episode,
        stableId: stableId,
        episodePageUrl: episodePageUrl,
      );
      _backfillProgressIdentity(
        history,
        progressMatch,
        episodePageUrl: episodePageUrl,
        stableId: stableId,
      );
      return progressMatch?.progress;
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
      await _deleteSyncAppender(history);
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
    String episodePageUrl = '',
    String stableId = '',
  }) async {
    try {
      final history = _findHistory(adapterName, bangumiItem, entryKind);
      final progressMatch = history == null
          ? null
          : _HistoryEpisodeMatcher.find(
              history,
              episode: episode,
              stableId: stableId,
              episodePageUrl: episodePageUrl,
            );
      if (history != null && progressMatch != null) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        progressMatch.progress.progress = Duration.zero;
        progressMatch.progress.updatedAtMs = nowMs;
        if (episodePageUrl.isNotEmpty &&
            progressMatch.progress.episodePageUrl.isEmpty) {
          progressMatch.progress.episodePageUrl = episodePageUrl;
        }
        history.progresses[progressMatch.bucket] = progressMatch.progress;
        await _historiesBox.put(history.key, history);
        await _progressSyncAppender(
          history: history,
          episode: progressMatch.progress.episode,
          road: progressMatch.progress.road,
          progressMs: 0,
          updatedAt: nowMs,
          episodePageUrl: progressMatch.progress.episodePageUrl,
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
      await _clearSyncAppender();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: clear all histories failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void migrateProgressPageUrls({
    required String adapterName,
    required BangumiItem bangumiItem,
    String entryKind = HistoryEntryKind.online,
    required String Function(int road, int episode) resolveCurrentPageUrl,
  }) {
    try {
      final history = _findHistory(adapterName, bangumiItem, entryKind);
      if (history == null) {
        return;
      }

      // Phase 1: 解析计划重写（仅记录，不修改）。
      // 必须使用 Progress 值的 road/episode，而非 map key，因为
      // bucketForNewProgress 会递增寻找空桶，key 可能不等于 episode。
      final plannedRewrites = <int, String>{};
      for (final entry in history.progresses.entries) {
        final progress = entry.value;
        final currentUrl = progress.episodePageUrl.trim();
        if (currentUrl.isEmpty) {
          continue;
        }
        final newUrl =
            resolveCurrentPageUrl(progress.road, progress.episode).trim();
        if (newUrl.isEmpty || newUrl == currentUrl) {
          continue;
        }
        plannedRewrites[entry.key] = newUrl;
      }

      if (plannedRewrites.isEmpty) {
        return;
      }

      // 在变更前记录顶层 URL 对应的桶，便于结束后同步迁移
      // history.episodePageUrl（getLastWatchingProgress 会优先用它匹配）。
      final topUrl = history.episodePageUrl.trim();
      int? topBucketKey;
      if (topUrl.isNotEmpty) {
        for (final entry in history.progresses.entries) {
          if (entry.value.episodePageUrl.trim() == topUrl) {
            topBucketKey = entry.key;
            break;
          }
        }
      }

      // Phase 2: 应用重写并解决目标 URL 冲突。
      var changed = false;
      final removedBuckets = <int>{};
      plannedRewrites.forEach((bucketKey, newUrl) {
        if (removedBuckets.contains(bucketKey)) {
          return;
        }
        final progress = history.progresses[bucketKey];
        if (progress == null) {
          return;
        }

        // 查找其它已持有 newUrl 的桶（既有真实条目或过往升级产生的重复）。
        int? conflictKey;
        for (final entry in history.progresses.entries) {
          if (entry.key == bucketKey || removedBuckets.contains(entry.key)) {
            continue;
          }
          if (entry.value.episodePageUrl == newUrl) {
            conflictKey = entry.key;
            break;
          }
        }

        if (conflictKey == null) {
          progress.episodePageUrl = newUrl;
          changed = true;
          return;
        }

        // 冲突：按 updatedAtMs 较大者为准，删除落败桶，仅向幸存桶写入。
        final conflictProgress = history.progresses[conflictKey]!;
        if (progress.updatedAtMs >= conflictProgress.updatedAtMs) {
          history.progresses.remove(conflictKey);
          removedBuckets.add(conflictKey);
          progress.episodePageUrl = newUrl;
        } else {
          history.progresses.remove(bucketKey);
          removedBuckets.add(bucketKey);
          // 幸存桶已持有 newUrl，无需再赋值。
        }
        changed = true;
      });

      if (topBucketKey != null) {
        final newTopUrl = plannedRewrites[topBucketKey];
        if (newTopUrl != null && newTopUrl != topUrl) {
          history.episodePageUrl = newTopUrl;
          changed = true;
        }
      }

      if (changed) {
        unawaited(_historiesBox.put(history.key, history));
      }
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'GStorage: migrate progress page urls failed. bangumi=${bangumiItem.name}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool getPrivateMode() {
    try {
      return _privateModeReader();
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

  /// 命中既有进度后，把缺失的身份字段（[Progress.episodePageUrl] /
  /// [Progress.stableId]）就地补齐，便于存量历史逐步收敛到 stableId 匹配。
  void _backfillProgressIdentity(
    History history,
    _HistoryEpisodeMatch? progressMatch, {
    String episodePageUrl = '',
    String stableId = '',
  }) {
    if (progressMatch == null) {
      return;
    }
    var changed = false;
    if (episodePageUrl.isNotEmpty &&
        progressMatch.progress.episodePageUrl.isEmpty) {
      progressMatch.progress.episodePageUrl = episodePageUrl;
      changed = true;
    }
    if (stableId.isNotEmpty && progressMatch.progress.stableId.isEmpty) {
      progressMatch.progress.stableId = stableId;
      changed = true;
    }
    if (!changed) {
      return;
    }
    history.progresses[progressMatch.bucket] = progressMatch.progress;
    unawaited(_historiesBox.put(history.key, history));
  }
}

class _HistoryEpisodeMatch {
  const _HistoryEpisodeMatch({
    required this.bucket,
    required this.progress,
  });

  final int bucket;
  final Progress progress;
}

class _HistoryEpisodeMatcher {
  /// 历史进度匹配，优先级：
  /// 1. [stableId]（规则产出的稳定身份，与域名/顺序无关）——主键；
  /// 2. [episodePageUrl]（存量数据兼容回退）；
  /// 3. 集号（最终回退）。
  static _HistoryEpisodeMatch? find(
    History history, {
    required int episode,
    String stableId = '',
    String episodePageUrl = '',
  }) {
    final id = stableId.trim();
    if (id.isNotEmpty) {
      for (final entry in history.progresses.entries) {
        if (entry.value.stableId == id) {
          return _HistoryEpisodeMatch(
            bucket: entry.key,
            progress: entry.value,
          );
        }
      }
    }

    final pageUrl = episodePageUrl.trim();
    if (pageUrl.isNotEmpty) {
      for (final entry in history.progresses.entries) {
        if (entry.value.episodePageUrl == pageUrl) {
          return _HistoryEpisodeMatch(
            bucket: entry.key,
            progress: entry.value,
          );
        }
      }

      final legacyProgress = history.progresses[episode];
      if (legacyProgress != null &&
          legacyProgress.episode == episode &&
          legacyProgress.episodePageUrl.isEmpty &&
          legacyProgress.stableId.isEmpty) {
        return _HistoryEpisodeMatch(
          bucket: episode,
          progress: legacyProgress,
        );
      }
      for (final entry in history.progresses.entries) {
        final progress = entry.value;
        if (progress.episode == episode &&
            progress.episodePageUrl.isEmpty &&
            progress.stableId.isEmpty) {
          return _HistoryEpisodeMatch(
            bucket: entry.key,
            progress: progress,
          );
        }
      }
      return null;
    }

    // 仅提供了 stableId 但未命中时，不再按集号兜底，避免误绑到错误的存量条目。
    if (id.isNotEmpty) {
      return null;
    }

    final progress = history.progresses[episode];
    if (progress != null && progress.episode == episode) {
      return _HistoryEpisodeMatch(bucket: episode, progress: progress);
    }

    for (final entry in history.progresses.entries) {
      if (entry.value.episode == episode) {
        return _HistoryEpisodeMatch(
          bucket: entry.key,
          progress: entry.value,
        );
      }
    }
    return null;
  }

  static int bucketForNewProgress(
    History history, {
    required int episode,
    String stableId = '',
    String episodePageUrl = '',
  }) {
    final id = stableId.trim();
    final pageUrl = episodePageUrl.trim();
    final existing = history.progresses[episode];
    if (existing == null) {
      return episode;
    }
    if (existing.episode == episode &&
        (id.isEmpty || existing.stableId.isEmpty || existing.stableId == id) &&
        (pageUrl.isEmpty ||
            existing.episodePageUrl.isEmpty ||
            existing.episodePageUrl == pageUrl)) {
      return episode;
    }

    var bucket = episode;
    while (history.progresses.containsKey(bucket)) {
      bucket++;
    }
    return bucket;
  }

  _HistoryEpisodeMatcher._();
}
