import 'dart:io';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';

class WebDav {
  late String webDavURL;
  late String webDavUsername;
  late String webDavPassword;
  late String webDavPath;
  late Directory webDavLocalTempDirectory;
  late webdav.Client client;

  bool initialized = false;
  // make sure only one upload history task at a time
  bool isHistorySyncing = false;

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
    webDavPath = 
        setting.get(SettingBoxKey.webDavPath, defaultValue: '/kazumiSync');
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
    try {
      await client.ping();
      try {
        // KazumiLogger().log(Level.warning, 'webDav backup directory not exists, creating');
        await client.mkdir(webDavPath);
        if (!await webDavLocalTempDirectory.exists()) {
          await webDavLocalTempDirectory.create(recursive: true);
        }
        initialized = true;
        KazumiLogger().log(Level.info, 'webDav backup directory create success');
      } catch (_) {
        KazumiLogger().log(Level.error, 'webDav backup directory create failed');
        rethrow;
      }
    } catch (e) {
      KazumiLogger().log(Level.error, 'WebDAV ping failed: $e');
      rethrow;
    }
  }

  Future<void> _update(String boxName) async {
    var directory = await getApplicationSupportDirectory();
    final localFilePath = '${directory.path}/hive/$boxName.hive'; 
    final tempFilePath = '${webDavLocalTempDirectory.path}/$boxName.tmp';
    final webDavDir = '${checkPath(webDavPath)}$boxName/';
    try {
      await client.mkdir(webDavDir);
    } catch (_) {}
    final now = DateTime.now();
    final dateString = "${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}";
    final filename = '$boxName-$dateString.tmp';
    final files = await client.readDir(webDavDir);
    final historyFiles = files.where((file) => 
      file.name != null && 
      file.name!.startsWith(boxName) && 
      file.name!.endsWith('.tmp')
    ).toList();
    String? oldFilePath;
    for (var file in historyFiles) {
      if (file.name != null && file.name!.startsWith('$boxName-$dateString')) {
        oldFilePath = file.path;
        break;
      }
    }
    if (oldFilePath != null) {
      await client.remove(oldFilePath);
    }
    if (historyFiles.length > 5) {
      historyFiles.sort((a, b) => a.name!.compareTo(b.name!));
      await client.remove(historyFiles.first.path!);
    }
    await File(localFilePath).copy(tempFilePath);
    try {
    await client.remove('$webDavDir$filename.cache');
    } catch (_) {}
    await client.writeFromFile(tempFilePath, '$webDavDir$filename.cache', onProgress: (c, t) {
    // print(c / t);
    });
    await client.rename(
      '$webDavDir$filename.cache', '$webDavDir$filename', true);
    KazumiLogger().log(Level.info, 'Uploaded $filename to $webDavDir');
    try {
      await File(tempFilePath).delete();
    } catch (_) {}
  }

  Future<void> updateHistory() async {
    if (isHistorySyncing) {
      KazumiLogger().log(Level.warning, 'History is currently syncing');
      throw Exception('History is currently syncing');
    }
    isHistorySyncing = true;
    try {
      await _update('histories');
    } catch (e) {
      KazumiLogger().log(Level.error, 'webDav update history failed $e');
      rethrow;
    } finally {
      isHistorySyncing = false;
    }
  }

  Future<void> updateCollectibles() async {
    // don't try muliti thread update here
    // some webdav server may not support muliti thread write
    // you will get 423 locked error
    await _update('collectibles');
    if (GStorage.collectChanges.isNotEmpty) {
      await _update('collectchanges');
    }
  }

  Future<void> _download(String boxName) async {
    final webDavDir = '${checkPath(webDavPath)}$boxName/';
    final existingFile = File('${webDavLocalTempDirectory.path}/$boxName.tmp');
    final files = await client.readDir(webDavDir);
    final historyFiles = files.where((file) => 
      file.name != null && 
      file.name!.startsWith(boxName) && 
      file.name!.endsWith('.tmp')
    ).toList();
    if (historyFiles.isEmpty) {
      throw Exception('No data file found for $boxName');
    }
    historyFiles.sort((a, b) => b.name!.compareTo(a.name!));
    final latestFile = historyFiles.first;
    if (await existingFile.exists()) {
      await existingFile.delete();
    }
    await client.read2File(latestFile.path!, existingFile.path, onProgress: (c, t) {
      // print(c / t);
    });
  }

  Future<void> downloadAndPatchHistory() async {
    if (isHistorySyncing) {
      KazumiLogger().log(Level.warning, 'History is currently syncing');
      throw Exception('History is currently syncing');
    }
    isHistorySyncing = true;
    
    try {
      await _download('histories');
      final existingFile = File('${webDavLocalTempDirectory.path}/histories.tmp');
      await GStorage.patchHistory(existingFile.path);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'webDav download and patch history failed $e');
      rethrow;
    } finally {
      isHistorySyncing = false;
    }
  }

  Future<void> syncCollectibles() async {
    List<CollectedBangumi> remoteCollectibles = [];
    List<CollectedBangumiChange> remoteChanges = [];

    // muliti thread download
    Future<void> collectiblesFuture = _download('collectibles').catchError((e) {
      KazumiLogger().log(Level.error, 'webDav download collectibles failed $e');
    });
    Future<void> changesFuture = _download('collectchanges').catchError((e) {
      KazumiLogger()
          .log(Level.error, 'webDav download collect changes failed $e');
    });
    await Future.wait([collectiblesFuture, changesFuture]);


    // we should block download changes when download collectibles failed
    // download changes failed but collectibles success means remote files broken or newwork error
    // we should force push local collectibles to remote to fix it
    try {
      remoteCollectibles = await GStorage.getCollectiblesFromFile(
          '${webDavLocalTempDirectory.path}/collectibles.tmp');
      remoteChanges = await GStorage.getCollectChangesFromFile(
          '${webDavLocalTempDirectory.path}/collectchanges.tmp');
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'webDav get collectibles from file failed $e');
    }
    if (remoteChanges.isNotEmpty || remoteCollectibles.isNotEmpty) {
      await GStorage.patchCollectibles(remoteCollectibles, remoteChanges);
    }
    await updateCollectibles();
  }

  Future<void> ping() async {
    try {
      await client.ping();
    } catch (e) {
      KazumiLogger().log(Level.error, 'WebDAV ping failed: $e');
      rethrow;
    }
  }

  String checkPath(String path) {
    return path.endsWith('/') ? path : '$path/';
  }
}
