import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/utils/download_manager.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/providers/providers.dart';
import 'package:mobx/mobx.dart';

part 'download_controller.g.dart';

class DownloadController = _DownloadController with _$DownloadController;

abstract class _DownloadController with Store {
  final _repository = Modular.get<IDownloadRepository>();
  final _downloadManager = Modular.get<IDownloadManager>();

  @observable
  ObservableList<DownloadRecord> records = ObservableList<DownloadRecord>();

  /// Queue for episodes waiting to be resolved via WebView (one at a time)
  final List<_ResolveRequest> _resolveQueue = [];
  bool _isResolving = false;

  void init() {
    final temp = _repository.getAllRecords();
    records.clear();
    records.addAll(temp);

    // Reset any 'downloading' or 'resolving' states to 'paused' on startup
    for (final record in records) {
      bool changed = false;
      for (final entry in record.episodes.entries) {
        if (entry.value.status == DownloadStatus.downloading ||
            entry.value.status == DownloadStatus.resolving) {
          entry.value.status = DownloadStatus.paused;
          changed = true;
        }
      }
      if (changed) {
        _repository.putRecord(record);
      }
    }

    _downloadManager.onProgress = _onDownloadProgress;
  }

  void _onDownloadProgress(
      String recordKey, int episodeNumber, DownloadEpisode episode) {
    _repository.updateEpisode(recordKey, episodeNumber, episode);
    refreshRecords();
  }

  @action
  void refreshRecords() {
    final temp = _repository.getAllRecords();
    records.clear();
    records.addAll(temp);
  }

  Plugin? _findPlugin(String pluginName) {
    final pluginsController = Modular.get<PluginsController>();
    for (final plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) return plugin;
    }
    return null;
  }

  DownloadRecord? getRecord(int bangumiId, String pluginName) {
    final key = '${pluginName}_$bangumiId';
    return _repository.getRecord(key);
  }

  DownloadEpisode? getEpisode(
      int bangumiId, String pluginName, int episodeNumber) {
    final record = getRecord(bangumiId, pluginName);
    return record?.episodes[episodeNumber];
  }

  String? getLocalVideoPath(
      int bangumiId, String pluginName, int episodeNumber) {
    final episode = getEpisode(bangumiId, pluginName, episodeNumber);
    return _downloadManager.getLocalVideoPath(episode);
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
      '', // networkM3u8Url - will be filled after WebView resolves
      null,
      '',
      0,
      episodePageUrl,
    );

    record.episodes[episodeNumber] = episode;
    await _repository.putRecord(record);
    refreshRecords();

    // Queue for WebView resolution
    _resolveQueue.add(_ResolveRequest(
      recordKey: recordKey,
      bangumiId: bangumiId,
      pluginName: pluginName,
      episodeNumber: episodeNumber,
      episodePageUrl: episodePageUrl,
    ));
    _processResolveQueue();
  }

  /// Process the resolve queue one at a time (sequential WebView resolution)
  Future<void> _processResolveQueue() async {
    if (_isResolving || _resolveQueue.isEmpty) return;
    _isResolving = true;

    while (_resolveQueue.isNotEmpty) {
      final request = _resolveQueue.removeAt(0);
      await _resolveAndEnqueue(request);
    }

    _isResolving = false;
  }

  /// Resolve a single episode's M3U8 URL via headless WebView, then enqueue download
  Future<void> _resolveAndEnqueue(_ResolveRequest request) async {
    final plugin = _findPlugin(request.pluginName);
    if (plugin == null) {
      _failEpisode(request.recordKey, request.episodeNumber, '找不到插件 ${request.pluginName}');
      return;
    }

    final record = _repository.getRecord(request.recordKey);
    if (record == null) return;
    final episode = record.episodes[request.episodeNumber];
    if (episode == null) return;

    // Skip if already cancelled/deleted
    if (episode.status != DownloadStatus.resolving) return;

    final fullUrl = plugin.buildFullUrl(request.episodePageUrl);

    KazumiLogger().i(
        'DownloadController: resolving video URL for episode ${request.episodeNumber} from $fullUrl');

    String? m3u8Url;
    final provider = WebViewVideoSourceProvider();
    try {
      final source = await provider.resolve(
        fullUrl,
        useNativePlayer: plugin.useNativePlayer,
        useLegacyParser: plugin.useLegacyParser,
        timeout: const Duration(seconds: 30),
      );
      m3u8Url = source.url;
    } on VideoSourceTimeoutException {
      KazumiLogger().w('DownloadController: WebView resolution timed out');
    } on VideoSourceCancelledException {
      KazumiLogger().i('DownloadController: WebView resolution cancelled');
    } catch (e) {
      KazumiLogger().e('DownloadController: WebView resolution failed', error: e);
    } finally {
      provider.dispose();
    }

    if (m3u8Url == null || m3u8Url.isEmpty) {
      _failEpisode(request.recordKey, request.episodeNumber, '解析视频源超时');
      return;
    }

    KazumiLogger().i(
        'DownloadController: resolved M3U8 URL for episode ${request.episodeNumber}: $m3u8Url');

    // Update episode with resolved URL
    final freshRecord = _repository.getRecord(request.recordKey);
    if (freshRecord == null) return;
    final freshEpisode = freshRecord.episodes[request.episodeNumber];
    if (freshEpisode == null) return;

    // Check if user cancelled during resolution
    if (freshEpisode.status != DownloadStatus.resolving) return;

    freshEpisode.networkM3u8Url = m3u8Url;
    freshEpisode.status = DownloadStatus.downloading;
    await _repository.updateEpisode(
        request.recordKey, request.episodeNumber, freshEpisode);
    refreshRecords();

    // Now enqueue the actual download
    final httpHeaders = plugin.buildHttpHeaders();
    bool adBlockerEnabled = _repository.getForceAdBlocker() || plugin.adBlocker;

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
  }

  void _failEpisode(String recordKey, int episodeNumber, String message) {
    final record = _repository.getRecord(recordKey);
    if (record == null) return;
    final episode = record.episodes[episodeNumber];
    if (episode == null) return;
    episode.status = DownloadStatus.failed;
    episode.errorMessage = message;
    _repository.updateEpisode(recordKey, episodeNumber, episode);
    refreshRecords();
    KazumiLogger().w('DownloadController: episode $episodeNumber failed: $message');
  }

  Future<void> pauseDownload(
      int bangumiId, String pluginName, int episodeNumber) async {
    final recordKey = '${pluginName}_$bangumiId';
    _downloadManager.pause(recordKey, episodeNumber);

    // Also remove from resolve queue if still pending
    _resolveQueue.removeWhere((r) =>
        r.recordKey == recordKey && r.episodeNumber == episodeNumber);

    final record = _repository.getRecord(recordKey);
    if (record != null) {
      final episode = record.episodes[episodeNumber];
      if (episode != null) {
        episode.status = DownloadStatus.paused;
        await _repository.updateEpisode(recordKey, episodeNumber, episode);
        refreshRecords();
      }
    }
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

    // If we already have a resolved M3U8 URL, go directly to download
    if (episode.networkM3u8Url.isNotEmpty) {
      episode.status = DownloadStatus.downloading;
      episode.errorMessage = '';
      episode.progressPercent = 0.0;
      episode.downloadedSegments = 0;
      await _repository.updateEpisode(recordKey, episodeNumber, episode);
      refreshRecords();

      final httpHeaders = plugin.buildHttpHeaders();
      bool adBlockerEnabled = _repository.getForceAdBlocker() || plugin.adBlocker;

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
      // Need to re-resolve via WebView
      episode.status = DownloadStatus.resolving;
      episode.errorMessage = '';
      episode.progressPercent = 0.0;
      episode.downloadedSegments = 0;
      await _repository.updateEpisode(recordKey, episodeNumber, episode);
      refreshRecords();

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
    _resolveQueue.removeWhere((r) =>
        r.recordKey == recordKey && r.episodeNumber == episodeNumber);
    await _downloadManager.deleteEpisodeFiles(
        bangumiId, pluginName, episodeNumber);
    await _repository.deleteEpisode(recordKey, episodeNumber);
    refreshRecords();
  }

  Future<void> deleteRecord(int bangumiId, String pluginName) async {
    final recordKey = '${pluginName}_$bangumiId';
    final record = _repository.getRecord(recordKey);
    if (record != null) {
      for (final ep in record.episodes.keys) {
        _downloadManager.cancel(recordKey, ep);
      }
    }
    _resolveQueue.removeWhere((r) => r.recordKey == recordKey);
    await _downloadManager.deleteRecordFiles(bangumiId, pluginName);
    await _repository.deleteRecord(recordKey);
    refreshRecords();
  }

  Future<void> deleteEpisode(
      int bangumiId, String pluginName, int episodeNumber) async {
    final recordKey = '${pluginName}_$bangumiId';
    _downloadManager.cancel(recordKey, episodeNumber);
    _resolveQueue.removeWhere((r) =>
        r.recordKey == recordKey && r.episodeNumber == episodeNumber);
    await _downloadManager.deleteEpisodeFiles(
        bangumiId, pluginName, episodeNumber);
    await _repository.deleteEpisode(recordKey, episodeNumber);
    refreshRecords();
  }

  int completedCount(DownloadRecord record) {
    return record.episodes.values
        .where((e) => e.status == DownloadStatus.completed)
        .length;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
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
