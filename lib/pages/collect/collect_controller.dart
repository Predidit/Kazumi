import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';

part 'collect_controller.g.dart';

class CollectController = _CollectController with _$CollectController;

abstract class _CollectController with Store {
  Box setting = GStorage.setting;
  List<BangumiItem> get favorites => GStorage.favorites.values.toList();

  @observable
  ObservableList<CollectedBangumi> collectibles =
      ObservableList<CollectedBangumi>();

  void loadCollectibles() {
    collectibles.clear();
    collectibles.addAll(GStorage.collectibles.values.toList());
  }

  int getCollectType(BangumiItem bangumiItem) {
    CollectedBangumi? collectedBangumi =
        GStorage.collectibles.get(bangumiItem.id);
    if (collectedBangumi == null) {
      return 0;
    } else {
      return collectedBangumi.type;
    }
  }

  Future<void> addCollect(BangumiItem bangumiItem, {type = 1}) async {
    if (type == 0) {
      await deleteCollect(bangumiItem);
      return;
    }
    CollectedBangumi collectedBangumi =
        CollectedBangumi(bangumiItem, DateTime.now(), type);
    await GStorage.collectibles.put(bangumiItem.id, collectedBangumi);
    await GStorage.collectibles.flush();
    final int collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final CollectedBangumiChange collectChange = CollectedBangumiChange(
        collectChangeId,
        bangumiItem.id,
        1,
        type,
        (DateTime.now().millisecondsSinceEpoch ~/ 1000));
    await GStorage.collectChanges.put(collectChangeId, collectChange);
    await GStorage.collectChanges.flush();
    loadCollectibles();
  }

  Future<void> deleteCollect(BangumiItem bangumiItem) async {
    await GStorage.collectibles.delete(bangumiItem.id);
    await GStorage.collectibles.flush();
    final int collectChangeId = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final CollectedBangumiChange collectChange = CollectedBangumiChange(
        collectChangeId,
        bangumiItem.id,
        3,
        5,
        (DateTime.now().millisecondsSinceEpoch ~/ 1000));
    await GStorage.collectChanges.put(collectChangeId, collectChange);
    await GStorage.collectChanges.flush();
    loadCollectibles();
  }

  Future<void> updateLocalCollect(BangumiItem bangumiItem) async {
    CollectedBangumi? collectedBangumi =
        GStorage.collectibles.get(bangumiItem.id);
    if (collectedBangumi == null) {
      return;
    } else {
      collectedBangumi.bangumiItem = bangumiItem;
      await GStorage.collectibles.put(bangumiItem.id, collectedBangumi);
      await GStorage.collectibles.flush();
      loadCollectibles();
    }
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
      await GStorage.favorites.clear();
      await GStorage.favorites.flush();
      KazumiLogger().log(Level.debug, '检测到$count条未分类追番记录, 已迁移');
    }
  }
}
