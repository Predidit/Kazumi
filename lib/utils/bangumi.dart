import 'package:hive_ce/hive.dart';
import 'dart:async';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/bangumi/bangumi_collection.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/modules/collect/collect_type_mapper.dart';
import 'package:kazumi/request/bangumi.dart';

/// Bangumi 相关工具类
class Bangumi {
  /// Current username corresponding to the token, set by ping()
  String username = '';

  /// is Bangumi initialized successfully
  /// set to true after successful ping() in init()
  bool initialized = false;

  /// Hive
  Box setting = GStorage.setting;

  /// Number of queued Bangumi operations waiting to enter the exclusive section.
  int _queuedOperationCount = 0;

  /// Number of Bangumi operations currently running in the exclusive section.
  int _activeOperationCount = 0;

  /// Shared serial queue for all Bangumi operations that must not overlap.
  Future<void> _operationQueue = Future.value();

  /// Whether any Bangumi operation is active or already queued.
  bool get isUsing => _queuedOperationCount > 0 || _activeOperationCount > 0;

  String get _configuredToken =>
      setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '')
          .toString()
          .trim();

  Bangumi._internal();
  static final Bangumi _instance = Bangumi._internal();
  factory Bangumi() => _instance;

  void reset() {
    initialized = false;
    username = '';
  }

  Future<void> init() async {
    initialized = false;
    username = '';
    if (_configuredToken.isEmpty) {
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
      throw Exception('Bangumi: 当前有操作正在进行，请稍后再试');
    }
    await _runExclusive(() async {
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
      }
    });
  }

  /// Update a single collectible on Bangumi, waiting for current Bangumi work
  /// to finish and serializing multiple immediate update requests.
  Future<bool> syncCollectibleWhenIdle(int bangumiId, int localType) {
    return _runExclusive(() async {
      return BangumiHTTP.updateBangumiByType(
        bangumiId,
        localType,
      );
    });
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previousOperation = _operationQueue;
    _queuedOperationCount++;

    _operationQueue = (() async {
      try {
        await previousOperation;
      } catch (_) {}

      _queuedOperationCount--;
      _activeOperationCount++;
      try {
        completer.complete(await action());
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      } finally {
        _activeOperationCount--;
      }
    })();

    return completer.future;
  }

  /// Record a collectible change (used for WebDAV incremental sync)
  /// [action] 1 代表新增（add），2 代表修改（update）
  /// [type] via: [CollectType]
  Future<void> _recordCollectibleChange(
    int bangumiId,
    int action,
    int type,
  ) async {
    await GStorage.appendCollectChange(
      bangumiId: bangumiId,
      action: action,
      type: type,
    );
  }

  /// Sync Bangumi collectibles with local data
  ///
  /// [onProgress] callback is used to report progress, with a message and current/total counts for operations.
  Future<void> syncCollectibles({
    void Function(String message, int current, int total)? onProgress,
  }) async {
    final syncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
    if (!syncEnable) {
      KazumiDialog.showToast(message: '同步已关闭');
      KazumiLogger().i('Bangumi: sync disabled');
      return;
    }
    if (isUsing) {
      KazumiLogger().w('Bangumi is currently syncing');
      throw Exception('Bangumi 正在同步');
    }
    await _runExclusive(() async {
      try {
        onProgress?.call('开始同步 Bangumi 状态', 0, 0);

        final priority = BangumiSyncPriority.fromValue(
          setting.get(SettingBoxKey.bangumiSyncPriority, defaultValue: 0),
        );

        // 1. 全量拉取远程收藏（带分页进度）
        final remoteCollection = await BangumiHTTP.getBangumiCollectibles(
          username: username,
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
        final remoteMap = <int, BangumiCollection>{};
        for (final item in remoteCollection) {
          final remoteCollectType = item.type.toCollectType();
          if (!remoteCollectType.isCollected) {
            KazumiLogger().w(
              'Bangumi: skip remote collectible with unsupported type '
              '${item.type.value} for id=${item.bangumiId}',
            );
            continue;
          }
          remoteMap[item.bangumiId] = item;
        }

        final localOnlyIds =
            localMap.keys.toSet().difference(remoteMap.keys.toSet());
        final remoteOnlyIds =
            remoteMap.keys.toSet().difference(localMap.keys.toSet());
        final sharedIds =
            localMap.keys.toSet().intersection(remoteMap.keys.toSet());
        final mismatchIds = <int>[];
        for (final id in sharedIds) {
          if (localMap[id]!.type != remoteMap[id]!.type.toCollectType().value) {
            mismatchIds.add(id);
          }
        }

        final totalOperations =
            localOnlyIds.length + remoteOnlyIds.length + mismatchIds.length;

        if (totalOperations == 0) {
          onProgress?.call('未发现状态差异，无需同步', 1, 1);
          KazumiDialog.showToast(message: '未发现状态差异，无需同步');
          return;
        }

        int syncedCount = 0;
        bool localModified = false;

        // 3. 仅本地有：直接上传到 Bangumi
        if (localOnlyIds.isNotEmpty) {
          onProgress?.call('正在上传本地新增状态', syncedCount, totalOperations);
          for (final id in localOnlyIds) {
            final updated = await BangumiHTTP.updateBangumiByType(
              id,
              localMap[id]!.type,
            );
            if (!updated) {
              onProgress?.call('上传本地新增状态失败', syncedCount, totalOperations);
              KazumiDialog.showToast(message: '同步失败：条目 $id 上传到 Bangumi 失败');
              return;
            }
            syncedCount++;
            onProgress?.call('正在上传本地新增状态', syncedCount, totalOperations);
          }
        }

        // 4. 仅远程有：直接补到本地
        if (remoteOnlyIds.isNotEmpty) {
          onProgress?.call('正在补全本地缺失状态', syncedCount, totalOperations);
          for (final id in remoteOnlyIds) {
            final remote = remoteMap[id]!;
            final localType = remote.type.toCollectType();
            final collected = CollectedBangumi(
              remote.toBangumiItem(),
              remote.updatedAt,
              localType.value,
            );
            await GStorage.collectibles.put(id, collected);
            // 记录一次收藏变更，action=1 代表新增（add），以便 WebDAV 增量同步能正确识别并上传变更
            await _recordCollectibleChange(id, 1, localType.value);
            syncedCount++;
            localModified = true;
            onProgress?.call('正在补全本地缺失状态', syncedCount, totalOperations);
          }
        }

        // 5. 双方都有但不一致：按优先级处理
        if (priority == BangumiSyncPriority.localFirst) {
          onProgress?.call('本地优先：正在处理冲突状态', syncedCount, totalOperations);
          for (final id in mismatchIds) {
            final updated =
                await BangumiHTTP.updateBangumiByType(id, localMap[id]!.type);
            if (updated != true) {
              throw Exception(
                  'Bangumi sync failed: updateBangumiByType failed for id=$id');
            }
            syncedCount++;
            onProgress?.call('本地优先：正在处理冲突状态', syncedCount, totalOperations);
          }
        } else {
          onProgress?.call('Bangumi 优先：正在处理冲突状态', syncedCount, totalOperations);
          for (final id in mismatchIds) {
            final local = localMap[id]!;
            final remote = remoteMap[id]!;
            final localType = remote.type.toCollectType();
            local.type = localType.value;
            local.time = remote.updatedAt;
            await GStorage.collectibles.put(id, local);
            // 记录一次收藏变更，action=2 代表修改（update），以便 WebDAV 增量同步能正确识别并上传变更
            await _recordCollectibleChange(id, 2, localType.value);
            syncedCount++;
            localModified = true;
            onProgress?.call(
                'Bangumi 优先：正在处理冲突状态', syncedCount, totalOperations);
          }
        }

        if (localModified) {
          await GStorage.collectibles.flush();
          // 确保收藏变更记录也持久化，以便后续增量同步时能正确识别已处理的变更
          await GStorage.collectChanges.flush();
        }
        onProgress?.call('Bangumi 状态同步完成', 1, 1);
      } catch (e) {
        KazumiLogger().e('Bangumi sync failed', error: e);
        rethrow;
      }
    });
  }
}
