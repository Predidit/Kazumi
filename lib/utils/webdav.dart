import 'dart:io';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';

class WebDav {
  late String webDavURL;
  late String webDavUsername;
  late String webDavPassword;
  late Directory webDavLocalTempDirectory;
  late webdav.Client client;

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
    await update('histories');
  }

  Future<void> updateCollectibles() async {
    await update('collectibles');
  }

  Future<void> downloadHistory() async {
    String fileName = 'histories.tmp';
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
    await GStorage.patchCollectibles(existingFile.path);
  }

  Future<void> ping() async {
    await client.ping();
  }
}
