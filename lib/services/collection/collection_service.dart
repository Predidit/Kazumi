import 'dart:async';

import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_review.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/modules/collect/collect_activity.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_sync_merger.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';
import 'package:kazumi/services/sync/webdav.dart';
import 'package:mobx/mobx.dart';

enum CollectDeleteAction { deleteLocalOnly, markAbandoned, openWeb, cancel }

enum CollectSyncFeedback { started, completed }

class CollectionService {
  CollectionService(this._repository)
      : _activity = Observable(_repository.activity) {
    _subscription = _repository.activityChanges.listen((value) {
      runInAction(() => _activity.value = value);
    });
  }

  final ICollectRepository _repository;
  final Observable<CollectActivity> _activity;
  late final StreamSubscription<CollectActivity> _subscription;
  CollectActivity get activity => _activity.value;
  Stream<void> get changes => _repository.changes;
  List<CollectedBangumi> get collectibles => _repository.getAllCollectibles();
  void dispose() => _subscription.cancel();

  Future<void> setType(BangumiItem item, int type,
          {void Function(CollectSyncFeedback)? onSync}) =>
      _repository.transaction(() async {
        if (type <= 0 || type > 5) throw ArgumentError.value(type, 'type');
        if (await _repository.getCollectType(item.id) == type) return;
        if (GStorage.getSetting(SettingsKeys.bangumiSyncEnable)) {
          onSync?.call(CollectSyncFeedback.started);
          final synced =
              await BangumiSyncService().updateCollectible(item.id, type);
          if (!synced) throw StateError('同步到 Bangumi 失败，已取消本次状态修改');
          onSync?.call(CollectSyncFeedback.completed);
        }
        await _repository.addCollectible(item, type);
      }, itemId: item.id);

  Future<void> delete(
    BangumiItem item, {
    required Future<CollectDeleteAction?> Function() chooseAction,
    required Future<void> Function(int) openWeb,
    void Function(CollectSyncFeedback)? onSync,
  }) =>
      _repository.transaction(() async {
        if (await _repository.getCollectType(item.id) == 0) return;
        final action = GStorage.getSetting(SettingsKeys.bangumiSyncEnable)
            ? await chooseAction()
            : CollectDeleteAction.deleteLocalOnly;
        switch (action) {
          case CollectDeleteAction.markAbandoned:
            await setType(item, CollectType.abandoned.value, onSync: onSync);
          case CollectDeleteAction.openWeb:
            await _repository.deleteCollectible(item.id);
            await openWeb(item.id);
          case CollectDeleteAction.deleteLocalOnly:
            await _repository.deleteCollectible(item.id);
          case CollectDeleteAction.cancel:
          case null:
            return;
        }
      }, itemId: item.id);

  Future<void> updateMetadata(BangumiItem item) =>
      _repository.updateCollectible(item);

  Future<bool> submitReview(int id, BangumiReview review,
          {required bool Function() isCurrent}) =>
      _repository.transaction(() async {
        if (!isCurrent()) return false;
        final type = await _repository.getCollectType(id);
        if (!isCurrent() || type == 0) return false;
        return BangumiApi.addOrUpdateBangumiEvaluationBySubjectID(id, type,
            comment: review.comment, rate: review.score, tags: review.tags);
      }, itemId: id);

  Future<void> syncWebDav() =>
      _withWebDav((webDav) => webDav.syncCollectibles(_repository));
  Future<void> uploadWebDav() =>
      _withWebDav((webDav) => webDav.updateCollectibles(_repository));
  Future<void> syncBangumi({void Function(String, int, int)? onProgress}) =>
      _repository.transaction(
          () => BangumiSyncService().runConnected((username) async {
                onProgress?.call('开始同步 Bangumi 状态', 0, 0);

                final priority = BangumiSyncPriority.fromValue(
                  GStorage.getSetting(SettingsKeys.bangumiSyncPriority),
                );

                final remoteCollection =
                    await BangumiApi.getBangumiCollectibles(
                  username: username,
                  limit: 50,
                  onProgress: onProgress,
                );

                final mergePlan = CollectSyncMerger.planBangumi(
                  localCollectibles: await _repository.readForSync(),
                  remoteCollections: remoteCollection,
                  priority: priority,
                );
                final totalOperations = mergePlan.totalOperations;

                if (totalOperations == 0) {
                  onProgress?.call('未发现状态差异，无需同步', 1, 1);
                  return;
                }

                int syncedCount = 0;
                if (mergePlan.localOnlyUploads.isNotEmpty) {
                  onProgress?.call('正在上传本地新增状态', syncedCount, totalOperations);
                  for (final upload in mergePlan.localOnlyUploads) {
                    final updated = await BangumiApi.updateBangumiByType(
                      upload.bangumiId,
                      upload.type,
                    );
                    if (!updated) {
                      onProgress?.call(
                          '上传本地新增状态失败', syncedCount, totalOperations);
                      throw Exception(
                          '同步失败：条目 ${upload.bangumiId} 上传到 Bangumi 失败');
                    }
                    syncedCount++;
                    onProgress?.call(
                        '正在上传本地新增状态', syncedCount, totalOperations);
                  }
                }

                if (mergePlan.remoteOnlyPuts.isNotEmpty) {
                  onProgress?.call('正在补全本地缺失状态', syncedCount, totalOperations);
                  for (final mutation in mergePlan.remoteOnlyPuts) {
                    await _repository
                        .putSyncedCollectible(mutation.collectible);
                    syncedCount++;
                    onProgress?.call(
                        '正在补全本地缺失状态', syncedCount, totalOperations);
                  }
                }

                if (mergePlan.conflictUploads.isNotEmpty) {
                  onProgress?.call('${priority.label}：正在上传冲突状态', syncedCount,
                      totalOperations);
                  for (final upload in mergePlan.conflictUploads) {
                    final updated = await BangumiApi.updateBangumiByType(
                      upload.bangumiId,
                      upload.type,
                    );
                    if (!updated) {
                      throw Exception(
                          '同步失败：条目 ${upload.bangumiId} 上传到 Bangumi 失败');
                    }
                    syncedCount++;
                    onProgress?.call('${priority.label}：正在上传冲突状态', syncedCount,
                        totalOperations);
                  }
                }
                if (mergePlan.conflictLocalUpdates.isNotEmpty) {
                  onProgress?.call('${priority.label}：正在更新本地冲突状态', syncedCount,
                      totalOperations);
                  for (final mutation in mergePlan.conflictLocalUpdates) {
                    await _repository
                        .putSyncedCollectible(mutation.collectible);
                    syncedCount++;
                    onProgress?.call('${priority.label}：正在更新本地冲突状态',
                        syncedCount, totalOperations);
                  }
                }
                onProgress?.call('Bangumi 状态同步完成', 1, 1);
              }, requireSyncEnabled: true),
          sync: true);

  Future<void> _withWebDav(Future<void> Function(WebDav) action) =>
      _repository.transaction(() async {
        if (!GStorage.getSetting(SettingsKeys.webDavEnableCollect)) {
          throw StateError('请开启 WebDAV 收藏同步');
        }
        final webDav = WebDav();
        if (!webDav.initialized) {
          throw StateError('WebDAV 未连接，请检查配置');
        }
        try {
          await webDav.ping();
        } catch (error, stackTrace) {
          KazumiLogger().e('WebDAV connection failed',
              error: error, stackTrace: stackTrace);
          throw StateError('WebDAV 连接失败，请检查网络或配置');
        }
        await action(webDav);
      }, sync: true);

  Future<void> syncAll(
    CollectSyncPlan plan, {
    required void Function(CollectSyncUpdate) onUpdate,
  }) =>
      _repository.transaction(() async {
        final succeeded = <CollectSyncStep>{};
        for (final step in plan.steps) {
          if (step == CollectSyncStep.upload &&
              !plan.shouldUploadWebDavAfterBangumi(
                webDavSynced: succeeded.contains(CollectSyncStep.webDav),
                bangumiSynced: succeeded.contains(CollectSyncStep.bangumi),
              )) {
            onUpdate(CollectSyncUpdate(step, CollectSyncStatus.skipped,
                message: '前两步未全部完成'));
            continue;
          }
          onUpdate(CollectSyncUpdate(step, CollectSyncStatus.running,
              message: '正在连接…'));
          String? failure;
          try {
            await switch (step) {
              CollectSyncStep.webDav => syncWebDav(),
              CollectSyncStep.upload => uploadWebDav(),
              CollectSyncStep.bangumi => syncBangumi(
                  onProgress: (message, current, total) =>
                      onUpdate(CollectSyncUpdate(
                    step,
                    CollectSyncStatus.running,
                    message:
                        total > 0 ? '$message · $current / $total' : message,
                    progress:
                        total > 0 ? (current / total).clamp(0.0, 1.0) : null,
                  )),
                ),
            };
            succeeded.add(step);
          } catch (error, stackTrace) {
            KazumiLogger().e('Collection sync failed: ${step.name}',
                error: error, stackTrace: stackTrace);
            failure = error is StateError
                ? error.message.toString()
                : switch (step) {
                    CollectSyncStep.bangumi =>
                      BangumiSyncService.describeError(error),
                    CollectSyncStep.webDav => 'WebDAV 同步失败，请检查连接',
                    CollectSyncStep.upload => 'WebDAV 回传失败，请检查连接',
                  };
          }
          onUpdate(CollectSyncUpdate(
            step,
            failure == null
                ? CollectSyncStatus.succeeded
                : CollectSyncStatus.failed,
            message: failure,
          ));
        }
      }, sync: true);

  Future<void> migrateCollect() => _repository.transaction(() async {
        final favorites = _repository.getFavorites();
        if (favorites.isEmpty) return;
        // Migration must work before Bangumi is initialized.
        for (final item in favorites) {
          await _repository.addCollectible(item, CollectType.watching.value);
        }
        await _repository.clearFavorites();
        KazumiLogger().d('Migrated ${favorites.length} legacy favorites');
      }, sync: true);
}
