import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:logger/logger.dart';
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
      KazumiLogger().log(Level.error, 'WebDav连接失败: $e');
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
      KazumiLogger().log(Level.debug, '检测到$count条未分类追番记录, 已迁移');
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
