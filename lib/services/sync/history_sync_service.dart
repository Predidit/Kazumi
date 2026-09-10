import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/services/logging/logger.dart';
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
  int _captureSequence = 0;

  Future<void> appendEvents(Iterable<HistorySyncEvent> events) async {
    final content = HistorySyncCodec.eventsToJsonLines(events);
    if (content.isEmpty) {
      return;
    }
    await _localLogQueue.run(() async {
      final file = await localChangeLogFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '\n$content',
        mode: FileMode.append,
        flush: true,
      );
    });
  }

  // Rotation preserves concurrent appends until the remote checkpoint commits.
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

  // The log queue prevents appends during replacement.
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

  // Reject malformed remote files as a whole without losing other devices' events.
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

// Keep the isolate entry point top-level to avoid capturing the service.
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
