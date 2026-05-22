import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_collection.dart';
import 'package:kazumi/modules/bangumi/bangumi_collection_type.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_sync_merger.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/modules/collect/collect_type.dart';

void main() {
  group('CollectSyncPlan', () {
    test('keeps WebDAV history-only mode out of collectible sync', () {
      const plan = CollectSyncPlan(
        webDavEnabled: true,
        webDavCollectiblesEnabled: false,
        bangumiEnabled: false,
      );

      expect(plan.shouldSyncWebDavCollectibles, isFalse);
      expect(plan.shouldSyncBangumi, isFalse);
      expect(plan.canSync, isFalse);
    });

    test('allows Bangumi-only sync while WebDAV is enabled for history', () {
      const plan = CollectSyncPlan(
        webDavEnabled: true,
        webDavCollectiblesEnabled: false,
        bangumiEnabled: true,
      );

      expect(plan.shouldSyncWebDavCollectibles, isFalse);
      expect(plan.shouldSyncBangumi, isTrue);
      expect(plan.canSync, isTrue);
    });

    test('allows WebDAV-only collectible sync', () {
      const plan = CollectSyncPlan(
        webDavEnabled: true,
        webDavCollectiblesEnabled: true,
        bangumiEnabled: false,
      );

      expect(plan.shouldSyncWebDavCollectibles, isTrue);
      expect(plan.shouldSyncBangumi, isFalse);
      expect(plan.canSync, isTrue);
    });

    test('uploads back to WebDAV only after both sources finished', () {
      const plan = CollectSyncPlan(
        webDavEnabled: true,
        webDavCollectiblesEnabled: true,
        bangumiEnabled: true,
      );

      expect(
        plan.shouldUploadWebDavAfterBangumi(
          webDavSynced: true,
          bangumiSynced: true,
        ),
        isTrue,
      );
      expect(
        plan.shouldUploadWebDavAfterBangumi(
          webDavSynced: true,
          bangumiSynced: false,
        ),
        isFalse,
      );
    });
  });

  group('CollectSyncMerger', () {
    test('merges local change log into WebDAV collectibles', () {
      final mergeResult = CollectSyncMerger.mergeWebDav(
        localCollectibles: [
          _collect(1, CollectType.watching, 10),
          _collect(2, CollectType.watched, 20),
          _collect(3, CollectType.abandoned, 30),
        ],
        localChanges: [
          _change(10, 1, 1, CollectType.watching, 10),
          _change(11, 2, 2, CollectType.watched, 20),
          _change(12, 3, 3, CollectType.abandoned, 30),
        ],
        remoteCollectibles: [
          _collect(2, CollectType.planToWatch, 5),
          _collect(3, CollectType.watching, 5),
          _collect(4, CollectType.onHold, 5),
        ],
        remoteChanges: [
          _change(9, 4, 1, CollectType.onHold, 5),
        ],
      );

      expect(_typesById(mergeResult.collectibles), {
        1: CollectType.watching.value,
        2: CollectType.watched.value,
        4: CollectType.onHold.value,
      });
      expect(mergeResult.changes.map((change) => change.id), [9, 10, 11, 12]);
    });

    test('plans Bangumi changes after local and WebDAV already diverged', () {
      final webDavResult = CollectSyncMerger.mergeWebDav(
        localCollectibles: [
          _collect(1, CollectType.watching, 10),
        ],
        localChanges: [
          _change(10, 1, 1, CollectType.watching, 10),
        ],
        remoteCollectibles: [
          _collect(2, CollectType.watched, 5),
          _collect(4, CollectType.onHold, 5),
        ],
        remoteChanges: [
          _change(9, 2, 1, CollectType.watched, 5),
          _change(8, 4, 1, CollectType.onHold, 5),
        ],
      );

      final bangumiPlan = CollectSyncMerger.planBangumi(
        localCollectibles: webDavResult.collectibles,
        remoteCollections: [
          _remote(1, BangumiCollectionType.watched, 40),
          _remote(2, BangumiCollectionType.watched, 20),
          _remote(3, BangumiCollectionType.onHold, 30),
        ],
        priority: BangumiSyncPriority.bangumiFirst,
      );

      expect(bangumiPlan.totalOperations, 3);
      expect(
        bangumiPlan.localOnlyUploads.map((upload) => upload.bangumiId),
        [4],
      );
      expect(
          bangumiPlan.localOnlyUploads.single.type, CollectType.onHold.value);
      expect(
        bangumiPlan.remoteOnlyPuts.map(
          (mutation) => mutation.collectible.bangumiItem.id,
        ),
        [3],
      );
      expect(
        bangumiPlan.conflictLocalUpdates.map(
          (mutation) => mutation.collectible.bangumiItem.id,
        ),
        [1],
      );
      expect(
        bangumiPlan.conflictLocalUpdates.single.collectible.type,
        CollectType.watched.value,
      );
      expect(bangumiPlan.conflictUploads, isEmpty);
    });

    test('uses local priority and skips unsupported Bangumi collection types',
        () {
      final plan = CollectSyncMerger.planBangumi(
        localCollectibles: [
          _collect(1, CollectType.watching, 10),
        ],
        remoteCollections: [
          _remote(1, BangumiCollectionType.watched, 40),
          _remote(2, BangumiCollectionType.unknown, 50),
        ],
        priority: BangumiSyncPriority.localFirst,
      );

      expect(plan.totalOperations, 1);
      expect(plan.conflictUploads.single.bangumiId, 1);
      expect(plan.conflictUploads.single.type, CollectType.watching.value);
      expect(plan.remoteOnlyPuts, isEmpty);
      expect(plan.conflictLocalUpdates, isEmpty);
    });
  });
}

CollectedBangumi _collect(int id, CollectType type, int timestamp) {
  return CollectedBangumi(
    _item(id),
    DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    type.value,
  );
}

CollectedBangumiChange _change(
  int id,
  int bangumiId,
  int action,
  CollectType type,
  int timestamp,
) {
  return CollectedBangumiChange(
    id,
    bangumiId,
    action,
    type.value,
    timestamp,
  );
}

BangumiCollection _remote(
  int id,
  BangumiCollectionType type,
  int timestamp,
) {
  return BangumiCollection(
    id,
    '2026-01-01',
    DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    type,
    'subject $id',
    '条目 $id',
    '',
    0,
    12,
    0,
    const {
      'large': '',
      'common': '',
      'medium': '',
      'small': '',
      'grid': '',
    },
    const [],
  );
}

BangumiItem _item(int id) {
  return BangumiItem(
    id: id,
    type: 2,
    name: 'subject $id',
    nameCn: '条目 $id',
    summary: '',
    airDate: '2026-01-01',
    airWeekday: 4,
    rank: 0,
    images: const {
      'large': '',
      'common': '',
      'medium': '',
      'small': '',
      'grid': '',
    },
    tags: const <BangumiTag>[],
    alias: const [],
    ratingScore: 0,
    votes: 0,
    votesCount: const [],
    info: '',
  );
}

Map<int, int> _typesById(List<CollectedBangumi> collectibles) {
  return {
    for (final collectible in collectibles)
      collectible.bangumiItem.id: collectible.type,
  };
}
