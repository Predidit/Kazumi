import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/services/sync/history_sync_service.dart';

void main() {
  group('HistorySyncDevice', () {
    test('generates stable UUID-shaped identifiers', () {
      final first = HistorySyncDevice.generateDeviceId();
      final second = HistorySyncDevice.generateDeviceId();

      expect(first, isNot(second));
      expect(
        first,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )),
      );
    });
  });

  group('HistorySyncMerger', () {
    test('merges progress per episode instead of replacing whole history', () {
      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.empty(),
        events: [
          ..._upsertPair(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 1000,
            episode: 1,
            progressMs: 10 * 1000,
          ),
          ..._upsertPair(
            deviceId: 'device-b',
            seq: 1,
            updatedAt: 2000,
            episode: 2,
            progressMs: 20 * 1000,
          ),
        ],
      );

      final history = merged.histories.single;
      expect(history.lastWatchEpisode, 2);
      expect(history.progresses[1]!.progress.inSeconds, 10);
      expect(history.progresses[2]!.progress.inSeconds, 20);
    });

    test('clearAll prevents older events from being resurrected', () {
      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.empty(),
        events: [
          ..._upsertPair(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 1000,
            episode: 1,
            progressMs: 10,
          ),
          HistorySyncEvent.clearAll(
            deviceId: 'device-b',
            seq: 1,
            updatedAt: 2000,
          ),
          ..._upsertPair(
            deviceId: 'device-a',
            seq: 2,
            updatedAt: 1500,
            episode: 2,
            progressMs: 20,
          ),
          ..._upsertPair(
            deviceId: 'device-c',
            seq: 1,
            updatedAt: 3000,
            episode: 3,
            progressMs: 30,
          ),
        ],
      );

      expect(merged.histories, hasLength(1));
      expect(merged.histories.single.lastWatchEpisode, 3);
      expect(merged.histories.single.progresses.keys, [3]);
      expect(merged.clearVersion, isNotNull);
    });

    test('deleteHistory blocks older upserts but allows newer watches', () {
      final entityKey = History.getKey('plugin', _item(1));
      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.empty(),
        events: [
          ..._upsertPair(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 1000,
            episode: 1,
            progressMs: 10,
          ),
          HistorySyncEvent.deleteHistory(
            deviceId: 'device-b',
            seq: 1,
            entityKey: entityKey,
            updatedAt: 2000,
          ),
          ..._upsertPair(
            deviceId: 'device-a',
            seq: 2,
            updatedAt: 1500,
            episode: 2,
            progressMs: 20,
          ),
          ..._upsertPair(
            deviceId: 'device-a',
            seq: 3,
            updatedAt: 2500,
            episode: 3,
            progressMs: 30,
          ),
        ],
      );

      expect(merged.histories, hasLength(1));
      expect(merged.histories.single.progresses.keys, [3]);
      expect(merged.deletedVersions, isEmpty);
    });

    test('legacy delete tombstone blocks older online upserts from snapshot',
        () {
      final legacyKey = History.legacyKey('plugin', _item(1));
      final deleteVersion = HistorySyncVersion.of(
        updatedAt: 2000,
        eventId: 'legacy-delete',
      );
      final snapshot = HistorySyncSnapshot.fromJson({
        'generatedAt': 2000,
        'histories': [],
        'itemVersions': {},
        'progressVersions': {},
        'deletedVersions': {legacyKey: deleteVersion},
      });

      final merged = HistorySyncMerger.merge(
        snapshot: snapshot,
        events: [
          _legacyUpsert(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 1500,
            episode: 1,
            progressMs: 10,
          ),
        ],
      );

      expect(merged.histories, isEmpty);
      expect(merged.deletedVersions, containsPair(legacyKey, deleteVersion));
    });

    test('newer online upsert clears legacy delete tombstone', () {
      final legacyKey = History.legacyKey('plugin', _item(1));
      final scopedKey = History.getKey('plugin', _item(1));
      final deleteVersion = HistorySyncVersion.of(
        updatedAt: 2000,
        eventId: 'legacy-delete',
      );

      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot(
          generatedAt: 2000,
          histories: const [],
          itemVersions: const {},
          progressVersions: const {},
          deletedVersions: {legacyKey: deleteVersion},
        ),
        events: [
          _legacyUpsert(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 2500,
            episode: 2,
            progressMs: 20,
          ),
        ],
      );

      expect(merged.histories, hasLength(1));
      expect(merged.histories.single.key, scopedKey);
      expect(merged.histories.single.lastWatchEpisode, 2);
      expect(merged.deletedVersions, isEmpty);
    });

    test('legacy delete tombstone does not block offline upserts', () {
      final legacyKey = History.legacyKey('plugin', _item(1));
      final deleteVersion = HistorySyncVersion.of(
        updatedAt: 2000,
        eventId: 'legacy-delete',
      );

      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot(
          generatedAt: 2000,
          histories: const [],
          itemVersions: const {},
          progressVersions: const {},
          deletedVersions: {legacyKey: deleteVersion},
        ),
        events: [
          _upsert(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 1500,
            episode: 1,
            progressMs: 10,
            entryKind: HistoryEntryKind.offline,
            episodePageUrl: '/offline/1',
          ),
        ],
      );

      expect(merged.histories, hasLength(1));
      expect(merged.histories.single.entryKind, HistoryEntryKind.offline);
      expect(merged.deletedVersions, containsPair(legacyKey, deleteVersion));
    });

    test('uses deterministic tie-breakers when timestamps are equal', () {
      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.empty(),
        events: [
          _upsert(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 1000,
            episode: 1,
            progressMs: 10,
          ),
          _upsert(
            deviceId: 'device-b',
            seq: 1,
            updatedAt: 1000,
            episode: 1,
            progressMs: 20,
          ),
        ],
      );

      expect(
          merged.histories.single.progresses[1]!.progress.inMilliseconds, 20);
    });

    test('preserves playback entry metadata when merging progress', () {
      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.empty(),
        events: [
          _upsert(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 1000,
            episode: 1,
            progressMs: 10 * 1000,
            entryKind: HistoryEntryKind.offline,
            episodePageUrl: '/episode/1',
          ),
        ],
      );

      final history = merged.histories.single;
      expect(history.entryKind, HistoryEntryKind.offline);
      expect(history.episodePageUrl, '/episode/1');
    });

    test('keeps online and offline progress separate for the same episode', () {
      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.empty(),
        events: [
          _upsert(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 1000,
            episode: 1,
            progressMs: 10 * 1000,
            entryKind: HistoryEntryKind.online,
            episodePageUrl: '/online/1',
          ),
          _upsert(
            deviceId: 'device-b',
            seq: 1,
            updatedAt: 2000,
            episode: 1,
            progressMs: 20 * 1000,
            entryKind: HistoryEntryKind.offline,
            episodePageUrl: '/offline/1',
          ),
        ],
      );

      expect(merged.histories, hasLength(2));
      final online = merged.histories.singleWhere(
        (history) => history.entryKind == HistoryEntryKind.online,
      );
      final offline = merged.histories.singleWhere(
        (history) => history.entryKind == HistoryEntryKind.offline,
      );
      expect(online.key, History.getKey('plugin', _item(1)));
      expect(
        offline.key,
        History.getKey(
          'plugin',
          _item(1),
          entryKind: HistoryEntryKind.offline,
        ),
      );
      expect(online.progresses[1]!.progress.inSeconds, 10);
      expect(offline.progresses[1]!.progress.inSeconds, 20);
    });

    test('canonicalizes legacy snapshot keys to online scoped keys', () {
      final history = History(
        _item(1),
        1,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        'https://example.com/video',
        'EP1',
      );
      history.progresses[1] = Progress(
        1,
        0,
        10 * 1000,
        updatedAtMs: 1500,
      );
      final legacyKey = History.legacyKey('plugin', _item(1));
      final scopedKey = History.getKey('plugin', _item(1));
      final legacyVersion = HistorySyncVersion.of(
        updatedAt: 1000,
        eventId: 'legacy',
      );
      final progressVersion = HistorySyncVersion.of(
        updatedAt: 1500,
        eventId: 'legacy-progress',
      );

      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot(
          generatedAt: 2000,
          histories: [history],
          itemVersions: {legacyKey: legacyVersion},
          progressVersions: {
            legacyKey: {1: progressVersion},
          },
          deletedVersions: const {},
        ),
        events: const [],
      );

      expect(merged.histories.single.key, scopedKey);
      expect(merged.itemVersions, containsPair(scopedKey, legacyVersion));
      expect(
        merged.progressVersions[scopedKey],
        containsPair(1, progressVersion),
      );
      expect(merged.itemVersions.containsKey(legacyKey), isFalse);
      expect(merged.progressVersions.containsKey(legacyKey), isFalse);
    });

    test('keeps watch state when local-state progress events share a timestamp',
        () {
      final history = History(
        _item(1),
        11,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        'https://example.com/video',
        'EP11',
      );
      history.progresses[6] = Progress(6, 0, 6 * 1000);
      history.progresses[11] = Progress(11, 0, 11 * 1000);

      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.fromHistories([history]),
        events: [
          _localStateUpsert(
            history: history,
            episode: 11,
            progressMs: 11 * 1000,
          ),
          _localStateUpsert(
            history: history,
            episode: 6,
            progressMs: 6 * 1000,
          ),
        ],
      );

      final mergedHistory = merged.histories.single;
      expect(mergedHistory.lastWatchEpisode, 11);
      expect(mergedHistory.lastWatchEpisodeName, 'EP11');
      expect(mergedHistory.progresses[6]!.progress.inSeconds, 6);
      expect(mergedHistory.progresses[11]!.progress.inSeconds, 11);
    });

    test('upsertProgress does not replace the latest watch state', () {
      final history = History(
        _item(1),
        5,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        'https://example.com/video',
        'EP5',
      );
      history.progresses[5] = Progress(5, 0, 5 * 1000);

      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.fromHistories([history]),
        events: [
          _upsert(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 2000,
            episode: 7,
            progressMs: 7 * 1000,
          ),
        ],
      );

      final mergedHistory = merged.histories.single;
      expect(mergedHistory.lastWatchEpisode, 5);
      expect(mergedHistory.lastWatchEpisodeName, 'EP5');
      expect(mergedHistory.progresses[7]!.progress.inSeconds, 7);
    });

    test('upsertWatchState updates latest episode metadata', () {
      final history = History(
        _item(1),
        5,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        'https://example.com/video',
        'EP5',
      );
      history.progresses[5] = Progress(5, 0, 5 * 1000);

      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.fromHistories([history]),
        events: [
          _watchState(
            deviceId: 'device-a',
            seq: 1,
            updatedAt: 2000,
            episode: 7,
          ),
        ],
      );

      final mergedHistory = merged.histories.single;
      expect(mergedHistory.lastWatchEpisode, 7);
      expect(mergedHistory.lastWatchTime.millisecondsSinceEpoch, 2000);
      expect(mergedHistory.lastSrc, 'https://example.com/video');
      expect(mergedHistory.lastWatchEpisodeName, 'EP7');
    });

    test('legacy upsertProgress payload can still update watch state', () {
      final legacyEvent = _legacyUpsert(
        deviceId: 'device-a',
        seq: 1,
        updatedAt: 1000,
        episode: 9,
        progressMs: 9 * 1000,
      );
      final restored = HistorySyncCodec.eventsFromJsonLines(
        HistorySyncCodec.eventsToJsonLines([legacyEvent]),
      );

      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.empty(),
        events: restored,
      );

      final mergedHistory = merged.histories.single;
      expect(mergedHistory.lastWatchEpisode, 9);
      expect(mergedHistory.lastWatchEpisodeName, 'EP9');
      expect(mergedHistory.progresses[9]!.progress.inSeconds, 9);
    });
  });

  group('HistorySyncCodec', () {
    test('round-trips events through json lines', () {
      final events = [
        _upsert(
          deviceId: 'device-a',
          seq: 1,
          updatedAt: 1000,
          episode: 1,
          progressMs: 10,
        ),
        _watchState(
          deviceId: 'device-a',
          seq: 2,
          updatedAt: 1000,
          episode: 1,
        ),
        HistorySyncEvent.clearAll(
          deviceId: 'device-a',
          seq: 3,
          updatedAt: 2000,
        ),
      ];

      final lines = HistorySyncCodec.eventsToJsonLines(events);
      final restored = HistorySyncCodec.eventsFromJsonLines(lines);

      expect(restored.map((event) => event.eventId),
          ['device-a:1', 'device-a:2', 'device-a:3']);
      expect(restored.map((event) => event.op), [
        HistorySyncOp.upsertProgress,
        HistorySyncOp.upsertWatchState,
        HistorySyncOp.clearAll,
      ]);
      expect(restored.first.bangumiItem!.id, 1);
    });
  });

  group('HistorySyncService', () {
    test('builds local state events with entry metadata and progress time', () {
      final history = History(
        _item(1),
        1,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        '',
        'EP1',
        entryKind: HistoryEntryKind.offline,
        episodePageUrl: '/offline/1',
      );
      history.progresses[1] = Progress(
        1,
        2,
        20 * 1000,
        updatedAtMs: 2500,
      );

      final events =
          HistorySyncService.buildStateEventsFromHistories([history]);

      expect(events, hasLength(2));
      final progressEvent = events.singleWhere(
        (event) => event.op == HistorySyncOp.upsertProgress,
      );
      final watchStateEvent = events.singleWhere(
        (event) => event.op == HistorySyncOp.upsertWatchState,
      );
      expect(progressEvent.entityKey, history.key);
      expect(progressEvent.entryKind, HistoryEntryKind.offline);
      expect(progressEvent.episodePageUrl, '/offline/1');
      expect(progressEvent.updatedAt, 2500);
      expect(progressEvent.progressMs, 20 * 1000);
      expect(watchStateEvent.entryKind, HistoryEntryKind.offline);
      expect(watchStateEvent.episodePageUrl, '/offline/1');
      expect(watchStateEvent.carriesWatchState, isTrue);
    });
  });
}

HistorySyncEvent _localStateUpsert({
  required History history,
  required int episode,
  required int progressMs,
}) {
  return HistorySyncEvent(
    eventId: 'local-state:${history.key}:$episode:0',
    deviceId: 'local-state',
    seq: 0,
    op: HistorySyncOp.upsertProgress,
    updatedAt: history.lastWatchTime.millisecondsSinceEpoch,
    entityKey: history.key,
    bangumiItem: history.bangumiItem,
    adapterName: history.adapterName,
    episode: episode,
    road: 0,
    progressMs: progressMs,
    lastSrc: history.lastSrc,
    lastWatchEpisodeName: history.lastWatchEpisodeName,
  );
}

HistorySyncEvent _upsert({
  required String deviceId,
  required int seq,
  required int updatedAt,
  required int episode,
  required int progressMs,
  String entryKind = HistoryEntryKind.online,
  String episodePageUrl = '',
}) {
  final history = History(
    _item(1),
    episode,
    'plugin',
    DateTime.fromMillisecondsSinceEpoch(updatedAt),
    'https://example.com/video',
    'EP$episode',
    entryKind: entryKind,
    episodePageUrl: episodePageUrl,
  );
  history.progresses[episode] = Progress(
    episode,
    0,
    progressMs,
    updatedAtMs: updatedAt,
  );
  return HistorySyncEvent.upsertProgress(
    deviceId: deviceId,
    seq: seq,
    history: history,
    episode: episode,
    road: 0,
    progressMs: progressMs,
    updatedAt: updatedAt,
  );
}

HistorySyncEvent _legacyUpsert({
  required String deviceId,
  required int seq,
  required int updatedAt,
  required int episode,
  required int progressMs,
}) {
  return HistorySyncEvent(
    eventId: '$deviceId:$seq',
    deviceId: deviceId,
    seq: seq,
    op: HistorySyncOp.upsertProgress,
    updatedAt: updatedAt,
    entityKey: History.legacyKey('plugin', _item(1)),
    bangumiItem: _item(1),
    adapterName: 'plugin',
    episode: episode,
    road: 0,
    progressMs: progressMs,
    lastSrc: 'https://example.com/video',
    lastWatchEpisodeName: 'EP$episode',
  );
}

HistorySyncEvent _watchState({
  required String deviceId,
  required int seq,
  required int updatedAt,
  required int episode,
}) {
  final history = History(
    _item(1),
    episode,
    'plugin',
    DateTime.fromMillisecondsSinceEpoch(updatedAt),
    'https://example.com/video',
    'EP$episode',
  );
  return HistorySyncEvent.upsertWatchState(
    deviceId: deviceId,
    seq: seq,
    history: history,
    episode: episode,
    updatedAt: updatedAt,
  );
}

List<HistorySyncEvent> _upsertPair({
  required String deviceId,
  required int seq,
  required int updatedAt,
  required int episode,
  required int progressMs,
}) {
  return [
    _upsert(
      deviceId: deviceId,
      seq: seq,
      updatedAt: updatedAt,
      episode: episode,
      progressMs: progressMs,
    ),
    _watchState(
      deviceId: deviceId,
      seq: seq + 1,
      updatedAt: updatedAt,
      episode: episode,
    ),
  ];
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
