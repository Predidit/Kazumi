import 'dart:io';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:hive/hive.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';

class WebDav {
  late String webDavURL;
  late String webDavUsername;
  late String webDavPassword;
  late String fileName;
  late Directory webDavLocalTempDirectory;
  late webdav.Client client;

  WebDav._internal();
  static final WebDav _instance = WebDav._internal();
  factory WebDav() => _instance;

  Future init() async {
    fileName = 'histories.tmp';
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
      debug: true,
    );
    client.setHeaders({'accept-charset': 'utf-8'});
    try {
      debugPrint('webDav backup diretory not exists, creating');
      await client.mkdir('/kazumiSync');
      debugPrint('webDav backup diretory create success');
    } catch (_) {
      debugPrint('webDav backup diretory create failed');
    }
  }

  Future update() async {
    if (!await webDavLocalTempDirectory.exists()) {
      await webDavLocalTempDirectory.create(recursive: true);
    }
    final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
    if (await existingFile.exists()) {
      await existingFile.delete();
    }
    await GStorage.backupBox('histories', existingFile.path);
    try {
      await client.remove('/kazumiSync/$fileName.cache');
    } catch (_) {}
    await client.writeFromFile(existingFile.path, '/kazumiSync/$fileName.cache',
        onProgress: (c, t) {
      print(c / t);
    });
    try {
      await client.remove('/kazumiSync/$fileName');
    } catch (_) {
      debugPrint('webDav former backup file not exist');
    }
    await client.rename(
        '/kazumiSync/$fileName.cache', '/kazumiSync/$fileName', true);
  }

  Future download() async {
    if (!await webDavLocalTempDirectory.exists()) {
      await webDavLocalTempDirectory.create(recursive: true);
    }
    final existingFile = File('${webDavLocalTempDirectory.path}/$fileName');
    if (await existingFile.exists()) {
      await existingFile.delete();
    }
    await client.read2File('/kazumiSync/$fileName', existingFile.path,
        onProgress: (c, t) {
      print(c / t);
    });
    await GStorage.patchHistory(existingFile.path);
  }

  Future ping() async {
    await client.ping();
  }
}
