import 'dart:io';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';
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
        await client.mkdir('/kazumiSync');    
        if (!await webDavLocalTempDirectory.exists()) {
          await webDavLocalTempDirectory.create(recursive: true);
        }
        initialized = true;
        KazumiLogger().i('WebDav: webDav backup directory create success');
      } catch (_) {
        KazumiLogger().e('WebDav: webDav backup directory create failed');
        rethrow;
      }
    } catch (e) {
      KazumiLogger().e('WebDav: WebDAV ping failed', error: e);
      rethrow;
    }
  }

  Future<void> update(String boxName) async {
    var directory = await getApplicationSupportDirectory();
    final localFilePath = '${directory.path}/hive/$boxName.hive'; 
    final tempFilePath = '${webDavLocalTempDirectory.path}/$boxName.tmp';
    final webDavPath = '/kazumiSync/$boxName.tmp';

    // 1. 复制本地 Hive 文件到临时目录
    await File(localFilePath)
          .copy(tempFilePath);
    
    // 2. 删除旧的缓存文件（如果存在）
    try {
      await client.remove('$webDavPath.cache');
    } catch (_) {}

      // 3. 上传临时文件到 WebDAV（先上传为 .cache 文件）
    await client.writeFromFile(tempFilePath,
        '$webDavPath.cache', onProgress: (c, t) {
      // print(c / t);
    });

    // 4. 删除旧的目标文件（如果存在）
    try {
      await client.remove(webDavPath);
    } catch (_) {
      KazumiLogger().w('WebDav: former backup file not exist');
    }

    // 5. 【关键】将 .cache 文件重命名为正式文件（原子操作）
    await client.rename(
        '$webDavPath.cache', webDavPath, true);
   
    // 6. 清理本地临时文件
   try {
      await File(tempFilePath).delete();
    } catch (_) {}
  }

  Future<void> updateHistory() async {
    if (isHistorySyncing) {
      KazumiLogger().w('WebDav: History is currently syncing');
      throw Exception('History is currently syncing');
    }
    isHistorySyncing = true;
    try {
      await update('histories');
    } catch (e) {
      KazumiLogger().e('WebDav: update history failed', error: e);
      rethrow;
    } finally {
      isHistorySyncing = false;
    }
  }

  Future<void> updateCollectibles() async {
    // don't try muliti thread update here
    // some webdav server may not support muliti thread write
    // you will get 423 locked error
    try {
      await update('collectibles');
      if (GStorage.collectChanges.isNotEmpty) {
        await update('collectchanges');
      }
    } catch (e) {
      KazumiLogger().e('WebDav: update collectibles failed', error: e);
      rethrow;
    }
  }

  Future<void> download(String boxName) async {
    String fileName = '$boxName.tmp';
    final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
    if (await existingFile.exists()) {
      await existingFile.delete();
    }
    await client.read2File('/kazumiSync/$fileName', existingFile.path,
        onProgress: (c, t) {
      // print(c / t);
    });
  }

  Future<void> downloadAndPatchHistory() async {
    if (isHistorySyncing) {
      KazumiLogger().w('WebDav: History is currently syncing');
      throw Exception('History is currently syncing');
    }
    isHistorySyncing = true;
    String fileName = 'histories.tmp';
    try {
      final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
      await download('histories');
      await GStorage.patchHistory(existingFile.path);
    } catch (e) {
      KazumiLogger()
          .e('WebDav: download and patch history failed', error: e);
      rethrow;
    } finally {
      isHistorySyncing = false;
    }
  }

  Future<void> syncCollectibles() async {
    List<CollectedBangumi> remoteCollectibles = [];
    List<CollectedBangumiChange> remoteChanges = [];

    final files = await client.readDir('/kazumiSync');
    final collectiblesExists = files.any((file) => file.name == 'collectibles.tmp');
    final changesExists = files.any((file) => file.name == 'collectchanges.tmp');

    // 如果云端啥都没有，直接上传本地的
    if (!collectiblesExists && !changesExists) {
      await updateCollectibles();
      return;
    }
    
    // 1. 下载文件
    List<Future<void>> downloadFutures = [];
    if (collectiblesExists) {
      downloadFutures.add(download('collectibles').catchError((e) {
        KazumiLogger().e('WebDav: download collectibles failed', error: e);
        throw Exception('WebDav: download collectibles failed');
      }));
    }
    if (changesExists) {
      downloadFutures.add(download('collectchanges').catchError((e) {
        KazumiLogger().e('WebDav: download collectchanges failed', error: e);
        throw Exception('WebDav: download collectchanges failed');
      }));
    }
    if (downloadFutures.isNotEmpty) {
      await Future.wait(downloadFutures);
    } 

    // 2. 解析文件内容
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

    // 3. 调用 GStorage 进行数据合并
    if (remoteChanges.isNotEmpty || remoteCollectibles.isNotEmpty) {
      await GStorage.patchCollectibles(remoteCollectibles, remoteChanges);
    }

    // 4. 将合并后的最新状态上传回 WebDAV
    await updateCollectibles();
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
