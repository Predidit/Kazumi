// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/collect/collect_type_mapper.dart';
import 'package:kazumi/utils/bangumi.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/bangumi/bangumi_collection_type.dart';

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

  @action
  Future<void> addCollect(BangumiItem bangumiItem, {type = 1}) async {
    if (type == 0) {
      await deleteCollect(bangumiItem);
      return;
    }
    await _collectCrudRepository.addCollectible(bangumiItem, type);
    final int collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final CollectedBangumiChange collectChange = CollectedBangumiChange(
        collectChangeId,
        bangumiItem.id,
        1,
        type,
        (DateTime.now().millisecondsSinceEpoch ~/ 1000));
    await _collectCrudRepository.addCollectChange(collectChange);
    loadCollectibles();
    await _syncBangumiCollectIfEnabled(bangumiItem.id, type);
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
    final int collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final CollectedBangumiChange collectChange = CollectedBangumiChange(
        collectChangeId,
        bangumiItem.id,
        3,
        5,
        (DateTime.now().millisecondsSinceEpoch ~/ 1000));
    await _collectCrudRepository.addCollectChange(collectChange);
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

  Future<void> _syncBangumiCollectIfEnabled(
      int bangumiId, int localType) async {
    final bool syncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
    final bool showImmediateSyncToast = setting.get(
      SettingBoxKey.bangumiImmediateSyncToastEnable,
      defaultValue: true,
    );

    if (!syncEnable) {
      return;
    }

    final bangumi = Bangumi();
    if (!bangumi.initialized) {
      return;
    }
    try {
      if (showImmediateSyncToast) {
        KazumiDialog.showToast(message: '正在同步到 Bangumi...');
      }
      final bool synced =
          await bangumi.syncCollectibleWhenIdle(bangumiId, localType);
      if (synced && showImmediateSyncToast) {
        KazumiDialog.showToast(message: '已同步到 Bangumi');
      } else if (!synced) {
        KazumiDialog.showToast(message: '同步到 Bangumi 失败');
        KazumiLogger().w(
          'Bangumi: immediate collect sync did not complete. bangumiId=$bangumiId, type=$localType',
        );
      }
    } catch (e, stackTrace) {
      KazumiDialog.showToast(message: '同步到 Bangumi 失败: $e');
      KazumiLogger().e(
        'Bangumi: immediate collect sync failed. bangumiId=$bangumiId, type=$localType',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> updateLocalCollect(BangumiItem bangumiItem) async {
    await _collectCrudRepository.updateCollectible(bangumiItem);
    loadCollectibles();
  }

  Future<void> syncCollectibles() async {
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
      return;
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
      return;
    }
    try {
      await WebDav().syncCollectibles();
    } catch (e){
      KazumiDialog.showToast(message: 'WebDav同步失败 $e');
    }
    loadCollectibles();
  }

  /// 仅上传当前本地收藏与变更日志到 WebDAV，不做下载合并
  Future<void> uploadCollectiblesToWebDav() async {
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
      return;
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
      return;
    }
    try {
      await WebDav().updateCollectibles();
    } catch (e) {
      KazumiDialog.showToast(message: 'WebDav上传失败 $e');
    }
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

  /// Put Bangumi's collect into local collectible,
  /// convert Bangumi's collect type to local collect type
  ///
  /// [bangumiItem] Bangumi item
  /// [bangumiType] Bangumi collect type
  Future<void> addCollectBangumi(BangumiItem bangumiItem,
      {bangumiType = 1}) async {
    final type =
        BangumiCollectionType.fromValue(bangumiType).toCollectType().value;
    await addCollect(bangumiItem, type: type);
  }

  /// Sync Bangumi collectibles.
  ///
  /// [onProgress] Progress callback, parameters are the name of the currently syncing Bangumi,
  /// the index of the currently syncing Bangumi, and the total number of Bangumi.
  /// The callback will be called when syncing each Bangumi, and can be used to show a progress indicator.
  Future<void> syncCollectiblesBangumi(
      {void Function(String message, int current, int total)?
          onProgress}) async {
    if (!Bangumi().initialized) {
      KazumiDialog.showToast(message: '未开启Bangumi同步或配置无效');
      return;
    }
    try {
      await Bangumi().ping();
      try {
        await Bangumi().syncCollectibles(onProgress: onProgress);
      } catch (e) {
        KazumiDialog.showToast(message: 'Bangumi同步失败 $e');
      }
    } catch (e) {
      KazumiLogger().e('Bangumi: Bangumi connection failed', error: e);
      KazumiDialog.showToast(message: 'Bangumi访问失败: $e');
    }
    loadCollectibles();
  }
}
