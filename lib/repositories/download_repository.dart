import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/utils/logger.dart';

abstract class IDownloadRepository {
  List<DownloadRecord> getAllRecords();
  DownloadRecord? getRecord(String key);
  Future<void> putRecord(DownloadRecord record);
  Future<void> deleteRecord(String key);
  Future<void> updateEpisode(String recordKey, int episodeNumber, DownloadEpisode episode);
  Future<void> deleteEpisode(String recordKey, int episodeNumber);
  bool getForceAdBlocker();

  /// 获取指定番剧的下载记录
  ///
  /// [bangumiId] 番剧 ID
  /// [pluginName] 插件名称
  DownloadRecord? getRecordByBangumiId(int bangumiId, String pluginName);

  /// 获取指定集数的下载信息
  ///
  /// [bangumiId] 番剧 ID
  /// [pluginName] 插件名称
  /// [episodeNumber] 集数编号
  DownloadEpisode? getEpisode(int bangumiId, String pluginName, int episodeNumber);

  /// 获取已完成下载的集数列表
  ///
  /// [bangumiId] 番剧 ID
  /// [pluginName] 插件名称
  /// 返回所有已完成下载的集数
  List<DownloadEpisode> getCompletedEpisodes(int bangumiId, String pluginName);

  /// 通过集数页面 URL 查找下载记录
  ///
  /// [bangumiId] 番剧 ID
  /// [pluginName] 插件名称
  /// [episodePageUrl] 集数页面 URL
  /// 当 URL 为空时返回 null（兼容旧数据）
  DownloadEpisode? getEpisodeByUrl(int bangumiId, String pluginName, String episodePageUrl);
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
          KazumiLogger().w('DownloadRepository: failed to read record key=$key, skipping', error: e);
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
      KazumiLogger().w('DownloadRepository: get record failed. key=$key', error: e);
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
  Future<void> updateEpisode(String recordKey, int episodeNumber, DownloadEpisode episode) async {
    try {
      // Update in-memory cache
      _progressCache.putIfAbsent(recordKey, () => {});
      _progressCache[recordKey]![episodeNumber] = episode;

      // Only persist to Hive when status changes (not on every progress update)
      // This dramatically reduces disk I/O and prevents corruption on crash
      final statusKey = '${recordKey}_$episodeNumber';
      final lastStatus = _lastPersistedStatus[statusKey];
      final shouldPersist = lastStatus != episode.status;

      if (shouldPersist) {
        final record = _downloadsBox.get(recordKey);
        if (record == null) return;
        record.episodes[episodeNumber] = episode;
        await _downloadsBox.put(recordKey, record);
        await _downloadsBox.flush();
        _lastPersistedStatus[statusKey] = episode.status;
      }
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: update episode failed. key=$recordKey, ep=$episodeNumber',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get episode with in-memory progress if available
  DownloadEpisode? getEpisodeWithProgress(String recordKey, int episodeNumber) {
    // Check in-memory cache first
    final cached = _progressCache[recordKey]?[episodeNumber];
    if (cached != null) return cached;

    // Fall back to Hive
    final record = getRecord(recordKey);
    return record?.episodes[episodeNumber];
  }

  @override
  bool getForceAdBlocker() {
    return GStorage.setting.get(SettingBoxKey.forceAdBlocker, defaultValue: false);
  }

  @override
  Future<void> deleteEpisode(String recordKey, int episodeNumber) async {
    try {
      final record = _downloadsBox.get(recordKey);
      if (record == null) return;
      record.episodes.remove(episodeNumber);
      if (record.episodes.isEmpty) {
        await _downloadsBox.delete(recordKey);
      } else {
        await _downloadsBox.put(recordKey, record);
      }
      await _downloadsBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'DownloadRepository: delete episode failed. key=$recordKey, ep=$episodeNumber',
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
  DownloadEpisode? getEpisode(int bangumiId, String pluginName, int episodeNumber) {
    final record = getRecordByBangumiId(bangumiId, pluginName);
    return record?.episodes[episodeNumber];
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
  DownloadEpisode? getEpisodeByUrl(int bangumiId, String pluginName, String episodePageUrl) {
    if (episodePageUrl.isEmpty) return null;
    final record = getRecordByBangumiId(bangumiId, pluginName);
    if (record == null) return null;
    for (final episode in record.episodes.values) {
      if (episode.episodePageUrl == episodePageUrl) {
        return episode;
      }
    }
    return null;
  }
}
