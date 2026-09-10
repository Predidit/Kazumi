import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_review.dart';
import 'package:kazumi/modules/collect/collect_activity.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/services/collection/collection_service.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';
import 'package:mobx/mobx.dart';
import 'package:url_launcher/url_launcher.dart';

part 'collect_controller.g.dart';

class CollectController = _CollectController with _$CollectController;

abstract class _CollectController with Store {
  _CollectController(this._service) {
    _reload();
    _subscription = _service.changes.listen((_) => _reload());
  }

  final CollectionService _service;

  CollectActivity get activity => _service.activity;

  late final StreamSubscription<void> _subscription;

  @readonly
  List<CollectedBangumi> _collectibles = const [];

  void _reload() {
    _collectibles = List.unmodifiable(_service.collectibles);
  }

  @computed
  Map<int, int> get _collectTypes => {
        for (final collectible in _collectibles)
          collectible.bangumiItem.id: collectible.type,
      };

  int getCollectType(BangumiItem bangumiItem) =>
      _collectTypes[bangumiItem.id] ?? 0;

  void dispose() => _subscription.cancel();

  Future<void> addCollect(BangumiItem item, {int type = 1}) => type == 0
      ? deleteCollect(item)
      : _runCommand(() => _service.setType(item, type, onSync: _syncFeedback));

  Future<void> deleteCollect(BangumiItem item) =>
      _runCommand(() => _service.delete(item,
          chooseAction: _resolveBangumiDeleteSyncAction,
          openWeb: _openBangumiSubjectPage,
          onSync: _syncFeedback));

  Future<void> _runCommand(Future<void> Function() command) async {
    try {
      await command();
    } catch (error, stackTrace) {
      KazumiLogger()
          .e('Collection command failed', error: error, stackTrace: stackTrace);
      KazumiDialog.showToast(message: BangumiSyncService.describeError(error));
    }
  }

  void _syncFeedback(CollectSyncFeedback feedback) {
    if (!GStorage.getSetting(SettingsKeys.bangumiImmediateSyncToastEnable)) {
      return;
    }
    KazumiDialog.showToast(
        message: feedback == CollectSyncFeedback.started
            ? '正在同步到 Bangumi...'
            : '已同步到 Bangumi');
  }

  Future<CollectDeleteAction?> _resolveBangumiDeleteSyncAction() async {
    return KazumiDialog.show<CollectDeleteAction>(
      clickMaskDismiss: true,
      builder: (context) => AlertDialog(
        title: const Text('Bangumi 不支持删除收藏'),
        content: const Text(
          '因为安全考虑，Bangumi 未提供删除接口，您可以选择把本地和远端标记为“抛弃”，或者选择仅删除本地收藏并打开网页后手动删除 Bangumi 数据。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(CollectDeleteAction.cancel);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(CollectDeleteAction.openWeb);
            },
            child: const Text('打开网页'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(CollectDeleteAction.markAbandoned);
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

  Future<void> updateLocalCollect(BangumiItem item) =>
      _service.updateMetadata(item);
  Future<void> migrateCollect() => _service.migrateCollect();
  Future<void> syncAll(CollectSyncPlan plan,
          {required ValueChanged<CollectSyncUpdate> onUpdate}) =>
      _service.syncAll(plan, onUpdate: onUpdate);
  Future<bool> submitReview(int id, BangumiReview review,
          {required bool Function() isCurrent}) =>
      _service.submitReview(id, review, isCurrent: isCurrent);
}
