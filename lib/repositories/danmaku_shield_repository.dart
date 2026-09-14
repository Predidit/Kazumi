import 'dart:async';
import 'dart:math';

import 'package:kazumi/modules/danmaku/danmaku_shield_rule.dart';
import 'package:kazumi/modules/danmaku/danmaku_shield_sync.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/async_serial_queue.dart';

enum DanmakuShieldChange { localEdit, restore }

abstract class IDanmakuShieldRepository {
  /// Emits once per completed edit or batch restore, never per Hive key.
  Stream<DanmakuShieldChange> get changes;
  List<String> getRules();
  Future<void> initialize();

  /// Returns false when the rule already has the requested state.
  Future<bool> setRule(String rule, {required bool deleted});
  Future<String> getDeviceId();
  Future<DanmakuShieldSyncState> mergeSyncState(DanmakuShieldSyncState remote);
}

class DanmakuShieldRepository implements IDanmakuShieldRepository {
  final _rules = GStorage.shieldList;
  final _writes = AsyncSerialQueue();
  final _changes = StreamController<DanmakuShieldChange>.broadcast(sync: true);

  @override
  Stream<DanmakuShieldChange> get changes => _changes.stream;

  @override
  List<String> getRules() => _rules.values.toList();

  @override
  Future<String> getDeviceId() => _writes.run(_getDeviceId);

  Future<String> _getDeviceId() async {
    var deviceId = GStorage.getSetting(SettingsKeys.danmakuShieldSyncDeviceId);
    if (deviceId.isEmpty) {
      final random = Random.secure();
      deviceId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await GStorage.putSetting(
          SettingsKeys.danmakuShieldSyncDeviceId, deviceId);
    }
    return deviceId;
  }

  Future<DanmakuShieldSyncState> _read() async {
    final saved = GStorage.getSetting(SettingsKeys.danmakuShieldSyncState);
    if (saved.isNotEmpty) {
      try {
        return DanmakuShieldSyncState.decode(saved);
      } on FormatException catch (e) {
        await GStorage.putSetting(
            SettingsKeys.danmakuShieldSyncCorruptState, saved);
        KazumiLogger().w(
          'Danmaku: restoring shield sync metadata from local rules',
          error: e,
        );
      }
    }
    final deviceId = await _getDeviceId();
    // Unknown edit times must not override cloud deletions.
    return DanmakuShieldSyncState([
      for (final rule in getRules())
        DanmakuShieldSyncEntry(
          rule: rule,
          updatedAt: 0,
          deviceId: deviceId,
          deleted: false,
        ),
    ]);
  }

  @override
  Future<void> initialize() => mergeSyncState(DanmakuShieldSyncState());

  @override
  Future<bool> setRule(String rule, {required bool deleted}) =>
      _writes.run(() async {
        if (DanmakuShieldRule.validate(rule) != null) {
          throw ArgumentError.value(rule, 'rule', 'Invalid shield rule');
        }
        final state = await _read();
        if ((state.entries[rule]?.deleted ?? true) == deleted) {
          await _save(state, DanmakuShieldChange.restore);
          return false;
        }
        final change = DanmakuShieldSyncEntry(
          rule: rule,
          updatedAt: max(
              DateTime.now().millisecondsSinceEpoch, state.latestTimestamp + 1),
          deviceId: await _getDeviceId(),
          deleted: deleted,
        );
        await _save(state.merge(DanmakuShieldSyncState([change])),
            DanmakuShieldChange.localEdit);
        return true;
      });

  @override
  Future<DanmakuShieldSyncState> mergeSyncState(
          DanmakuShieldSyncState remote) =>
      _writes.run(() async {
        final merged = (await _read()).merge(remote);
        await _save(merged, DanmakuShieldChange.restore);
        return merged;
      });

  Future<void> _save(
      DanmakuShieldSyncState state, DanmakuShieldChange source) async {
    final before = getRules().toSet();
    // Commit metadata first so initialize can repair an interrupted projection.
    await GStorage.putSetting(
        SettingsKeys.danmakuShieldSyncState, state.encode());
    final rules = state.rules.toSet();
    await _rules.deleteAll([
      for (final key in _rules.keys)
        if (!rules.contains(_rules.get(key))) key,
    ]);
    await _rules.putAll({
      for (final rule in rules)
        if (!_rules.containsKey(rule)) rule: rule,
    });
    await _rules.flush();
    if (source == DanmakuShieldChange.localEdit ||
        before.length != rules.length ||
        !before.containsAll(rules)) {
      _changes.add(source);
    }
  }

  Future<void> dispose() => _changes.close();
}
