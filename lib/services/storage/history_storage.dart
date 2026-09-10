import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/utils/async_serial_queue.dart';

class HistoryStorage {
  HistoryStorage(this._items, this._journal,
      {required this.deviceId,
      int initialSequence = 0,
      DateTime Function()? now})
      : _sequence = initialSequence,
        _now = now ?? DateTime.now;

  final Box<History> _items;
  final Box<dynamic> _journal;
  final String deviceId;
  final DateTime Function() _now;
  final _writes = AsyncSerialQueue();
  final _changes = StreamController<void>.broadcast(sync: true);
  HistorySyncSnapshot _snapshot = HistorySyncSnapshot.empty();
  int _sequence;
  bool _changed = false;

  Stream<void> get changes => _changes.stream;
  List<History> get histories =>
      List.unmodifiable(_snapshot.histories.map((history) => history.copy()));

  Future<T> _run<T>(Future<T> Function() action) => _writes.run(() async {
        try {
          await _recover();
          return await action();
        } finally {
          if (_changed) {
            _changed = false;
            _changes.add(null);
          }
        }
      });

  Future<void> initialize() => _run(() async {
        _capture();
      });

  void _capture() {
    final versions = Map<String, dynamic>.from(
        (_journal.get('versions') as Map?) ?? const {});
    final byKey = <String, History>{};
    for (final history in _items.values) {
      final existing = byKey[history.key];
      if (existing == null ||
          existing.lastWatchTime.isBefore(history.lastWatchTime)) {
        byKey[history.key] = history.copy();
      }
    }
    final base = HistorySyncSnapshot.fromHistories(byKey.values.toList());
    _snapshot = versions.isEmpty
        ? HistorySyncMerger.mergeSnapshots(HistorySyncSnapshot.empty(), base)
        : HistorySyncSnapshot(
            generatedAt: _now().millisecondsSinceEpoch,
            histories: base.histories,
            itemVersions: Map<String, String>.from(versions['items'] as Map),
            progressVersions: (versions['progress'] as Map).map((key, value) =>
                MapEntry(key as String, Map<int, String>.from(value as Map))),
            deletedVersions:
                Map<String, String>.from(versions['deleted'] as Map),
            clearVersion: versions['clear'] as String?,
          );
    final sequence = _journal.get('sequence', defaultValue: 0) as int;
    if (sequence > _sequence) _sequence = sequence;
  }

  Future<void> _recover() async {
    if (_journal.get('pending') case final Map pending) {
      await _apply(Map<String, dynamic>.from(pending));
    }
  }

  Future<void> _apply(Map<String, dynamic> commit) async {
    final puts = (commit['items'] as List).cast<History>();
    if (commit['replace'] == true) await _items.clear();
    await _items.putAll({for (final history in puts) history.key: history});
    await _items.deleteAll((commit['deletes'] as List).cast<String>());
    await _journal
        .putAll(Map<dynamic, dynamic>.from(commit['metadata'] as Map));
    await _items.flush();
    await _journal.flush();
    _capture();
    _changed = true;
    await _journal.delete('pending');
    await _journal.flush();
  }

  Future<void> _commit(HistorySyncSnapshot snapshot,
      {required List<History> items,
      List<String> deletes = const [],
      List<HistorySyncEvent> events = const [],
      bool replace = false}) async {
    final commit = {
      'items': items,
      'deletes': deletes,
      'replace': replace,
      'metadata': {
        'versions': {
          'items': snapshot.itemVersions,
          'progress': snapshot.progressVersions,
          'deleted': snapshot.deletedVersions,
          'clear': snapshot.clearVersion,
        },
        'sequence': _sequence,
        'timestamp': events.isEmpty
            ? _journal.get('timestamp', defaultValue: 0)
            : events.last.updatedAt,
        for (final event in events) _outboxKey(event): event.toJson(),
      },
    };
    // The journal commits history, tombstones, and the durable outbox together.
    await _journal.put('pending', commit);
    await _journal.flush();
    await _apply(commit);
  }

  String _outboxKey(HistorySyncEvent event) =>
      'outbox:${event.op.value}:${event.entityKey ?? ''}:${event.op == HistorySyncOp.upsertProgress ? event.episode : ''}';

  int _timestamp() {
    var previous = _journal.get('timestamp', defaultValue: 0) as int;
    final versions = [
      ..._snapshot.itemVersions.values,
      ..._snapshot.progressVersions.values
          .expand((versions) => versions.values),
      ..._snapshot.deletedVersions.values,
      if (_snapshot.clearVersion case final version?) version,
    ];
    for (final version in versions) {
      final timestamp = int.parse(version.substring(0, version.indexOf('|')));
      if (timestamp > previous) previous = timestamp;
    }
    final current = _now().millisecondsSinceEpoch;
    return current > previous ? current : previous + 1;
  }

  Future<void> update(PlaybackHistoryIdentity identity, Duration progress,
          {required bool Function() canRecord}) =>
      _run(() async {
        if (!canRecord()) return;
        final timestamp = _timestamp();
        final history = History(
            identity.bangumiItem,
            identity.episodeNumber,
            identity.pluginName,
            DateTime.fromMillisecondsSinceEpoch(timestamp),
            identity.onlineBangumiSrc,
            identity.episodeTitle,
            entryKind: identity.entryKind,
            episodePageUrl: identity.episodePageUrl);
        final events = [
          HistorySyncEvent.upsertProgress(
              deviceId: deviceId,
              seq: ++_sequence,
              history: history,
              episode: identity.episodeNumber,
              road: identity.road,
              progressMs: progress.inMilliseconds,
              updatedAt: timestamp),
          HistorySyncEvent.upsertWatchState(
              deviceId: deviceId,
              seq: ++_sequence,
              history: history,
              episode: identity.episodeNumber,
              updatedAt: timestamp),
        ];
        final next =
            HistorySyncMerger.merge(snapshot: _snapshot, events: events);
        final updated = next.histories.where((item) => item.key == history.key);
        await _commit(next, items: updated.toList(), events: events, deletes: [
          if (identity.entryKind == HistoryEntryKind.online)
            History.legacyKey(identity.pluginName, identity.bangumiItem),
        ]);
      });

  Future<void> delete(History history) => _run(() async {
        if (!_snapshot.histories.any((item) => item.key == history.key)) return;
        final event = HistorySyncEvent.deleteHistory(
            deviceId: deviceId,
            seq: ++_sequence,
            entityKey: history.key,
            updatedAt: _timestamp());
        final next =
            HistorySyncMerger.merge(snapshot: _snapshot, events: [event]);
        await _commit(next, items: [], events: [
          event
        ], deletes: [
          history.key,
          if (history.entryKind == HistoryEntryKind.online)
            History.legacyKey(history.adapterName, history.bangumiItem),
        ]);
      });

  Future<void> clear() => _run(() async {
        final event = HistorySyncEvent.clearAll(
            deviceId: deviceId, seq: ++_sequence, updatedAt: _timestamp());
        final next =
            HistorySyncMerger.merge(snapshot: _snapshot, events: [event]);
        await _commit(next, items: [], events: [event], replace: true);
      });

  Future<HistorySyncSnapshot> read() => _run(() async => _copySnapshot());

  HistorySyncSnapshot _copySnapshot() => HistorySyncSnapshot(
        generatedAt: _snapshot.generatedAt,
        histories: histories,
        itemVersions: Map.of(_snapshot.itemVersions),
        progressVersions: _snapshot.progressVersions
            .map((key, value) => MapEntry(key, Map.of(value))),
        deletedVersions: Map.of(_snapshot.deletedVersions),
        clearVersion: _snapshot.clearVersion,
      );

  Future<HistorySyncSnapshot> reconcile(HistorySyncSnapshot remote) =>
      _run(() async {
        // Rebase under the local write lock, including deletes after log capture.
        final next = HistorySyncMerger.mergeSnapshots(remote, _snapshot);
        await _commit(next, items: next.histories, replace: true);
        return _copySnapshot();
      });

  Future<void> flushEvents(
          Future<void> Function(Iterable<HistorySyncEvent>) append) =>
      _run(() async {
        final keys = _journal.keys
            .whereType<String>()
            .where((key) => key.startsWith('outbox:'))
            .toList();
        if (keys.isEmpty) return;
        final events = keys
            .map((key) => HistorySyncEvent.fromJson(
                Map<String, dynamic>.from(_journal.get(key) as Map)))
            .toList();
        await append(events);
        // Replaying after an interrupted acknowledgement uses the same event IDs.
        await _journal.deleteAll(keys);
        await _journal.flush();
      });
}
