import 'dart:io';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/collect/collect_module_bangumi.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:path/path.dart' as p;

class Bangumi {
  late Directory bgmLocalTempDirectory; // 用的文档夹
  late String token;
  late String username; // 当前token对应的用户名
  late String lastSyncUsername; // 上次同步的Bangumi用户名
  // late int firstSyncMode;
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

  /// GET
  /// 获取远程收藏列表
  ///
  /// [list] 收藏列表，传入以省去从网上get
  Future<List<CollectedBangumi>> getCollectedBangumiList(
      [List<BangumiRemoteCollection>? list]) async {
    list ??= await BangumiHTTP.getBangumiCollectibles();
    final collectCrudRepository = Modular.get<ICollectCrudRepository>();
    final collectibles = <CollectedBangumi>[];
    for (final item in list) {
      // 遍历所有远程数据，如果有则用本地，否则尝试从远程获取
      var collect = collectCrudRepository.getCollectible(item.bangumiId);
      if (collect == null) {
        final remote = await BangumiHTTP.getBangumiInfoByID(item.bangumiId);
        if (remote == null) {
          KazumiLogger().w(
              'get bangumi info failed. name: ${item.name}, id: ${item.bangumiId}}');
          continue;
        }
        collect = CollectedBangumi(remote, DateTime.now(), item.type);
      }
      collectibles.add(collect);
    }
    return collectibles;
  }

  /// FUTURE: 重构
  /// 获得与 bgm 的差异
  ///
  /// [remoteCollectibles] 获取的 bangumi 收藏
  /// [localCollectibles] 本地收藏
  /// [remoteChanges] 可合并的远程改变
  /// [inorLocalChanges] 不可上传的本地改变，即删除
  /// [inorBgmChanges] 不可下载的远程改变，可能是删除，也可能是首次上传
  Future<
      ({
        List<BangumiRemoteCollection> remoteCollection,
        List<CollectedBangumiChange> remoteChangesUnMer,
        List<CollectedBangumiChange> localChangesUnMer,
        List<CollectedBangumiChange> inorLocalChanges,
        List<CollectedBangumiChange> inorBgmChanges
      })> getCollectedChanges() async {
    // 1. 对本地和远程的收藏进行预处理
    final remoteCollectiblesRaw = await BangumiHTTP.getBangumiCollectibles();
    final localCollectibles = GStorage.collectibles.values.toList();
    final remoteCollectiblesMap = {
      for (var item in remoteCollectiblesRaw) item.bangumiId: item
    };
    final localCollectiblesMap = {
      for (var item in localCollectibles) item.bangumiItem.id: item
    };

    // 2. change生成函数
    int timestampCount = 0;
    final timestampStart =
        DateTime.now().millisecondsSinceEpoch ~/ 1000; // 时间开始
    int getTimeForId() {
      timestampCount++;
      return timestampStart + timestampCount;
    }
    CollectedBangumiChange func<T>(
        Iterable<int> timesForId, T item, int action) {
          int time;
          int bangumiId;
          int type;
          int updateAt;
          if (item is BangumiRemoteCollection) {
            time = item.updatedAt.millisecondsSinceEpoch ~/ 1000;
            bangumiId = item.bangumiId;
            type = item.type;
            updateAt = item.getUpdateAtToInt();
          }  else if (item is CollectedBangumi) {
            time = getTimeForId();
            bangumiId = item.bangumiItem.id;
            type = item.type;
            updateAt = time;
            }
           else {
            throw Exception('TODO: change 生成函数item类型错误');
          }
      while (true) {
        if (!timesForId.contains(time)) {
          return CollectedBangumiChange(
              time, bangumiId, action, type, updateAt);
        }
        time = getTimeForId();
      }
    }

    // 3. 对本地改变记录以时间从新到旧排序
    final localChanges = GStorage.collectChanges;
    final localChangesList = localChanges.values.toList();
    localChangesList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 4. 遍历生成远程 chanage
    final remoteChangesUnMer = <int, CollectedBangumiChange>{}; // 未合并的远程 changes，change的id为key
    final localChangesUnMer = <int, CollectedBangumiChange>{};
    final inorLocalChanges = <CollectedBangumiChange>[]; // 因删除，被忽略的本地 changes
    final inorBgmChanges = <CollectedBangumiChange>[]; // 可能因删除，被忽略的远程 changes
    final bgmIds = {
      ...remoteCollectiblesMap.keys,
      ...localCollectiblesMap.keys
    };
    for (final id in bgmIds) {
      if (remoteCollectiblesMap.containsKey(id) &&
          localCollectiblesMap.containsKey(id)) {
        // 远程有 本地有 若收藏type不同 比较最新
        try {
          final remote = remoteCollectiblesMap[id]!;
          CollectedBangumiChange localChange;
          try {
            localChange = localChangesList
                .firstWhere((element) => element.bangumiID == id);
          } catch (e) {
            // 本地changes可能损坏或人为删除 基于远程记录重新生成本地change
            KazumiLogger().w(
                'Bangumi.getCollectedChanges: unable to find the change record $id: ${remote.name}');
            localChange = func(localChanges.keys.cast<int>(), remote, 1);
            await localChanges.put(localChange.id, localChange);
          }
          if (localChange.type != remote.type) {
            // 如果收藏类型不同 记录待合并的change
            if (localChange.timestamp > remote.getUpdateAtToInt()) {
              localChangesUnMer[localChange.id] = localChange;
            } else {
              final remoteChange = func(localChanges.keys.cast<int>(), remote, 2);
              remoteChangesUnMer[remoteChange.id] = remoteChange;
            }
          }
        } catch (e, stackTrace) {
          KazumiLogger().e(
            'Bangumi: 生成远程changes失败. Id=$id',
            error: e,
            stackTrace: stackTrace,
          );
          rethrow;
        }
      } else if (remoteCollectiblesMap.containsKey(id)) {
        // 远程有 本地没有 尝试获得本地删除记录 有则记为删除 否则记为远程新增
        CollectedBangumiChange? deletedChange;
        try {
          deletedChange = localChangesList.firstWhere(
              (element) => element.bangumiID == id && element.action == 3);
        } catch (_) {}
        if (deletedChange != null) {
          // 本地删除了
          inorLocalChanges.add(deletedChange);
        } else {
          // 未获得本地删除记录 视为远程新增
          final remoteChange = func(localChanges.keys.cast<int>(), remoteCollectiblesMap[id]!, 1);
          remoteChangesUnMer[remoteChange.timestamp] = remoteChange;
        }
      } else {
        // 远程没有 本地有
        final local = localCollectiblesMap[id]!;
        CollectedBangumiChange localChange;
        try {
          // 尝试获得本地记录
          localChange = localChangesList.firstWhere((element) => element.bangumiID == local.bangumiItem.id);
        } catch (e) {
          // 本地changes可能损坏或人为删除 重新生成本地change
          KazumiLogger().w(
              'Bangumi.getCollectedChanges: unable to find the change record ${local.bangumiItem.id}: ${local.bangumiItem.name}');
          localChange = func(localChanges.keys.cast<int>(), local, 1);
          await localChanges.put(localChange.id, localChange);
        }
        // FUTURE: 可能是远程删除了 也可能是待同步 暂时都视为待同步
        localChangesUnMer[localChange.id] = localChange;
        // final item = localCollectiblesMap[id]!;
        // final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        // inorBgmChanges.add(CollectedBangumiChange(
        //     timestamp, item.bangumiItem.id, 3, item.type, timestamp));
      }
    }

    // 5. 返回最终数据
    return (
      remoteCollection: remoteCollectiblesRaw,
      remoteChangesUnMer: remoteChangesUnMer.values.toList(),
      localChangesUnMer: localChangesUnMer.values.toList(),
      inorLocalChanges: inorLocalChanges,
      inorBgmChanges: inorBgmChanges
    );
  }

  /// 更新
  /// 将本地收藏数据同步到 Bangumi 服务器，基于 changes
  Future<void> update(
      [List<CollectedBangumiChange>? localChangesUnMer, bool skipLock = false]) async {
    final updateEnanbe =
        setting.get(SettingBoxKey.bangumiUpdateEnable, defaultValue: true);
    if (!updateEnanbe) {
      KazumiDialog.showToast(message: '上传已禁用');
      KazumiLogger().i('Bangumi: update is disabled');
      return;
    }
    bool ownsLock = false;
    if (!skipLock && isUsing) {
      KazumiLogger().w('Bangumi: History is currently syncing');
      throw Exception('History is currently syncing');
    }
    if (!skipLock) {
      isUsing = true;
      ownsLock = true;
    }
    try {
      // 1. 获取本地可以上传的changes
      final localChanges = localChangesUnMer ?? (await getCollectedChanges()).localChangesUnMer;

      // 2. 上传
      for (final change in localChanges) {
        await BangumiHTTP.updateBangumiByType(change.bangumiID, change.type);
      }

      // 3. 检测用户名
      checkUpdateUsername();

      KazumiLogger()
          .i('Bangumi: update collection success. updatedCount: ${localChanges.length}');
    } catch (e) {
      KazumiLogger().e('Bangumi: update collection failed', error: e);
      rethrow;
    } finally {
      if (ownsLock) {
        isUsing = false;
      }
    }
  }

  /// 将Bangumi收藏数据同步到本地
  Future<void> download(
      [List<BangumiRemoteCollection>? remoteCollection_,
      List<CollectedBangumiChange>? remoteChangesUnMer_,
      bool skipLock = false]) async {
    final downloadEnable =
        setting.get(SettingBoxKey.bangumiDownloadEnable, defaultValue: true);
    if (!downloadEnable) {
      KazumiDialog.showToast(message: '下载已被禁止');
      KazumiLogger().w('Bangumi: download is disabled');
      return;
    }
    bool ownsLock = false;
    if (!skipLock && isUsing) {
      KazumiLogger().w('Bangumi: History is currently syncing');
      throw Exception('History is currently syncing');
    }
    if (!skipLock) {
      isUsing = true;
      ownsLock = true;
    }
    try {
      if (username.isEmpty) {
        throw Exception('username is empty');
      }
      // 1. 远程收藏初始化
      List<BangumiRemoteCollection> remoteCollection;
      List<CollectedBangumiChange> remoteChangesUnMer;
      if (remoteCollection_ == null || remoteChangesUnMer_ == null) {
        final record = await getCollectedChanges();
        remoteCollection = record.remoteCollection;
        remoteChangesUnMer = record.remoteChangesUnMer;
      } else {
        remoteCollection = remoteCollection_;
        remoteChangesUnMer = remoteChangesUnMer_;
      }

        // 2. 合并收藏
      await GStorage.patchCollectibles(
          await getCollectedBangumiList(remoteCollection),
          remoteChangesUnMer);
      
      // 4. 检测用户名
      checkUpdateUsername();
    } catch (e) {
      KazumiLogger().e('Bangumi: download collection failed', error: e);
      rethrow;
    } finally {
      if (ownsLock) {
        isUsing = false;
      }
    }
  }

  /// 同步收藏
  Future<void> syncCollectibles() async {
    final syncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: true);
    final updateEnanbe =
        setting.get(SettingBoxKey.bangumiUpdateEnable, defaultValue: true);
    final downloadEnable =
      setting.get(SettingBoxKey.bangumiDownloadEnable, defaultValue: true);
    if (!syncEnable || (!updateEnanbe && !downloadEnable)) {
      KazumiDialog.showToast(message: '同步已关闭');
      KazumiLogger().i('Bangumi: sync disabled');
      return;
    }
    if (isUsing) {
      KazumiLogger().w('Bangumi: History is currently syncing');
      throw Exception('History is currently syncing');
    }
    isUsing = true;
    try {
      await checkAndBackup();

      // 1. 获得更改
      final record = await getCollectedChanges();

      // 2. 下载远程更改
      await download(record.remoteCollection, record.remoteChangesUnMer, true);

      // 3. 上传本地更改
      await update(record.localChangesUnMer, true);
    } catch (e) {
      KazumiLogger().e('Bangumi: sync history failed', error: e);
      rethrow;
    } finally {
      isUsing = false;
    }
  }
}
