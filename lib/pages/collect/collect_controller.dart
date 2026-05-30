import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/webdav.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/services/logging/logger.dart';

part 'collect_controller.g.dart';

// Define actions for handling Bangumi collect deletion.
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

  BangumiItem? getCollectibleBangumiItem(int id) {
    return _collectCrudRepository.getCollectible(id)?.bangumiItem;
  }

  @action
  Future<void> addCollect(BangumiItem bangumiItem, {type = 1}) async {
    if (type == 0) {
      await deleteCollect(bangumiItem);
      return;
    }

    // 1. Sync with Bangumi if enabled
    final bool syncSucceeded = await _syncBangumiCollectIfEnabled(
      bangumiItem.id,
      type,
    );
    if (!syncSucceeded) {
      return;
    }

    final int currentCollectType = getCollectType(bangumiItem);
    final int collectChangeAction = currentCollectType == 0 ? 1 : 2;

    // 2. Update local database and change logs
    await _collectCrudRepository.addCollectible(bangumiItem, type);
    await GStorage.appendCollectChange(
      bangumiId: bangumiItem.id,
      action: collectChangeAction,
      type: type,
    );
    loadCollectibles();
  }

  @action
  Future<void> deleteCollect(BangumiItem bangumiItem) async {
    // Resolve how to handle deletion with user
    final action = await _resolveBangumiDeleteSyncAction(bangumiItem);
    switch (action) {
      case _BangumiDeleteSyncAction.markAbandoned:
        await addCollect(
          bangumiItem,
          type: CollectType.abandoned.value,
        );
        return;

      case _BangumiDeleteSyncAction.openWeb:
        await _deleteCollectLocally(bangumiItem);
        await _openBangumiSubjectPage(bangumiItem.id);
        return;

      case _BangumiDeleteSyncAction.deleteLocalOnly:
        await _deleteCollectLocally(bangumiItem);
        return;

      case _BangumiDeleteSyncAction.cancel:
      case null:
        return;
    }
  }

  Future<void> _deleteCollectLocally(BangumiItem bangumiItem) async {
    await _collectCrudRepository.deleteCollectible(bangumiItem.id);
    await GStorage.appendCollectChange(
      bangumiId: bangumiItem.id,
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

    final bangumi = BangumiSyncService();
    if (!bangumi.initialized) {
      return _BangumiDeleteSyncAction.deleteLocalOnly;
    }

    return KazumiDialog.show<_BangumiDeleteSyncAction>(
      clickMaskDismiss: true,
      builder: (context) => AlertDialog(
        title: const Text('Bangumi does not support deleting collections'),
        content: const Text(
          'For security reasons, Bangumi does not provide a delete interface. You can mark both local and remote as “Dropped”, or delete only the local collection and remove the Bangumi data manually after opening the web page.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_BangumiDeleteSyncAction.cancel);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_BangumiDeleteSyncAction.openWeb);
            },
            child: const Text('Open web page'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(_BangumiDeleteSyncAction.markAbandoned);
            },
            child: const Text('Mark as dropped'),
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
    KazumiDialog.showToast(message: 'Cannot open the Bangumi web page');
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

    final bangumi = BangumiSyncService();
    if (!bangumi.initialized) {
      KazumiDialog.showToast(message: 'Bangumi is not initialized, sync failed, this status change has been canceled');
      KazumiLogger().w(
        'Bangumi: immediate collect sync skipped because Bangumi is not initialized. '
        'bangumiId=$bangumiId, type=$localType',
      );
      return false;
    }
    try {
      if (showImmediateSyncToast) {
        KazumiDialog.showToast(message: 'Syncing to Bangumi...');
      }
      final bool synced =
          await bangumi.syncCollectibleWhenIdle(bangumiId, localType);
      if (synced && showImmediateSyncToast) {
        KazumiDialog.showToast(message: 'Synced to Bangumi');
        return true;
      } else if (!synced) {
        KazumiDialog.showToast(message: 'Failed to sync to Bangumi, this status change has been canceled');
        KazumiLogger().w(
          'Bangumi: immediate collect sync did not complete. bangumiId=$bangumiId, type=$localType',
        );
        return false;
      }
      return true;
    } catch (e, stackTrace) {
      KazumiDialog.showToast(message: 'Failed to sync to Bangumi, this status change has been canceled: $e');
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
    final bool webDavCollectEnable =
        setting.get(SettingBoxKey.webDavEnableCollect, defaultValue: false);
    if (!webDavCollectEnable) {
      KazumiDialog.showToast(message: 'WebDav collection sync is not enabled');
      return false;
    }
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: 'WebDav sync is not enabled or the configuration is invalid');
      return false;
    }
    bool flag = true;
    try {
      await WebDav().ping();
    } catch (e) {
      KazumiLogger().e('WebDav: WebDav connection failed', error: e);
      KazumiDialog.showToast(message: 'WebDav connection failed: $e');
      flag = false;
    }
    if (!flag) {
      return false;
    }
    try {
      await WebDav().syncCollectibles();
      if (showSuccessToast) {
        KazumiDialog.showToast(message: 'WebDav sync complete');
      }
    } catch (e) {
      KazumiDialog.showToast(message: 'WebDav sync failed $e');
      return false;
    }
    loadCollectibles();
    return true;
  }

  /// Only upload local collectibles and change logs to WebDAV, without downloading and merging.
  /// Used by full sync to push Bangumi-updated local changes back to WebDAV.
  Future<bool> uploadCollectiblesToWebDav(
      {bool showSuccessToast = true}) async {
    final bool webDavCollectEnable =
        setting.get(SettingBoxKey.webDavEnableCollect, defaultValue: false);
    if (!webDavCollectEnable) {
      KazumiDialog.showToast(message: 'WebDav collection sync is not enabled');
      return false;
    }
    if (!WebDav().initialized) {
      KazumiDialog.showToast(message: 'WebDav sync is not enabled or the configuration is invalid');
      return false;
    }
    bool flag = true;
    try {
      await WebDav().ping();
    } catch (e) {
      KazumiLogger().e('WebDav: WebDav connection failed', error: e);
      KazumiDialog.showToast(message: 'WebDav connection failed: $e');
      flag = false;
    }
    if (!flag) {
      return false;
    }
    try {
      await WebDav().updateCollectibles();
      if (showSuccessToast) {
        KazumiDialog.showToast(message: 'WebDav upload complete');
      }
    } catch (e) {
      KazumiDialog.showToast(message: 'WebDav upload failed $e');
      return false;
    }
    return true;
  }

  // migrate collect from old version (favorites)
  Future<void> migrateCollect() async {
    if (favorites.isNotEmpty) {
      int count = 0;
      for (BangumiItem bangumiItem in favorites) {
        // Migration should never depend on runtime Bangumi initialization.
        // Persist locally and append change logs, then let later sync handle remote updates.
        final int currentCollectType = getCollectType(bangumiItem);
        final int collectChangeAction = currentCollectType == 0 ? 1 : 2;
        await _collectCrudRepository.addCollectible(bangumiItem, 1);
        await GStorage.appendCollectChange(
          bangumiId: bangumiItem.id,
          action: collectChangeAction,
          type: 1,
        );
        count++;
      }
      await _collectCrudRepository.clearFavorites();
      loadCollectibles();
      KazumiLogger().d(
          'GStorage: detected $count uncategorized favorites, migrated to collectibles');
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
    return bangumiList.where((item) => !excludeIds.contains(item.id)).toList();
  }

  /// Sync Bangumi collectibles.
  Future<bool> syncCollectiblesBangumi(
      {void Function(String message, int current, int total)? onProgress,
      bool showSuccessToast = true}) async {
    final bool syncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
    if (!syncEnable) {
      KazumiDialog.showToast(message: 'Bangumi sync is not enabled, please enable it in settings first');
      return false;
    }

    if (!BangumiSyncService().initialized) {
      KazumiDialog.showToast(message: 'Bangumi sync is enabled but not initialized, please check the Token and retry');
      return false;
    }
    try {
      await BangumiSyncService().ping();
      try {
        final hasChanges =
            await BangumiSyncService().syncCollectibles(onProgress: onProgress);
        if (showSuccessToast) {
          KazumiDialog.showToast(
            message: hasChanges ? 'Bangumi sync complete' : 'No status differences found, no sync needed',
          );
        }
      } catch (e) {
        KazumiDialog.showToast(message: 'Bangumi sync failed $e');
        return false;
      }
    } catch (e) {
      KazumiLogger().e('Bangumi: Bangumi connection failed', error: e);
      KazumiDialog.showToast(message: 'Bangumi access failed: $e');
      return false;
    }
    loadCollectibles();
    return true;
  }
}
