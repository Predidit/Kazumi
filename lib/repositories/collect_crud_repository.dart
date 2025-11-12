import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// 收藏CRUD数据访问接口
///
/// 提供收藏数据的增删改查操作
abstract class ICollectCrudRepository {
  /// 获取所有收藏
  List<CollectedBangumi> getAllCollectibles();

  /// 获取单个收藏
  ///
  /// [id] 番剧ID
  /// 返回收藏对象，如果不存在返回null
  CollectedBangumi? getCollectible(int id);

  /// 获取收藏类型
  ///
  /// [id] 番剧ID
  /// 返回收藏类型值，未收藏返回0
  int getCollectType(int id);

  /// 添加或更新收藏
  ///
  /// [bangumiItem] 番剧信息
  /// [type] 收藏类型
  Future<void> addCollectible(BangumiItem bangumiItem, int type);

  /// 更新收藏的番剧信息
  ///
  /// [bangumiItem] 更新后的番剧信息
  Future<void> updateCollectible(BangumiItem bangumiItem);

  /// 删除收藏
  ///
  /// [id] 番剧ID
  Future<void> deleteCollectible(int id);

  /// 记录收藏变更（用于WebDAV同步）
  ///
  /// [change] 变更记录
  Future<void> addCollectChange(CollectedBangumiChange change);

  /// 获取旧版收藏列表（用于迁移）
  List<BangumiItem> getFavorites();

  /// 清空旧版收藏（迁移后）
  Future<void> clearFavorites();
}

/// 收藏CRUD数据访问实现类
///
/// 基于Hive实现的收藏CRUD数据访问层
class CollectCrudRepository implements ICollectCrudRepository {
  final _collectiblesBox = GStorage.collectibles;
  final _collectChangesBox = GStorage.collectChanges;
  final _favoritesBox = GStorage.favorites;

  @override
  List<CollectedBangumi> getAllCollectibles() {
    try {
      return _collectiblesBox.values.cast<CollectedBangumi>().toList();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取所有收藏失败',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  CollectedBangumi? getCollectible(int id) {
    try {
      return _collectiblesBox.get(id);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取收藏失败: id=$id',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  int getCollectType(int id) {
    try {
      final collectible = _collectiblesBox.get(id);
      return collectible?.type ?? 0;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取收藏类型失败: id=$id',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  @override
  Future<void> addCollectible(BangumiItem bangumiItem, int type) async {
    try {
      final collectedBangumi = CollectedBangumi(
        bangumiItem,
        DateTime.now(),
        type,
      );
      await _collectiblesBox.put(bangumiItem.id, collectedBangumi);
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '添加收藏失败: id=${bangumiItem.id}, type=$type',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateCollectible(BangumiItem bangumiItem) async {
    try {
      final collectible = _collectiblesBox.get(bangumiItem.id);
      if (collectible == null) {
        KazumiLogger().log(
          Level.warning,
          '更新收藏失败: 收藏不存在, id=${bangumiItem.id}',
        );
        return;
      }
      collectible.bangumiItem = bangumiItem;
      await _collectiblesBox.put(bangumiItem.id, collectible);
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '更新收藏失败: id=${bangumiItem.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteCollectible(int id) async {
    try {
      await _collectiblesBox.delete(id);
      await _collectiblesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '删除收藏失败: id=$id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> addCollectChange(CollectedBangumiChange change) async {
    try {
      await _collectChangesBox.put(change.id, change);
      await _collectChangesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '记录收藏变更失败: changeId=${change.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  List<BangumiItem> getFavorites() {
    try {
      return _favoritesBox.values.cast<BangumiItem>().toList();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取旧版收藏失败',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  Future<void> clearFavorites() async {
    try {
      await _favoritesBox.clear();
      await _favoritesBox.flush();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '清空旧版收藏失败',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
