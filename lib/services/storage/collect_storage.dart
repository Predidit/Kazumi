import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_sync_merger.dart';
import 'package:kazumi/services/storage/collect_transactions.dart';

class CollectStorage {
  CollectStorage(this._items, this._logs, this._journal);

  final Box<CollectedBangumi> _items;
  final Box<CollectedBangumiChange> _logs;
  final Box<dynamic> _journal;
  final _operations = CollectTransactions();
  final _changes = StreamController<void>.broadcast(sync: true);
  List<CollectedBangumi> _committed = const [];
  List<CollectedBangumi> _published = const [];
  List<CollectedBangumiChange> _committedLogs = const [];
  List<CollectedBangumiChange> _publishedLogs = const [];
  int _nextId = 0;

  List<CollectedBangumi> get snapshot => _published;
  List<CollectedBangumiChange> get changeLog => _publishedLogs;
  Stream<void> get changes => _changes.stream;

  Future<void> initialize() => _operations.run(() async {
        await _recover();
        _capture();
        _published = _committed;
        _publishedLogs = _committedLogs;
      });

  void _capture() {
    _committed = List.unmodifiable(_items.values);
    _committedLogs = List.unmodifiable(_logs.values);
    for (final id in _logs.keys.cast<int>()) {
      if (id > _nextId) _nextId = id;
    }
  }

  void _publish() {
    _published = _committed;
    _publishedLogs = _committedLogs;
    _changes.add(null);
  }

  Future<void> _recover() async {
    final pending = _journal.get('pending');
    if (pending == null) return;
    await _apply(Map<String, dynamic>.from(pending as Map));
  }

  Future<void> _apply(Map<String, dynamic> commit) async {
    final puts = (commit['items'] as List).cast<CollectedBangumi>();
    final logs = (commit['logs'] as List).cast<CollectedBangumiChange>();
    if (commit['replace'] == true) {
      await _items.clear();
      await _logs.clear();
    }
    await _items.putAll({for (final item in puts) item.bangumiItem.id: item});
    await _items.deleteAll((commit['deletes'] as List).cast<int>());
    await _logs.putAll({for (final log in logs) log.id: log});
    await _items.flush();
    await _logs.flush();
    _capture();
    _operations.publishAfterOperation(_publish);
    await _journal.delete('pending');
    await _journal.flush();
  }

  Future<void> _commit({
    List<CollectedBangumi> items = const [],
    List<int> deletes = const [],
    List<CollectedBangumiChange> logs = const [],
    bool replace = false,
  }) async {
    final commit = <String, dynamic>{
      'items': items,
      'deletes': deletes,
      'logs': logs,
      'replace': replace,
    };
    // Keep the legacy boxes compatible with WebDAV; replay interrupted commits.
    await _journal.put('pending', commit);
    await _journal.flush();
    await _apply(commit);
  }

  CollectedBangumiChange _change(int id, int action, int type) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _nextId = _nextId < timestamp ? timestamp : _nextId + 1;
    return CollectedBangumiChange(_nextId, id, action, type, timestamp);
  }

  Future<List<CollectedBangumi>> read() => _operations.run(() async {
        await _recover();
        return _committed;
      });

  Future<int> readType(int id) => _operations.run(() async {
        await _recover();
        return _items.get(id)?.type ?? 0;
      });

  Future<void> put(CollectedBangumi item) => _operations.run(() async {
        await _recover();
        final action = _items.containsKey(item.bangumiItem.id) ? 2 : 1;
        await _commit(
            items: [item],
            logs: [_change(item.bangumiItem.id, action, item.type)]);
      }, itemId: item.bangumiItem.id);

  Future<void> delete(int id) => _operations.run(() async {
        await _recover();
        if (!_items.containsKey(id)) return;
        await _commit(deletes: [id], logs: [_change(id, 3, 5)]);
      }, itemId: id);

  Future<void> updateMetadata(BangumiItem item) => _operations.run(() async {
        await _recover();
        final current = _items.get(item.id);
        if (current == null) return;
        await _commit(
            items: [CollectedBangumi(item, current.time, current.type)]);
      }, itemId: item.id);

  Future<void> merge(List<CollectedBangumi> remoteItems,
          List<CollectedBangumiChange> remoteLogs) =>
      _operations.run(() async {
        await _recover();
        final result = CollectSyncMerger.mergeWebDav(
          localCollectibles: _committed,
          localChanges: _logs.values.toList(),
          remoteCollectibles: remoteItems,
          remoteChanges: remoteLogs,
        );
        await _commit(
            items: result.collectibles, logs: result.changes, replace: true);
      }, sync: true);

  Future<void> replace(
          List<CollectedBangumi> items, List<CollectedBangumiChange> logs) =>
      _operations.run(() async {
        await _recover();
        await _commit(items: items, logs: logs, replace: true);
      }, sync: true);

  Future<Map<String, List<int>>> exportFiles() => _operations.run(() async {
        await _recover();
        await _items.flush();
        await _logs.flush();
        return {
          'collectibles': await File(_items.path!).readAsBytes(),
          'collectchanges': await File(_logs.path!).readAsBytes(),
        };
      });
}
