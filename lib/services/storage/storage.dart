import 'dart:async';
import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_sync_merger.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/modules/download/download_module.dart';

enum SettingGroup {
  player,
  danmaku,
  theme,
  interface,
  proxy,
  webdav,
  download,
  bangumi,
  collect,
  sync,
  update,
  misc,
}

class SettingContext {
  const SettingContext({this.compactLayout = false});

  final bool compactLayout;
}

class SettingKey<T> {
  const SettingKey(
    this.name,
    this.defaultValue, {
    required this.group,
    this.defaultResolver,
  });

  final String name;
  final T defaultValue;
  final SettingGroup group;
  final T Function(SettingContext context)? defaultResolver;

  T resolveDefault(SettingContext context) {
    return defaultResolver?.call(context) ?? defaultValue;
  }
}

// Add new settings here. SettingsKeys is the public typed registry used by
// callers; new keys can use literal string names directly.
class SettingsKeys {
  static const hAenable = SettingKey<bool>(
    _SettingBoxKey.hAenable,
    true,
    group: SettingGroup.player,
  );
  static const hardwareDecoder = SettingKey<String>(
    _SettingBoxKey.hardwareDecoder,
    'auto-safe',
    group: SettingGroup.player,
  );
  static const searchEnhanceEnable = SettingKey<bool>(
    _SettingBoxKey.searchEnhanceEnable,
    true,
    group: SettingGroup.misc,
  );
  static const autoUpdate = SettingKey<bool>(
    _SettingBoxKey.autoUpdate,
    true,
    group: SettingGroup.update,
  );
  static const alwaysOntop = SettingKey<bool>(
    _SettingBoxKey.alwaysOntop,
    false,
    group: SettingGroup.misc,
  );
  static const defaultPlaySpeed = SettingKey<double>(
    _SettingBoxKey.defaultPlaySpeed,
    1.0,
    group: SettingGroup.player,
  );
  static const defaultShortcutForwardPlaySpeed = SettingKey<double>(
    _SettingBoxKey.defaultShortcutForwardPlaySpeed,
    2.0,
    group: SettingGroup.player,
  );
  static const defaultAspectRatioType = SettingKey<int>(
    _SettingBoxKey.defaultAspectRatioType,
    1,
    group: SettingGroup.player,
  );
  static const buttonSkipTime = SettingKey<int>(
    _SettingBoxKey.buttonSkipTime,
    80,
    group: SettingGroup.player,
  );
  static const arrowKeySkipTime = SettingKey<int>(
    _SettingBoxKey.arrowKeySkipTime,
    10,
    group: SettingGroup.player,
  );
  static const danmakuEnhance = SettingKey<bool>(
    _SettingBoxKey.danmakuEnhance,
    true,
    group: SettingGroup.danmaku,
  );
  static const danmakuBorder = SettingKey<bool>(
    _SettingBoxKey.danmakuBorder,
    true,
    group: SettingGroup.danmaku,
  );
  static const danmakuBorderSize = SettingKey<double>(
    _SettingBoxKey.danmakuBorderSize,
    1.5,
    group: SettingGroup.danmaku,
  );
  static const danmakuOpacity = SettingKey<double>(
    _SettingBoxKey.danmakuOpacity,
    1.0,
    group: SettingGroup.danmaku,
  );
  static final danmakuFontSize = SettingKey<double>(
    _SettingBoxKey.danmakuFontSize,
    25.0,
    group: SettingGroup.danmaku,
    defaultResolver: (context) => context.compactLayout ? 16.0 : 25.0,
  );
  static const danmakuTop = SettingKey<bool>(
    _SettingBoxKey.danmakuTop,
    true,
    group: SettingGroup.danmaku,
  );
  static const danmakuScroll = SettingKey<bool>(
    _SettingBoxKey.danmakuScroll,
    true,
    group: SettingGroup.danmaku,
  );
  static const danmakuBottom = SettingKey<bool>(
    _SettingBoxKey.danmakuBottom,
    false,
    group: SettingGroup.danmaku,
  );
  static const danmakuMassive = SettingKey<bool>(
    _SettingBoxKey.danmakuMassive,
    false,
    group: SettingGroup.danmaku,
  );
  static const danmakuDeduplication = SettingKey<bool>(
    _SettingBoxKey.danmakuDeduplication,
    false,
    group: SettingGroup.danmaku,
  );
  static const danmakuArea = SettingKey<double>(
    _SettingBoxKey.danmakuArea,
    1.0,
    group: SettingGroup.danmaku,
  );
  static const danmakuColor = SettingKey<bool>(
    _SettingBoxKey.danmakuColor,
    true,
    group: SettingGroup.danmaku,
  );
  static const danmakuDuration = SettingKey<double>(
    _SettingBoxKey.danmakuDuration,
    8.0,
    group: SettingGroup.danmaku,
  );
  static const danmakuLineHeight = SettingKey<double>(
    _SettingBoxKey.danmakuLineHeight,
    1.6,
    group: SettingGroup.danmaku,
  );
  static const danmakuTimeOffset = SettingKey<double>(
    _SettingBoxKey.danmakuTimeOffset,
    0.0,
    group: SettingGroup.danmaku,
  );
  static const danmakuEnabledByDefault = SettingKey<bool>(
    _SettingBoxKey.danmakuEnabledByDefault,
    false,
    group: SettingGroup.danmaku,
  );
  static const danmakuBiliBiliSource = SettingKey<bool>(
    _SettingBoxKey.danmakuBiliBiliSource,
    true,
    group: SettingGroup.danmaku,
  );
  static const danmakuGamerSource = SettingKey<bool>(
    _SettingBoxKey.danmakuGamerSource,
    true,
    group: SettingGroup.danmaku,
  );
  static const danmakuDanDanSource = SettingKey<bool>(
    _SettingBoxKey.danmakuDanDanSource,
    true,
    group: SettingGroup.danmaku,
  );
  static const danmakuFontWeight = SettingKey<int>(
    _SettingBoxKey.danmakuFontWeight,
    4,
    group: SettingGroup.danmaku,
  );
  static const danmakuFollowSpeed = SettingKey<bool>(
    _SettingBoxKey.danmakuFollowSpeed,
    true,
    group: SettingGroup.danmaku,
  );
  static const themeMode = SettingKey<String>(
    _SettingBoxKey.themeMode,
    'system',
    group: SettingGroup.theme,
  );
  static const themeColor = SettingKey<String>(
    _SettingBoxKey.themeColor,
    'default',
    group: SettingGroup.theme,
  );
  static const privateMode = SettingKey<bool>(
    _SettingBoxKey.privateMode,
    false,
    group: SettingGroup.player,
  );
  static const autoPlay = SettingKey<bool>(
    _SettingBoxKey.autoPlay,
    true,
    group: SettingGroup.player,
  );
  static const autoPlayNext = SettingKey<bool>(
    _SettingBoxKey.autoPlayNext,
    true,
    group: SettingGroup.player,
  );
  static const playResume = SettingKey<bool>(
    _SettingBoxKey.playResume,
    true,
    group: SettingGroup.player,
  );
  static const showPlayerError = SettingKey<bool>(
    _SettingBoxKey.showPlayerError,
    true,
    group: SettingGroup.player,
  );
  static const oledEnhance = SettingKey<bool>(
    _SettingBoxKey.oledEnhance,
    false,
    group: SettingGroup.theme,
  );
  static const displayMode = SettingKey<String?>(
    _SettingBoxKey.displayMode,
    null,
    group: SettingGroup.interface,
  );
  static const enableGitProxy = SettingKey<bool>(
    _SettingBoxKey.enableGitProxy,
    false,
    group: SettingGroup.proxy,
  );
  static const enableBangumiProxy = SettingKey<bool>(
    _SettingBoxKey.enableBangumiProxy,
    false,
    group: SettingGroup.proxy,
  );
  static const enableSystemProxy = SettingKey<bool>(
    _SettingBoxKey.enableSystemProxy,
    false,
    group: SettingGroup.proxy,
  );
  static const defaultStartupPage = SettingKey<String>(
    _SettingBoxKey.defaultStartupPage,
    '/tab/popular/',
    group: SettingGroup.interface,
  );
  static const isWideScreen = SettingKey<bool>(
    _SettingBoxKey.isWideScreen,
    false,
    group: SettingGroup.interface,
  );
  static const webDavEnable = SettingKey<bool>(
    _SettingBoxKey.webDavEnable,
    false,
    group: SettingGroup.webdav,
  );
  static const webDavEnableHistory = SettingKey<bool>(
    _SettingBoxKey.webDavEnableHistory,
    false,
    group: SettingGroup.webdav,
  );
  static const webDavEnableCollect = SettingKey<bool>(
    _SettingBoxKey.webDavEnableCollect,
    false,
    group: SettingGroup.webdav,
  );
  static const webDavURL = SettingKey<String>(
    _SettingBoxKey.webDavURL,
    '',
    group: SettingGroup.webdav,
  );
  static const webDavUsername = SettingKey<String>(
    _SettingBoxKey.webDavUsername,
    '',
    group: SettingGroup.webdav,
  );
  static const webDavPassword = SettingKey<String>(
    _SettingBoxKey.webDavPassword,
    '',
    group: SettingGroup.webdav,
  );
  static const lowMemoryMode = SettingKey<bool>(
    _SettingBoxKey.lowMemoryMode,
    false,
    group: SettingGroup.player,
  );
  static const showWindowButton = SettingKey<bool>(
    _SettingBoxKey.showWindowButton,
    false,
    group: SettingGroup.theme,
  );
  static const useDynamicColor = SettingKey<bool>(
    _SettingBoxKey.useDynamicColor,
    false,
    group: SettingGroup.theme,
  );
  static const exitBehavior = SettingKey<int>(
    _SettingBoxKey.exitBehavior,
    2,
    group: SettingGroup.interface,
  );
  static const playerDebugMode = SettingKey<bool>(
    _SettingBoxKey.playerDebugMode,
    false,
    group: SettingGroup.player,
  );
  static const syncPlayEndPoint = SettingKey<String>(
    _SettingBoxKey.syncPlayEndPoint,
    '127.0.0.1:8999',
    group: SettingGroup.player,
  );
  static const androidEnableOpenSLES = SettingKey<bool>(
    _SettingBoxKey.androidEnableOpenSLES,
    true,
    group: SettingGroup.player,
  );
  static const androidVideoRenderer = SettingKey<String>(
    _SettingBoxKey.androidVideoRenderer,
    'auto',
    group: SettingGroup.player,
  );
  static const androidAutoEnterPIP = SettingKey<bool>(
    _SettingBoxKey.androidAutoEnterPIP,
    false,
    group: SettingGroup.player,
  );
  static const defaultSuperResolutionType = SettingKey<int>(
    _SettingBoxKey.defaultSuperResolutionType,
    1,
    group: SettingGroup.player,
  );
  static const superResolutionWarn = SettingKey<bool>(
    _SettingBoxKey.superResolutionWarn,
    false,
    group: SettingGroup.player,
  );
  static const playerDisableAnimations = SettingKey<bool>(
    _SettingBoxKey.playerDisableAnimations,
    false,
    group: SettingGroup.player,
  );
  static const playerLogLevel = SettingKey<int>(
    _SettingBoxKey.playerLogLevel,
    2,
    group: SettingGroup.player,
  );
  static const searchNotShowWatchedBangumis = SettingKey<bool>(
    _SettingBoxKey.searchNotShowWatchedBangumis,
    false,
    group: SettingGroup.collect,
  );
  static const searchNotShowAbandonedBangumis = SettingKey<bool>(
    _SettingBoxKey.searchNotShowAbandonedBangumis,
    false,
    group: SettingGroup.collect,
  );
  static const timelineNotShowAbandonedBangumis = SettingKey<bool>(
    _SettingBoxKey.timelineNotShowAbandonedBangumis,
    false,
    group: SettingGroup.collect,
  );
  static const timelineNotShowWatchedBangumis = SettingKey<bool>(
    _SettingBoxKey.timelineNotShowWatchedBangumis,
    false,
    group: SettingGroup.collect,
  );
  static const timelineOnlyShowWatchingBangumis = SettingKey<bool>(
    _SettingBoxKey.timelineOnlyShowWatchingBangumis,
    false,
    group: SettingGroup.collect,
  );
  static const useSystemFont = SettingKey<bool>(
    _SettingBoxKey.useSystemFont,
    false,
    group: SettingGroup.theme,
  );
  static const forceAdBlocker = SettingKey<bool>(
    _SettingBoxKey.forceAdBlocker,
    false,
    group: SettingGroup.player,
  );
  static const backgroundPlayback = SettingKey<bool>(
    _SettingBoxKey.backgroundPlayback,
    false,
    group: SettingGroup.player,
  );
  static const proxyEnable = SettingKey<bool>(
    _SettingBoxKey.proxyEnable,
    false,
    group: SettingGroup.proxy,
  );
  static const proxyConfigured = SettingKey<bool>(
    _SettingBoxKey.proxyConfigured,
    false,
    group: SettingGroup.proxy,
  );
  static const proxyUrl = SettingKey<String>(
    _SettingBoxKey.proxyUrl,
    '',
    group: SettingGroup.proxy,
  );
  static const proxyTestUrl = SettingKey<String>(
    _SettingBoxKey.proxyTestUrl,
    '',
    group: SettingGroup.proxy,
  );
  static const showRating = SettingKey<bool>(
    _SettingBoxKey.showRating,
    true,
    group: SettingGroup.interface,
  );
  static const downloadParallelEpisodes = SettingKey<int>(
    _SettingBoxKey.downloadParallelEpisodes,
    2,
    group: SettingGroup.download,
  );
  static const downloadParallelSegments = SettingKey<int>(
    _SettingBoxKey.downloadParallelSegments,
    3,
    group: SettingGroup.download,
  );
  static const downloadDanmaku = SettingKey<bool>(
    _SettingBoxKey.downloadDanmaku,
    true,
    group: SettingGroup.download,
  );
  static const shortcutDialogShown = SettingKey<bool>(
    _SettingBoxKey.shortcutDialogShown,
    false,
    group: SettingGroup.misc,
  );
  static const bangumiSyncEnable = SettingKey<bool>(
    _SettingBoxKey.bangumiSyncEnable,
    false,
    group: SettingGroup.bangumi,
  );
  static const bangumiAccessToken = SettingKey<String>(
    _SettingBoxKey.bangumiAccessToken,
    '',
    group: SettingGroup.bangumi,
  );
  static const bangumiSyncPriority = SettingKey<int>(
    _SettingBoxKey.bangumiSyncPriority,
    0,
    group: SettingGroup.bangumi,
  );
  static const bangumiImmediateSyncToastEnable = SettingKey<bool>(
    _SettingBoxKey.bangumiImmediateSyncToastEnable,
    true,
    group: SettingGroup.bangumi,
  );
  static const brightnessVolumeGesture = SettingKey<bool>(
    _SettingBoxKey.brightnessVolumeGesture,
    true,
    group: SettingGroup.player,
  );
  static const historySyncDeviceId = SettingKey<String>(
    _SettingBoxKey.historySyncDeviceId,
    '',
    group: SettingGroup.sync,
  );
  static const historySyncSequence = SettingKey<int>(
    _SettingBoxKey.historySyncSequence,
    0,
    group: SettingGroup.sync,
  );
  static const historySyncSnapshotInitialized = SettingKey<bool>(
    _SettingBoxKey.historySyncSnapshotInitialized,
    false,
    group: SettingGroup.sync,
  );

  static final List<SettingKey<Object?>> all = [
    hAenable,
    hardwareDecoder,
    searchEnhanceEnable,
    autoUpdate,
    alwaysOntop,
    defaultPlaySpeed,
    defaultShortcutForwardPlaySpeed,
    defaultAspectRatioType,
    buttonSkipTime,
    arrowKeySkipTime,
    danmakuEnhance,
    danmakuBorder,
    danmakuBorderSize,
    danmakuOpacity,
    danmakuFontSize,
    danmakuTop,
    danmakuScroll,
    danmakuBottom,
    danmakuMassive,
    danmakuDeduplication,
    danmakuArea,
    danmakuColor,
    danmakuDuration,
    danmakuLineHeight,
    danmakuTimeOffset,
    danmakuEnabledByDefault,
    danmakuBiliBiliSource,
    danmakuGamerSource,
    danmakuDanDanSource,
    danmakuFontWeight,
    danmakuFollowSpeed,
    themeMode,
    themeColor,
    privateMode,
    autoPlay,
    autoPlayNext,
    playResume,
    showPlayerError,
    oledEnhance,
    displayMode,
    enableGitProxy,
    enableBangumiProxy,
    enableSystemProxy,
    defaultStartupPage,
    isWideScreen,
    webDavEnable,
    webDavEnableHistory,
    webDavEnableCollect,
    webDavURL,
    webDavUsername,
    webDavPassword,
    lowMemoryMode,
    showWindowButton,
    useDynamicColor,
    exitBehavior,
    playerDebugMode,
    syncPlayEndPoint,
    androidEnableOpenSLES,
    androidVideoRenderer,
    androidAutoEnterPIP,
    defaultSuperResolutionType,
    superResolutionWarn,
    playerDisableAnimations,
    playerLogLevel,
    searchNotShowWatchedBangumis,
    searchNotShowAbandonedBangumis,
    timelineNotShowAbandonedBangumis,
    timelineNotShowWatchedBangumis,
    timelineOnlyShowWatchingBangumis,
    useSystemFont,
    forceAdBlocker,
    backgroundPlayback,
    proxyEnable,
    proxyConfigured,
    proxyUrl,
    proxyTestUrl,
    showRating,
    downloadParallelEpisodes,
    downloadParallelSegments,
    downloadDanmaku,
    shortcutDialogShown,
    bangumiSyncEnable,
    bangumiAccessToken,
    bangumiSyncPriority,
    bangumiImmediateSyncToastEnable,
    brightnessVolumeGesture,
    historySyncDeviceId,
    historySyncSequence,
    historySyncSnapshotInitialized,
  ];

  static List<SettingKey<Object?>> byGroup(SettingGroup group) {
    return [
      for (final key in all)
        if (key.group == group) key
    ];
  }

  SettingsKeys._();
}

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

    Hive.registerAdapter(BangumiItemAdapter());
    Hive.registerAdapter(BangumiTagAdapter());
    Hive.registerAdapter(CollectedBangumiAdapter());
    Hive.registerAdapter(ProgressAdapter());
    Hive.registerAdapter(HistoryAdapter());
    Hive.registerAdapter(CollectedBangumiChangeAdapter());
    Hive.registerAdapter(SearchHistoryAdapter());
    Hive.registerAdapter(DownloadRecordAdapter());
    Hive.registerAdapter(DownloadEpisodeAdapter());

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

// Historical Hive key names used by settings created before the typed registry.
// Keep these strings stable so existing users keep their saved settings.
// New settings do not need to be added here unless they intentionally reuse an
// existing persisted key.
class _SettingBoxKey {
  static const String hAenable = 'hAenable',
      hardwareDecoder = 'hardwareDecoder',
      searchEnhanceEnable = 'searchEnhanceEnable',
      autoUpdate = 'autoUpdate',
      alwaysOntop = 'alwaysOntop',
      defaultPlaySpeed = 'defaultPlaySpeed',
      defaultShortcutForwardPlaySpeed = 'defaultShortcutForwardPlaySpeed',
      defaultAspectRatioType = 'defaultAspectRatioType',
      buttonSkipTime = 'buttonSkipTime',
      arrowKeySkipTime = 'arrowKeySkipTime',
      danmakuEnhance = 'danmakuEnhance',
      danmakuBorder = 'danmakuBorder',
      danmakuBorderSize = 'danmakuBorderSize',
      danmakuOpacity = 'danmakuOpacity',
      danmakuFontSize = 'danmakuFontSize',
      danmakuTop = 'danmakuTop',
      danmakuScroll = 'danmakuScroll',
      danmakuBottom = 'danmakuBottom',
      danmakuMassive = 'danmakuMassive',
      danmakuDeduplication = 'danmakuDeduplication',
      danmakuArea = 'danmakuArea',
      danmakuColor = 'danmakuColor',
      danmakuDuration = 'danmakuDuration',
      danmakuLineHeight = 'danmakuLineHeight',
      danmakuTimeOffset = 'danmakuTimeOffset',
      danmakuEnabledByDefault = 'danmakuEnabledByDefault',
      danmakuBiliBiliSource = 'danmakuBiliBiliSource',
      danmakuGamerSource = 'danmakuGamerSource',
      danmakuDanDanSource = 'danmakuDanDanSource',
      danmakuFontWeight = 'danmakuFontWeight',
      danmakuFollowSpeed = 'danmakuFollowSpeed',
      themeMode = 'themeMode',
      themeColor = 'themeColor',
      privateMode = 'privateMode',
      autoPlay = 'autoPlay',
      autoPlayNext = 'autoPlayNext',
      playResume = 'playResume',
      showPlayerError = 'showPlayerError',
      oledEnhance = 'oledEnhance',
      displayMode = 'displayMode',
      enableGitProxy = 'enableGitProxy',
      enableBangumiProxy = 'enableBangumiProxy',
      enableSystemProxy = 'enableSystemProxy',
      defaultStartupPage = 'defaultStartupPage',

      /// Deprecated
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
      androidVideoRenderer = 'androidVideoRenderer',
      androidAutoEnterPIP = 'androidAutoEnterPIP',
      defaultSuperResolutionType = 'defaultSuperResolutionType',
      superResolutionWarn = 'superResolutionWarn',
      playerDisableAnimations = 'playerDisableAnimations',
      playerLogLevel = 'playerLogLevel',
      searchNotShowWatchedBangumis = 'searchNotShowWatchedBangumis',
      searchNotShowAbandonedBangumis = 'searchNotShowAbandonedBangumis',
      timelineNotShowAbandonedBangumis = 'timelineNotShowAbandonedBangumis',
      timelineNotShowWatchedBangumis = 'timelineNotShowWatchedBangumis',
      timelineOnlyShowWatchingBangumis = 'timelineOnlyShowWatchingBangumis',
      useSystemFont = 'useSystemFont',
      forceAdBlocker = 'forceAdBlocker',
      backgroundPlayback = 'backgroundPlayback',
      proxyEnable = 'proxyEnable',
      proxyConfigured = 'proxyConfigured',
      proxyUrl = 'proxyUrl',
      proxyTestUrl = 'proxyTestUrl',
      showRating = 'showRating',
      downloadParallelEpisodes = 'downloadParallelEpisodes',
      downloadParallelSegments = 'downloadParallelSegments',
      downloadDanmaku = 'downloadDanmaku',
      shortcutDialogShown = 'shortcutDialogShown',
      bangumiSyncEnable = 'bangumiSyncEnable',
      bangumiAccessToken = 'bangumiAccessToken',
      bangumiSyncPriority = 'bangumiSyncPriority',
      bangumiImmediateSyncToastEnable = 'bangumiImmediateSyncToastEnable',
      brightnessVolumeGesture = 'brightnessVolumeGesture',
      historySyncDeviceId = 'historySyncDeviceId',
      historySyncSequence = 'historySyncSequence',
      historySyncSnapshotInitialized = 'historySyncSnapshotInitialized';
}
