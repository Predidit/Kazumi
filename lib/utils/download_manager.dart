import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/utils/m3u8_parser.dart';
import 'package:kazumi/utils/m3u8_ad_filter.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:path_provider/path_provider.dart';

class _NotM3u8Exception implements Exception {
  final String message;
  _NotM3u8Exception(this.message);
  @override
  String toString() => message;
}

class DownloadTask {
  final String recordKey;
  final int episodeNumber;
  CancelToken cancelToken;
  bool isPaused;

  DownloadTask({
    required this.recordKey,
    required this.episodeNumber,
    CancelToken? cancelToken,
    this.isPaused = false,
  }) : cancelToken = cancelToken ?? CancelToken();
}

typedef ProgressCallback = void Function(
    String recordKey, int episodeNumber, DownloadEpisode episode, double speed);

class DownloadRequest {
  final String recordKey;
  final int bangumiId;
  final String pluginName;
  final int episodeNumber;
  final String m3u8Url;
  final Map<String, String> httpHeaders;
  final bool adBlockerEnabled;
  final DownloadEpisode episode;

  const DownloadRequest({
    required this.recordKey,
    required this.bangumiId,
    required this.pluginName,
    required this.episodeNumber,
    required this.m3u8Url,
    required this.httpHeaders,
    required this.adBlockerEnabled,
    required this.episode,
  });
}

abstract class IDownloadManager {
  ProgressCallback? onProgress;

  bool isDownloading(String recordKey, int episodeNumber);
  Future<void> enqueue(DownloadRequest request);
  Future<void> enqueuePriority(DownloadRequest request);
  void pause(String recordKey, int episodeNumber);
  Future<void> resume(DownloadRequest request);
  void cancel(String recordKey, int episodeNumber);
  String? getLocalVideoPath(DownloadEpisode? episode);
  Future<void> deleteEpisodeFiles(int bangumiId, String pluginName, int episodeNumber);
  Future<void> deleteRecordFiles(int bangumiId, String pluginName);
  double getSpeed(String recordKey, int episodeNumber);
}

/// Tracks download speed for a single episode
class _SpeedTracker {
  int _lastBytes = 0;
  DateTime _lastTime = DateTime.now();
  double currentSpeed = 0.0; // bytes/sec

  void update(int totalBytes) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastTime).inMilliseconds;
    if (elapsed > 500) {
      // Update speed every 500ms
      final bytesDownloaded = totalBytes - _lastBytes;
      currentSpeed = bytesDownloaded / (elapsed / 1000);
      _lastBytes = totalBytes;
      _lastTime = now;
    }
  }

  void reset() {
    _lastBytes = 0;
    _lastTime = DateTime.now();
    currentSpeed = 0.0;
  }
}

class DownloadManager implements IDownloadManager {
  DownloadManager() {
    _loadSettings();
  }

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  final Map<String, DownloadTask> _activeTasks = {};
  final List<DownloadRequest> _queue = [];
  final Map<String, _SpeedTracker> _speedTrackers = {};
  int maxParallelEpisodes = 2;
  int maxParallelSegments = 3;
  int _runningCount = 0;

  @override
  ProgressCallback? onProgress;

  void _loadSettings() {
    final setting = GStorage.setting;
    maxParallelEpisodes = setting.get(
      SettingBoxKey.downloadParallelEpisodes,
      defaultValue: 2,
    );
    maxParallelSegments = setting.get(
      SettingBoxKey.downloadParallelSegments,
      defaultValue: 3,
    );
  }

  @override
  double getSpeed(String recordKey, int episodeNumber) {
    final key = _taskKey(recordKey, episodeNumber);
    return _speedTrackers[key]?.currentSpeed ?? 0.0;
  }

  String _taskKey(String recordKey, int episodeNumber) =>
      '${recordKey}_$episodeNumber';

  @override
  bool isDownloading(String recordKey, int episodeNumber) =>
      _activeTasks.containsKey(_taskKey(recordKey, episodeNumber));

  Future<String> get _downloadBaseDir async {
    final appSupport = await getApplicationSupportDirectory();
    return '${appSupport.path}/downloads';
  }

  String getEpisodeDir(String downloadBase, int bangumiId, String pluginName, int episodeNumber) {
    return '$downloadBase/${bangumiId}_$pluginName/$episodeNumber';
  }

  @override
  Future<void> enqueue(DownloadRequest request) async {
    final key = _taskKey(request.recordKey, request.episodeNumber);
    if (_activeTasks.containsKey(key)) return;

    final task = DownloadTask(
      recordKey: request.recordKey,
      episodeNumber: request.episodeNumber,
    );

    if (_runningCount < maxParallelEpisodes) {
      _runningCount++;
      _activeTasks[key] = task;
      _runEpisodeDownload(
        task: task,
        bangumiId: request.bangumiId,
        pluginName: request.pluginName,
        m3u8Url: request.m3u8Url,
        httpHeaders: request.httpHeaders,
        adBlockerEnabled: request.adBlockerEnabled,
        episode: request.episode,
      );
    } else {
      request.episode.status = DownloadStatus.pending;
      _queue.add(request);
      _activeTasks[key] = task;
    }
  }

  @override
  Future<void> enqueuePriority(DownloadRequest request) async {
    final key = _taskKey(request.recordKey, request.episodeNumber);

    // Remove from queue if already waiting
    _queue.removeWhere(
      (r) => r.recordKey == request.recordKey && r.episodeNumber == request.episodeNumber,
    );
    _activeTasks.remove(key);

    final task = DownloadTask(
      recordKey: request.recordKey,
      episodeNumber: request.episodeNumber,
    );

    // Start immediately, bypassing the parallel limit (priority download)
    _runningCount++;
    _activeTasks[key] = task;
    _runEpisodeDownload(
      task: task,
      bangumiId: request.bangumiId,
      pluginName: request.pluginName,
      m3u8Url: request.m3u8Url,
      httpHeaders: request.httpHeaders,
      adBlockerEnabled: request.adBlockerEnabled,
      episode: request.episode,
    );
  }

  @override
  void pause(String recordKey, int episodeNumber) {
    final key = _taskKey(recordKey, episodeNumber);
    final task = _activeTasks[key];
    if (task != null) {
      task.isPaused = true;
      task.cancelToken.cancel('paused');
    }
  }

  @override
  Future<void> resume(DownloadRequest request) async {
    final key = _taskKey(request.recordKey, request.episodeNumber);
    _activeTasks.remove(key);

    final task = DownloadTask(
      recordKey: request.recordKey,
      episodeNumber: request.episodeNumber,
    );
    _activeTasks[key] = task;

    if (_runningCount < maxParallelEpisodes) {
      _runningCount++;
      _runEpisodeDownload(
        task: task,
        bangumiId: request.bangumiId,
        pluginName: request.pluginName,
        m3u8Url: request.m3u8Url,
        httpHeaders: request.httpHeaders,
        adBlockerEnabled: request.adBlockerEnabled,
        episode: request.episode,
      );
    } else {
      _queue.add(request);
    }
  }

  @override
  void cancel(String recordKey, int episodeNumber) {
    final key = _taskKey(recordKey, episodeNumber);
    final task = _activeTasks[key];
    if (task != null) {
      task.cancelToken.cancel('cancelled');
      _activeTasks.remove(key);
      _queue.removeWhere(
        (r) => r.recordKey == recordKey && r.episodeNumber == episodeNumber,
      );
    }
  }

  void _processQueue() {
    while (_runningCount < maxParallelEpisodes && _queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      final key = _taskKey(request.recordKey, request.episodeNumber);
      final existingTask = _activeTasks[key];
      if (existingTask == null || existingTask.isPaused || existingTask.cancelToken.isCancelled) {
        _activeTasks.remove(key);
        continue;
      }

      _runningCount++;
      _runEpisodeDownload(
        task: existingTask,
        bangumiId: request.bangumiId,
        pluginName: request.pluginName,
        m3u8Url: request.m3u8Url,
        httpHeaders: request.httpHeaders,
        adBlockerEnabled: request.adBlockerEnabled,
        episode: request.episode,
      );
    }
  }

  Future<void> _runEpisodeDownload({
    required DownloadTask task,
    required int bangumiId,
    required String pluginName,
    required String m3u8Url,
    required Map<String, String> httpHeaders,
    required bool adBlockerEnabled,
    required DownloadEpisode episode,
  }) async {
    final key = _taskKey(task.recordKey, task.episodeNumber);
    try {
      // Step 1: Fetch M3U8 content
      episode.status = DownloadStatus.downloading;
      episode.networkM3u8Url = m3u8Url;
      _notifyProgress(task.recordKey, task.episodeNumber, episode);

      String m3u8Content;
      try {
        m3u8Content = await _fetchM3u8(m3u8Url, httpHeaders, task.cancelToken);
      } on _NotM3u8Exception {
        // URL is not an M3U8 playlist, fall back to direct file download
        KazumiLogger().i(
          'DownloadManager: URL is not M3U8, falling back to direct file download '
          'for episode ${task.episodeNumber}',
        );
        await _runDirectFileDownload(
          task: task,
          bangumiId: bangumiId,
          pluginName: pluginName,
          videoUrl: m3u8Url,
          httpHeaders: httpHeaders,
          episode: episode,
        );
        return;
      }

      // Step 2: Parse M3U8
      final type = M3u8Parser.detectType(m3u8Content);
      String mediaM3u8Content = m3u8Content;
      String mediaM3u8Url = m3u8Url;

      if (type == M3u8Type.master) {
        final master = M3u8Parser.parseMasterPlaylist(m3u8Content, m3u8Url);
        final bestVariant = master.bestVariant;
        mediaM3u8Url = bestVariant.uri;
        mediaM3u8Content = await _fetchM3u8(mediaM3u8Url, httpHeaders, task.cancelToken);
      }

      final playlist = M3u8Parser.parseMediaPlaylist(mediaM3u8Content, mediaM3u8Url);

      // 展开嵌套 m3u8 片段（部分源将实际内容嵌套在 m3u8 引用中）
      final resolvedSegments = await M3u8Parser.resolveNestedSegments(
        playlist.segments,
        (url) => _fetchM3u8(url, httpHeaders, task.cancelToken),
      );
      final resolvedPlaylist = M3u8MediaPlaylist(
        segments: resolvedSegments,
        targetDuration: playlist.targetDuration,
        isVod: playlist.isVod,
      );

      if (!resolvedPlaylist.isVod) {
        episode.status = DownloadStatus.failed;
        episode.errorMessage = '不支持下载直播流 (无有效分片)';
        _notifyProgress(task.recordKey, task.episodeNumber, episode);
        _onTaskComplete(key);
        return;
      }

      if (resolvedPlaylist.segments.isEmpty) {
        episode.status = DownloadStatus.failed;
        episode.errorMessage = 'M3U8 中未找到可下载的分片';
        _notifyProgress(task.recordKey, task.episodeNumber, episode);
        _onTaskComplete(key);
        return;
      }

      // Step 3: Ad filtering
      List<M3u8Segment> segments = resolvedPlaylist.segments;
      if (adBlockerEnabled) {
        segments = M3u8AdFilter.filterAds(segments);
      }

      // Step 4: Create download directory
      final base = await _downloadBaseDir;
      final episodeDir = getEpisodeDir(base, bangumiId, pluginName, task.episodeNumber);
      await Directory(episodeDir).create(recursive: true);
      episode.downloadDirectory = episodeDir;

      // Step 5: Download encryption keys
      final keys = M3u8Parser.extractUniqueKeys(
        M3u8MediaPlaylist(
          segments: segments,
          targetDuration: resolvedPlaylist.targetDuration,
          isVod: true,
        ),
      );
      final keyUriToLocal = <String, String>{};
      for (int i = 0; i < keys.length; i++) {
        final keyFile = 'key_$i.key';
        final keyPath = '$episodeDir/$keyFile';
        await _downloadFile(keys[i].uri, keyPath, httpHeaders, task.cancelToken);
        keyUriToLocal[keys[i].uri] = keyFile;
      }

      // Step 6: Download TS segments
      episode.totalSegments = segments.length;
      episode.downloadedSegments = 0;
      _notifyProgress(task.recordKey, task.episodeNumber, episode);

      // Clean up .tmp files from previous incomplete downloads
      final episodeDirObj = Directory(episodeDir);
      if (await episodeDirObj.exists()) {
        await for (final entity in episodeDirObj.list()) {
          if (entity.path.endsWith('.tmp')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }

      // Check which segments already exist (for resume)
      final existingSegments = <int>{};
      for (int i = 0; i < segments.length; i++) {
        final segFile = File('$episodeDir/seg_${i.toString().padLeft(5, '0')}.ts');
        if (await segFile.exists() && await segFile.length() > 0) {
          existingSegments.add(i);
          episode.downloadedSegments++;
        }
      }

      // Download remaining segments with concurrency control
      final pendingIndices = <int>[];
      for (int i = 0; i < segments.length; i++) {
        if (!existingSegments.contains(i)) {
          pendingIndices.add(i);
        }
      }

      int totalBytes = 0;
      final completer = Completer<void>();
      int completedCount = 0;
      int failedCount = 0;
      final semaphore = _Semaphore(maxParallelSegments);

      // Initialize speed tracker for this episode
      _speedTrackers[key] = _SpeedTracker();

      if (pendingIndices.isEmpty) {
        // All segments already downloaded
      } else {
        for (final idx in pendingIndices) {
          if (task.isPaused || task.cancelToken.isCancelled) break;

          await semaphore.acquire();
          if (task.isPaused || task.cancelToken.isCancelled) {
            semaphore.release();
            break;
          }

          _downloadSegmentWithRetry(
            segments[idx].uri,
            '$episodeDir/seg_${idx.toString().padLeft(5, '0')}.ts',
            httpHeaders,
            task.cancelToken,
          ).then((bytes) {
            totalBytes += bytes;
            episode.downloadedSegments++;
            episode.totalBytes = totalBytes;
            episode.progressPercent =
                episode.downloadedSegments / episode.totalSegments;
            // Update speed tracker
            _speedTrackers[key]?.update(totalBytes);
            _notifyProgress(task.recordKey, task.episodeNumber, episode);
            completedCount++;
            semaphore.release();
            if (completedCount + failedCount == pendingIndices.length) {
              completer.complete();
            }
          }).catchError((e) {
            failedCount++;
            semaphore.release();
            if (completedCount + failedCount == pendingIndices.length) {
              completer.complete();
            }
          });
        }

        if (!task.isPaused && !task.cancelToken.isCancelled && pendingIndices.isNotEmpty) {
          await completer.future;
        }
      }

      if (task.isPaused || task.cancelToken.isCancelled) {
        if (task.isPaused) {
          episode.status = DownloadStatus.paused;
        }
        _notifyProgress(task.recordKey, task.episodeNumber, episode);
        _onTaskComplete(key);
        return;
      }

      if (failedCount > 0) {
        episode.status = DownloadStatus.failed;
        episode.errorMessage = '$failedCount 个分片下载失败';
        _notifyProgress(task.recordKey, task.episodeNumber, episode);
        _onTaskComplete(key);
        return;
      }

      // Step 7: Write local M3U8
      final targetDuration = adBlockerEnabled
          ? M3u8AdFilter.calculateTargetDuration(segments)
          : resolvedPlaylist.targetDuration;
      final localM3u8 = M3u8Parser.buildLocalM3u8(
        segments,
        targetDuration: targetDuration,
        keyUriToLocal: keyUriToLocal,
      );
      final m3u8Path = '$episodeDir/playlist.m3u8';
      await File(m3u8Path).writeAsString(localM3u8);

      // Step 8: Mark completed
      episode.status = DownloadStatus.completed;
      episode.localM3u8Path = m3u8Path;
      episode.progressPercent = 1.0;
      episode.completedAt = DateTime.now();
      _notifyProgress(task.recordKey, task.episodeNumber, episode);

      KazumiLogger().i(
        'DownloadManager: episode ${task.episodeNumber} completed. '
        '${segments.length} segments, ${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        if (task.isPaused) {
          episode.status = DownloadStatus.paused;
        }
      } else {
        episode.status = DownloadStatus.failed;
        episode.errorMessage = e.message ?? '网络错误';
      }
      _notifyProgress(task.recordKey, task.episodeNumber, episode);
    } catch (e) {
      episode.status = DownloadStatus.failed;
      episode.errorMessage = e.toString();
      _notifyProgress(task.recordKey, task.episodeNumber, episode);
      KazumiLogger().e('DownloadManager: episode download failed', error: e);
    } finally {
      _onTaskComplete(key);
    }
  }

  /// Download a direct video file (non-M3U8) with resume support
  Future<void> _runDirectFileDownload({
    required DownloadTask task,
    required int bangumiId,
    required String pluginName,
    required String videoUrl,
    required Map<String, String> httpHeaders,
    required DownloadEpisode episode,
  }) async {
    final key = _taskKey(task.recordKey, task.episodeNumber);
    try {
      final base = await _downloadBaseDir;
      final episodeDir = getEpisodeDir(base, bangumiId, pluginName, task.episodeNumber);
      await Directory(episodeDir).create(recursive: true);
      episode.downloadDirectory = episodeDir;

      final filePath = '$episodeDir/video.mp4';
      final tmpPath = '$filePath.tmp';

      // Check for existing partial download (for resume)
      // For direct downloads, .tmp files contain valid partial data and can be resumed
      int existingBytes = 0;
      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        existingBytes = await tmpFile.length();
      }

      episode.totalSegments = 1;
      episode.downloadedSegments = 0;
      _notifyProgress(task.recordKey, task.episodeNumber, episode);

      // Use stream response for resume support
      final requestHeaders = Map<String, String>.from(httpHeaders);
      bool useRange = existingBytes > 0;
      if (useRange) {
        requestHeaders['Range'] = 'bytes=$existingBytes-';
      }

      Response<ResponseBody> response;
      try {
        response = await _dio.get<ResponseBody>(
          videoUrl,
          options: Options(
            headers: requestHeaders,
            responseType: ResponseType.stream,
            receiveTimeout: const Duration(minutes: 30),
          ),
          cancelToken: task.cancelToken,
        );
      } on DioException catch (e) {
        // Handle 416 Range Not Satisfiable - delete local file and retry without Range
        if (e.response?.statusCode == 416 && useRange) {
          KazumiLogger().w(
            'DownloadManager: 416 Range Not Satisfiable, deleting tmp file and retrying',
          );
          await tmpFile.delete();
          existingBytes = 0;
          requestHeaders.remove('Range');
          response = await _dio.get<ResponseBody>(
            videoUrl,
            options: Options(
              headers: requestHeaders,
              responseType: ResponseType.stream,
              receiveTimeout: const Duration(minutes: 30),
            ),
            cancelToken: task.cancelToken,
          );
        } else {
          rethrow;
        }
      }

      // Parse total size from Content-Range or Content-Length
      final contentRange = response.headers.value('content-range');
      final contentLength = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '') ?? 0;
      int totalSize;
      if (contentRange != null) {
        // Format: "bytes start-end/total"
        final totalMatch = RegExp(r'/(\d+)').firstMatch(contentRange);
        totalSize = totalMatch != null ? int.parse(totalMatch.group(1)!) : 0;
      } else {
        totalSize = existingBytes + contentLength;
      }

      final raf = await tmpFile.open(
          mode: existingBytes > 0 ? FileMode.append : FileMode.write);
      int received = existingBytes;

      // Initialize speed tracker for direct file download
      _speedTrackers[key] = _SpeedTracker();

      try {
        await for (final chunk in response.data!.stream) {
          if (task.isPaused || task.cancelToken.isCancelled) break;
          await raf.writeFrom(chunk);
          received += chunk.length;
          episode.totalBytes = received;
          episode.progressPercent = totalSize > 0 ? received / totalSize : 0;
          // Update speed tracker
          _speedTrackers[key]?.update(received);
          _notifyProgress(task.recordKey, task.episodeNumber, episode);
        }
      } finally {
        await raf.close();
      }

      if (task.isPaused || task.cancelToken.isCancelled) {
        if (task.isPaused) {
          episode.status = DownloadStatus.paused;
        }
        _notifyProgress(task.recordKey, task.episodeNumber, episode);
        _onTaskComplete(key);
        return;
      }

      // Rename .tmp to final path
      await File(tmpPath).rename(filePath);

      // Mark completed
      episode.status = DownloadStatus.completed;
      episode.localM3u8Path = filePath;
      episode.downloadedSegments = 1;
      episode.progressPercent = 1.0;
      episode.completedAt = DateTime.now();
      episode.totalBytes = await File(filePath).length();
      _notifyProgress(task.recordKey, task.episodeNumber, episode);

      KazumiLogger().i(
        'DownloadManager: episode ${task.episodeNumber} completed (direct download). '
        '${(episode.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        if (task.isPaused) {
          episode.status = DownloadStatus.paused;
        }
      } else {
        episode.status = DownloadStatus.failed;
        episode.errorMessage = e.message ?? '网络错误';
      }
      _notifyProgress(task.recordKey, task.episodeNumber, episode);
    } catch (e) {
      episode.status = DownloadStatus.failed;
      episode.errorMessage = e.toString();
      _notifyProgress(task.recordKey, task.episodeNumber, episode);
      KazumiLogger().e('DownloadManager: direct file download failed', error: e);
    } finally {
      _onTaskComplete(key);
    }
  }

  void _onTaskComplete(String key) {
    _activeTasks.remove(key);
    _speedTrackers.remove(key);
    _runningCount--;
    _processQueue();
  }

  void _notifyProgress(
      String recordKey, int episodeNumber, DownloadEpisode episode) {
    final key = _taskKey(recordKey, episodeNumber);
    final speed = _speedTrackers[key]?.currentSpeed ?? 0.0;
    onProgress?.call(recordKey, episodeNumber, episode, speed);
  }

  Future<String> _fetchM3u8(
      String url, Map<String, String> headers, CancelToken cancelToken) async {
    // Use a separate CancelToken to abort large non-M3U8 responses
    // without cancelling the entire download task
    final fetchToken = CancelToken();

    // Forward cancellation from the task's main token
    if (cancelToken.isCancelled) {
      throw DioException(
        type: DioExceptionType.cancel,
        requestOptions: RequestOptions(path: url),
      );
    }

    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 15),
        ),
        cancelToken: fetchToken,
        onReceiveProgress: (received, total) {
          // Check if parent task was cancelled
          if (cancelToken.isCancelled) {
            fetchToken.cancel('task cancelled');
            return;
          }
          // Abort if response is too large (> 2MB, definitely not M3U8)
          if (received > 2 * 1024 * 1024) {
            fetchToken.cancel('too large');
          }
        },
      );

      final content = response.data!;

      // Validate M3U8 content
      final trimmed = content.trimLeft();
      if (!trimmed.startsWith('#EXTM3U')) {
        throw _NotM3u8Exception('URL 不是 M3U8 播放列表');
      }

      return content;
    } on DioException catch (e) {
      // Re-throw if the main task was cancelled/paused
      if (cancelToken.isCancelled) rethrow;
      // fetchToken cancelled due to too-large response
      if (e.type == DioExceptionType.cancel) {
        throw _NotM3u8Exception('响应过大，非 M3U8 播放列表');
      }
      rethrow;
    }
  }

  Future<void> _downloadFile(String url, String savePath,
      Map<String, String> headers, CancelToken cancelToken) async {
    await _dio.download(
      url,
      savePath,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }

  Future<int> _downloadSegmentWithRetry(
    String url,
    String savePath,
    Map<String, String> headers,
    CancelToken cancelToken, {
    int maxRetries = 3,
  }) async {
    final tmpPath = '$savePath.tmp';
    int retryCount = 0;
    while (true) {
      try {
        await _dio.download(
          url,
          tmpPath,
          options: Options(headers: headers),
          cancelToken: cancelToken,
        );
        await File(tmpPath).rename(savePath);
        return await File(savePath).length();
      } catch (e) {
        // Clean up incomplete .tmp file on failure
        try {
          final tmpFile = File(tmpPath);
          if (await tmpFile.exists()) await tmpFile.delete();
        } catch (_) {}
        if (cancelToken.isCancelled) rethrow;
        retryCount++;
        if (retryCount >= maxRetries) rethrow;
        final delay = Duration(seconds: [1, 3, 9][retryCount - 1]);
        await Future.delayed(delay);
      }
    }
  }

  @override
  Future<void> deleteEpisodeFiles(
      int bangumiId, String pluginName, int episodeNumber) async {
    final base = await _downloadBaseDir;
    final dir = Directory(getEpisodeDir(base, bangumiId, pluginName, episodeNumber));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<void> deleteRecordFiles(int bangumiId, String pluginName) async {
    final base = await _downloadBaseDir;
    final dir = Directory('$base/${bangumiId}_$pluginName');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  String? getLocalVideoPath(DownloadEpisode? episode) {
    if (episode == null) return null;
    if (episode.status != DownloadStatus.completed) return null;
    if (episode.localM3u8Path.isEmpty) return null;
    final file = File(episode.localM3u8Path);
    if (!file.existsSync()) return null;
    return episode.localM3u8Path;
  }
}

class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _waitQueue = <Completer<void>>[];

  _Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeAt(0);
      completer.complete();
    } else {
      _currentCount--;
    }
  }
}
