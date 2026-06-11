import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/services/download/background_download_service.dart';
import 'package:kazumi/services/download/download_manager.dart';
import 'package:kazumi/utils/format.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/video_source/services.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:mobx/mobx.dart';

part 'download_controller.g.dart';

class DownloadController = _DownloadController with _$DownloadController;

abstract class _DownloadController with Store {
  final _repository = Modular.get<IDownloadRepository>();
  final _downloadManager = Modular.get<IDownloadManager>();
  final _backgroundService = BackgroundDownloadService();
  final _resolverPool = VideoSourceResolverPool();

  @observable
  ObservableList<DownloadRecord> records = ObservableList<DownloadRecord>();
  final ObservableList<String> recordKeys = ObservableList<String>();
  final ObservableMap<String, DownloadRecord> recordByKey =
      ObservableMap<String, DownloadRecord>();

  final List<_ResolveRequest> _resolveQueue = [];
  final Map<String, VideoSourceResolverLease> _activeResolveLeases = {};
  bool _isBackgroundServiceInitialized = false;

  Future<void> init() async {
    _replaceRecords(_repository.getAllRecords());

    // Reset any incomplete states to 'paused' on startup
    // This includes 'pending' because the in-memory queue is lost on restart
    var resetIncompleteRecords = false;
    for (final record in records) {
      bool changed = false;
      for (final entry in record.episodes.entries) {
        if (entry.value.status == DownloadStatus.downloading ||
            entry.value.status == DownloadStatus.resolving ||
            entry.value.status == DownloadStatus.pending) {
          entry.value.status = DownloadStatus.paused;
          changed = true;
        }
      }
      if (changed) {
        resetIncompleteRecords = true;
        await _repository.putRecord(record);
      }
    }
    if (resetIncompleteRecords) {
      _replaceRecords(_repository.getAllRecords());
    }

    // 将旧 Hive danmakuData 迁移到独立文件，防止 Hive compact 时 OOM
    await _migrateDanmakuDataToFiles();

    _downloadManager.onProgress = _onDownloadProgress;
    await _initBackgroundService();
  }

  /// 启动时将所有旧 Hive danmakuData 迁移到独立文件并清空 Hive 字段
  Future<void> _migrateDanmakuDataToFiles() async {
    int migratedCount = 0;
    for (final record in records) {
      bool recordChanged = false;
      for (final entry in record.episodes.entries) {
        final episode = entry.value;
        if (episode.danmakuData.isEmpty || episode.downloadDirectory.isEmpty) {
          continue;
        }
        try {
          // danmakuData 已经是弹幕数组的 JSON 字符串，直接拼接成新格式写入
          // 避免 jsonDecode → DanmakuEntry.fromJson × N → toJson × N → jsonEncode 的开销
          final file = File(_danmakuFilePath(episode.downloadDirectory));
          await file.writeAsString(
              '{"danDanBangumiID":${episode.danDanBangumiID},"danmakus":${episode.danmakuData}}');
          episode.danmakuData = '';
          recordChanged = true;
          migratedCount++;
        } catch (e) {
          KazumiLogger().w(
              'DownloadController: danmaku migration failed for episode ${entry.key}',
              error: e);
        }
      }
      if (recordChanged) {
        await _repository.putRecord(record);
      }
    }
    if (migratedCount > 0) {
      KazumiLogger().i(
          'DownloadController: migrated danmaku data for $migratedCount episodes');
    }
  }

  Future<void> _initBackgroundService() async {
    if (!_backgroundService.isSupported) return;
    if (_isBackgroundServiceInitialized) return;

    await _backgroundService.init();
    _backgroundService.onPauseAll = pauseAllDownloads;
    _backgroundService.addTaskDataCallback(_onTaskData);
    _isBackgroundServiceInitialized = true;
  }

  void _onTaskData(Object data) {
    if (data is Map) {
      final action = data['action'];
      if (action == 'button_pressed') {
        _backgroundService.handleNotificationAction(data['id'] as String);
      } else if (action == 'navigate_to_download') {
        _backgroundService.handleNavigateToDownload();
      }
    }
  }

  final Map<String, double> _speeds = {};
  final _backgroundNotificationUpdater = _LatestAsyncRunner();
  DateTime _lastUiUpdateTime = DateTime.now();
  static const _uiUpdateInterval = Duration(milliseconds: 500);

  void _onDownloadProgress(String recordKey, int episodeNumber,
      DownloadEpisode episode, double speed) {
    final record = _repository.getRecord(recordKey);
    if (record == null || !record.episodes.containsKey(episodeNumber)) {
      return;
    }
    _repository.updateEpisode(recordKey, episodeNumber, episode);

    final key = '${recordKey}_$episodeNumber';

    final isFinalState = episode.status == DownloadStatus.completed ||
        episode.status == DownloadStatus.failed ||
        episode.status == DownloadStatus.paused;
    if (isFinalState) {
      _speeds.remove(key);
    } else {
      _speeds[key] = speed;
    }

    final now = DateTime.now();
    if (isFinalState ||
        now.difference(_lastUiUpdateTime) >= _uiUpdateInterval) {
      _lastUiUpdateTime = now;
      _refreshRecord(recordKey);
      _queueBackgroundNotificationUpdate();
    }
  }

  void _queueBackgroundNotificationUpdate() {
    _backgroundNotificationUpdater.schedule(() async {
      try {
        await _updateBackgroundNotification();
      } catch (e) {
        KazumiLogger().w(
          'DownloadController: background notification update failed',
          error: e,
        );
      }
    });
  }

  Future<void> _updateBackgroundNotification() async {
    if (!_backgroundService.isRunning) return;

    final stats = _getDownloadStats();
    if (!stats.hasWork) {
      await _backgroundService.stopService();
      return;
    }

    var totalSpeed = 0.0;
    for (final key in stats.activeKeys) {
      totalSpeed += _speeds[key] ?? 0;
    }

    await _backgroundService.updateProgress(
      activeCount: stats.activeCount,
      totalCount: stats.totalCount,
      overallProgress: stats.overallProgress,
      speedText: formatSpeed(totalSpeed),
    );
  }

  Future<void> _startBackgroundServiceIfNeeded() async {
    if (!_backgroundService.isSupported || _backgroundService.isRunning) return;

    final started = await _backgroundService.startService();
    if (started) {
      KazumiLogger().i('DownloadController: background service started');
    }
  }

  _DownloadStats _getDownloadStats() {
    var activeCount = 0;
    var pendingCount = 0;
    var totalCount = 0;
    var totalProgress = 0.0;
    final activeKeys = <String>{};

    for (final record in _repository.getAllRecords()) {
      for (final entry in record.episodes.entries) {
        final episode = entry.value;
        if (episode.status == DownloadStatus.downloading) {
          activeCount++;
          totalCount++;
          totalProgress += episode.progressPercent;
          activeKeys.add('${record.key}_${entry.key}');
        } else if (episode.status == DownloadStatus.resolving ||
            episode.status == DownloadStatus.pending) {
          pendingCount++;
          totalCount++;
        }
      }
    }

    return _DownloadStats(
      activeCount: activeCount,
      pendingCount: pendingCount,
      totalCount: totalCount,
      overallProgress: totalCount > 0 ? totalProgress / totalCount : 0.0,
      activeKeys: activeKeys,
    );
  }

  double getSpeed(int bangumiId, String pluginName, int episodeNumber) {
    final key = '${pluginName}_${bangumiId}_$episodeNumber';
    return _speeds[key] ?? 0.0;
  }

  @action
  void refreshRecords() {
    _replaceRecords(_repository.getAllRecords());
  }

  void _replaceRecords(List<DownloadRecord> nextRecords) {
    runInAction(() {
      records
        ..clear()
        ..addAll(nextRecords.map(_cloneRecord));

      recordKeys
        ..clear()
        ..addAll(nextRecords.map((record) => record.key));

      recordByKey
        ..clear()
        ..addEntries(nextRecords.map(
          (record) => MapEntry(record.key, _cloneRecord(record)),
        ));
    });
  }

  void _refreshRecord(String recordKey) {
    final record = _repository.getRecord(recordKey);
    runInAction(() {
      if (record == null || record.episodes.isEmpty) {
        recordByKey.remove(recordKey);
        recordKeys.remove(recordKey);
        records.removeWhere((item) => item.key == recordKey);
        return;
      }

      final snapshot = _cloneRecord(record);
      recordByKey[recordKey] = snapshot;
      final keyIndex = recordKeys.indexOf(recordKey);
      if (keyIndex == -1) {
        recordKeys.add(recordKey);
      }

      final recordIndex = records.indexWhere((item) => item.key == recordKey);
      if (recordIndex == -1) {
        records.add(_cloneRecord(record));
      } else {
        records[recordIndex] = _cloneRecord(record);
      }
    });
  }

  DownloadRecord? getRecordSnapshot(String recordKey) => recordByKey[recordKey];

  DownloadRecord _cloneRecord(DownloadRecord record) {
    return DownloadRecord(
      record.bangumiId,
      record.bangumiName,
      record.bangumiCover,
      record.pluginName,
      record.episodes.map(
        (episodeNumber, episode) => MapEntry(
          episodeNumber,
          _cloneEpisode(episode),
        ),
      ),
      record.createdAt,
    );
  }

  DownloadEpisode _cloneEpisode(DownloadEpisode episode) {
    return DownloadEpisode(
      episode.episodeNumber,
      episode.episodeName,
      episode.road,
      episode.status,
      episode.progressPercent,
      episode.totalSegments,
      episode.downloadedSegments,
      episode.localM3u8Path,
      episode.downloadDirectory,
      episode.networkM3u8Url,
      episode.completedAt,
      episode.errorMessage,
      episode.totalBytes,
      episode.episodePageUrl,
      danmakuData: episode.danmakuData,
      danDanBangumiID: episode.danDanBangumiID,
    );
  }

  Plugin? _findPlugin(String pluginName) {
    final pluginsController = Modular.get<PluginsController>();
    for (final plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) return plugin;
    }
    return null;
  }

  DownloadRecord? getRecord(int bangumiId, String pluginName) {
    return _repository.getRecordByBangumiId(bangumiId, pluginName);
  }

  DownloadEpisode? getEpisode(
      int bangumiId, String pluginName, int episodeNumber) {
    return _repository.getEpisode(bangumiId, pluginName, episodeNumber);
  }

  DownloadEpisode? getEpisodeByUrl(
      int bangumiId, String pluginName, String episodePageUrl) {
    return _repository.getEpisodeByUrl(bangumiId, pluginName, episodePageUrl);
  }

  String? getLocalVideoPath(
      int bangumiId, String pluginName, int episodeNumber) {
    final episode =
        _repository.getEpisode(bangumiId, pluginName, episodeNumber);
    return _downloadManager.getLocalVideoPath(episode);
  }

  List<DownloadEpisode> getCompletedEpisodes(int bangumiId, String pluginName) {
    return _repository.getCompletedEpisodes(bangumiId, pluginName);
  }

  /// 弹幕文件路径
  String _danmakuFilePath(String downloadDirectory) {
    return '$downloadDirectory/danmaku.json';
  }

  /// 从文件读取弹幕数据
  /// 支持新格式 (带 danDanBangumiID 的 wrapper) 和旧格式 (纯数组)
  Future<({List<DanmakuEntry> danmakus, int danDanBangumiID})?>
      _readDanmakuFromFile(String downloadDirectory) async {
    if (downloadDirectory.isEmpty) return null;
    final file = File(_danmakuFilePath(downloadDirectory));
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        // 旧格式：纯弹幕数组
        final danmakus =
            decoded.map((json) => DanmakuEntry.fromJson(json)).toList();
        return (danmakus: danmakus, danDanBangumiID: 0);
      } else if (decoded is Map<String, dynamic>) {
        // 新格式：带 danDanBangumiID 的 wrapper
        final danDanBangumiID = decoded['danDanBangumiID'] as int? ?? 0;
        final List<dynamic> jsonList = decoded['danmakus'] as List? ?? [];
        final danmakus =
            jsonList.map((json) => DanmakuEntry.fromJson(json)).toList();
        return (danmakus: danmakus, danDanBangumiID: danDanBangumiID);
      }
      return null;
    } catch (e) {
      KazumiLogger()
          .w('DownloadController: failed to read danmaku file', error: e);
      return null;
    }
  }

  /// 写入弹幕数据到文件 (新格式，包含 danDanBangumiID)
  Future<void> _writeDanmakuToFile(String downloadDirectory,
      List<DanmakuEntry> danmakus, int danDanBangumiID) async {
    if (downloadDirectory.isEmpty) return;
    final file = File(_danmakuFilePath(downloadDirectory));
    final wrapper = {
      'danDanBangumiID': danDanBangumiID,
      'danmakus': danmakus.map((d) => d.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(wrapper));
  }

  Future<List<DanmakuEntry>?> getCachedDanmakus(
      int bangumiId, String pluginName, int episodeNumber) async {
    final episode =
        _repository.getEpisode(bangumiId, pluginName, episodeNumber);
    if (episode == null) return null;

    // 从文件读取
    final fromFile = await _readDanmakuFromFile(episode.downloadDirectory);
    if (fromFile != null && fromFile.danmakus.isNotEmpty) {
      return fromFile.danmakus;
    }

    return null;
  }

  Future<void> updateCachedDanmakus(
    int bangumiId,
    String pluginName,
    int episodeNumber,
    List<DanmakuEntry> danmakus,
    int danDanBangumiID,
  ) async {
    final recordKey = '${pluginName}_$bangumiId';
    final record = _repository.getRecord(recordKey);
    if (record == null) return;
    final episode = record.episodes[episodeNumber];
    if (episode == null) return;

    try {
      // 写入独立文件而非 Hive
      await _writeDanmakuToFile(
          episode.downloadDirectory, danmakus, danDanBangumiID);
      // 确保 Hive 中不存储弹幕大数据
      if (episode.danmakuData.isNotEmpty) {
        episode.danmakuData = '';
        await _repository.updateEpisode(recordKey, episodeNumber, episode);
      }
      KazumiLogger().i(
          'DownloadController: updated cached danmakus for episode $episodeNumber');
    } catch (e) {
      KazumiLogger()
          .w('DownloadController: failed to update cached danmaku', error: e);
    }
  }

  Future<void> startDownload({
    required int bangumiId,
    required String bangumiName,
    required String bangumiCover,
    required String pluginName,
    required int episodeNumber,
    required String episodeName,
    required int road,
    required String episodePageUrl,
  }) async {
    final recordKey = '${pluginName}_$bangumiId';

    final record = _repository.getRecord(recordKey) ??
        DownloadRecord(
          bangumiId,
          bangumiName,
          bangumiCover,
          pluginName,
          {},
          DateTime.now(),
        );

    if (episodePageUrl.isNotEmpty) {
      for (final entry in record.episodes.entries) {
        if (entry.value.episodePageUrl == episodePageUrl) {
          KazumiLogger().i(
              'DownloadController: episode URL already exists at position ${entry.key}, skipping');
          return;
        }
      }
    }

    final episode = DownloadEpisode(
      episodeNumber,
      episodeName,
      road,
      DownloadStatus.resolving,
      0.0,
      0,
      0,
      '',
      '',
      '',
      null,
      '',
      0,
      episodePageUrl,
    );

    record.episodes[episodeNumber] = episode;
    await _repository.putRecord(record);
    refreshRecords();

    _resolveQueue.add(_ResolveRequest(
      recordKey: recordKey,
      bangumiId: bangumiId,
      pluginName: pluginName,
      episodeNumber: episodeNumber,
      episodePageUrl: episodePageUrl,
    ));
    _processResolveQueue();
  }

  void _processResolveQueue() {
    if (_resolveQueue.isEmpty) return;

    _resolverPool.resize(
      GStorage.getSetting(SettingsKeys.downloadParallelEpisodes),
    );

    var index = 0;
    while (index < _resolveQueue.length) {
      final request = _resolveQueue[index];
      final key = _resolveTaskKey(request.recordKey, request.episodeNumber);

      if (_activeResolveLeases.containsKey(key)) {
        index++;
        continue;
      }

      final lease = _resolverPool.tryAcquire(key);
      if (lease == null) return;

      _resolveQueue.removeAt(index);
      _activeResolveLeases[key] = lease;
      unawaited(_resolveAndEnqueue(request, lease));
    }
  }

  Future<void> _resolveAndEnqueue(
      _ResolveRequest request, VideoSourceResolverLease lease) async {
    final key = _resolveTaskKey(request.recordKey, request.episodeNumber);
    var wasCancelled = false;

    try {
      final plugin = _findPlugin(request.pluginName);
      if (plugin == null) {
        _failEpisode(request.recordKey, request.episodeNumber,
            '找不到插件 ${request.pluginName}');
        return;
      }

      final record = _repository.getRecord(request.recordKey);
      if (record == null) return;
      final episode = record.episodes[request.episodeNumber];
      if (episode == null) return;

      if (episode.status != DownloadStatus.resolving) return;

      final fullUrl = plugin.buildFullUrl(request.episodePageUrl);

      KazumiLogger().i(
          'DownloadController: resolving video URL for episode ${request.episodeNumber} from $fullUrl');

      String? m3u8Url;
      try {
        if (lease.isCancelled) {
          throw const VideoSourceCancelledException();
        }
        final source = await lease.resolve(
          fullUrl,
          useLegacyParser: plugin.useLegacyParser,
          timeout: const Duration(seconds: 30),
        );
        m3u8Url = source.url;
      } on VideoSourceTimeoutException {
        if (lease.isCancelled) {
          wasCancelled = true;
        } else {
          KazumiLogger().w('DownloadController: WebView resolution timed out');
        }
      } on VideoSourceCancelledException {
        wasCancelled = true;
        KazumiLogger().i('DownloadController: WebView resolution cancelled');
      } catch (e) {
        if (lease.isCancelled) {
          wasCancelled = true;
        } else {
          lease.retire();
          KazumiLogger()
              .e('DownloadController: WebView resolution failed', error: e);
        }
      }

      if (wasCancelled || lease.isCancelled) {
        return;
      }

      if (m3u8Url == null || m3u8Url.isEmpty) {
        _failEpisode(request.recordKey, request.episodeNumber, '解析视频源超时');
        return;
      }

      KazumiLogger().i(
          'DownloadController: resolved M3U8 URL for episode ${request.episodeNumber}: $m3u8Url');

      final freshRecord = _repository.getRecord(request.recordKey);
      if (freshRecord == null) return;
      final freshEpisode = freshRecord.episodes[request.episodeNumber];
      if (freshEpisode == null) return;

      if (freshEpisode.status != DownloadStatus.resolving) return;

      freshEpisode.networkM3u8Url = m3u8Url;
      freshEpisode.status = DownloadStatus.downloading;
      await _repository.updateEpisode(
          request.recordKey, request.episodeNumber, freshEpisode);
      _refreshRecord(request.recordKey);

      await _startBackgroundServiceIfNeeded();

      final httpHeaders = plugin.buildHttpHeaders();
      bool adBlockerEnabled =
          _repository.getForceAdBlocker() || plugin.adBlocker;

      await _downloadManager.enqueue(DownloadRequest(
        recordKey: request.recordKey,
        bangumiId: request.bangumiId,
        pluginName: request.pluginName,
        episodeNumber: request.episodeNumber,
        m3u8Url: m3u8Url,
        httpHeaders: httpHeaders,
        adBlockerEnabled: adBlockerEnabled,
        episode: freshEpisode,
      ));

      final bool downloadDanmaku =
          GStorage.getSetting(SettingsKeys.downloadDanmaku);
      if (downloadDanmaku) {
        _fetchAndCacheDanmakuAsync(
          request.recordKey,
          request.bangumiId,
          request.episodeNumber,
        );
      }
    } finally {
      _releaseResolveLease(key, lease);
    }
  }

  void _releaseResolveLease(String key, VideoSourceResolverLease lease) {
    if (_activeResolveLeases[key] == lease) {
      _activeResolveLeases.remove(key);
    }
    _resolverPool.release(lease);
    _processResolveQueue();
  }

  String _resolveTaskKey(String recordKey, int episodeNumber) =>
      '${recordKey.length}:$recordKey:$episodeNumber';

  bool _resolveTaskKeyBelongsToRecord(String key, String recordKey) =>
      key.startsWith('${recordKey.length}:$recordKey:');

  void _cancelResolve(String recordKey, int episodeNumber) {
    final key = _resolveTaskKey(recordKey, episodeNumber);
    _resolveQueue.removeWhere(
        (r) => r.recordKey == recordKey && r.episodeNumber == episodeNumber);
    _activeResolveLeases.remove(key)?.cancel();
    _resolverPool.cancel(key);
  }

  void _cancelResolveRecord(String recordKey) {
    _resolveQueue.removeWhere((r) => r.recordKey == recordKey);
    final activeKeys = _activeResolveLeases.keys
        .where((key) => _resolveTaskKeyBelongsToRecord(key, recordKey))
        .toList();
    for (final key in activeKeys) {
      _activeResolveLeases.remove(key)?.cancel();
      _resolverPool.cancel(key);
    }
  }

  void _cancelAllResolves() {
    _resolveQueue.clear();
    for (final lease in _activeResolveLeases.values.toList()) {
      lease.cancel();
    }
    _activeResolveLeases.clear();
    _resolverPool.cancelAll();
  }

  void _fetchAndCacheDanmakuAsync(
      String recordKey, int bangumiId, int episodeNumber) {
    Future(() async {
      try {
        KazumiLogger().i(
            'DownloadController: fetching danmaku for episode $episodeNumber (async)');

        // 获取 DanDan 番剧 ID
        final danDanBangumiID =
            await DanmakuApi.getDanDanBangumiIDByBgmBangumiID(bangumiId);
        if (danDanBangumiID == 0) {
          KazumiLogger().w(
              'DownloadController: failed to get DanDan bangumiID for $bangumiId');
          return;
        }

        // 获取弹幕列表
        final danmakus =
            await DanmakuApi.getDanDanmaku(danDanBangumiID, episodeNumber);
        if (danmakus.isEmpty) {
          KazumiLogger().i(
              'DownloadController: no danmaku found for episode $episodeNumber');
          return;
        }

        // 等待 downloadDirectory 就绪（下载管理器处理任务后才设置）
        String downloadDirectory = '';
        for (int i = 0; i < 10; i++) {
          final record = _repository.getRecord(recordKey);
          final episode = record?.episodes[episodeNumber];
          if (episode == null) return;
          if (episode.status == DownloadStatus.failed ||
              episode.status == DownloadStatus.paused) {
            return;
          }
          if (episode.downloadDirectory.isNotEmpty) {
            downloadDirectory = episode.downloadDirectory;
            break;
          }
          await Future.delayed(const Duration(seconds: 3));
        }
        if (downloadDirectory.isEmpty) {
          KazumiLogger().w(
              'DownloadController: downloadDirectory not ready for episode $episodeNumber, skipping danmaku cache');
          return;
        }

        // 写入独立文件
        await _writeDanmakuToFile(downloadDirectory, danmakus, danDanBangumiID);

        KazumiLogger().i(
            'DownloadController: cached ${danmakus.length} danmakus for episode $episodeNumber');
      } catch (e) {
        // 弹幕获取失败不影响下载
        KazumiLogger()
            .w('DownloadController: failed to fetch danmaku', error: e);
      }
    });
  }

  void _failEpisode(String recordKey, int episodeNumber, String message) {
    final record = _repository.getRecord(recordKey);
    if (record == null) return;
    final episode = record.episodes[episodeNumber];
    if (episode == null) return;
    episode.status = DownloadStatus.failed;
    episode.errorMessage = message;
    _repository.updateEpisode(recordKey, episodeNumber, episode);
    _refreshRecord(recordKey);
    KazumiLogger()
        .w('DownloadController: episode $episodeNumber failed: $message');
  }

  Future<void> pauseDownload(
      int bangumiId, String pluginName, int episodeNumber) async {
    final recordKey = '${pluginName}_$bangumiId';
    _downloadManager.pause(recordKey, episodeNumber);
    _cancelResolve(recordKey, episodeNumber);

    final record = _repository.getRecord(recordKey);
    if (record != null) {
      final episode = record.episodes[episodeNumber];
      if (episode != null) {
        episode.status = DownloadStatus.paused;
        await _repository.updateEpisode(recordKey, episodeNumber, episode);
        _refreshRecord(recordKey);
        _queueBackgroundNotificationUpdate();
      }
    }
  }

  Future<void> pauseAllDownloads() async {
    KazumiLogger().i('DownloadController: pausing all downloads');

    _cancelAllResolves();

    for (final record in records) {
      for (final entry in record.episodes.entries) {
        final episode = entry.value;
        if (episode.status == DownloadStatus.downloading ||
            episode.status == DownloadStatus.resolving ||
            episode.status == DownloadStatus.pending) {
          final recordKey = '${record.pluginName}_${record.bangumiId}';
          _downloadManager.pause(recordKey, entry.key);
          episode.status = DownloadStatus.paused;
          await _repository.updateEpisode(recordKey, entry.key, episode);
        }
      }
    }

    refreshRecords();

    await _backgroundService.stopService();
  }

  Future<void> retryDownload({
    required int bangumiId,
    required String pluginName,
    required int episodeNumber,
  }) async {
    final recordKey = '${pluginName}_$bangumiId';
    final record = _repository.getRecord(recordKey);
    if (record == null) return;
    final episode = record.episodes[episodeNumber];
    if (episode == null) return;

    final plugin = _findPlugin(pluginName);
    if (plugin == null) {
      _failEpisode(recordKey, episodeNumber, '找不到插件 $pluginName');
      return;
    }

    if (episode.networkM3u8Url.isNotEmpty) {
      episode.status = DownloadStatus.downloading;
      episode.errorMessage = '';
      episode.progressPercent = 0.0;
      episode.downloadedSegments = 0;
      await _repository.updateEpisode(recordKey, episodeNumber, episode);
      _refreshRecord(recordKey);

      await _startBackgroundServiceIfNeeded();

      final httpHeaders = plugin.buildHttpHeaders();
      bool adBlockerEnabled =
          _repository.getForceAdBlocker() || plugin.adBlocker;

      await _downloadManager.enqueue(DownloadRequest(
        recordKey: recordKey,
        bangumiId: bangumiId,
        pluginName: pluginName,
        episodeNumber: episodeNumber,
        m3u8Url: episode.networkM3u8Url,
        httpHeaders: httpHeaders,
        adBlockerEnabled: adBlockerEnabled,
        episode: episode,
      ));
    } else {
      _cancelResolve(recordKey, episodeNumber);
      episode.status = DownloadStatus.resolving;
      episode.errorMessage = '';
      episode.progressPercent = 0.0;
      episode.downloadedSegments = 0;
      await _repository.updateEpisode(recordKey, episodeNumber, episode);
      _refreshRecord(recordKey);

      _resolveQueue.add(_ResolveRequest(
        recordKey: recordKey,
        bangumiId: bangumiId,
        pluginName: pluginName,
        episodeNumber: episodeNumber,
        episodePageUrl: episode.episodePageUrl,
      ));
      _processResolveQueue();
    }
  }

  Future<void> cancelDownload(
      int bangumiId, String pluginName, int episodeNumber) async {
    final recordKey = '${pluginName}_$bangumiId';
    _downloadManager.cancel(recordKey, episodeNumber);
    _cancelResolve(recordKey, episodeNumber);
    await _downloadManager.deleteEpisodeFiles(
        bangumiId, pluginName, episodeNumber);
    await _repository.deleteEpisode(recordKey, episodeNumber);
    _refreshRecord(recordKey);
    _queueBackgroundNotificationUpdate();
  }

  Future<void> deleteRecord(int bangumiId, String pluginName) async {
    final recordKey = '${pluginName}_$bangumiId';
    final record = _repository.getRecord(recordKey);
    if (record != null) {
      for (final ep in record.episodes.keys) {
        _downloadManager.cancel(recordKey, ep);
        _speeds.remove('${recordKey}_$ep');
      }
    }
    _cancelResolveRecord(recordKey);
    await _downloadManager.deleteRecordFiles(bangumiId, pluginName);
    await _repository.deleteRecord(recordKey);
    _refreshRecord(recordKey);
    _queueBackgroundNotificationUpdate();
  }

  Future<void> deleteEpisode(
      int bangumiId, String pluginName, int episodeNumber) async {
    final recordKey = '${pluginName}_$bangumiId';
    _downloadManager.cancel(recordKey, episodeNumber);
    _speeds.remove('${recordKey}_$episodeNumber');
    _cancelResolve(recordKey, episodeNumber);
    await _downloadManager.deleteEpisodeFiles(
        bangumiId, pluginName, episodeNumber);
    await _repository.deleteEpisode(recordKey, episodeNumber);
    _refreshRecord(recordKey);
    _queueBackgroundNotificationUpdate();
  }

  Future<void> priorityDownload({
    required int bangumiId,
    required String pluginName,
    required int episodeNumber,
  }) async {
    final recordKey = '${pluginName}_$bangumiId';
    final record = _repository.getRecord(recordKey);
    if (record == null) return;
    final episode = record.episodes[episodeNumber];
    if (episode == null) return;

    final plugin = _findPlugin(pluginName);
    if (plugin == null) {
      _failEpisode(recordKey, episodeNumber, '找不到插件 $pluginName');
      return;
    }

    _cancelResolve(recordKey, episodeNumber);

    if (episode.networkM3u8Url.isNotEmpty) {
      episode.status = DownloadStatus.downloading;
      episode.errorMessage = '';
      await _repository.updateEpisode(recordKey, episodeNumber, episode);
      _refreshRecord(recordKey);

      await _startBackgroundServiceIfNeeded();

      final httpHeaders = plugin.buildHttpHeaders();
      bool adBlockerEnabled =
          _repository.getForceAdBlocker() || plugin.adBlocker;

      await _downloadManager.enqueuePriority(DownloadRequest(
        recordKey: recordKey,
        bangumiId: bangumiId,
        pluginName: pluginName,
        episodeNumber: episodeNumber,
        m3u8Url: episode.networkM3u8Url,
        httpHeaders: httpHeaders,
        adBlockerEnabled: adBlockerEnabled,
        episode: episode,
      ));
    } else {
      episode.status = DownloadStatus.resolving;
      episode.errorMessage = '';
      await _repository.updateEpisode(recordKey, episodeNumber, episode);
      _refreshRecord(recordKey);

      _resolveQueue.insert(
          0,
          _ResolveRequest(
            recordKey: recordKey,
            bangumiId: bangumiId,
            pluginName: pluginName,
            episodeNumber: episodeNumber,
            episodePageUrl: episode.episodePageUrl,
          ));
      _processResolveQueue();
    }
  }

  Future<void> resumeAllDownloads(int bangumiId, String pluginName) async {
    final recordKey = '${pluginName}_$bangumiId';
    final record = _repository.getRecord(recordKey);
    if (record == null) return;

    final incompleteEpisodes = record.episodes.entries
        .where((e) =>
            e.value.status == DownloadStatus.paused ||
            e.value.status == DownloadStatus.failed ||
            e.value.status == DownloadStatus.pending)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in incompleteEpisodes) {
      await retryDownload(
        bangumiId: bangumiId,
        pluginName: pluginName,
        episodeNumber: entry.key,
      );
    }

    if (incompleteEpisodes.isNotEmpty) {
      KazumiLogger().i(
        'DownloadController: resumed ${incompleteEpisodes.length} downloads for $recordKey',
      );
    }
  }

  int completedCount(DownloadRecord record) {
    return record.episodes.values
        .where((e) => e.status == DownloadStatus.completed)
        .length;
  }
}

class _ResolveRequest {
  final String recordKey;
  final int bangumiId;
  final String pluginName;
  final int episodeNumber;
  final String episodePageUrl;

  _ResolveRequest({
    required this.recordKey,
    required this.bangumiId,
    required this.pluginName,
    required this.episodeNumber,
    required this.episodePageUrl,
  });
}

class _DownloadStats {
  final int activeCount;
  final int pendingCount;
  final int totalCount;
  final double overallProgress;
  final Set<String> activeKeys;

  const _DownloadStats({
    required this.activeCount,
    required this.pendingCount,
    required this.totalCount,
    required this.overallProgress,
    required this.activeKeys,
  });

  bool get hasWork => activeCount > 0 || pendingCount > 0;
}

class _LatestAsyncRunner {
  bool _isRunning = false;
  bool _needsRun = false;

  void schedule(Future<void> Function() task) {
    if (_isRunning) {
      _needsRun = true;
      return;
    }
    unawaited(_run(task));
  }

  Future<void> _run(Future<void> Function() task) async {
    _isRunning = true;
    try {
      do {
        _needsRun = false;
        await task();
      } while (_needsRun);
    } finally {
      _isRunning = false;
    }
  }
}
