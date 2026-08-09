import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/hive_registrar.g.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_sync_merger.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/services/storage/history_storage_coordinator.dart';

import 'package:kazumi/services/storage/settings_keys.dart';
export 'package:kazumi/services/storage/settings_keys.dart';

class GStorage {
  /// Don't use favorites box, it's replaced by collectibles.
  static late Box<BangumiItem> favorites;
  static late Box<CollectedBangumi> collectibles;
  static late Box<History> histories;
  static late Box<CollectedBangumiChange> collectChanges;
  static late Box<String> shieldList;
  static late final Box<dynamic> _setting;
  static late Box<SearchHistory> searchHistory;
  static late Box<DownloadRecord> downloads;

  /// Hive directory path, initialized during init()
  static String? _hivePath;

  /// Queue to serialize write operations
  static Future<void> _collectChangesWriteQueue = Future.value();

  /// Next ID
  static int _nextCollectChangeId = 0;

  /// Flag to indicate if the next ID has initialized
  static bool _collectChangeIdInitialized = false;

  /// Ensure collect-related write sequentially
  static Future<T> _runCollectChangesWriteExclusive<T>(
    Future<T> Function() action,
  ) {
    final completer = Completer<T>();
    final previousWrite = _collectChangesWriteQueue;

    _collectChangesWriteQueue = (() async {
      try {
        await previousWrite;
      } catch (_) {}

      try {
        completer.complete(await action());
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
    })();

    return completer.future;
  }

  /// init id generator
  static void _initializeNextCollectChangeIdLocked() {
    if (_collectChangeIdInitialized) {
      return;
    }

    var maxExistingId = 0;
    for (final key in collectChanges.keys) {
      if (key is int && key > maxExistingId) {
        maxExistingId = key;
      }
    }

    _nextCollectChangeId = maxExistingId;
    _collectChangeIdInitialized = true;
  }

  /// Generate id for collect change
  static int _generateCollectChangeIdLocked() {
    _initializeNextCollectChangeIdLocked();

    final currentSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Ensure ID is greater than any existing ID, or equal to current timestamp.
    var nextId = _nextCollectChangeId < currentSeconds
        ? currentSeconds
        : _nextCollectChangeId + 1;
    while (collectChanges.containsKey(nextId)) {
      nextId++;
    }
    _nextCollectChangeId = nextId;
    return nextId;
  }

  /// Append a new collect change
  static Future<CollectedBangumiChange> appendCollectChange({
    required int bangumiId,
    required int action,
    required int type,
    int? timestamp,
  }) {
    return _runCollectChangesWriteExclusive(() async {
      final change = CollectedBangumiChange(
        _generateCollectChangeIdLocked(),
        bangumiId,
        action,
        type,
        timestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );
      await collectChanges.put(change.id, change);
      await collectChanges.flush();
      return change;
    });
  }

  /// Update an existing collect change
  static Future<void> putCollectChange(CollectedBangumiChange change) {
    return _runCollectChangesWriteExclusive(() async {
      _initializeNextCollectChangeIdLocked();
      if (change.id > _nextCollectChangeId) {
        _nextCollectChangeId = change.id;
      }
      await collectChanges.put(change.id, change);
      await collectChanges.flush();
    });
  }

  /// Put a collectible using the same write queue
  static Future<void> putCollectible(CollectedBangumi collectible) {
    return _runCollectChangesWriteExclusive(() async {
      await collectibles.put(collectible.bangumiItem.id, collectible);
      await collectibles.flush();
    });
  }

  /// Delete a collectible using the shared collect write queue.
  static Future<void> deleteCollectible(int bangumiId) {
    return _runCollectChangesWriteExclusive(() async {
      await collectibles.delete(bangumiId);
      await collectibles.flush();
    });
  }

  static Future init() async {
    _hivePath = '${(await getApplicationSupportDirectory()).path}/hive';

    Hive.registerAdapters();

    // Open each box with automatic recovery on corruption
    favorites = await _openBoxSafe<BangumiItem>('favorites');
    collectibles = await _openBoxSafe<CollectedBangumi>('collectibles');
    histories = await _openBoxSafe<History>('histories');
    _setting = await _openBoxSafe<dynamic>('setting');
    collectChanges =
        await _openBoxSafe<CollectedBangumiChange>('collectchanges');
    shieldList = await _openBoxSafe<String>('shieldList');
    searchHistory = await _openBoxSafe<SearchHistory>('searchHistory');
    downloads = await _openBoxSafe<DownloadRecord>('downloads');
  }

  /// Open a Hive box with automatic recovery on corruption.
  /// If the box is corrupted, delete it and create a new empty one.
  static Future<Box<T>> _openBoxSafe<T>(String boxName) async {
    try {
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      KazumiLogger().e(
          'GStorage: Box "$boxName" corrupted, attempting recovery',
          error: e);

      // Delete the corrupted box files
      await _deleteBoxFiles(boxName);

      // Try to open again (will create a new empty box)
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

  /// Delete Hive box files for a given box name
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

  static Future<void> backupBox(String boxName, String backupFilePath) async {
    final appDocumentDir = await getApplicationSupportDirectory();
    final hiveBoxFile = File('${appDocumentDir.path}/hive/$boxName.hive');
    if (await hiveBoxFile.exists()) {
      await hiveBoxFile.copy(backupFilePath);
      KazumiLogger().i('GStorage: backup success: $backupFilePath');
    } else {
      KazumiLogger().w('GStorage: Hive box does not exist: $boxName');
    }
  }

  static Future<void> patchHistory(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsBytes();
    final tempBox = await Hive.openBox('tempHistoryBox', bytes: backupContent);
    try {
      final tempBoxItems = tempBox.toMap().entries;
      await HistoryStorageCoordinator().run(() async {
        for (final tempBoxItem in tempBoxItems) {
          final tempHistory = tempBoxItem.value as History;
          tempHistory.entryKind =
              HistoryEntryKind.normalize(tempHistory.entryKind);
          final targetKey = tempHistory.key;
          final existing = histories.get(targetKey);
          if (existing == null ||
              existing.lastWatchTime.isBefore(tempHistory.lastWatchTime)) {
            await histories.put(targetKey, tempHistory);
          }
        }
      });
    } finally {
      await tempBox.close();
    }
  }

  static Future<void> restoreCollectibles(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsBytes();
    final tempBox =
        await Hive.openBox('tempCollectiblesBox', bytes: backupContent);
    final tempBoxItems = tempBox.toMap().entries;
    KazumiLogger().i(
        'WebDav: restoring collectibles. tempCollectiblesBox length ${tempBoxItems.length}');

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
    KazumiLogger().i(
        'WebDav: get collectibles from file. tempCollectiblesBox length ${tempBoxItems.length}');

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
    KazumiLogger().i(
        'WebDav: get collectChanges from file. tempCollectChangesBox length ${tempBoxItems.length}');

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
    await _runCollectChangesWriteExclusive(() async {
      final mergeResult = CollectSyncMerger.mergeWebDav(
        localCollectibles: collectibles.values.toList(),
        localChanges: collectChanges.values.toList(),
        remoteCollectibles: remoteCollectibles,
        remoteChanges: remoteChanges,
      );

      // Update local storage
      await collectibles.clear();
      for (var collect in mergeResult.collectibles) {
        await collectibles.put(collect.bangumiItem.id, collect);
      }
      await collectibles.flush();

      await collectChanges.clear();
      for (var change in mergeResult.changes) {
        await collectChanges.put(change.id, change);
      }
      await collectChanges.flush();

      _collectChangeIdInitialized = false;
      _initializeNextCollectChangeIdLocked();
    });
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

  /// Flushes the application data that is included in a backup.
  static Future<void> flushBackupData() async {
    await _runCollectChangesWriteExclusive(() async {
      await collectibles.flush();
    });
    await HistoryStorageCoordinator().run(() async {
      await histories.flush();
    });
    await _setting.flush();
  }

  static Future<Uint8List> readBackupBoxBytes(String boxName) async {
    await flushBackupData();
    final hivePath = _hivePath;
    if (hivePath == null) {
      throw StateError('GStorage has not been initialized');
    }
    final file = File('$hivePath/$boxName.hive');
    if (!await file.exists()) {
      throw FileSystemException('Hive box file does not exist', file.path);
    }
    return file.readAsBytes();
  }

  static int backupBoxLength(String boxName) {
    switch (boxName) {
      case 'collectibles':
        return collectibles.length;
      case 'histories':
        return histories.length;
      case 'setting':
        return _setting.length;
      default:
        throw ArgumentError('Unsupported backup box: $boxName');
    }
  }

  static Future<void> replaceBackupBoxBytes(
    String boxName,
    Uint8List bytes,
  ) async {
    switch (boxName) {
      case 'collectibles':
        final box = await _openBackupBox<CollectedBangumi>(boxName, bytes);
        try {
          await _runCollectChangesWriteExclusive(() async {
            await collectibles.clear();
            await collectibles.putAll(box.toMap());
            await collectibles.flush();
          });
        } finally {
          await box.close();
        }
      case 'histories':
        final box = await _openBackupBox<History>(boxName, bytes);
        try {
          await HistoryStorageCoordinator().run(() async {
            await histories.clear();
            await histories.putAll(box.toMap());
            await histories.flush();
          });
        } finally {
          await box.close();
        }
      case 'setting':
        final box = await _openBackupBox<dynamic>(boxName, bytes);
        try {
          await _setting.clear();
          await _setting.putAll(box.toMap());
          await _setting.flush();
        } finally {
          await box.close();
        }
      default:
        throw ArgumentError('Unsupported backup box: $boxName');
    }
  }

  static Future<Box<T>> _openBackupBox<T>(
    String boxName,
    Uint8List bytes,
  ) {
    final name =
        'backupRestore_${boxName}_${DateTime.now().microsecondsSinceEpoch}';
    return Hive.openBox<T>(name, bytes: bytes);
  }

  /// Validates a serialized box against the adapters and value type of the
  /// target box without mutating the live box.
  static Future<void> validateBackupBoxBytes({
    required String boxName,
    required Uint8List bytes,
  }) async {
    final validationName =
        'backupValidation_${boxName}_${DateTime.now().microsecondsSinceEpoch}';
    final validationBox = await Hive.openBox<dynamic>(
      validationName,
      bytes: bytes,
    );
    try {
      switch (boxName) {
        case 'collectibles':
          for (final value in validationBox.values) {
            if (value is! CollectedBangumi) {
              throw FormatException(
                'Backup value type mismatch for $boxName: '
                '${value.runtimeType}',
              );
            }
          }
        case 'histories':
          for (final value in validationBox.values) {
            if (value is! History) {
              throw FormatException(
                'Backup value type mismatch for $boxName: '
                '${value.runtimeType}',
              );
            }
          }
        case 'setting':
          break;
        default:
          throw ArgumentError('Unsupported backup box: $boxName');
      }
    } finally {
      await validationBox.close();
    }
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
