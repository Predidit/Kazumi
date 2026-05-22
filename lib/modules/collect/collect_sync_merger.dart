import 'package:kazumi/modules/bangumi/bangumi_collection.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type_mapper.dart';

class CollectiblesMergeResult {
  const CollectiblesMergeResult({
    required this.collectibles,
    required this.changes,
  });

  final List<CollectedBangumi> collectibles;
  final List<CollectedBangumiChange> changes;
}

class BangumiUploadMutation {
  const BangumiUploadMutation({
    required this.bangumiId,
    required this.type,
  });

  final int bangumiId;
  final int type;
}

class BangumiLocalMutation {
  const BangumiLocalMutation({
    required this.collectible,
    required this.changeAction,
  });

  final CollectedBangumi collectible;
  final int changeAction;
}

class BangumiCollectiblesMergePlan {
  const BangumiCollectiblesMergePlan({
    required this.localOnlyUploads,
    required this.remoteOnlyPuts,
    required this.conflictUploads,
    required this.conflictLocalUpdates,
  });

  final List<BangumiUploadMutation> localOnlyUploads;
  final List<BangumiLocalMutation> remoteOnlyPuts;
  final List<BangumiUploadMutation> conflictUploads;
  final List<BangumiLocalMutation> conflictLocalUpdates;

  int get totalOperations =>
      localOnlyUploads.length +
      remoteOnlyPuts.length +
      conflictUploads.length +
      conflictLocalUpdates.length;
}

class CollectSyncMerger {
  static CollectiblesMergeResult mergeWebDav({
    required List<CollectedBangumi> localCollectibles,
    required List<CollectedBangumiChange> localChanges,
    required List<CollectedBangumi> remoteCollectibles,
    required List<CollectedBangumiChange> remoteChanges,
  }) {
    final mergedCollectibles =
        remoteCollectibles.map(_copyCollectible).toList();
    final newLocalChanges = localChanges.where((localChange) {
      return !remoteChanges
          .any((remoteChange) => remoteChange.id == localChange.id);
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final change in newLocalChanges) {
      if (change.action == 3) {
        mergedCollectibles
            .removeWhere((item) => item.bangumiItem.id == change.bangumiID);
        continue;
      }

      final localCollectible = _findCollectible(
        localCollectibles,
        change.bangumiID,
      );
      if (localCollectible == null) {
        continue;
      }

      final changedCollectible = CollectedBangumi(
        localCollectible.bangumiItem,
        localCollectible.time,
        change.type,
      );
      final index = mergedCollectibles.indexWhere(
        (item) => item.bangumiItem.id == change.bangumiID,
      );

      if (change.action == 1) {
        if (index == -1) {
          mergedCollectibles.add(changedCollectible);
        } else {
          mergedCollectibles[index] = changedCollectible;
        }
      } else if (change.action == 2 && index != -1) {
        mergedCollectibles[index] = changedCollectible;
      }
    }

    final mergedChanges = <int, CollectedBangumiChange>{
      for (final change in remoteChanges) change.id: change,
      for (final change in newLocalChanges) change.id: change,
    }.values.toList();

    return CollectiblesMergeResult(
      collectibles: mergedCollectibles,
      changes: mergedChanges,
    );
  }

  static BangumiCollectiblesMergePlan planBangumi({
    required List<CollectedBangumi> localCollectibles,
    required List<BangumiCollection> remoteCollections,
    required BangumiSyncPriority priority,
  }) {
    final localMap = {
      for (final item in localCollectibles) item.bangumiItem.id: item,
    };
    final remoteMap = <int, BangumiCollection>{};
    for (final item in remoteCollections) {
      final remoteCollectType = item.type.toCollectType();
      if (!remoteCollectType.isCollected) {
        continue;
      }
      remoteMap[item.bangumiId] = item;
    }

    final localOnlyIds = localMap.keys
        .toSet()
        .difference(remoteMap.keys.toSet())
        .toList()
      ..sort();
    final remoteOnlyIds = remoteMap.keys
        .toSet()
        .difference(localMap.keys.toSet())
        .toList()
      ..sort();
    final sharedIds = localMap.keys
        .toSet()
        .intersection(remoteMap.keys.toSet())
        .toList()
      ..sort();
    final mismatchIds = <int>[];
    for (final id in sharedIds) {
      if (localMap[id]!.type != remoteMap[id]!.type.toCollectType().value) {
        mismatchIds.add(id);
      }
    }

    final localOnlyUploads = [
      for (final id in localOnlyIds)
        BangumiUploadMutation(bangumiId: id, type: localMap[id]!.type),
    ];
    final remoteOnlyPuts = [
      for (final id in remoteOnlyIds)
        BangumiLocalMutation(
          collectible: _fromBangumiCollection(remoteMap[id]!),
          changeAction: 1,
        ),
    ];

    final conflictUploads = <BangumiUploadMutation>[];
    final conflictLocalUpdates = <BangumiLocalMutation>[];
    if (priority == BangumiSyncPriority.localFirst) {
      for (final id in mismatchIds) {
        conflictUploads.add(
          BangumiUploadMutation(bangumiId: id, type: localMap[id]!.type),
        );
      }
    } else {
      for (final id in mismatchIds) {
        conflictLocalUpdates.add(
          BangumiLocalMutation(
            collectible: _fromBangumiCollection(remoteMap[id]!),
            changeAction: 2,
          ),
        );
      }
    }

    return BangumiCollectiblesMergePlan(
      localOnlyUploads: localOnlyUploads,
      remoteOnlyPuts: remoteOnlyPuts,
      conflictUploads: conflictUploads,
      conflictLocalUpdates: conflictLocalUpdates,
    );
  }

  static CollectedBangumi _fromBangumiCollection(BangumiCollection remote) {
    final localType = remote.type.toCollectType();
    return CollectedBangumi(
      remote.toBangumiItem(),
      remote.updatedAt,
      localType.value,
    );
  }

  static CollectedBangumi? _findCollectible(
    List<CollectedBangumi> collectibles,
    int bangumiId,
  ) {
    for (final collectible in collectibles) {
      if (collectible.bangumiItem.id == bangumiId) {
        return collectible;
      }
    }
    return null;
  }

  static CollectedBangumi _copyCollectible(CollectedBangumi collectible) {
    return CollectedBangumi(
      collectible.bangumiItem,
      collectible.time,
      collectible.type,
    );
  }

  CollectSyncMerger._();
}
