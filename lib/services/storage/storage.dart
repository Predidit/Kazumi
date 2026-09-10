import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:kazumi/hive_registrar.g.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/collect_storage.dart';
import 'package:kazumi/services/storage/history_storage.dart';
import 'package:kazumi/services/storage/settings_keys.dart';
import 'package:path_provider/path_provider.dart';

export 'package:kazumi/services/storage/settings_keys.dart';

class GStorage {
  // Legacy favorites are read only during migration.
  static late Box<BangumiItem> favorites;
  static late final HistoryStorage history;
  static late Box<String> shieldList;
  static late final Box<dynamic> _setting;
  static late Box<SearchHistory> searchHistory;
  static late Box<DownloadRecord> downloads;

  static String? _hivePath;

  static late final CollectStorage collection;

  static Future init() async {
    _hivePath = '${(await getApplicationSupportDirectory()).path}/hive';

    Hive.registerAdapters();

    favorites = await _openBoxSafe<BangumiItem>('favorites');
    final collectibles = await _openBoxSafe<CollectedBangumi>('collectibles');
    final histories = await _openBoxSafe<History>('histories');
    _setting = await _openBoxSafe<dynamic>('setting');
    var historyDeviceId = getSetting(SettingsKeys.historySyncDeviceId);
    if (historyDeviceId.isEmpty) {
      historyDeviceId = HistorySyncDevice.generateDeviceId();
      await putSetting(SettingsKeys.historySyncDeviceId, historyDeviceId);
    }
    history = HistoryStorage(
        histories, await Hive.openBox<dynamic>('historyjournal'),
        deviceId: historyDeviceId,
        initialSequence: getSetting(SettingsKeys.historySyncSequence));
    await history.initialize();
    final collectChanges =
        await _openBoxSafe<CollectedBangumiChange>('collectchanges');
    final journal = await Hive.openBox<dynamic>('collectjournal');
    collection = CollectStorage(collectibles, collectChanges, journal);
    await collection.initialize();
    shieldList = await _openBoxSafe<String>('shieldList');
    searchHistory = await _openBoxSafe<SearchHistory>('searchHistory');
    downloads = await _openBoxSafe<DownloadRecord>('downloads');
  }

  // Recovery may discard corrupt boxes; journals must bypass this helper.
  static Future<Box<T>> _openBoxSafe<T>(String boxName) async {
    try {
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      KazumiLogger().e(
          'GStorage: Box "$boxName" corrupted, attempting recovery',
          error: e);

      await _deleteBoxFiles(boxName);

      try {
        final box = await Hive.openBox<T>(boxName);
        KazumiLogger()
            .i('GStorage: Box "$boxName" recovered successfully (data lost)');
        return box;
      } catch (e2) {
        KazumiLogger()
            .e('GStorage: Failed to recover box "$boxName"', error: e2);
        rethrow;
      }
    }
  }

  static Future<void> _deleteBoxFiles(String boxName) async {
    if (_hivePath == null) return;

    final boxFile = File('$_hivePath/$boxName.hive');
    final lockFile = File('$_hivePath/$boxName.lock');

    try {
      if (await boxFile.exists()) {
        await boxFile.delete();
        KazumiLogger().i('GStorage: Deleted corrupted box file: $boxName.hive');
      }
      if (await lockFile.exists()) {
        await lockFile.delete();
        KazumiLogger().i('GStorage: Deleted lock file: $boxName.lock');
      }
    } catch (e) {
      KazumiLogger()
          .e('GStorage: Failed to delete box files for "$boxName"', error: e);
    }
  }

  static Future<List<History>> getHistoriesFromFile(String path) async =>
      (await _readBoxFile<History>(path, 'tempHistoryBox'))
          .map((history) => history.copy())
          .toList();

  static Future<List<CollectedBangumi>> getCollectiblesFromFile(String path) =>
      _readBoxFile<CollectedBangumi>(path, 'tempCollectiblesBox');

  static Future<List<CollectedBangumiChange>> getCollectChangesFromFile(
          String path) =>
      _readBoxFile<CollectedBangumiChange>(path, 'tempCollectChangesBox');

  static Future<List<T>> _readBoxFile<T>(String path, String boxName) async {
    final bytes = await File(path).readAsBytes();
    final box = await Hive.openBox(boxName, bytes: bytes);
    try {
      return box.values.cast<T>().toList();
    } finally {
      await box.close();
    }
  }

  static T getSetting<T>(
    SettingKey<T> key, {
    SettingContext context = const SettingContext(),
  }) {
    final defaultValue = key.resolveDefault(context);
    final storedValue = _setting.get(key.name);
    if (storedValue is T) {
      return storedValue;
    }
    return defaultValue;
  }

  static Future<void> putSetting<T>(SettingKey<T> key, T value) async {
    await _setting.put(key.name, value);
  }

  static Stream<void> watchSettings(Iterable<SettingKey<Object?>> keys) {
    final names = keys.map((key) => key.name).toSet();
    return _setting
        .watch()
        .where((event) => names.contains(event.key))
        .map((_) {});
  }

  static List<String> getStringListSettingByName(
    String key, {
    List<String> defaultValue = const [],
  }) {
    final storedValue = _setting.get(key);
    if (storedValue is List) {
      return storedValue.whereType<String>().toList();
    }
    return defaultValue;
  }

  static Future<void> putStringListSettingByName(
    String key,
    List<String> value,
  ) async {
    await _setting.put(key, value);
  }

  static Future<void> resetSettings(Iterable<SettingKey<Object?>> keys) async {
    await _setting.deleteAll(keys.map((key) => key.name));
    await _setting.flush();
  }

  static Future<void> resetPlayerSettings() async {
    await resetSettings(SettingsKeys.byGroup(SettingGroup.player));
  }

  static Future<void> resetDanmakuSettings() async {
    await resetSettings(SettingsKeys.byGroup(SettingGroup.danmaku));
  }

  GStorage._();
}
