import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/services/logging/logger.dart';

abstract class IDownloadRepository {
  List<DownloadRecord> getAllRecords();
  DownloadRecord? getRecord(String key);
  Future<void> putRecord(DownloadRecord record);
  Future<void> deleteRecord(String key);
  Future<void> updateEpisode(
      String recordKey, int downloadKey, DownloadEpisode episode);
  Future<void> deleteEpisode(String recordKey, int downloadKey);
  bool getForceAdBlocker();

  /// 获取指定番剧的下载记录
  ///
  /// [bangumiId] 番剧 ID
  /// [pluginName] 插件名称
  DownloadRecord? getRecordByBangumiId(int bangumiId, String pluginName);

  /// 获取指定本地下载 key 的下载信息
  ///
  /// [bangumiId] 番剧 ID
  /// [pluginName] 插件名称
  /// [downloadKey] `DownloadRecord.episodes` 的本地 key；旧记录可等同集数编号
  DownloadEpisode? getEpisode(
      int bangumiId, String pluginName, int downloadKey);

  /// 获取已完成下载的集数列表
  ///
  /// [bangumiId] 番剧 ID
  /// [pluginName] 插件名称
  /// 返回所有已完成下载的集数
  List<DownloadEpisode> getCompletedEpisodes(int bangumiId, String pluginName);

  /// 通过订阅规则产出的稳定集身份查找下载记录。
  DownloadEpisode? getEpisodeByStableId(
      int bangumiId, String pluginName, String stableId,
      {required int road});
}

class DownloadRepository implements IDownloadRepository {
  final _downloadsBox = GStorage.downloads;

  @override
  List<DownloadRecord> getAllRecords() {
    final List<DownloadRecord> result = [];
    try {
      for (final key in _downloadsBox.keys) {
        try {
          final record = _downloadsBox.get(key);
          if (record != null) {
            // Merge in-memory progress into the record
            final cachedEpisodes = _progressCache[key as String];
            if (cachedEpisodes != null) {
              for (final entry in cachedEpisodes.entries) {
                record.episodes[entry.key] = entry.value;
              }
            }
            result.add(record);
          }
        } catch (e) {
          // 单条记录读取失败，跳过该记录并记录日志
          KazumiLogger().w(
              'DownloadRepository: failed to read record key=$key, skipping',
              error: e);
        }
      }
    } catch (e) {
      KazumiLogger().w('DownloadRepository: get all records failed', error: e);
    }
    return result;
  }

  @override
  DownloadRecord? getRecord(String key) {
    try {
      final record = _downloadsBox.get(key);
      if (record != null) {
        // Merge in-memory progress into the record
        final cachedEpisodes = _progressCache[key];
        if (cachedEpisodes != null) {
          for (final entry in cachedEpisodes.entries) {
            record.episodes[entry.key] = entry.value;
          }
        }
      }
      return record;
    } catch (e) {
      KazumiLogger()
          .w('DownloadRepository: get record failed. key=$key', error: e);
      return null;
    }
  }

  @override
  Future<void> putRecord(DownloadRecord record) async {
    try {
      await _downloadsBox.put(record.key, record);
      await _downloadsBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: put record failed. key=${record.key}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteRecord(String key) async {
    try {
      await _downloadsBox.delete(key);
      await _downloadsBox.flush();
      _progressCache.remove(key);
      _lastPersistedStatus.removeWhere((k, v) => k.startsWith('${key}_'));
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: delete record failed. key=$key',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Track last persisted status to avoid unnecessary writes
  final Map<String, int> _lastPersistedStatus = {};

  /// In-memory cache for progress updates (not persisted until status changes)
  final Map<String, Map<int, DownloadEpisode>> _progressCache = {};

  @override
  Future<void> updateEpisode(
      String recordKey, int downloadKey, DownloadEpisode episode) async {
    try {
      // Update in-memory cache
      _progressCache.putIfAbsent(recordKey, () => {});
      _progressCache[recordKey]![downloadKey] = episode;

      // Only persist to Hive when status changes (not on every progress update)
      // This dramatically reduces disk I/O and prevents corruption on crash
      final statusKey = '${recordKey}_$downloadKey';
      final lastStatus = _lastPersistedStatus[statusKey];
      final shouldPersist = lastStatus != episode.status;

      if (shouldPersist) {
        final record = _downloadsBox.get(recordKey);
        if (record == null) return;
        record.episodes[downloadKey] = episode;
        await _downloadsBox.put(recordKey, record);
        await _downloadsBox.flush();
        _lastPersistedStatus[statusKey] = episode.status;
      }
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: update episode failed. key=$recordKey, downloadKey=$downloadKey',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get episode with in-memory progress if available
  DownloadEpisode? getEpisodeWithProgress(String recordKey, int downloadKey) {
    // Check in-memory cache first
    final cached = _progressCache[recordKey]?[downloadKey];
    if (cached != null) return cached;

    // Fall back to Hive
    final record = getRecord(recordKey);
    return record?.episodes[downloadKey];
  }

  @override
  bool getForceAdBlocker() {
    return GStorage.getSetting(SettingsKeys.forceAdBlocker);
  }

  @override
  Future<void> deleteEpisode(String recordKey, int downloadKey) async {
    try {
      final record = _downloadsBox.get(recordKey);
      if (record == null) return;
      record.episodes.remove(downloadKey);
      if (record.episodes.isEmpty) {
        await _downloadsBox.delete(recordKey);
        _progressCache.remove(recordKey);
        _lastPersistedStatus
            .removeWhere((k, v) => k.startsWith('${recordKey}_'));
      } else {
        await _downloadsBox.put(recordKey, record);
        _progressCache[recordKey]?.remove(downloadKey);
        _lastPersistedStatus.remove('${recordKey}_$downloadKey');
      }
      await _downloadsBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: delete episode failed. key=$recordKey, downloadKey=$downloadKey',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  DownloadRecord? getRecordByBangumiId(int bangumiId, String pluginName) {
    final key = '${pluginName}_$bangumiId';
    return getRecord(key);
  }

  @override
  DownloadEpisode? getEpisode(
      int bangumiId, String pluginName, int downloadKey) {
    final record = getRecordByBangumiId(bangumiId, pluginName);
    return record?.episodes[downloadKey];
  }

  @override
  List<DownloadEpisode> getCompletedEpisodes(int bangumiId, String pluginName) {
    final record = getRecordByBangumiId(bangumiId, pluginName);
    if (record == null) return [];

    return record.episodes.values
        .where((e) => e.status == DownloadStatus.completed)
        .toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  }

  @override
  DownloadEpisode? getEpisodeByStableId(
    int bangumiId,
    String pluginName,
    String stableId, {
    required int road,
  }) {
    if (stableId.isEmpty) return null;
    final record = getRecordByBangumiId(bangumiId, pluginName);
    if (record == null) return null;
    for (final episode in record.episodes.values) {
      if (episode.stableId == stableId && episode.road == road) {
        return episode;
      }
    }
    return null;
  }
}
