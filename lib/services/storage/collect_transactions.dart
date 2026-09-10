import 'dart:async';

import 'package:kazumi/modules/collect/collect_activity.dart';
import 'package:kazumi/utils/async_serial_queue.dart';

class CollectTransactions {
  CollectTransactions._();

  static final _instance = CollectTransactions._();
  factory CollectTransactions() => _instance;

  final _queue = AsyncSerialQueue();
  final _zoneKey = Object();
  final _items = <int, int>{};
  int _pending = 0;
  int _syncs = 0;
  final _activityChanges =
      StreamController<CollectActivity>.broadcast(sync: true);
  var _activity = CollectActivity(
    pendingIds: {},
    isSyncing: false,
    hasPending: false,
  );

  CollectActivity get activity => _activity;
  Stream<CollectActivity> get activityChanges => _activityChanges.stream;

  _CollectOperation? get _current {
    final operation = Zone.current[_zoneKey] as _CollectOperation?;
    return operation?.active == true ? operation : null;
  }

  // Nested service calls keep the outer operation's lock and notification batch.
  Future<T> run<T>(
    Future<T> Function() action, {
    int? itemId,
    bool sync = false,
  }) {
    if (_current != null) return action();
    _pending++;
    if (sync) _syncs++;
    if (itemId != null) {
      _items.update(itemId, (count) => count + 1, ifAbsent: () => 1);
    }
    _notifyActivity();
    return _queue.run(() async {
      final operation = _CollectOperation();
      try {
        return await runZoned(action, zoneValues: {_zoneKey: operation});
      } finally {
        operation.active = false;
        try {
          for (final publish in operation.notifications) {
            publish();
          }
        } finally {
          _pending--;
          if (sync) _syncs--;
          if (itemId != null) {
            final count = _items[itemId]! - 1;
            if (count == 0) {
              _items.remove(itemId);
            } else {
              _items[itemId] = count;
            }
          }
          _notifyActivity();
        }
      }
    });
  }

  void publishAfterOperation(void Function() publish) {
    final operation = _current;
    if (operation == null) throw StateError('No active collection operation');
    operation.notifications.add(publish);
  }

  void _notifyActivity() {
    _activity = CollectActivity(
      pendingIds: _items.keys.toSet(),
      isSyncing: _syncs > 0,
      hasPending: _pending > 0,
    );
    _activityChanges.add(_activity);
  }
}

class _CollectOperation {
  bool active = true;
  final notifications = <void Function()>{};
}
