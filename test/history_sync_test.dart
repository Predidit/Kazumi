import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';

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
}) {
  final history = History(
    _item(1),
    episode,
    'plugin',
    DateTime.fromMillisecondsSinceEpoch(updatedAt),
    'https://example.com/video',
    'EP$episode',
  );
  history.progresses[episode] = Progress(episode, 0, progressMs);
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
  final history = History(
    _item(1),
    episode,
    'plugin',
    DateTime.fromMillisecondsSinceEpoch(updatedAt),
    'https://example.com/video',
    'EP$episode',
  );
  return HistorySyncEvent(
    eventId: '$deviceId:$seq',
    deviceId: deviceId,
    seq: seq,
    op: HistorySyncOp.upsertProgress,
    updatedAt: updatedAt,
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
