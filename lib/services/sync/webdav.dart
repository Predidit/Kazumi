import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/services/sync/history_sync_service.dart';
import 'package:kazumi/services/sync/webdav_remote_file_commit.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:kazumi/utils/async_single_flight.dart';

class WebDav {
  static const String _syncRootPath = '/kazumiSync';
  static const String _historyRootPath = '$_syncRootPath/history';
  static const String _historyChangesPath = '$_historyRootPath/changes';
  static const String _historySnapshotPath = '$_historyRootPath/snapshot.json';

  late String webDavURL;
  late String webDavUsername;
  late String webDavPassword;
  late Directory webDavLocalTempDirectory;
  late webdav.Client client;

  bool initialized = false;
  static const Duration _staleRunDirectoryAge = Duration(hours: 24);

  final AsyncSingleFlight<void> _historySyncSingleFlight =
      AsyncSingleFlight<void>();
  final AsyncSerialQueue _webDavOperationQueue = AsyncSerialQueue();
  final WebDavRemoteFileCommitter _remoteFileCommitter =
      const WebDavRemoteFileCommitter();

  bool get isHistorySyncing => _historySyncSingleFlight.isRunning;

  WebDav._internal();
  static final WebDav _instance = WebDav._internal();
  factory WebDav() => _instance;

  Future<void> init() async {
    var directory = await getApplicationSupportDirectory();
    webDavLocalTempDirectory = Directory('${directory.path}/webdavTemp');
    webDavURL = GStorage.getSetting(SettingsKeys.webDavURL);
    webDavUsername = GStorage.getSetting(SettingsKeys.webDavUsername);
    webDavPassword = GStorage.getSetting(SettingsKeys.webDavPassword);
    if (webDavURL.isEmpty) {
      throw Exception('请先填写WebDAV URL');
    }
    client = webdav.newClient(
      webDavURL,
      user: webDavUsername,
      password: webDavPassword,
      debug: false,
    );
    client.setHeaders({'accept-charset': 'utf-8'});
    client.c.options.contentType = 'application/octet-stream';
    try {
      await client.ping();
      await _ensureRemoteDirectory(_syncRootPath);
      await _ensureLocalTempDirectory();
      initialized = true;
      KazumiLogger().i('WebDav: webDav backup directory ready');
    } catch (e) {
      KazumiLogger().e('WebDav: WebDAV ping failed', error: e);
      rethrow;
    }
  }

  Future<T> _runWebDavExclusive<T>(Future<T> Function() action) {
    return _webDavOperationQueue.run(action);
  }

  Future<void> _updateBox(String boxName) async {
    var directory = await getApplicationSupportDirectory();
    final localFilePath = '${directory.path}/hive/$boxName.hive';
    final tempFilePath = '${webDavLocalTempDirectory.path}/$boxName.tmp';
    final webDavPath = '$_syncRootPath/$boxName.tmp';
    await File(localFilePath).copy(tempFilePath);
    await _publishRemoteFile(
      sourceFilePath: tempFilePath,
      destinationPath: webDavPath,
    );
    try {
      await File(tempFilePath).delete();
    } catch (_) {}
  }

  Future<void> syncHistory() {
    return _historySyncSingleFlight.run(() async {
      try {
        await _runWebDavExclusive(_syncHistory);
      } catch (e) {
        KazumiLogger().e('WebDav: history sync failed', error: e);
        rethrow;
      }
    });
  }

  Future<void> updateCollectibles() async {
    try {
      await _runWebDavExclusive(() async {
        await _updateBox('collectibles');
        if (GStorage.collectChanges.isNotEmpty) {
          await _updateBox('collectchanges');
        }
      });
    } catch (e) {
      KazumiLogger().e('WebDav: update collectibles failed', error: e);
      rethrow;
    }
  }

  Future<void> _downloadBox(String boxName) async {
    String fileName = '$boxName.tmp';
    final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
    if (await existingFile.exists()) {
      await existingFile.delete();
    }
    await client.read2File('$_syncRootPath/$fileName', existingFile.path);
  }

  Future<void> syncCollectibles() async {
    return _runWebDavExclusive(_syncCollectibles);
  }

  Future<void> _syncCollectibles() async {
    List<CollectedBangumi> remoteCollectibles = [];
    List<CollectedBangumiChange> remoteChanges = [];

    final files = await client.readDir(_syncRootPath);
    final collectiblesExists =
        files.any((file) => file.name == 'collectibles.tmp');
    final changesExists =
        files.any((file) => file.name == 'collectchanges.tmp');
    if (!collectiblesExists && !changesExists) {
      await _updateBox('collectibles');
      if (GStorage.collectChanges.isNotEmpty) {
        await _updateBox('collectchanges');
      }
      return;
    }

    List<Future<void>> downloadFutures = [];
    if (collectiblesExists) {
      downloadFutures.add(_downloadBox('collectibles').catchError((e) {
        KazumiLogger().e('WebDav: download collectibles failed', error: e);
        throw Exception('WebDav: download collectibles failed');
      }));
    }
    if (changesExists) {
      downloadFutures.add(_downloadBox('collectchanges').catchError((e) {
        KazumiLogger().e('WebDav: download collectchanges failed', error: e);
        throw Exception('WebDav: download collectchanges failed');
      }));
    }
    if (downloadFutures.isNotEmpty) {
      await Future.wait(downloadFutures);
    }
    try {
      if (collectiblesExists) {
        remoteCollectibles = await GStorage.getCollectiblesFromFile(
            '${webDavLocalTempDirectory.path}/collectibles.tmp');
      }
      if (changesExists) {
        remoteChanges = await GStorage.getCollectChangesFromFile(
            '${webDavLocalTempDirectory.path}/collectchanges.tmp');
      }
    } catch (e) {
      KazumiLogger().e('WebDav: get collectibles failed', error: e);
      throw Exception('WebDav: get collectibles from file failed');
    }
    if (remoteChanges.isNotEmpty || remoteCollectibles.isNotEmpty) {
      await GStorage.patchCollectibles(remoteCollectibles, remoteChanges);
    }
    await _updateBox('collectibles');
    if (GStorage.collectChanges.isNotEmpty) {
      await _updateBox('collectchanges');
    }
  }

  Future<void> _syncHistory() async {
    await _ensureHistoryStorage();
    final historySync = HistorySyncService();
    final deviceId = await historySync.getDeviceId();
    final runDirectory = await _createHistorySyncRunDirectory();

    try {
      final downloads = await _downloadHistorySyncFiles(
        runDirectory: runDirectory,
        deviceId: deviceId,
      );
      final snapshotReadResult = await _readRemoteHistorySnapshot(
        historySync,
        downloads.snapshotFile,
      );
      var remoteSnapshot = snapshotReadResult.snapshot;
      var importedLegacyHistory = false;

      if (_isEmptyHistorySnapshot(remoteSnapshot) &&
          downloads.eventFiles.isEmpty) {
        importedLegacyHistory = await _tryImportLegacyHistory(runDirectory);
        if (importedLegacyHistory) {
          remoteSnapshot = await historySync.buildSnapshotFromLocal();
        }
      }

      final snapshotInitialized =
          GStorage.getSetting(SettingsKeys.historySyncSnapshotInitialized);
      final localBatch = await historySync.prepareLocalLogs(
        runDirectory: runDirectory,
        forceCheckpoint: snapshotInitialized != true ||
            snapshotReadResult.needsRepair ||
            downloads.currentDeviceLogOversized ||
            importedLegacyHistory,
      );
      final mergedRemoteSnapshot = await _mergeRemoteHistoryEventFiles(
        historySync: historySync,
        snapshot: remoteSnapshot,
        eventFiles: downloads.eventFiles,
      );
      // Locally-owned logs tolerate malformed lines: a crash mid-append must
      // not permanently block sync, and the Hive box still holds the state a
      // damaged line described. Remote logs above stay fail-closed so an
      // invalid file is quarantined as a whole.
      final mergedFromFiles = await historySync.mergeEventFiles(
        snapshot: mergedRemoteSnapshot,
        eventFiles: localBatch.files,
        inMemoryEvents: await historySync.buildLocalStateEvents(),
        tolerateMalformedLines: true,
      );

      final mergedSnapshot = await historySync.reconcileAndApplySnapshot(
        mergedFromFiles,
      );

      if (localBatch.shouldCheckpoint) {
        final snapshotFile = File(
          '${runDirectory.path}${Platform.pathSeparator}snapshot.json',
        );
        await historySync.writeSnapshotFile(mergedSnapshot, snapshotFile);
        await _publishHistorySnapshot(
          snapshotFile: snapshotFile,
        );
        await historySync.completeCheckpoint(localBatch);
        await _removeDeviceHistoryChanges(deviceId);
        await GStorage.putSetting(
          SettingsKeys.historySyncSnapshotInitialized,
          true,
        );
      } else {
        final uploadFile =
            await historySync.copyActiveLogForUpload(runDirectory);
        if (uploadFile != null) {
          await _publishDeviceHistoryChanges(
            sourceFile: uploadFile,
            deviceId: deviceId,
          );
        }
      }
    } finally {
      try {
        if (await runDirectory.exists()) {
          await runDirectory.delete(recursive: true);
        }
      } catch (e) {
        KazumiLogger().w(
          'WebDav: failed to clean history sync temp directory',
          error: e,
        );
      }
    }
  }

  bool _isEmptyHistorySnapshot(HistorySyncSnapshot snapshot) {
    return snapshot.histories.isEmpty &&
        snapshot.itemVersions.isEmpty &&
        snapshot.progressVersions.isEmpty &&
        snapshot.deletedVersions.isEmpty &&
        snapshot.clearVersion == null;
  }

  Future<_HistorySnapshotReadResult> _readRemoteHistorySnapshot(
    HistorySyncService historySync,
    File? snapshotFile,
  ) async {
    if (snapshotFile == null) {
      return _HistorySnapshotReadResult(
        snapshot: HistorySyncSnapshot.empty(),
        needsRepair: false,
      );
    }

    try {
      return _HistorySnapshotReadResult(
        snapshot: await historySync.readSnapshotFile(snapshotFile),
        needsRepair: false,
      );
    } catch (e, stackTrace) {
      KazumiLogger().w(
        'WebDav: invalid history snapshot, rebuilding from event logs',
        error: e,
        stackTrace: stackTrace,
      );
      return _HistorySnapshotReadResult(
        snapshot: HistorySyncSnapshot.empty(),
        needsRepair: true,
      );
    }
  }

  Future<HistorySyncSnapshot> _mergeRemoteHistoryEventFiles({
    required HistorySyncService historySync,
    required HistorySyncSnapshot snapshot,
    required List<_DownloadedHistoryEventFile> eventFiles,
  }) async {
    final eventFilesByPath = {
      for (final eventFile in eventFiles)
        eventFile.localFile.path: eventFile.remoteName,
    };
    return historySync.mergeRemoteEventFiles(
      snapshot: snapshot,
      eventFiles: eventFiles.map((eventFile) => eventFile.localFile),
      onInvalidFile: (file, error, stackTrace) async {
        final remoteName = eventFilesByPath[file.path]!;
        KazumiLogger().w(
          'WebDav: invalid remote history event log $remoteName, skipping',
          error: error,
          stackTrace: stackTrace,
        );
        await _quarantineRemoteHistoryEventFile(remoteName);
      },
    );
  }

  Future<Directory> _createHistorySyncRunDirectory() async {
    await _cleanupStaleHistorySyncRunDirectories();
    return webDavLocalTempDirectory.createTemp('history-sync-run-');
  }

  Future<void> _cleanupStaleHistorySyncRunDirectories() async {
    await _ensureLocalTempDirectory();
    final staleBefore = DateTime.now().subtract(_staleRunDirectoryAge);
    await for (final entity
        in webDavLocalTempDirectory.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!name.startsWith('history-sync-run-')) {
        continue;
      }
      try {
        final stat = await entity.stat();
        // A recent directory may belong to another running Kazumi process.
        if (stat.modified.isAfter(staleBefore)) {
          continue;
        }
        await entity.delete(recursive: true);
      } catch (e) {
        KazumiLogger().w(
          'WebDav: failed to remove stale history sync directory $name',
          error: e,
        );
      }
    }
  }

  Future<_HistorySyncDownloads> _downloadHistorySyncFiles({
    required Directory runDirectory,
    required String deviceId,
  }) async {
    File? snapshotFile;
    final historyEntries = await client.readDir(_historyRootPath);
    final hasSnapshot = historyEntries.any(
      (file) => file.name == 'snapshot.json',
    );
    if (hasSnapshot) {
      snapshotFile = File(
        '${runDirectory.path}${Platform.pathSeparator}remote-snapshot.json',
      );
      await client.read2File(_historySnapshotPath, snapshotFile.path);
    }

    final eventFiles = <_DownloadedHistoryEventFile>[];
    var currentDeviceLogOversized = false;
    final changeEntries = await client.readDir(_historyChangesPath);
    var index = 0;
    for (final entry in changeEntries) {
      final name = entry.name ?? '';
      if (!name.endsWith('.jsonl') || entry.size == 0) {
        continue;
      }
      final localFile = File(
        '${runDirectory.path}${Platform.pathSeparator}'
        'remote-events-${index++}.jsonl',
      );
      await client.read2File(
        '$_historyChangesPath/$name',
        localFile.path,
      );
      if (name == '$deviceId.jsonl' &&
          await localFile.length() >
              HistorySyncService.checkpointLogThresholdBytes) {
        currentDeviceLogOversized = true;
      }
      eventFiles.add(
        _DownloadedHistoryEventFile(
          remoteName: name,
          localFile: localFile,
        ),
      );
    }

    return _HistorySyncDownloads(
      snapshotFile: snapshotFile,
      eventFiles: eventFiles,
      currentDeviceLogOversized: currentDeviceLogOversized,
    );
  }

  Future<void> _publishHistorySnapshot({
    required File snapshotFile,
  }) {
    return _publishRemoteFile(
      sourceFilePath: snapshotFile.path,
      destinationPath: _historySnapshotPath,
    );
  }

  Future<void> _publishDeviceHistoryChanges({
    required File sourceFile,
    required String deviceId,
  }) {
    final destinationPath = '$_historyChangesPath/$deviceId.jsonl';
    return _publishRemoteFile(
      sourceFilePath: sourceFile.path,
      destinationPath: destinationPath,
    );
  }

  Future<void> _publishRemoteFile({
    required String sourceFilePath,
    required String destinationPath,
  }) async {
    await _remoteFileCommitter.replaceFile(
      sourceFilePath: sourceFilePath,
      destinationPath: destinationPath,
      remove: (path) => client.remove(path),
      uploadFromFile: (sourceFilePath, remotePath) =>
          client.writeFromFile(sourceFilePath, remotePath),
      rename: (sourcePath, targetPath) =>
          client.rename(sourcePath, targetPath, true),
      exists: _remoteEntryExists,
      verify: _verifyRemoteFile,
    );
  }

  Future<void> _verifyRemoteFile(
    String sourceFilePath,
    String destinationPath,
  ) async {
    final localDigest =
        await sha256.bind(File(sourceFilePath).openRead()).first;
    final remoteDigest = sha256.convert(await client.read(destinationPath));
    if (localDigest != remoteDigest) {
      throw StateError(
        'WebDav: remote verification failed for $destinationPath',
      );
    }
  }

  Future<void> _removeDeviceHistoryChanges(String deviceId) async {
    final remotePath = '$_historyChangesPath/$deviceId.jsonl';
    try {
      await client.remove(remotePath);
    } catch (e) {
      KazumiLogger().w(
        'WebDav: failed to remove checkpointed device history log',
        error: e,
      );
    }
  }

  Future<void> _quarantineRemoteHistoryEventFile(String remoteName) {
    final sourcePath = '$_historyChangesPath/$remoteName';
    final quarantinePath = '$sourcePath.invalid.'
        '${DateTime.now().millisecondsSinceEpoch}';
    return _quarantineRemoteFile(
      sourcePath: sourcePath,
      quarantinePath: quarantinePath,
      description: 'history event log $remoteName',
    );
  }

  Future<void> _ensureHistoryStorage() async {
    await _ensureLocalTempDirectory();
    await _ensureRemoteDirectory(_syncRootPath);
    await _ensureRemoteDirectory(_historyRootPath);
    await _ensureRemoteDirectory(_historyChangesPath);
  }

  Future<void> _ensureLocalTempDirectory() async {
    if (!await webDavLocalTempDirectory.exists()) {
      await webDavLocalTempDirectory.create(recursive: true);
    }
  }

  Future<void> _ensureRemoteDirectory(String path) async {
    try {
      await client.mkdir(path);
    } catch (e) {
      if (!await _remoteEntryExists(path)) {
        rethrow;
      }
    }
  }

  Future<bool> _remoteEntryExists(String path) async {
    final normalized = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    final index = normalized.lastIndexOf('/');
    final parent = index <= 0 ? '/' : normalized.substring(0, index);
    final name = normalized.substring(index + 1);
    try {
      final files = await client.readDir(parent);
      return files.any((file) => file.name == name);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryImportLegacyHistory(Directory runDirectory) async {
    final syncEntries = await client.readDir(_syncRootPath);
    if (!syncEntries.any((file) => file.name == 'histories.tmp')) {
      return false;
    }

    const fileName = 'histories.tmp';
    final existingFile = File(
      '${runDirectory.path}${Platform.pathSeparator}$fileName',
    );
    try {
      await client.read2File('$_syncRootPath/$fileName', existingFile.path);
    } catch (e, stackTrace) {
      KazumiLogger().w(
        'WebDav: failed to download legacy history backup, skipping import',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }

    try {
      await GStorage.patchHistory(existingFile.path);
      KazumiLogger().i('WebDav: imported legacy history backup');
      return true;
    } catch (e, stackTrace) {
      KazumiLogger().w(
        'WebDav: invalid legacy history backup, skipping import',
        error: e,
        stackTrace: stackTrace,
      );
      await _quarantineLegacyHistoryBackup();
      return false;
    }
  }

  Future<void> _quarantineLegacyHistoryBackup() async {
    final quarantinePath = '$_syncRootPath/histories.invalid.'
        '${DateTime.now().millisecondsSinceEpoch}.tmp';
    await _quarantineRemoteFile(
      sourcePath: '$_syncRootPath/histories.tmp',
      quarantinePath: quarantinePath,
      description: 'legacy history backup',
    );
  }

  Future<void> _quarantineRemoteFile({
    required String sourcePath,
    required String quarantinePath,
    required String description,
  }) async {
    try {
      await client.rename(
        sourcePath,
        quarantinePath,
        false,
      );
      KazumiLogger().w(
        'WebDav: moved invalid $description to $quarantinePath',
      );
    } catch (e, stackTrace) {
      KazumiLogger().w(
        'WebDav: failed to quarantine invalid $description',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> ping() async {
    try {
      await client.ping();
    } catch (e) {
      KazumiLogger().e('WebDav: WebDav ping failed', error: e);
      rethrow;
    }
  }
}

class _HistorySyncDownloads {
  const _HistorySyncDownloads({
    required this.snapshotFile,
    required this.eventFiles,
    required this.currentDeviceLogOversized,
  });

  final File? snapshotFile;
  final List<_DownloadedHistoryEventFile> eventFiles;
  final bool currentDeviceLogOversized;
}

class _DownloadedHistoryEventFile {
  const _DownloadedHistoryEventFile({
    required this.remoteName,
    required this.localFile,
  });

  final String remoteName;
  final File localFile;
}

class _HistorySnapshotReadResult {
  const _HistorySnapshotReadResult({
    required this.snapshot,
    required this.needsRepair,
  });

  final HistorySyncSnapshot snapshot;
  final bool needsRepair;
}
