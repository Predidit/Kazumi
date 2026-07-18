import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/history_storage_coordinator.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/services/sync/history_sync_path_policy.dart';

class HistorySyncService {
  static const int checkpointLogThresholdBytes = 1024 * 1024;
  static const String _pendingLogPrefix = 'history.local.pending.';

  HistorySyncService._internal()
      : _applicationSupportDirectoryProvider = getApplicationSupportDirectory;

  static final HistorySyncService _instance = HistorySyncService._internal();

  factory HistorySyncService() => _instance;

  @visibleForTesting
  HistorySyncService.forTesting(Directory applicationSupportDirectory)
      : _applicationSupportDirectoryProvider =
            (() async => applicationSupportDirectory);

  final Future<Directory> Function() _applicationSupportDirectoryProvider;
  final AsyncSerialQueue _localLogQueue = AsyncSerialQueue();
  final AsyncSerialQueue _sequenceQueue = AsyncSerialQueue();
  int _captureSequence = 0;

  Future<String> getDeviceId() async {
    return _sequenceQueue.run(() async {
      final existing = GStorage.getSetting(SettingsKeys.historySyncDeviceId);
      if (isValidHistorySyncDeviceId(existing)) {
        return existing;
      }
      final deviceId = HistorySyncDevice.generateDeviceId();
      await GStorage.putSetting(SettingsKeys.historySyncDeviceId, deviceId);
      return deviceId;
    });
  }

  Future<void> appendUpsertProgress({
    required History history,
    required int episode,
    required int road,
    required int progressMs,
    int? updatedAt,
  }) async {
    final deviceId = await getDeviceId();
    final effectiveUpdatedAt =
        updatedAt ?? history.lastWatchTime.millisecondsSinceEpoch;
    final progressSeq = await _nextSeq();
    final watchStateSeq = await _nextSeq();
    final events = [
      HistorySyncEvent.upsertProgress(
        deviceId: deviceId,
        seq: progressSeq,
        history: history,
        episode: episode,
        road: road,
        progressMs: progressMs,
        updatedAt: effectiveUpdatedAt,
      ),
      HistorySyncEvent.upsertWatchState(
        deviceId: deviceId,
        seq: watchStateSeq,
        history: history,
        episode: episode,
        updatedAt: effectiveUpdatedAt,
      ),
    ];
    await appendEvents(events);
  }

  Future<void> appendEvent(HistorySyncEvent event) async {
    await appendEvents([event]);
  }

  Future<void> appendEvents(Iterable<HistorySyncEvent> events) async {
    final content = HistorySyncCodec.eventsToJsonLines(events);
    if (content.isEmpty) {
      return;
    }
    await _localLogQueue.run(() async {
      final file = await localChangeLogFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        content,
        mode: FileMode.append,
        flush: true,
      );
    });
  }

  Future<void> appendDeleteHistory(History history) async {
    final event = HistorySyncEvent.deleteHistory(
      deviceId: await getDeviceId(),
      seq: await _nextSeq(),
      entityKey: history.key,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await appendEvent(event);
  }

  Future<void> appendClearAll() async {
    final event = HistorySyncEvent.clearAll(
      deviceId: await getDeviceId(),
      seq: await _nextSeq(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await appendEvent(event);
  }

  Future<HistorySyncSnapshot> buildSnapshotFromLocal() {
    return HistoryStorageCoordinator().run(() async {
      return HistorySyncSnapshot.fromHistories(
        GStorage.histories.values.toList(),
      );
    });
  }

  Future<List<HistorySyncEvent>> buildLocalStateEvents() {
    return HistoryStorageCoordinator().run(() async {
      return buildStateEventsFromHistories(GStorage.histories.values);
    });
  }

  static List<HistorySyncEvent> buildStateEventsFromHistories(
    Iterable<History> histories,
  ) {
    final events = <HistorySyncEvent>[];
    for (final history in histories) {
      history.entryKind = HistoryEntryKind.normalize(history.entryKind);
      for (final progress in history.progresses.values) {
        final updatedAt = progress.effectiveUpdatedAtMs(history.lastWatchTime);
        events.add(
          HistorySyncEvent(
            eventId:
                'local-state:${history.key}:${progress.episode}:${progress.road}',
            deviceId: 'local-state',
            seq: 0,
            op: HistorySyncOp.upsertProgress,
            updatedAt: updatedAt,
            entityKey: history.key,
            bangumiItem: history.bangumiItem,
            adapterName: history.adapterName,
            episode: progress.episode,
            road: progress.road,
            progressMs: progress.progress.inMilliseconds,
            lastSrc: history.lastSrc,
            lastWatchEpisodeName: history.lastWatchEpisodeName,
            entryKind: history.entryKind,
            episodePageUrl: history.episodePageUrl,
          ),
        );
      }
      events.add(
        HistorySyncEvent(
          eventId: 'local-state:${history.key}:watch-state',
          deviceId: 'local-state',
          seq: 0,
          op: HistorySyncOp.upsertWatchState,
          updatedAt: history.lastWatchTime.millisecondsSinceEpoch,
          entityKey: history.key,
          bangumiItem: history.bangumiItem,
          adapterName: history.adapterName,
          episode: history.lastWatchEpisode,
          lastSrc: history.lastSrc,
          lastWatchEpisodeName: history.lastWatchEpisodeName,
          entryKind: history.entryKind,
          episodePageUrl: history.episodePageUrl,
          carriesWatchState: true,
        ),
      );
    }
    return events;
  }

  Future<HistorySyncSnapshot> reconcileAndApplySnapshot(
    HistorySyncSnapshot snapshot,
  ) {
    return HistoryStorageCoordinator().run(() async {
      final reconciled = HistorySyncMerger.merge(
        snapshot: snapshot,
        events: buildStateEventsFromHistories(GStorage.histories.values),
      );
      await _applySnapshotToLocal(reconciled);
      return reconciled;
    });
  }

  Future<void> _applySnapshotToLocal(HistorySyncSnapshot snapshot) async {
    final historiesByKey = {
      for (final history in snapshot.histories) history.key: history,
    };
    final staleKeys = GStorage.histories.keys
        .where((key) => !historiesByKey.containsKey(key))
        .toList();

    if (historiesByKey.isNotEmpty) {
      await GStorage.histories.putAll(historiesByKey);
    }
    if (staleKeys.isNotEmpty) {
      await GStorage.histories.deleteAll(staleKeys);
    }
    await GStorage.histories.flush();
  }

  /// Creates a stable set of local logs for one sync attempt.
  ///
  /// A checkpoint attempt renames the active log to a pending file, allowing
  /// playback to continue appending to a fresh log. Pending files survive
  /// failed or interrupted syncs and are picked up by the next attempt.
  Future<HistorySyncLogBatch> prepareLocalLogs({
    required Directory runDirectory,
    required bool forceCheckpoint,
  }) {
    return _localLogQueue.run(() async {
      final activeFile = await localChangeLogFile();
      await activeFile.parent.create(recursive: true);
      await runDirectory.create(recursive: true);

      final pendingFiles = await _pendingLocalLogFiles(activeFile.parent);
      final activeLength =
          await activeFile.exists() ? await activeFile.length() : 0;
      final pendingLength = await _totalFileLength(pendingFiles);
      final shouldCheckpoint = forceCheckpoint ||
          pendingFiles.isNotEmpty ||
          activeLength + pendingLength > checkpointLogThresholdBytes;

      if (shouldCheckpoint) {
        if (activeLength > 0) {
          final separator = Platform.pathSeparator;
          final pendingFile = File(
            '${activeFile.parent.path}$separator'
            '$_pendingLogPrefix'
            '${DateTime.now().microsecondsSinceEpoch}.'
            '${_captureSequence++}.jsonl',
          );
          await activeFile.rename(pendingFile.path);
          pendingFiles.add(pendingFile);
        }
        pendingFiles.sort((a, b) => a.path.compareTo(b.path));
        return HistorySyncLogBatch(
          files: pendingFiles,
          shouldCheckpoint: true,
        );
      }

      if (activeLength == 0) {
        return HistorySyncLogBatch(
          files: [],
          shouldCheckpoint: false,
        );
      }

      final stableCopy = File(
        '${runDirectory.path}${Platform.pathSeparator}local-events.jsonl',
      );
      await activeFile.copy(stableCopy.path);
      return HistorySyncLogBatch(
        files: [stableCopy],
        shouldCheckpoint: false,
      );
    });
  }

  /// Copies the active log for upload, dropping lines other devices could
  /// not merge. When malformed lines are found the active log itself is
  /// rewritten from the sanitized copy so the damage does not resurface on
  /// every following sync. Returns null when nothing valid is left to upload.
  Future<File?> copyActiveLogForUpload(Directory runDirectory) {
    return _localLogQueue.run(() async {
      final activeFile = await localChangeLogFile();
      if (!await activeFile.exists() || await activeFile.length() == 0) {
        return null;
      }
      final uploadFile = File(
        '${runDirectory.path}${Platform.pathSeparator}'
        'local-events-upload.jsonl',
      );
      final result = await _sanitizeEventLogCopy(
        sourcePath: activeFile.path,
        targetPath: uploadFile.path,
      );
      final malformedLines = result['malformedLines']!;
      if (malformedLines > 0) {
        KazumiLogger().w(
          'HistorySync: dropped $malformedLines malformed line(s) '
          'from local event log upload',
        );
        await _repairActiveLog(activeFile, uploadFile);
      }
      if (result['validLines'] == 0) {
        return null;
      }
      return uploadFile;
    });
  }

  /// Replaces the active log with its sanitized copy. Must be called while
  /// holding [_localLogQueue] so no append interleaves. Best-effort: on
  /// failure the damaged log stays and the next sync retries.
  Future<void> _repairActiveLog(File activeFile, File sanitizedFile) async {
    try {
      final tempFile = File('${activeFile.path}.repair');
      await sanitizedFile.copy(tempFile.path);
      await tempFile.rename(activeFile.path);
      KazumiLogger().w(
        'HistorySync: rewrote local event log without malformed lines',
      );
    } catch (e, stackTrace) {
      KazumiLogger().w(
        'HistorySync: failed to repair local event log',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> completeCheckpoint(HistorySyncLogBatch batch) {
    return _localLogQueue.run(() async {
      if (!batch.shouldCheckpoint) {
        return;
      }
      for (final file in batch.files) {
        if (_isPendingLocalLog(file) && await file.exists()) {
          await file.delete();
        }
      }
    });
  }

  Future<HistorySyncSnapshot> readSnapshotFile(File file) async {
    final path = file.path;
    final json = await Isolate.run(() => _readSnapshotFile(path));
    return HistorySyncSnapshot.fromJson(json);
  }

  /// Merges event files into [snapshot].
  ///
  /// With [tolerateMalformedLines] each unparsable line is skipped and
  /// reported through a warning log instead of failing the whole merge. This
  /// keeps sync alive when a crash mid-append leaves a truncated line in a
  /// locally-owned log; the local Hive box remains the source of truth for
  /// anything a skipped line described.
  Future<HistorySyncSnapshot> mergeEventFiles({
    required HistorySyncSnapshot snapshot,
    required Iterable<File> eventFiles,
    required Iterable<HistorySyncEvent> inMemoryEvents,
    bool tolerateMalformedLines = false,
  }) async {
    final request = <String, dynamic>{
      'snapshot': snapshot.toJson(),
      'eventFiles': eventFiles.map((file) => file.path).toList(),
      'events': inMemoryEvents.map((event) => event.toJson()).toList(),
      'tolerateMalformedLines': tolerateMalformedLines,
    };
    final response = await Isolate.run(() => _mergeHistoryEventFiles(request));
    final skippedLines = Map<String, int>.from(response['skippedLines'] as Map);
    for (final entry in skippedLines.entries) {
      KazumiLogger().w(
        'HistorySync: skipped ${entry.value} malformed line(s) '
        'in local event log ${entry.key}',
      );
    }
    return HistorySyncSnapshot.fromJson(
      Map<String, dynamic>.from(response['snapshot'] as Map),
    );
  }

  /// Merges independently-owned remote logs without letting one invalid file
  /// block every device. Each file is transactional: none of its events are
  /// applied if parsing fails.
  Future<HistorySyncSnapshot> mergeRemoteEventFiles({
    required HistorySyncSnapshot snapshot,
    required Iterable<File> eventFiles,
    required Future<void> Function(
      File file,
      Object error,
      StackTrace stackTrace,
    ) onInvalidFile,
  }) async {
    var mergedSnapshot = snapshot;
    for (final file in eventFiles) {
      try {
        mergedSnapshot = await mergeEventFiles(
          snapshot: mergedSnapshot,
          eventFiles: [file],
          inMemoryEvents: const [],
        );
      } catch (e, stackTrace) {
        await onInvalidFile(file, e, stackTrace);
      }
    }
    return mergedSnapshot;
  }

  Future<void> writeSnapshotFile(
    HistorySyncSnapshot snapshot,
    File file,
  ) async {
    final path = file.path;
    final snapshotJson = snapshot.toJson();
    await Isolate.run(() async {
      final target = File(path);
      await target.parent.create(recursive: true);
      await target.writeAsString(
        jsonEncode(snapshotJson),
        flush: true,
      );
    });
  }

  Future<File> localChangeLogFile() async {
    final directory = await _applicationSupportDirectoryProvider();
    return File('${directory.path}/webdavTemp/history.local.jsonl');
  }

  Future<int> _nextSeq() async {
    return _sequenceQueue.run(() async {
      final value = GStorage.getSetting(SettingsKeys.historySyncSequence);
      final next = value + 1;
      await GStorage.putSetting(SettingsKeys.historySyncSequence, next);
      return next;
    });
  }

  Future<void> appendSafely(Future<void> Function() append) async {
    final webDavEnable = GStorage.getSetting(SettingsKeys.webDavEnable);
    final historySyncEnable =
        GStorage.getSetting(SettingsKeys.webDavEnableHistory);
    if (webDavEnable != true || historySyncEnable != true) {
      return;
    }
    try {
      await append();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'HistorySync: failed to append local change',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<File>> _pendingLocalLogFiles(Directory directory) async {
    if (!await directory.exists()) {
      return [];
    }
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && _isPendingLocalLog(entity)) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  bool _isPendingLocalLog(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    return name.startsWith(_pendingLogPrefix) && name.endsWith('.jsonl');
  }

  Future<int> _totalFileLength(Iterable<File> files) async {
    var total = 0;
    for (final file in files) {
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }
}

class HistorySyncLogBatch {
  HistorySyncLogBatch({
    required List<File> files,
    required this.shouldCheckpoint,
  }) : files = List.unmodifiable(files);

  final List<File> files;
  final bool shouldCheckpoint;
}

Future<Map<String, dynamic>> _readSnapshotFile(String path) async {
  final content = await File(path).openRead().transform(utf8.decoder).join();
  return Map<String, dynamic>.from(jsonDecode(content) as Map);
}

Future<Map<String, dynamic>> _mergeHistoryEventFiles(
  Map<String, dynamic> request,
) async {
  final snapshot = HistorySyncSnapshot.fromJson(
    Map<String, dynamic>.from(request['snapshot'] as Map),
  );
  final merger = HistorySyncStreamMerger(snapshot);
  final eventFiles = (request['eventFiles'] as List).cast<String>();
  final tolerateMalformedLines =
      request['tolerateMalformedLines'] as bool? ?? false;
  final skippedLines = <String, int>{};

  for (final path in eventFiles) {
    final lines = File(path)
        .openRead()
        .transform(Utf8Decoder(allowMalformed: tolerateMalformedLines))
        .transform(const LineSplitter());
    await for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      try {
        merger.add(
          HistorySyncEvent.fromJson(
            Map<String, dynamic>.from(jsonDecode(line) as Map),
          ),
        );
      } catch (_) {
        if (!tolerateMalformedLines) {
          rethrow;
        }
        skippedLines[path] = (skippedLines[path] ?? 0) + 1;
      }
    }
  }

  merger.addAll(
    (request['events'] as List).map(
      (eventJson) => HistorySyncEvent.fromJson(
        Map<String, dynamic>.from(eventJson as Map),
      ),
    ),
  );

  return <String, dynamic>{
    'snapshot': merger.snapshot().toJson(),
    'skippedLines': skippedLines,
  };
}

/// Runs [_copyValidEventLines] in an isolate. Top-level so the isolate
/// closure captures only the paths, not the service instance.
Future<Map<String, int>> _sanitizeEventLogCopy({
  required String sourcePath,
  required String targetPath,
}) {
  final request = <String, String>{
    'sourcePath': sourcePath,
    'targetPath': targetPath,
  };
  return Isolate.run(() => _copyValidEventLines(request));
}

/// Copies only the lines other devices can merge, so one corrupt local line
/// cannot get this device's remote log quarantined by every peer.
Future<Map<String, int>> _copyValidEventLines(
  Map<String, String> request,
) async {
  final sourcePath = request['sourcePath']!;
  final targetPath = request['targetPath']!;
  final probe = HistorySyncStreamMerger(HistorySyncSnapshot.empty());
  final sink = File(targetPath).openWrite();
  var validLines = 0;
  var malformedLines = 0;
  try {
    final lines = File(sourcePath)
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    await for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      try {
        probe.add(
          HistorySyncEvent.fromJson(
            Map<String, dynamic>.from(jsonDecode(line) as Map),
          ),
        );
      } catch (_) {
        malformedLines++;
        continue;
      }
      sink.writeln(line);
      validLines++;
    }
  } finally {
    await sink.close();
  }
  return {'validLines': validLines, 'malformedLines': malformedLines};
}
