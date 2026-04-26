import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/utils/bangumi.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/logger.dart';

part 'collect_controller.g.dart';

enum _BangumiDeleteSyncAction {
  deleteLocalOnly,
  markAbandoned,
  openWeb,
  cancel,
}

class CollectController = _CollectController with _$CollectController;

abstract class _CollectController with Store {
  final _collectCrudRepository = Modular.get<ICollectCrudRepository>();
  final _collectRepository = Modular.get<ICollectRepository>();
  int _nextCollectChangeId = 0;
  bool _collectChangeIdInitialized = false;

  Box setting = GStorage.setting;
  List<BangumiItem> get favorites => _collectCrudRepository.getFavorites();

  @observable
  ObservableList<CollectedBangumi> collectibles =
      ObservableList<CollectedBangumi>();

  void loadCollectibles() {
    collectibles.clear();
    collectibles.addAll(_collectCrudRepository.getAllCollectibles());
  }

  int getCollectType(BangumiItem bangumiItem) {
    return _collectCrudRepository.getCollectType(bangumiItem.id);
  }

  // Init _nextCollectChangeId
  void _initializeNextCollectChangeId() {
    if (_collectChangeIdInitialized) {
      return;
    }

    var maxExistingId = 0;
    for (final key in GStorage.collectChanges.keys) {
      if (key is int && key > maxExistingId) {
        maxExistingId = key;
      }
    }

    _nextCollectChangeId = maxExistingId;
    _collectChangeIdInitialized = true;
  }

  // Generate a unique and incrementing collect change ID
  int _generateCollectChangeId() {
    _initializeNextCollectChangeId();

    final currentSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Ensure the new ID is greater than both the last generated ID and the current timestamp
    var nextId = _nextCollectChangeId < currentSeconds
        ? currentSeconds
        : _nextCollectChangeId + 1;
    while (GStorage.collectChanges.containsKey(nextId)) {
      nextId++;
    }
    _nextCollectChangeId = nextId;
    return nextId;
  }

  // Record collect changelog
  // NOTE: 分离出来是因为如果同一秒内的多次变更需要保证ID唯一且递增
  Future<void> _recordCollectChange(
    BangumiItem bangumiItem, {
    required int action,
    required int type,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final collectChange = CollectedBangumiChange(
      _generateCollectChangeId(),
      bangumiItem.id,
      action,
      type,
      timestamp,
    );
    await _collectCrudRepository.addCollectChange(collectChange);
  }

  @action
  Future<void> addCollect(BangumiItem bangumiItem, {type = 1}) async {
    if (type == 0) {
      await deleteCollect(bangumiItem);
      return;
    }

    final bool syncSucceeded = await _syncBangumiCollectIfEnabled(
      bangumiItem.id,
      type,
    );
    if (!syncSucceeded) {
      return;
    }

    // 判断新增还是修改收藏
    final int currentCollectType = getCollectType(bangumiItem);
    final int collectChangeAction = currentCollectType == 0 ? 1 : 2;

    await _collectCrudRepository.addCollectible(bangumiItem, type);
    await _recordCollectChange(
      bangumiItem,
      action: collectChangeAction,
      type: type,
    );
    loadCollectibles();
  }

  @action
  Future<void> deleteCollect(BangumiItem bangumiItem) async {
    final action = await _resolveBangumiDeleteSyncAction(bangumiItem);
    switch (action) {
      // 标记删除
      case _BangumiDeleteSyncAction.markAbandoned:
        await addCollect(
          bangumiItem,
          type: CollectType.abandoned.value,
        );
        return;

      // 打开网页
      case _BangumiDeleteSyncAction.openWeb:
        await _deleteCollectLocally(bangumiItem);
        await _openBangumiSubjectPage(bangumiItem.id);
        return;

      // 未开启 Bangumi 同步走这里
      case _BangumiDeleteSyncAction.deleteLocalOnly:
        await _deleteCollectLocally(bangumiItem);
        return;

      // 取消按钮
      case _BangumiDeleteSyncAction.cancel:
      case null:
        return;
    }
  }

  Future<void> _deleteCollectLocally(BangumiItem bangumiItem) async {
    await _collectCrudRepository.deleteCollectible(bangumiItem.id);
    await _recordCollectChange(
      bangumiItem,
      action: 3,
      type: 5,
    );
    loadCollectibles();
  }

  Future<_BangumiDeleteSyncAction?> _resolveBangumiDeleteSyncAction(
      BangumiItem bangumiItem) async {
    final bool syncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
    if (!syncEnable) {
      return _BangumiDeleteSyncAction.deleteLocalOnly;
    }

    final bangumi = Bangumi();
    if (!bangumi.initialized) {
      return _BangumiDeleteSyncAction.deleteLocalOnly;
    }

    return KazumiDialog.show<_BangumiDeleteSyncAction>(
      clickMaskDismiss: true,
      builder: (context) => AlertDialog(
        title: const Text('Bangumi 不支持删除收藏'),
        content: const Text(
          '因为安全考虑，Bangumi 未提供删除接口，您可以选择把本地和远端标记为“抛弃”，或者选择仅删除本地收藏并打开网页后手动删除 Bangumi 数据。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_BangumiDeleteSyncAction.cancel);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_BangumiDeleteSyncAction.openWeb);
            },
            child: const Text('打开网页'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(_BangumiDeleteSyncAction.markAbandoned);
            },
            child: const Text('标记为抛弃'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBangumiSubjectPage(int bangumiId) async {
    final url = Uri.parse('https://bangumi.tv/subject/$bangumiId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    KazumiDialog.showToast(message: '无法打开 Bangumi 网页');
  }

  Future<bool> _syncBangumiCollectIfEnabled(
      int bangumiId, int localType) async {
    final bool syncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
    final bool showImmediateSyncToast = setting.get(
      SettingBoxKey.bangumiImmediateSyncToastEnable,
      defaultValue: true,
    );

    if (!syncEnable) {
      return true;
    }

    final bangumi = Bangumi();
    if (!bangumi.initialized) {
      KazumiDialog.showToast(message: 'Bangumi 未初始化，同步失败，已取消本次状态修改');
      KazumiLogger().w(
        'Bangumi: immediate collect sync skipped because Bangumi is not initialized. '
        'bangumiId=$bangumiId, type=$localType',
      );
      return false;
    }
    try {
      if (showImmediateSyncToast) {
        KazumiDialog.showToast(message: '正在同步到 Bangumi...');
      }
      final bool synced =
          await bangumi.syncCollectibleWhenIdle(bangumiId, localType);
      if (synced && showImmediateSyncToast) {
        KazumiDialog.showToast(message: '已同步到 Bangumi');
        return true;
      } else if (!synced) {
        KazumiDialog.showToast(message: '同步到 Bangumi 失败，已取消本次状态修改');
        KazumiLogger().w(
          'Bangumi: immediate collect sync did not complete. bangumiId=$bangumiId, type=$localType',
        );
        return false;
      }
      return true;
    } catch (e, stackTrace) {
      KazumiDialog.showToast(message: '同步到 Bangumi 失败，已取消本次状态修改: $e');
      KazumiLogger().e(
        'Bangumi: immediate collect sync failed. bangumiId=$bangumiId, type=$localType',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> updateLocalCollect(BangumiItem bangumiItem) async {
    await _collectCrudRepository.updateCollectible(bangumiItem);
    loadCollectibles();
  }

  Future<bool> syncCollectibles({bool showSuccessToast = true}) async {
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
      return false;
    }
    bool flag = true;
    try {
      await WebDav().ping();
    } catch (e) {
      KazumiLogger().e('WebDav: WebDav connection failed', error: e);
      KazumiDialog.showToast(message: 'WebDav连接失败: $e');
      flag = false;
    }
    if (!flag) {
      return false;
    }
    try {
      await WebDav().syncCollectibles();
      if (showSuccessToast) {
        KazumiDialog.showToast(message: 'WebDav同步完成');
      }
    } catch (e) {
      KazumiDialog.showToast(message: 'WebDav同步失败 $e');
      return false;
    }
    loadCollectibles();
    return true;
  }

  /// 仅上传当前本地收藏与变更日志到 WebDAV，不做下载合并
  Future<bool> uploadCollectiblesToWebDav({bool showSuccessToast = true}) async {
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
      return false;
    }
    bool flag = true;
    try {
      await WebDav().ping();
    } catch (e) {
      KazumiLogger().e('WebDav: WebDav connection failed', error: e);
      KazumiDialog.showToast(message: 'WebDav连接失败: $e');
      flag = false;
    }
    if (!flag) {
      return false;
    }
    try {
      await WebDav().updateCollectibles();
      if (showSuccessToast) {
        KazumiDialog.showToast(message: 'WebDav上传完成');
      }
    } catch (e) {
      KazumiDialog.showToast(message: 'WebDav上传失败 $e');
      return false;
    }
    return true;
  }

  // migrate collect from old version (favorites)
  Future<void> migrateCollect() async {
    if (favorites.isNotEmpty) {
      int count = 0;
      for (BangumiItem bangumiItem in favorites) {
        await addCollect(bangumiItem, type: 1);
        count++;
      }
      await _collectCrudRepository.clearFavorites();
      KazumiLogger().d('GStorage: detected $count uncategorized favorites, migrated to collectibles');
    }
  }

  /// 根据收藏类型获取番剧ID集合
  ///
  /// [type] 收藏类型
  /// 返回番剧ID集合
  Set<int> getBangumiIdsByType(CollectType type) {
    return _collectRepository.getBangumiIdsByType(type);
  }

  /// 过滤掉指定收藏类型的番剧
  ///
  /// [bangumiList] 原始番剧列表
  /// [excludeType] 要排除的收藏类型
  /// 返回过滤后的番剧列表
  List<BangumiItem> filterBangumiByType(
      List<BangumiItem> bangumiList, CollectType excludeType) {
    final excludeIds = getBangumiIdsByType(excludeType);
    return bangumiList
        .where((item) => !excludeIds.contains(item.id))
        .toList();
  }

  /// Sync Bangumi collectibles.
  ///
  /// [onProgress] Progress callback, parameters are the name of the currently syncing Bangumi,
  /// the index of the currently syncing Bangumi, and the total number of Bangumi.
  /// The callback will be called when syncing each Bangumi, and can be used to show a progress indicator.
  Future<bool> syncCollectiblesBangumi(
      {void Function(String message, int current, int total)?
          onProgress,
      bool showSuccessToast = true}) async {
    final bool syncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
    if (!syncEnable) {
      KazumiDialog.showToast(message: '未开启Bangumi同步或配置无效');
      return false;
    }

    if (!Bangumi().initialized) {
      KazumiDialog.showToast(message: '未开启Bangumi同步或配置无效');
      return false;
    }
    try {
      await Bangumi().ping();
      try {
        await Bangumi().syncCollectibles(onProgress: onProgress);
        if (showSuccessToast) {
          KazumiDialog.showToast(message: 'Bangumi同步完成');
        }
      } catch (e) {
        KazumiDialog.showToast(message: 'Bangumi同步失败 $e');
        return false;
      }
    } catch (e) {
      KazumiLogger().e('Bangumi: Bangumi connection failed', error: e);
      KazumiDialog.showToast(message: 'Bangumi访问失败: $e');
      return false;
    }
    loadCollectibles();
    return true;
  }
}
