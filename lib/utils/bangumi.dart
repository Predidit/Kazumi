import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
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
    await func('collectChanges');
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
          Directory(p.join(bgmLocalTempDirectory.path, 'collectibles.hive'));
      final collectChanges =
          Directory(p.join(bgmLocalTempDirectory.path, 'collectChanges.hive'));
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

      // 2. 与本地数据对比，找出类型不一致的条目
      final localCollectibles = GStorage.collectibles.values.toList();
      final localMap = {
        for (final item in localCollectibles) item.bangumiItem.id: item,
      };
      final remoteMap = {
        for (final item in remoteCollection) item.bangumiId: item,
      };
      final sharedIds = localMap.keys.toSet().intersection(remoteMap.keys.toSet());
      final mismatchIds = <int>[];
      for (final id in sharedIds) {
        if (localMap[id]!.type != remoteMap[id]!.type) {
          mismatchIds.add(id);
        }
      }

      if (mismatchIds.isEmpty) {
        onProgress?.call('未发现状态差异，无需同步', 1, 1);
        KazumiDialog.showToast(message: '未发现状态差异，无需同步');
        checkUpdateUsername();
        return;
      }

      // 3. 按优先级处理差异
      if (priority == BangumiSyncPriority.localFirst) {
        // 本地优先：将本地类型上传到 Bangumi
        int syncedCount = 0;
        final total = mismatchIds.length;
        onProgress?.call('本地 First：正在上传差异状态', 0, total);
        for (final id in mismatchIds) {
          await BangumiHTTP.updateBangumiByType(id, localMap[id]!.type);
          syncedCount++;
          onProgress?.call('本地 First：正在上传差异状态', syncedCount, total);
        }
      } else {
        // Bangumi 优先：用远程类型覆盖本地
        int syncedCount = 0;
        final total = mismatchIds.length;
        onProgress?.call('Bangumi First：正在更新本地状态', 0, total);
        for (final id in mismatchIds) {
          final local = localMap[id]!;
          final remote = remoteMap[id]!;
          local.type = remote.type;
          local.time = remote.updatedAt;
          await GStorage.collectibles.put(id, local);
          syncedCount++;
          onProgress?.call('Bangumi First：正在更新本地状态', syncedCount, total);
        }
      }

      await GStorage.collectibles.flush();
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
