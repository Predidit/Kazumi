import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_activity.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/storage/collect_transactions.dart';
import 'package:kazumi/services/storage/storage.dart';

abstract class ICollectRepository {
  Stream<void> get changes;
  List<CollectedBangumi> getAllCollectibles();
  CollectedBangumi? getCollectible(int id);
  Future<int> getCollectType(int id);
  Future<void> addCollectible(BangumiItem bangumiItem, int type);
  Future<void> updateCollectible(BangumiItem bangumiItem);
  Future<void> deleteCollectible(int id);
  List<BangumiItem> getFavorites();
  Future<void> clearFavorites();
  CollectActivity get activity;
  Stream<CollectActivity> get activityChanges;
  Future<T> transaction<T>(Future<T> Function() action,
      {int? itemId, bool sync = false});
  Future<List<CollectedBangumi>> readForSync();
  Future<void> putSyncedCollectible(CollectedBangumi item);
  Future<void> mergeSyncFiles({String? itemsPath, String? changesPath});
  Future<Map<String, List<int>>> exportSyncFiles();

  Set<int> getBangumiIdsByType(CollectType type);
}

class CollectRepository implements ICollectRepository {
  final _storage = GStorage.collection;
  final _favorites = GStorage.favorites;

  @override
  Stream<void> get changes => _storage.changes;

  @override
  List<CollectedBangumi> getAllCollectibles() => _storage.snapshot;

  @override
  CollectedBangumi? getCollectible(int id) {
    for (final item in _storage.snapshot) {
      if (item.bangumiItem.id == id) return item;
    }
    return null;
  }

  @override
  Future<int> getCollectType(int id) => _storage.readType(id);

  @override
  Future<void> addCollectible(BangumiItem bangumiItem, int type) =>
      _storage.put(CollectedBangumi(bangumiItem, DateTime.now(), type));

  @override
  Future<void> updateCollectible(BangumiItem bangumiItem) =>
      _storage.updateMetadata(bangumiItem);

  @override
  Future<void> deleteCollectible(int id) => _storage.delete(id);

  @override
  List<BangumiItem> getFavorites() => _favorites.values.toList();

  @override
  Future<void> clearFavorites() async {
    await _favorites.clear();
    await _favorites.flush();
  }

  final _transactions = CollectTransactions();

  @override
  CollectActivity get activity => _transactions.activity;

  @override
  Stream<CollectActivity> get activityChanges => _transactions.activityChanges;

  @override
  Future<T> transaction<T>(Future<T> Function() action,
          {int? itemId, bool sync = false}) =>
      _transactions.run(action, itemId: itemId, sync: sync);

  @override
  Future<List<CollectedBangumi>> readForSync() => _storage.read();

  @override
  Future<void> putSyncedCollectible(CollectedBangumi item) =>
      _storage.put(item);

  @override
  Future<void> mergeSyncFiles({String? itemsPath, String? changesPath}) async {
    final items = itemsPath == null
        ? <CollectedBangumi>[]
        : await GStorage.getCollectiblesFromFile(itemsPath);
    final changes = changesPath == null
        ? <CollectedBangumiChange>[]
        : await GStorage.getCollectChangesFromFile(changesPath);
    if (items.isNotEmpty || changes.isNotEmpty) {
      await _storage.merge(items, changes);
    }
  }

  @override
  Future<Map<String, List<int>>> exportSyncFiles() => _storage.exportFiles();

  @override
  Set<int> getBangumiIdsByType(CollectType type) => _storage.snapshot
      .where((item) => item.type == type.value)
      .map((item) => item.bangumiItem.id)
      .toSet();
}
