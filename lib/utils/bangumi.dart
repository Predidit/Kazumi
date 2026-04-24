import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:path/path.dart' as p;

class Bangumi {
  late Directory bgmLocalTempDirectory; // 用的文档夹
  late String token;
  String username = ''; // 当前token对应的用户名，由 ping() 设置
  String lastSyncUsername = ''; // 上次同步的Bangumi用户名，由 ping()/init() 从存储加载
  bool initialized = false;
  Box setting = GStorage.setting;
  int _nextCollectChangeId = 0;

  bool isUsing = false; // 是否正在使用

  Bangumi._internal();
  static final Bangumi _instance = Bangumi._internal();
  factory Bangumi() => _instance;

  /// 初始化
  Future<void> init() async {
    initialized = false;
    var directory = await getApplicationDocumentsDirectory();
    bgmLocalTempDirectory = Directory(p.join(directory.path, 'Kazumi'));
    if (!await bgmLocalTempDirectory.exists()) {
      await bgmLocalTempDirectory.create(recursive: true);
    }
    Box setting = GStorage.setting;
    token = setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');
    lastSyncUsername =
        setting.get(SettingBoxKey.bangumiLastSyncUsername, defaultValue: '');
    if (token.isEmpty) {
      throw Exception('请先填写Bangumi Access Token');
    }
    try {
      await ping();
      initialized = true;
    } catch (e) {
      KazumiLogger().e('Bangumi: Bangumi ping failed', error: e);
      rethrow;
    }
  }

  Future<void> ping() async {
    if (isUsing) {
      return;
    }
    isUsing = true;
    try {
      final name = await BangumiHTTP.getUsername();
      if (name == null) {
        throw Exception('Bangumi: 获取用户名失败');
      } else {
        username = name;
        // 确保 lastSyncUsername 已从存储加载（未经 init() 直接调用 ping() 时同样有效）
        if (lastSyncUsername.isEmpty) {
          lastSyncUsername =
              setting.get(SettingBoxKey.bangumiLastSyncUsername, defaultValue: '');
        }
      }
    } catch (e) {
      KazumiLogger().e('Bangumi: Bangumi ping failed', error: e);
      rethrow;
    } finally {
      isUsing = false;
    }
  }

  /// 备份
  /// 首次同步时，备份
  Future<void> backup() async {
    Future<void> func(String boxName) async {
      final path = '${bgmLocalTempDirectory.path}/$boxName.hive';
      await GStorage.backupBox(boxName, path);
    }

    await func('collectibles');
    await func('collectchanges');
  }

  /// 打开文件夹以进行恢复数据
  Future<void> openFolderRestore() async {
    var appDocumentDir = await getApplicationSupportDirectory();
    final hiveBoxDir = File(p.join(appDocumentDir.path, 'hive'));
    Future<void> func(String name) async {
      await Process.start(name, [bgmLocalTempDirectory.path]);
      await Process.start(name, [hiveBoxDir.path]);
    }

    if (Platform.isWindows) {
      await func('explorer');
    } else if (Platform.isLinux) {
      await func('xdg-open');
    } else if (Platform.isMacOS) {
      await func('open');
    } else {
      throw Exception('不支持的操作系统');
    }
  }

  /// 检测是否需要备份
  Future<void> checkAndBackup() async {
    final debugEnable =
        setting.get(SettingBoxKey.bangumiSyncDebug, defaultValue: true);
    if (debugEnable && username != lastSyncUsername) {
      final collectibles =
        File(p.join(bgmLocalTempDirectory.path, 'collectibles.hive'));
      final collectChanges =
        File(p.join(bgmLocalTempDirectory.path, 'collectchanges.hive'));
      if (await collectibles.exists() || await collectChanges.exists()) {
        await openFolderRestore();
        KazumiDialog.showToast(message: '检测到存在上次备份数据，请检查数据');
        throw Exception('检测到存在上次备份数据，请检查数据');
      } else {
        await backup();
      }
    }
  }

  /// 检测是否需要更新上一个更新用户名
  void checkUpdateUsername() {
    if (username != lastSyncUsername) {
      lastSyncUsername = username;
      setting.put(SettingBoxKey.bangumiLastSyncUsername, lastSyncUsername);
    }
  }

  /// 生成一个新的收藏变更 ID（用于记录收藏更新变更）
  int _generateCollectChangeId() {
    final currentSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_nextCollectChangeId < currentSeconds) {
      _nextCollectChangeId = currentSeconds;
    } else {
      _nextCollectChangeId++;
    }
    return _nextCollectChangeId;
  }

  /// 记录一次收藏变更（用于 WebDAV 增量同步）
  Future<void> _recordCollectibleChange(
    int bangumiId,
    int action,
    int type,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final change = CollectedBangumiChange(
      _generateCollectChangeId(),
      bangumiId,
      action,
      type,
      timestamp,
    );
    await GStorage.collectChanges.put(change.id, change);
  }

  /// 同步收藏
  /// 全量拉取 Bangumi 远程收藏，与本地对比，按优先级处理差异。
  /// [force] 为 true 时跳过 bangumiSyncEnable 检查（用于用户主动触发同步）
  Future<void> syncCollectibles({
    bool force = false,
    void Function(String message, int current, int total)? onProgress,
  }) async {
    if (!force) {
      final syncEnable =
          setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
      if (!syncEnable) {
        KazumiDialog.showToast(message: '同步已关闭');
        KazumiLogger().i('Bangumi: sync disabled');
        return;
      }
    }
    if (isUsing) {
      KazumiLogger().w('Bangumi: History is currently syncing');
      throw Exception('History is currently syncing');
    }
    isUsing = true;
    try {
      onProgress?.call('开始同步 Bangumi 状态', 0, 0);

      // 确保备份目录已初始化（未经 init() 直接调用时同样安全）
      if (!initialized) {
        final dir = await getApplicationDocumentsDirectory();
        bgmLocalTempDirectory = Directory(p.join(dir.path, 'Kazumi'));
        if (!await bgmLocalTempDirectory.exists()) {
          await bgmLocalTempDirectory.create(recursive: true);
        }
      }

      await checkAndBackup();

      final priority = BangumiSyncPriority.fromValue(
        setting.get(SettingBoxKey.bangumiSyncPriority, defaultValue: 1),
      );

      // 1. 全量拉取远程收藏（带分页进度）
      final remoteCollection = await BangumiHTTP.getBangumiCollectibles(
        onProgress: onProgress,
      );

      // 2. 与本地数据对比，分三类处理：
      // - 仅本地有：直接上传到 Bangumi
      // - 仅远程有：直接补到本地
      // - 双方都有但类型不一致：按优先级处理
      final localCollectibles = GStorage.collectibles.values.toList();
      final localMap = {
        for (final item in localCollectibles) item.bangumiItem.id: item,
      };
      final remoteMap = {
        for (final item in remoteCollection) item.bangumiId: item,
      };

      final localOnlyIds = localMap.keys.toSet().difference(remoteMap.keys.toSet());
      final remoteOnlyIds = remoteMap.keys.toSet().difference(localMap.keys.toSet());
      final sharedIds = localMap.keys.toSet().intersection(remoteMap.keys.toSet());
      final mismatchIds = <int>[];
      for (final id in sharedIds) {
        if (localMap[id]!.type != remoteMap[id]!.type) {
          mismatchIds.add(id);
        }
      }

      final totalOperations =
          localOnlyIds.length + remoteOnlyIds.length + mismatchIds.length;

      if (totalOperations == 0) {
        onProgress?.call('未发现状态差异，无需同步', 1, 1);
        KazumiDialog.showToast(message: '未发现状态差异，无需同步');
        checkUpdateUsername();
        return;
      }

      int syncedCount = 0;
      bool localModified = false;

      // 3. 仅本地有：直接上传到 Bangumi
      if (localOnlyIds.isNotEmpty) {
        onProgress?.call('正在上传本地新增状态', syncedCount, totalOperations);
        for (final id in localOnlyIds) {
          await BangumiHTTP.updateBangumiByType(id, localMap[id]!.type);
          syncedCount++;
          onProgress?.call('正在上传本地新增状态', syncedCount, totalOperations);
        }
      }

      // 4. 仅远程有：直接补到本地
      if (remoteOnlyIds.isNotEmpty) {
        onProgress?.call('正在补全本地缺失状态', syncedCount, totalOperations);
        for (final id in remoteOnlyIds) {
          final remote = remoteMap[id]!;
          final collected = CollectedBangumi(
            remote.toBangumiItem(),
            remote.updatedAt,
            remote.type,
          );
          await GStorage.collectibles.put(id, collected);
          // 记录一次收藏变更，action=1 代表新增（add），以便 WebDAV 增量同步能正确识别并上传变更
          await _recordCollectibleChange(id, 1, remote.type);
          syncedCount++;
          localModified = true;
          onProgress?.call('正在补全本地缺失状态', syncedCount, totalOperations);
        }
      }

      // 5. 双方都有但不一致：按优先级处理
      if (priority == BangumiSyncPriority.localFirst) {
        onProgress?.call('本地 First：正在处理冲突状态', syncedCount, totalOperations);
        for (final id in mismatchIds) {
          await BangumiHTTP.updateBangumiByType(id, localMap[id]!.type);
          syncedCount++;
          onProgress?.call('本地 First：正在处理冲突状态', syncedCount, totalOperations);
        }
      } else {
        onProgress?.call('Bangumi First：正在处理冲突状态', syncedCount, totalOperations);
        for (final id in mismatchIds) {
          final local = localMap[id]!;
          final remote = remoteMap[id]!;
          local.type = remote.type;
          local.time = remote.updatedAt;
          await GStorage.collectibles.put(id, local);
          // 记录一次收藏变更，action=2 代表修改（update），以便 WebDAV 增量同步能正确识别并上传变更
          await _recordCollectibleChange(id, 2, remote.type);
          syncedCount++;
          localModified = true;
          onProgress?.call('Bangumi First：正在处理冲突状态', syncedCount, totalOperations);
        }
      }

      if (localModified) {
        await GStorage.collectibles.flush();
        // 确保收藏变更记录也持久化，以便后续增量同步时能正确识别已处理的变更
        await GStorage.collectChanges.flush();
      }
      checkUpdateUsername();
      onProgress?.call('Bangumi 状态同步完成', 1, 1);
    } catch (e) {
      KazumiLogger().e('Bangumi: sync history failed', error: e);
      rethrow;
    } finally {
      isUsing = false;
    }
  }
}
