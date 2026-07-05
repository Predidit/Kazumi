import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

    test('legacy tombstone is not canonicalized onto offline snapshot history',
        () {
      final offlineHistory = History(
        _item(1),
        1,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        '',
        'EP1',
        entryKind: HistoryEntryKind.offline,
        episodePageUrl: '/offline/1',
      );
      final legacyKey = History.legacyKey('plugin', _item(1));
      final offlineKey = History.getKey(
        'plugin',
        _item(1),
        entryKind: HistoryEntryKind.offline,
      );
      final deleteVersion = HistorySyncVersion.of(
        updatedAt: 2000,
        eventId: 'legacy-delete',
      );
      final snapshot = HistorySyncSnapshot.fromJson({
        'generatedAt': 2000,
        'histories': [HistorySyncCodec.historyToJson(offlineHistory)],
        'itemVersions': {},
        'progressVersions': {},
        'deletedVersions': {legacyKey: deleteVersion},
      });

      final merged = HistorySyncMerger.merge(
        snapshot: snapshot,
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
      expect(merged.histories.single.key, offlineKey);
      expect(
          merged.histories.single.progresses[1]!.progress.inMilliseconds, 10);
      expect(merged.deletedVersions, containsPair(legacyKey, deleteVersion));
      expect(merged.deletedVersions.containsKey(offlineKey), isFalse);
    });

    test('legacy delete event does not delete an existing offline history', () {
      final offlineHistory = History(
        _item(1),
        1,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        '',
        'EP1',
        entryKind: HistoryEntryKind.offline,
        episodePageUrl: '/offline/1',
      );
      final legacyKey = History.legacyKey('plugin', _item(1));
      final offlineKey = History.getKey(
        'plugin',
        _item(1),
        entryKind: HistoryEntryKind.offline,
      );

      final merged = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot(
          generatedAt: 1000,
          histories: [offlineHistory],
          itemVersions: const {},
          progressVersions: const {},
          deletedVersions: const {},
        ),
        events: [
          HistorySyncEvent.deleteHistory(
            deviceId: 'device-a',
            seq: 1,
            entityKey: legacyKey,
            updatedAt: 2000,
          ),
        ],
      );

      expect(merged.histories, hasLength(1));
      expect(merged.histories.single.key, offlineKey);
      expect(merged.deletedVersions, contains(legacyKey));
      expect(merged.deletedVersions.containsKey(offlineKey), isFalse);
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

      final streamMerger = HistorySyncStreamMerger(HistorySyncSnapshot.empty())
        ..add(legacyEvent);
      final streamedHistory = streamMerger.snapshot().histories.single;
      expect(streamedHistory.lastWatchEpisode, 9);
      expect(streamedHistory.lastWatchEpisodeName, 'EP9');
      expect(streamedHistory.progresses[9]!.progress.inSeconds, 9);
    });

    test('stream merger matches sorted merge for out-of-order events', () {
      final events = <HistorySyncEvent>[
        ..._upsertPair(
          deviceId: 'device-a',
          seq: 1,
          updatedAt: 1000,
          episode: 1,
          progressMs: 10,
        ),
        HistorySyncEvent.deleteHistory(
          deviceId: 'device-a',
          seq: 3,
          entityKey: History.getKey('plugin', _item(1)),
          updatedAt: 2000,
        ),
        ..._upsertPair(
          deviceId: 'device-b',
          seq: 1,
          updatedAt: 2500,
          episode: 3,
          progressMs: 30,
        ),
        HistorySyncEvent.clearAll(
          deviceId: 'device-c',
          seq: 1,
          updatedAt: 3000,
        ),
        ..._upsertPair(
          deviceId: 'device-a',
          seq: 4,
          updatedAt: 3500,
          episode: 4,
          progressMs: 40,
        ),
      ];
      final expected = HistorySyncMerger.merge(
        snapshot: HistorySyncSnapshot.empty(),
        events: events,
      );
      final streamMerger = HistorySyncStreamMerger(HistorySyncSnapshot.empty());

      for (final event in events.reversed) {
        streamMerger.add(event);
      }

      expect(
        _canonicalSnapshot(streamMerger.snapshot()),
        _canonicalSnapshot(expected),
      );
    });

    test('stream merger is permutation-equivalent to sorted merge', () {
      final events = <HistorySyncEvent>[];
      for (var index = 0; index < 80; index++) {
        final updatedAt = 1000 + ((index * 37) % 53);
        switch (index % 11) {
          case 0:
            events.add(
              HistorySyncEvent.clearAll(
                deviceId: 'device-c',
                seq: index + 1,
                updatedAt: updatedAt,
              ),
            );
          case 1:
            events.add(
              HistorySyncEvent.deleteHistory(
                deviceId: 'device-b',
                seq: index + 1,
                entityKey: History.getKey('plugin', _item(1)),
                updatedAt: updatedAt,
              ),
            );
          case 2:
          case 3:
            events.add(
              _watchState(
                deviceId: 'device-b',
                seq: index + 1,
                updatedAt: updatedAt,
                episode: (index % 4) + 1,
              ),
            );
          default:
            events.add(
              _upsert(
                deviceId: 'device-a',
                seq: index + 1,
                updatedAt: updatedAt,
                episode: (index % 4) + 1,
                progressMs: index * 100,
              ),
            );
        }
      }
      final expected = _canonicalSnapshot(
        HistorySyncMerger.merge(
          snapshot: HistorySyncSnapshot.empty(),
          events: events,
        ),
      );

      for (var seed = 0; seed < 20; seed++) {
        final shuffled = [...events]..shuffle(Random(seed));
        final merger = HistorySyncStreamMerger(HistorySyncSnapshot.empty())
          ..addAll(shuffled);
        expect(
          _canonicalSnapshot(merger.snapshot()),
          expected,
          reason: 'failed permutation seed $seed',
        );
      }
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

    test('streams a large event file into bounded history state', () async {
      final directory =
          await Directory.systemTemp.createTemp('kazumi_history_stream_');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final file = File('${directory.path}/events.jsonl');
      final sink = file.openWrite();
      const eventCount = 10000;
      for (var index = 0; index < eventCount; index++) {
        sink.write(
          HistorySyncCodec.eventsToJsonLines([
            _upsert(
              deviceId: 'device-a',
              seq: index + 1,
              updatedAt: index + 1,
              episode: 1,
              progressMs: index,
            ),
          ]),
        );
      }
      await sink.close();

      final merged = await HistorySyncService().mergeEventFiles(
        snapshot: HistorySyncSnapshot.empty(),
        eventFiles: [file],
        inMemoryEvents: const [],
      );

      expect(merged.histories, hasLength(1));
      expect(
        merged.histories.single.progresses[1]!.progress.inMilliseconds,
        eventCount - 1,
      );
      expect(merged.progressVersions.values.single, hasLength(1));
    });

    test('fails closed and preserves malformed event files', () async {
      final directory =
          await Directory.systemTemp.createTemp('kazumi_history_invalid_');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final file = File('${directory.path}/events.jsonl');
      const malformed = '{"eventId":"truncated"';
      await file.writeAsString(malformed, flush: true);

      await expectLater(
        HistorySyncService().mergeEventFiles(
          snapshot: HistorySyncSnapshot.empty(),
          eventFiles: [file],
          inMemoryEvents: const [],
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await file.readAsString(), malformed);
    });

    test('checkpoint keeps events appended during an active sync', () async {
      final directory =
          await Directory.systemTemp.createTemp('kazumi_history_checkpoint_');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final service = HistorySyncService.forTesting(directory);
      final runDirectory = await directory.createTemp('run-');
      await service.appendEvents([
        _upsert(
          deviceId: 'device-a',
          seq: 1,
          updatedAt: 1000,
          episode: 1,
          progressMs: 10,
        ),
      ]);

      final batch = await service.prepareLocalLogs(
        runDirectory: runDirectory,
        forceCheckpoint: true,
      );
      await service.appendEvents([
        _upsert(
          deviceId: 'device-a',
          seq: 2,
          updatedAt: 2000,
          episode: 1,
          progressMs: 20,
        ),
      ]);
      await service.completeCheckpoint(batch);

      expect(batch.shouldCheckpoint, isTrue);
      expect(batch.files, hasLength(1));
      expect(await batch.files.single.exists(), isFalse);
      final activeLog = await service.localChangeLogFile();
      final activeContent = await activeLog.readAsString();
      expect(activeContent, contains('device-a:2'));
      expect(activeContent, isNot(contains('device-a:1')));
    });

    test('recovers pending logs left by an interrupted checkpoint', () async {
      final directory =
          await Directory.systemTemp.createTemp('kazumi_history_recovery_');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final service = HistorySyncService.forTesting(directory);
      final firstRun = await directory.createTemp('run-first-');
      await service.appendEvents([
        _upsert(
          deviceId: 'device-a',
          seq: 1,
          updatedAt: 1000,
          episode: 1,
          progressMs: 10,
        ),
      ]);
      await service.prepareLocalLogs(
        runDirectory: firstRun,
        forceCheckpoint: true,
      );
      await service.appendEvents([
        _upsert(
          deviceId: 'device-a',
          seq: 2,
          updatedAt: 2000,
          episode: 1,
          progressMs: 20,
        ),
      ]);

      final secondRun = await directory.createTemp('run-second-');
      final recoveredBatch = await service.prepareLocalLogs(
        runDirectory: secondRun,
        forceCheckpoint: false,
      );
      final merged = await service.mergeEventFiles(
        snapshot: HistorySyncSnapshot.empty(),
        eventFiles: recoveredBatch.files,
        inMemoryEvents: const [],
      );

      expect(recoveredBatch.shouldCheckpoint, isTrue);
      expect(recoveredBatch.files, hasLength(2));
      expect(
        merged.histories.single.progresses[1]!.progress.inMilliseconds,
        20,
      );
    });
  });
}

Map<String, dynamic> _canonicalSnapshot(HistorySyncSnapshot snapshot) {
  final json = snapshot.toJson();
  json.remove('generatedAt');
  final histories = (json['histories'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList()
    ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  json['histories'] = histories;
  return json;
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
