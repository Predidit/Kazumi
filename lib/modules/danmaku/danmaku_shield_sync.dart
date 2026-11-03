import 'dart:convert';

import 'package:kazumi/modules/danmaku/danmaku_shield_rule.dart';

/// A rule keeps its deletion so an offline device cannot resurrect it.
class DanmakuShieldSyncEntry {
  const DanmakuShieldSyncEntry({
    required this.rule,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
  });

  final String rule;
  final int updatedAt;
  final String deviceId;
  final bool deleted;

  int _compareTo(DanmakuShieldSyncEntry other) {
    final timeOrder = updatedAt.compareTo(other.updatedAt);
    if (timeOrder != 0) return timeOrder;
    final deviceOrder = deviceId.compareTo(other.deviceId);
    if (deviceOrder != 0) return deviceOrder;
    return (deleted ? 1 : 0).compareTo(other.deleted ? 1 : 0);
  }

  Map<String, Object> _toJson() => {
        'rule': rule,
        'updatedAt': updatedAt,
        'deviceId': deviceId,
        'deleted': deleted,
      };

  factory DanmakuShieldSyncEntry._fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid danmaku shield entry');
    }
    final rule = value['rule'];
    final updatedAt = value['updatedAt'];
    final deviceId = value['deviceId'];
    final deleted = value['deleted'];
    if (rule is! String ||
        DanmakuShieldRule.validate(rule) != null ||
        updatedAt is! int ||
        updatedAt < 0 ||
        deviceId is! String ||
        deviceId.isEmpty ||
        deleted is! bool) {
      throw const FormatException('Invalid danmaku shield entry');
    }
    return DanmakuShieldSyncEntry(
      rule: rule,
      updatedAt: updatedAt,
      deviceId: deviceId,
      deleted: deleted,
    );
  }
}

class DanmakuShieldSyncState {
  DanmakuShieldSyncState([Iterable<DanmakuShieldSyncEntry> entries = const []])
      : entries = Map.unmodifiable(_mergeEntries(entries));

  final Map<String, DanmakuShieldSyncEntry> entries;

  List<String> get rules => [
        for (final entry in entries.values)
          if (!entry.deleted) entry.rule,
      ];

  int get latestTimestamp => entries.values.fold(
        0,
        (latest, entry) => entry.updatedAt > latest ? entry.updatedAt : latest,
      );

  DanmakuShieldSyncState merge(DanmakuShieldSyncState other) =>
      DanmakuShieldSyncState([...entries.values, ...other.entries.values]);

  String encode() {
    final sorted = entries.values.toList()
      ..sort((a, b) => a.rule.compareTo(b.rule));
    return jsonEncode({
      'version': 1,
      'entries': sorted.map((entry) => entry._toJson()).toList(),
    });
  }

  factory DanmakuShieldSyncState.decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['entries'] is! List) {
      throw const FormatException('Invalid danmaku shield sync document');
    }
    return DanmakuShieldSyncState(
      (value['entries'] as List).map(DanmakuShieldSyncEntry._fromJson),
    );
  }

  static Map<String, DanmakuShieldSyncEntry> _mergeEntries(
    Iterable<DanmakuShieldSyncEntry> entries,
  ) {
    final merged = <String, DanmakuShieldSyncEntry>{};
    for (final entry in entries) {
      final previous = merged[entry.rule];
      if (previous == null || entry._compareTo(previous) > 0) {
        merged[entry.rule] = entry;
      }
    }
    return merged;
  }
}
