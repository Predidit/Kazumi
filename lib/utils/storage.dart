import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/search/search_history_module.dart';

class GStorage {
  /// Don't use favorites box, it's replaced by collectibles.
  static late Box<BangumiItem> favorites;
  static late Box<CollectedBangumi> collectibles;
  static late Box<History> histories;
  static late Box<CollectedBangumiChange> collectChanges;
  static late Box<String> shieldList;
  static late final Box<dynamic> setting;
  static late Box<SearchHistory> searchHistory;

  static Future init() async {
    Hive.registerAdapter(BangumiItemAdapter());
    Hive.registerAdapter(BangumiTagAdapter());
    Hive.registerAdapter(CollectedBangumiAdapter());
    Hive.registerAdapter(ProgressAdapter());
    Hive.registerAdapter(HistoryAdapter());
    Hive.registerAdapter(CollectedBangumiChangeAdapter());
    Hive.registerAdapter(SearchHistoryAdapter());
    favorites = await Hive.openBox('favorites');
    collectibles = await Hive.openBox('collectibles');
    histories = await Hive.openBox('histories');
    setting = await Hive.openBox('setting');
    collectChanges = await Hive.openBox('collectchanges');
    shieldList = await Hive.openBox('shieldList');
    searchHistory = await Hive.openBox('searchHistory');
  }

  static Future<void> backupBox(String boxName, String backupFilePath) async {
    final appDocumentDir = await getApplicationSupportDirectory();
    final hiveBoxFile = File('${appDocumentDir.path}/hive/$boxName.hive');
    if (await hiveBoxFile.exists()) {
      await hiveBoxFile.copy(backupFilePath);
      print('Backup success: $backupFilePath');
    } else {
      print('Hive box not exists');
    }
  }

  static Future<void> patchHistory(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsBytes();
    final tempBox = await Hive.openBox('tempHistoryBox', bytes: backupContent);
    final tempBoxItems = tempBox.toMap().entries;

    for (var tempBoxItem in tempBoxItems) {
      if (histories.get(tempBoxItem.key) != null) {
        if (histories
            .get(tempBoxItem.key)!
            .lastWatchTime
            .isBefore(tempBoxItem.value.lastWatchTime)) {
          await histories.delete(tempBoxItem.key);
          await histories.put(tempBoxItem.key, tempBoxItem.value);
        }
      } else {
        await histories.put(tempBoxItem.key, tempBoxItem.value);
      }
    }
    await tempBox.close();
  }

  static Future<void> restoreCollectibles(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsBytes();
    final tempBox =
        await Hive.openBox('tempCollectiblesBox', bytes: backupContent);
    final tempBoxItems = tempBox.toMap().entries;
    debugPrint('webDav追番列表长度 ${tempBoxItems.length}');

    await collectibles.clear();
    for (var tempBoxItem in tempBoxItems) {
      await collectibles.put(tempBoxItem.key, tempBoxItem.value);
    }
    await tempBox.close();
  }

  static Future<List<CollectedBangumi>> getCollectiblesFromFile(
      String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsBytes();
    final tempBox =
        await Hive.openBox('tempCollectiblesBox', bytes: backupContent);
    final tempBoxItems = tempBox.toMap().entries;
    debugPrint('webDav追番列表长度 ${tempBoxItems.length}');

    final List<CollectedBangumi> collectibles = [];
    for (var tempBoxItem in tempBoxItems) {
      collectibles.add(tempBoxItem.value);
    }
    await tempBox.close();
    return collectibles;
  }

  static Future<List<CollectedBangumiChange>> getCollectChangesFromFile(
      String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsBytes();
    final tempBox =
        await Hive.openBox('tempCollectChangesBox', bytes: backupContent);
    final tempBoxItems = tempBox.toMap().entries;
    debugPrint('webDav追番变更列表长度 ${tempBoxItems.length}');

    final List<CollectedBangumiChange> collectChanges = [];
    for (var tempBoxItem in tempBoxItems) {
      collectChanges.add(tempBoxItem.value);
    }
    await tempBox.close();
    return collectChanges;
  }

  static Future<void> patchCollectibles(
      List<CollectedBangumi> remoteCollectibles,
      List<CollectedBangumiChange> remoteChanges) async {
    List<CollectedBangumi> localCollectibles = collectibles.values.toList();
    List<CollectedBangumiChange> localChanges = collectChanges.values.toList();

    final List<CollectedBangumiChange> newLocalChanges =
        localChanges.where((localChange) {
      return !remoteChanges
          .any((remoteChange) => remoteChange.id == localChange.id);
    }).toList();

    newLocalChanges.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Process local changes
    for (var change in newLocalChanges) {
      // For delete action, we don't need to look up the local collectible.
      // We can directly remove the item from the remote list.
      if (change.action == 3) {
        // Action 3: delete
        remoteCollectibles.removeWhere(
            (b) => b.bangumiItem.id == change.bangumiID);
      } else {
        // For add/update, we still need to look up the local collectible.
        final changedBangumiID = change.bangumiID.toString();
        for (var localCollect in localCollectibles) {
          if (localCollect.bangumiItem.id.toString() == changedBangumiID) {
            if (change.action == 1) {
              // Action 1: add
              final exists = remoteCollectibles
                  .any((b) => b.bangumiItem.id == localCollect.bangumiItem.id);
              if (!exists) {
                remoteCollectibles.add(localCollect);
              } else {
                final index = remoteCollectibles.indexWhere(
                    (b) => b.bangumiItem.id == localCollect.bangumiItem.id);
                localCollect.type = change.type;
                if (index != -1) {
                  // Update the entry with local data.
                  remoteCollectibles[index] = localCollect;
                }
              }
            } else if (change.action == 2) {
              // Action 2: update
              final index = remoteCollectibles.indexWhere(
                  (b) => b.bangumiItem.id == localCollect.bangumiItem.id);
              localCollect.type = change.type;
              if (index != -1) {
                // Update the entry with local data.
                remoteCollectibles[index] = localCollect;
              }
            }
            break;
          }
        }
      }
    }

    // merge local changes with remote changes
    final Map<int, CollectedBangumiChange> mergedMap = {};
    for (var change in remoteChanges) {
      mergedMap[change.id] = change;
    }
    for (var change in newLocalChanges) {
      if (!mergedMap.containsKey(change.id)) {
        mergedMap[change.id] = change;
      }
    }
    final List<CollectedBangumiChange> mergedChanges =
        mergedMap.values.toList();

    // Update local storage
    await collectibles.clear();
    for (var collect in remoteCollectibles) {
      await collectibles.put(collect.bangumiItem.id, collect);
    }
    await collectChanges.clear();
    for (var change in mergedChanges) {
      await collectChanges.put(change.id, change);
    }
  }

  // Prevent instantiation
  GStorage._();
}

class SettingBoxKey {
  static const String hAenable = 'hAenable',
      hardwareDecoder = 'hardwareDecoder',
      searchEnhanceEnable = 'searchEnhanceEnable',
      autoUpdate = 'autoUpdate',
      alwaysOntop = 'alwaysOntop',
      defaultPlaySpeed = 'defaultPlaySpeed',
      defaultAspectRatioType = 'defaultAspectRatioType',
      buttonSkipTime = 'buttonSkipTime',
      arrowKeySkipTime = 'arrowKeySkipTime',
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
      danmakuEnabledByDefault = 'danmakuEnabledByDefault',
      danmakuBiliBiliSource = 'danmakuBiliBiliSource',
      danmakuGamerSource = 'danmakuGamerSource',
      danmakuDanDanSource = 'danmakuDanDanSource',
      danmakuFontWeight = 'danmakuFontWeight',
      themeMode = 'themeMode',
      themeColor = 'themeColor',
      privateMode = 'privateMode',
      autoPlay = 'autoPlay',
      playResume = 'playResume',
      showPlayerError = 'showPlayerError',
      oledEnhance = 'oledEnhance',
      displayMode = 'displayMode',
      enableGitProxy = 'enableGitProxy',
      enableSystemProxy = 'enableSystemProxy',
      isWideScreen = 'isWideScreen',
      webDavEnable = 'webDavEnable',
      webDavEnableHistory = 'webDavEnableHistory',
      webDavEnableCollect = 'webDavEnableCollect',
      webDavURL = 'webDavURL',
      webDavUsername = 'webDavUsername',
      webDavPassword = 'webDavPasswd',
      lowMemoryMode = 'lowMemoryMode',
      showWindowButton = 'showWindowButton',
      useDynamicColor = 'useDynamicColor',
      exitBehavior = 'exitBehavior',
      playerDebugMode = 'playerDebugMode',
      syncPlayEndPoint = 'syncPlayEndPoint',
      androidEnableOpenSLES = 'androidEnableOpenSLES',
      defaultSuperResolutionType = 'defaultSuperResolutionType',
      superResolutionWarn = 'superResolutionWarn',
      playerDisableAnimations = 'playerDisableAnimations';
}
