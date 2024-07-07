import 'dart:io';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';

class GStorage {
  static late Box<BangumiItem> favorites;
  static late Box<History> histories;
  static late final Box<dynamic> setting;

  static Future init() async {
    Hive.registerAdapter(BangumiItemAdapter());
    Hive.registerAdapter(ProgressAdapter());
    Hive.registerAdapter(HistoryAdapter());
    favorites = await Hive.openBox('favorites');
    histories = await Hive.openBox('histories');
    setting = await Hive.openBox('setting');
  }

  static Future<void> backupBox(String boxName, String backupFilePath) async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    final hiveBoxFile = File('${appDocumentDir.path}/hive/$boxName.hive');
    if (await hiveBoxFile.exists()) {
      await hiveBoxFile.copy(backupFilePath);
      print('Backup success: ${backupFilePath}');
    } else {
      print('Hive box not exists');
    }
  }

  static Future<void> restoreHistory(String backupFilePath) async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    final backupFile = File(backupFilePath);
    final hiveBoxFile = File('${appDocumentDir.path}/hive/histories.hive');
    final hiveBoxLockFile = File('${appDocumentDir.path}/hive/histories.lock');
    histories.close();
    try {
      await hiveBoxFile.delete();
      try {
        await hiveBoxLockFile.delete();
      } catch (_) {}
      await backupFile.copy(hiveBoxFile.path);
    } catch (e) {
      print('Hive box restore error: $e');
    }
    histories = await Hive.openBox('histories');
  }

  static Future<void> patchHistory(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsBytes();
    final tempBox = await Hive.openBox('tempBox', bytes: backupContent);
    final tempBoxItems = tempBox.toMap().entries;

    for (var tempBoxItem in tempBoxItems) {
      if (histories.get(tempBoxItem.key) != null) {
        if (histories.get(tempBoxItem.key)!.lastWatchTime.isBefore(tempBoxItem.value.lastWatchTime)) {
          histories.delete(tempBoxItem.key);
          histories.put(tempBoxItem.key, tempBoxItem.value);
        }
      } else {
        histories.put(tempBoxItem.key, tempBoxItem.value);
      }
    }
    await tempBox.close();
  }

  // 阻止实例化
  GStorage._();
}

class SettingBoxKey {
  static const String hAenable = 'hAenable',
      searchEnhanceEnable = 'searchEnhanceEnable',
      autoUpdate = 'autoUpdate',
      alwaysOntop = 'alwaysOntop',
      danmakuEnhance = 'danmakuEnhance',
      danmakuBorder = 'danmakuBorder',
      danmakuOpacity = 'danmakuOpacity',
      danmakuFontSize = 'danmakuFontSize',
      danmakuTop = 'danmakuTop',
      danmakuScroll = 'danmakuScroll',
      danmakuBottom = 'danmakuBottom',
      danmakuMassive = 'danmakuMassive',
      danmakuArea = 'danmakuArea',
      danmakuColor = 'danmakuColor',
      themeMode = 'themeMode',
      themeColor = 'themeColor',
      privateMode = 'privateMode',
      autoPlay = 'autoPlay',
      playResume = 'playResume',
      oledEnhance = 'oledEnhance',
      displayMode = 'displayMode',
      enableGitProxy = 'enableGitProxy',
      enableSystemProxy = 'enableSystemProxy',
      isWideScreen = 'isWideScreen',
      webDavEnable = 'webDavEnable',
      webDavURL = 'webDavURL',
      webDavUsername = 'webDavUsername',
      webDavPassword = 'webDavPasswd';
}
