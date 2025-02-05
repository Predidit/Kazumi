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
    client = webdav.newClient(
      webDavURL,
      user: webDavUsername,
      password: webDavPassword,
      debug: false,
    );
    client.setHeaders({'accept-charset': 'utf-8'});
    try {
      // KazumiLogger().log(Level.warning, 'webDav backup directory not exists, creating');
      await client.mkdir('/kazumiSync');
      initialized = true;
      KazumiLogger().log(Level.info, 'webDav backup directory create success');
    } catch (_) {
      KazumiLogger().log(Level.error, 'webDav backup directory create failed');
    }
  }

  Future<void> update(String boxName) async {
    var directory = await getApplicationSupportDirectory();
    try {
      await client.remove('/kazumiSync/$boxName.tmp.cache');
    } catch (_) {}
    await client.writeFromFile('${directory.path}/hive/$boxName.hive',
        '/kazumiSync/$boxName.tmp.cache', onProgress: (c, t) {
      // print(c / t);
    });
    try {
      await client.remove('/kazumiSync/$boxName.tmp');
    } catch (_) {
      KazumiLogger().log(Level.warning, 'webDav former backup file not exist');
    }
    await client.rename(
        '/kazumiSync/$boxName.tmp.cache', '/kazumiSync/$boxName.tmp', true);
  }

  Future<void> updateHistory() async {
    if (isHistorySyncing) {
      return;
    }
    isHistorySyncing = true;
    try {
      await update('histories');
    } catch (e) {
      KazumiLogger().log(Level.error, 'webDav update history failed $e');
    }
    isHistorySyncing = false;
  }

  Future<void> updateCollectibles() async {
    // don't try muliti thread update here
    // some webdav server may not support muliti thread write
    // you will get 423 locked error
    await update('collectibles');
    if (GStorage.collectChanges.isNotEmpty) {
      await update('collectchanges');
    }
  }

  Future<void> downloadAndPatchHistory() async {
    if (isHistorySyncing) {
      return;
    }
    isHistorySyncing = true;
    String fileName = 'histories.tmp';
    try {
      if (!await webDavLocalTempDirectory.exists()) {
        await webDavLocalTempDirectory.create(recursive: true);
      }
      final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
      if (await existingFile.exists()) {
        await existingFile.delete();
      }
      await client.read2File('/kazumiSync/$fileName', existingFile.path,
          onProgress: (c, t) {
        // print(c / t);
      });
      await GStorage.patchHistory(existingFile.path);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'webDav download and patch history failed $e');
    }
    isHistorySyncing = false;
  }

  Future<void> downloadCollectibles() async {
    String fileName = 'collectibles.tmp';
    if (!await webDavLocalTempDirectory.exists()) {
      await webDavLocalTempDirectory.create(recursive: true);
    }
    final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
    if (await existingFile.exists()) {
      await existingFile.delete();
    }
    await client.read2File('/kazumiSync/$fileName', existingFile.path,
        onProgress: (c, t) {
      // print(c / t);
    });
  }

  Future<void> downloadCollectChanges() async {
    String fileName = 'collectChanges.tmp';
    if (!await webDavLocalTempDirectory.exists()) {
      await webDavLocalTempDirectory.create(recursive: true);
    }
    final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
    if (await existingFile.exists()) {
      await existingFile.delete();
    }
    await client.read2File('/kazumiSync/$fileName', existingFile.path,
        onProgress: (c, t) {
      // print(c / t);
    });
  }

  Future<void> syncCollectibles() async {
    List<CollectedBangumi> remoteCollectibles = [];
    List<CollectedBangumiChange> remoteChanges = [];

    // muliti thread download
    Future<void> collectiblesFuture = downloadCollectibles().catchError((e) {
      KazumiLogger().log(Level.error, 'webDav download collectibles failed $e');
    });
    Future<void> changesFuture = downloadCollectChanges().catchError((e) {
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
          '${webDavLocalTempDirectory.path}/collectChanges.tmp');
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
    await client.ping();
  }
}
