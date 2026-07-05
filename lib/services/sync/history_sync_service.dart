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
      if (existing.isNotEmpty) {
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
      await activeFile.copy(uploadFile.path);
      return uploadFile;
    });
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

  Future<HistorySyncSnapshot> mergeEventFiles({
    required HistorySyncSnapshot snapshot,
    required Iterable<File> eventFiles,
    required Iterable<HistorySyncEvent> inMemoryEvents,
  }) async {
    final request = <String, dynamic>{
      'snapshot': snapshot.toJson(),
      'eventFiles': eventFiles.map((file) => file.path).toList(),
      'events': inMemoryEvents.map((event) => event.toJson()).toList(),
    };
    final mergedJson =
        await Isolate.run(() => _mergeHistoryEventFiles(request));
    return HistorySyncSnapshot.fromJson(mergedJson);
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

  for (final path in eventFiles) {
    final lines = File(path)
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      merger.add(
        HistorySyncEvent.fromJson(
          Map<String, dynamic>.from(jsonDecode(line) as Map),
        ),
      );
    }
  }

  merger.addAll(
    (request['events'] as List).map(
      (eventJson) => HistorySyncEvent.fromJson(
        Map<String, dynamic>.from(eventJson as Map),
      ),
    ),
  );

  return merger.snapshot().toJson();
}
