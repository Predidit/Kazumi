import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_auth_models.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:hive_ce/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/logger.dart';

part 'collect_controller.g.dart';

class CollectController = _CollectController with _$CollectController;

abstract class _CollectController with Store {
  final _collectCrudRepository = Modular.get<ICollectCrudRepository>();
  final _collectRepository = Modular.get<ICollectRepository>();

  Box setting = GStorage.setting;
  List<BangumiItem> get favorites => _collectCrudRepository.getFavorites();

  @observable
  ObservableList<CollectedBangumi> collectibles =
      ObservableList<CollectedBangumi>();

  @observable
  bool bangumiSyncing = false;

  @observable
  int bangumiSyncTotal = 0;

  @observable
  int bangumiSyncProcessed = 0;

  @observable
  String bangumiSyncCurrentName = '';

  @observable
  String bangumiSyncStage = '';

  double get bangumiSyncProgress {
    if (bangumiSyncTotal <= 0) {
      return 0;
    }
    return bangumiSyncProcessed / bangumiSyncTotal;
  }

  @action
  void _startBangumiSync() {
    bangumiSyncing = true;
    bangumiSyncTotal = 0;
    bangumiSyncProcessed = 0;
    bangumiSyncCurrentName = '';
    bangumiSyncStage = '正在拉取 Bangumi 收藏列表';
  }

  @action
  void _updateBangumiSyncProgress({
    int? total,
    int? processed,
    String? currentName,
    String? stage,
  }) {
    if (total != null) {
      bangumiSyncTotal = total;
    }
    if (processed != null) {
      bangumiSyncProcessed = processed;
    }
    if (currentName != null) {
      bangumiSyncCurrentName = currentName;
    }
    if (stage != null) {
      bangumiSyncStage = stage;
    }
  }

  @action
  void _finishBangumiSync() {
    bangumiSyncing = false;
    bangumiSyncCurrentName = '';
    bangumiSyncStage = '';
  }

  void loadCollectibles() {
    collectibles.clear();
    collectibles.addAll(_collectCrudRepository.getAllCollectibles());
  }

  Future<int?> syncBangumiCollectionType(BangumiItem bangumiItem) async {
    if (!BangumiAuth.isLoggedIn) {
      return null;
    }
    final int? remoteType = await BangumiHTTP.getCollectionType(bangumiItem.id);
    if (remoteType == null) {
      return null;
    }
    if (remoteType == 0) {
      await _collectCrudRepository.deleteCollectible(bangumiItem.id);
    } else {
      await _collectCrudRepository.addCollectible(bangumiItem, remoteType);
    }
    loadCollectibles();
    return remoteType;
  }

  Future<void> addCollectAndSync(BangumiItem bangumiItem, {required int type}) async {
    await addCollect(bangumiItem, type: type);
    if (!BangumiAuth.isLoggedIn || type == 0) {
      return;
    }
    await BangumiHTTP.updateCollectionType(bangumiItem.id, type);
  }

  Future<void> syncBangumiCollections() async {
    if (!BangumiAuth.isLoggedIn) {
      KazumiDialog.showToast(message: '请先登录 Bangumi');
      return;
    }
    _startBangumiSync();
    final List<BangumiSubjectCollection> remoteCollections = [];
    try {
      int offset = 0;
      const int limit = 100;
      while (true) {
        final page = await BangumiHTTP.getUserCollections(limit: limit, offset: offset);
        if (page.isEmpty) {
          break;
        }
        remoteCollections.addAll(page);
        _updateBangumiSyncProgress(
          total: remoteCollections.length,
          stage: '已获取 ${remoteCollections.length} 条 Bangumi 收藏',
        );
        if (page.length < limit) {
          break;
        }
        offset += limit;
      }

      final remoteIds = <int>{};
      _updateBangumiSyncProgress(
        total: remoteCollections.length,
        processed: 0,
        stage: '正在同步收藏状态',
      );
      for (final collection in remoteCollections) {
        remoteIds.add(collection.subjectId);
        final subject = collection.subject;
        final displayName = subject?.nameCn.isNotEmpty == true
            ? subject!.nameCn
            : (subject?.name ?? 'ID ${collection.subjectId}');
        _updateBangumiSyncProgress(currentName: displayName);
        final mappedType = await BangumiHTTP.getCollectionType(collection.subjectId);
        if (mappedType != null && mappedType != 0 && subject != null) {
          await _collectCrudRepository.addCollectible(
              subject.toBangumiItem(), mappedType);
          loadCollectibles();
        }
        _updateBangumiSyncProgress(
          processed: bangumiSyncProcessed + 1,
          stage: '正在同步收藏状态',
        );
      }

      _updateBangumiSyncProgress(
        stage: '正在清理本地不存在于 Bangumi 的条目',
        currentName: '',
      );
      final localItems = _collectCrudRepository.getAllCollectibles();
      for (final localItem in localItems) {
        if (!remoteIds.contains(localItem.bangumiItem.id)) {
          await _collectCrudRepository.deleteCollectible(localItem.bangumiItem.id);
          loadCollectibles();
        }
      }
      loadCollectibles();
      _updateBangumiSyncProgress(
        processed: bangumiSyncTotal,
        stage: 'Bangumi 收藏同步完成',
      );
    } finally {
      _finishBangumiSync();
    }
  }

  Future<void> markEpisodeWatchedIfNeeded({
    required BangumiItem bangumiItem,
    required int subjectId,
    required int episodeId,
  }) async {
    if (!BangumiAuth.isLoggedIn) {
      return;
    }
    final int currentType = getCollectType(bangumiItem);
    if (currentType != 1) {
      return;
    }
    await BangumiHTTP.updateCollectionType(subjectId, 1);
    await BangumiHTTP.markEpisodeWatched(subjectId: subjectId, episodeId: episodeId);
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
  }

  @action
  Future<void> deleteCollect(BangumiItem bangumiItem) async {
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
}
