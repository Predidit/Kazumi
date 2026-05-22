import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/utils/history_sync_service.dart';

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
  bool isHistorySyncing = false;
  Future<void> _webDavOperationQueue = Future.value();

  WebDav._internal();
  static final WebDav _instance = WebDav._internal();
  factory WebDav() => _instance;

  Future<void> init() async {
    var directory = await getApplicationSupportDirectory();
    webDavLocalTempDirectory = Directory('${directory.path}/webdavTemp');
    Box setting = GStorage.setting;
    webDavURL = setting.get(SettingBoxKey.webDavURL, defaultValue: '');
    webDavUsername =
        setting.get(SettingBoxKey.webDavUsername, defaultValue: '');
    webDavPassword =
        setting.get(SettingBoxKey.webDavPassword, defaultValue: '');
    if (webDavURL.isEmpty) {
      //KazumiLogger().log(Level.warning, 'WebDAV URL is not set');
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
    final previousOperation = _webDavOperationQueue;
    final completer = Completer<T>();
    _webDavOperationQueue = (() async {
      try {
        await previousOperation;
      } catch (_) {}
      try {
        completer.complete(await action());
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
    })();
    return completer.future;
  }

  Future<void> _updateBox(String boxName) async {
    var directory = await getApplicationSupportDirectory();
    final localFilePath = '${directory.path}/hive/$boxName.hive';
    final tempFilePath = '${webDavLocalTempDirectory.path}/$boxName.tmp';
    final webDavPath = '$_syncRootPath/$boxName.tmp';
    await File(localFilePath).copy(tempFilePath);
    try {
      await client.remove('$webDavPath.cache');
    } catch (_) {}
    await client.writeFromFile(tempFilePath, '$webDavPath.cache');
    try {
      await client.remove(webDavPath);
    } catch (_) {
      KazumiLogger().w('WebDav: former backup file not exist');
    }
    await client.rename('$webDavPath.cache', webDavPath, true);
    try {
      await File(tempFilePath).delete();
    } catch (_) {}
  }

  Future<void> syncHistory() async {
    if (isHistorySyncing) {
      KazumiLogger().w('WebDav: History is currently syncing');
      throw Exception('History is currently syncing');
    }
    isHistorySyncing = true;
    try {
      await _runWebDavExclusive(_syncHistory);
    } catch (e) {
      KazumiLogger().e('WebDav: history sync failed', error: e);
      rethrow;
    } finally {
      isHistorySyncing = false;
    }
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
    final localEvents = await historySync.readLocalEvents();
    final localStateEvents = await _eventsFromLocalHistories();
    var remoteSnapshot =
        await _readHistorySnapshot() ?? HistorySyncSnapshot.empty();
    final remoteEvents = await _readRemoteHistoryEvents();

    if (remoteSnapshot.histories.isEmpty &&
        remoteSnapshot.itemVersions.isEmpty &&
        remoteEvents.isEmpty &&
        await _tryImportLegacyHistory()) {
      remoteSnapshot = historySync.buildSnapshotFromLocal();
      await _writeHistorySnapshot(remoteSnapshot);
    }

    final mergedSnapshot = HistorySyncMerger.merge(
      snapshot: remoteSnapshot,
      events: [
        ...remoteEvents,
        ...localStateEvents,
        ...localEvents,
      ],
    );
    await historySync.applySnapshotToLocal(mergedSnapshot);

    if (localEvents.isNotEmpty) {
      await _writeDeviceHistoryChanges(localEvents);
    }

    final snapshotInitialized = GStorage.setting.get(
      SettingBoxKey.historySyncSnapshotInitialized,
      defaultValue: false,
    );
    if (snapshotInitialized != true ||
        await historySync.shouldCompactLocalLog()) {
      await _writeHistorySnapshot(mergedSnapshot);
      await historySync.replaceLocalEvents(const []);
      await _writeDeviceHistoryChanges(const []);
      await GStorage.setting.put(
        SettingBoxKey.historySyncSnapshotInitialized,
        true,
      );
    }
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

  Future<HistorySyncSnapshot?> _readHistorySnapshot() async {
    try {
      final content = await _readRemoteText(_historySnapshotPath);
      return HistorySyncSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(content) as Map),
      );
    } catch (e) {
      KazumiLogger().w('WebDav: history snapshot not available', error: e);
      return null;
    }
  }

  Future<List<HistorySyncEvent>> _readRemoteHistoryEvents() async {
    final events = <HistorySyncEvent>[];
    final files = await client.readDir(_historyChangesPath);
    for (final file in files) {
      final name = file.name ?? '';
      if (!name.endsWith('.jsonl') || file.size == 0) {
        continue;
      }
      try {
        final content = await _readRemoteText('$_historyChangesPath/$name');
        events.addAll(HistorySyncCodec.eventsFromJsonLines(content));
      } catch (e) {
        KazumiLogger().w(
          'WebDav: failed to read history change log $name',
          error: e,
        );
      }
    }
    return events;
  }

  Future<List<HistorySyncEvent>> _eventsFromLocalHistories() async {
    final events = <HistorySyncEvent>[];
    for (final history in GStorage.histories.values) {
      for (final progress in history.progresses.values) {
        events.add(
          HistorySyncEvent(
            eventId:
                'local-state:${history.key}:${progress.episode}:${progress.road}',
            deviceId: 'local-state',
            seq: 0,
            op: HistorySyncOp.upsertProgress,
            updatedAt: history.lastWatchTime.millisecondsSinceEpoch,
            entityKey: history.key,
            bangumiItem: history.bangumiItem,
            adapterName: history.adapterName,
            episode: progress.episode,
            road: progress.road,
            progressMs: progress.progress.inMilliseconds,
            lastSrc: history.lastSrc,
            lastWatchEpisodeName: history.lastWatchEpisodeName,
          ),
        );
      }
    }
    return events;
  }

  Future<bool> _tryImportLegacyHistory() async {
    try {
      final fileName = 'histories.tmp';
      final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
      if (await existingFile.exists()) {
        await existingFile.delete();
      }
      await client.read2File('$_syncRootPath/$fileName', existingFile.path);
      await GStorage.patchHistory(existingFile.path);
      KazumiLogger().i('WebDav: imported legacy history backup');
      return true;
    } catch (e) {
      KazumiLogger().w('WebDav: no legacy history backup imported', error: e);
      return false;
    }
  }

  Future<void> _writeHistorySnapshot(HistorySyncSnapshot snapshot) async {
    await _writeRemoteText(
      _historySnapshotPath,
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<void> _writeDeviceHistoryChanges(
    Iterable<HistorySyncEvent> events,
  ) async {
    final deviceId = await HistorySyncService().getDeviceId();
    final remotePath = '$_historyChangesPath/$deviceId.jsonl';
    final content = HistorySyncCodec.eventsToJsonLines(events);
    if (content.isEmpty) {
      try {
        await client.remove(remotePath);
      } catch (_) {}
      return;
    }
    await _writeRemoteText(remotePath, content);
  }

  Future<String> _readRemoteText(String remotePath) async {
    final bytes = await client.read(remotePath);
    return utf8.decode(bytes);
  }

  Future<void> _writeRemoteText(String remotePath, String content) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final response = await client.c.req(
      client,
      'PUT',
      remotePath,
      data: bytes,
      optionsHandler: (options) {
        options.contentType = 'application/octet-stream';
      },
    );
    final statusCode = response.statusCode;
    if (statusCode == 200 || statusCode == 201 || statusCode == 204) {
      return;
    }
    throw Exception('WebDav: PUT $remotePath failed with $statusCode');
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
