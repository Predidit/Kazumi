import 'dart:convert';
import 'dart:math';

import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';

enum HistorySyncOp {
  upsertProgress('upsertProgress'),
  upsertWatchState('upsertWatchState'),
  deleteHistory('deleteHistory'),
  clearAll('clearAll');

  const HistorySyncOp(this.value);

  final String value;

  static HistorySyncOp fromValue(String value) {
    return HistorySyncOp.values.firstWhere(
      (op) => op.value == value,
      orElse: () => throw FormatException('Unknown history sync op: $value'),
    );
  }
}

class HistorySyncDevice {
  static String generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20),
    ].join('-');
  }
}

class HistorySyncEvent {
  const HistorySyncEvent({
    required this.eventId,
    required this.deviceId,
    required this.seq,
    required this.op,
    required this.updatedAt,
    this.entityKey,
    this.bangumiItem,
    this.adapterName,
    this.episode,
    this.road,
    this.progressMs,
    this.lastSrc,
    this.lastWatchEpisodeName,
    this.entryKind,
    this.episodePageUrl,
    this.stableId,
    this.carriesWatchState = false,
  });

  final String eventId;
  final String deviceId;
  final int seq;
  final HistorySyncOp op;
  final int updatedAt;
  final String? entityKey;
  final BangumiItem? bangumiItem;
  final String? adapterName;
  final int? episode;
  final int? road;
  final int? progressMs;
  final String? lastSrc;
  final String? lastWatchEpisodeName;
  final String? entryKind;
  final String? episodePageUrl;
  final String? stableId;
  final bool carriesWatchState;

  String get version => HistorySyncVersion.of(
        updatedAt: updatedAt,
        eventId: eventId,
      );

  factory HistorySyncEvent.upsertProgress({
    required String deviceId,
    required int seq,
    required History history,
    required int episode,
    required int road,
    required int progressMs,
    required int updatedAt,
    String? episodePageUrl,
    String? stableId,
  }) {
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
      road: road,
      progressMs: progressMs,
      entryKind: history.entryKind,
      episodePageUrl: episodePageUrl ?? history.episodePageUrl,
      stableId: stableId,
    );
  }

  factory HistorySyncEvent.upsertWatchState({
    required String deviceId,
    required int seq,
    required History history,
    required int episode,
    required int updatedAt,
  }) {
    return HistorySyncEvent(
      eventId: '$deviceId:$seq',
      deviceId: deviceId,
      seq: seq,
      op: HistorySyncOp.upsertWatchState,
      updatedAt: updatedAt,
      entityKey: history.key,
      bangumiItem: history.bangumiItem,
      adapterName: history.adapterName,
      episode: episode,
      lastSrc: history.lastSrc,
      lastWatchEpisodeName: history.lastWatchEpisodeName,
      entryKind: history.entryKind,
      episodePageUrl: history.episodePageUrl,
      stableId: history.stableId,
      carriesWatchState: true,
    );
  }

  factory HistorySyncEvent.deleteHistory({
    required String deviceId,
    required int seq,
    required String entityKey,
    required int updatedAt,
  }) {
    return HistorySyncEvent(
      eventId: '$deviceId:$seq',
      deviceId: deviceId,
      seq: seq,
      op: HistorySyncOp.deleteHistory,
      updatedAt: updatedAt,
      entityKey: entityKey,
    );
  }

  factory HistorySyncEvent.clearAll({
    required String deviceId,
    required int seq,
    required int updatedAt,
  }) {
    return HistorySyncEvent(
      eventId: '$deviceId:$seq',
      deviceId: deviceId,
      seq: seq,
      op: HistorySyncOp.clearAll,
      updatedAt: updatedAt,
    );
  }

  factory HistorySyncEvent.fromJson(Map<String, dynamic> json) {
    return HistorySyncEvent(
      eventId: json['eventId'] as String,
      deviceId: json['deviceId'] as String,
      seq: (json['seq'] as num).toInt(),
      op: HistorySyncOp.fromValue(json['op'] as String),
      updatedAt: (json['updatedAt'] as num).toInt(),
      entityKey: json['entityKey'] as String?,
      bangumiItem: json['bangumiItem'] == null
          ? null
          : HistorySyncCodec.bangumiItemFromJson(
              Map<String, dynamic>.from(json['bangumiItem'] as Map),
            ),
      adapterName: json['adapterName'] as String?,
      episode: (json['episode'] as num?)?.toInt(),
      road: (json['road'] as num?)?.toInt(),
      progressMs: (json['progressMs'] as num?)?.toInt(),
      lastSrc: json['lastSrc'] as String?,
      lastWatchEpisodeName: json['lastWatchEpisodeName'] as String?,
      entryKind: json['entryKind'] as String?,
      episodePageUrl: json['episodePageUrl'] as String?,
      stableId: json['stableId'] as String?,
      carriesWatchState: (json['carriesWatchState'] as bool?) ??
          (json.containsKey('lastSrc') ||
              json.containsKey('lastWatchEpisodeName')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'deviceId': deviceId,
      'seq': seq,
      'op': op.value,
      'updatedAt': updatedAt,
      if (entityKey != null) 'entityKey': entityKey,
      if (bangumiItem != null)
        'bangumiItem': HistorySyncCodec.bangumiItemToJson(bangumiItem!),
      if (adapterName != null) 'adapterName': adapterName,
      if (episode != null) 'episode': episode,
      if (road != null) 'road': road,
      if (progressMs != null) 'progressMs': progressMs,
      if (lastSrc != null) 'lastSrc': lastSrc,
      if (lastWatchEpisodeName != null)
        'lastWatchEpisodeName': lastWatchEpisodeName,
      if (entryKind != null) 'entryKind': entryKind,
      if (episodePageUrl != null) 'episodePageUrl': episodePageUrl,
      if (stableId != null) 'stableId': stableId,
      if (carriesWatchState) 'carriesWatchState': carriesWatchState,
    };
  }
}

class HistorySyncSnapshot {
  const HistorySyncSnapshot({
    required this.generatedAt,
    required this.histories,
    required this.itemVersions,
    required this.progressVersions,
    required this.deletedVersions,
    this.clearVersion,
  });

  final int generatedAt;
  final List<History> histories;
  final Map<String, String> itemVersions;
  final Map<String, Map<int, String>> progressVersions;
  final Map<String, String> deletedVersions;
  final String? clearVersion;

  factory HistorySyncSnapshot.empty() {
    return HistorySyncSnapshot(
      generatedAt: DateTime.now().millisecondsSinceEpoch,
      histories: const [],
      itemVersions: const {},
      progressVersions: const {},
      deletedVersions: const {},
    );
  }

  factory HistorySyncSnapshot.fromHistories(List<History> histories) {
    final itemVersions = <String, String>{};
    final progressVersions = <String, Map<int, String>>{};
    for (final history in histories) {
      history.entryKind = HistoryEntryKind.normalize(history.entryKind);
      final version = HistorySyncVersion.of(
        updatedAt: history.lastWatchTime.millisecondsSinceEpoch,
        eventId: 'local-import:${history.key}',
      );
      itemVersions[history.key] = version;
      progressVersions[history.key] = {
        for (final entry in history.progresses.entries)
          entry.key: HistorySyncVersion.of(
            updatedAt: entry.value.effectiveUpdatedAtMs(history.lastWatchTime),
            eventId: 'local-import:${history.key}:${entry.key}',
          ),
      };
    }
    return HistorySyncSnapshot(
      generatedAt: DateTime.now().millisecondsSinceEpoch,
      histories: histories,
      itemVersions: itemVersions,
      progressVersions: progressVersions,
      deletedVersions: const {},
    );
  }

  factory HistorySyncSnapshot.fromJson(Map<String, dynamic> json) {
    final histories = ((json['histories'] as List?) ?? const [])
        .map((item) => HistorySyncCodec.historyFromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    final keyMap = {
      for (final history in histories) history.key: history.key,
      for (final history in histories)
        if (history.entryKind == HistoryEntryKind.online)
          History.legacyKey(history.adapterName, history.bangumiItem):
              history.key,
    };
    String canonicalSnapshotKey(String key) => keyMap[key] ?? key;
    final progressJson = Map<String, dynamic>.from(
      (json['progressVersions'] as Map?) ?? const {},
    );
    final itemVersions = Map<String, String>.from(
      (json['itemVersions'] as Map?) ?? const {},
    );
    final progressVersions = {
      for (final entry in progressJson.entries)
        entry.key: (Map<String, dynamic>.from(entry.value as Map)).map(
          (episode, version) => MapEntry(int.parse(episode), '$version'),
        ),
    };
    final deletedVersions = Map<String, String>.from(
      (json['deletedVersions'] as Map?) ?? const {},
    );
    return HistorySyncSnapshot(
      generatedAt: (json['generatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      histories: histories,
      itemVersions: HistorySyncState._canonicalizeVersionMap(
        itemVersions,
        canonicalSnapshotKey,
      ),
      progressVersions: HistorySyncState._canonicalizeProgressVersionMap(
        progressVersions,
        canonicalSnapshotKey,
      ),
      deletedVersions: HistorySyncState._canonicalizeVersionMap(
        deletedVersions,
        canonicalSnapshotKey,
      ),
      clearVersion: json['clearVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'generatedAt': generatedAt,
      'histories': histories
          .map((history) => HistorySyncCodec.historyToJson(history))
          .toList(),
      'itemVersions': itemVersions,
      'progressVersions': {
        for (final entry in progressVersions.entries)
          entry.key: {
            for (final episodeVersion in entry.value.entries)
              episodeVersion.key.toString(): episodeVersion.value,
          },
      },
      'deletedVersions': deletedVersions,
      if (clearVersion != null) 'clearVersion': clearVersion,
    };
  }
}

class HistorySyncState {
  HistorySyncState._({
    required Map<String, History> histories,
    required Map<String, String> itemVersions,
    required Map<String, Map<int, String>> progressVersions,
    required Map<String, String> deletedVersions,
    required this.clearVersion,
  })  : histories = Map.of(histories),
        itemVersions = Map.of(itemVersions),
        progressVersions = progressVersions.map(
          (key, value) => MapEntry(key, Map<int, String>.of(value)),
        ),
        deletedVersions = Map.of(deletedVersions);

  factory HistorySyncState.fromSnapshot(HistorySyncSnapshot snapshot) {
    final histories = <String, History>{};
    final keyMap = <String, String>{};
    for (final history in snapshot.histories) {
      history.entryKind = HistoryEntryKind.normalize(history.entryKind);
      histories[history.key] = history;
      keyMap[history.key] = history.key;
      if (history.entryKind == HistoryEntryKind.online) {
        keyMap[History.legacyKey(history.adapterName, history.bangumiItem)] =
            history.key;
      }
    }
    String canonicalSnapshotKey(String key) => keyMap[key] ?? key;

    return HistorySyncState._(
      histories: histories,
      itemVersions: _canonicalizeVersionMap(
        snapshot.itemVersions,
        canonicalSnapshotKey,
      ),
      progressVersions: _canonicalizeProgressVersionMap(
        snapshot.progressVersions,
        canonicalSnapshotKey,
      ),
      deletedVersions: _canonicalizeVersionMap(
        snapshot.deletedVersions,
        canonicalSnapshotKey,
      ),
      clearVersion: snapshot.clearVersion,
    );
  }

  final Map<String, History> histories;
  final Map<String, String> itemVersions;
  final Map<String, Map<int, String>> progressVersions;
  final Map<String, String> deletedVersions;
  String? clearVersion;

  void apply(HistorySyncEvent event) {
    switch (event.op) {
      case HistorySyncOp.upsertProgress:
        _applyUpsertProgress(event);
      case HistorySyncOp.upsertWatchState:
        _applyUpsertWatchState(event);
      case HistorySyncOp.deleteHistory:
        _applyDelete(event);
      case HistorySyncOp.clearAll:
        _applyClear(event);
    }
  }

  HistorySyncSnapshot toSnapshot() {
    return HistorySyncSnapshot(
      generatedAt: DateTime.now().millisecondsSinceEpoch,
      histories: histories.values.toList(),
      itemVersions: itemVersions,
      progressVersions: progressVersions,
      deletedVersions: deletedVersions,
      clearVersion: clearVersion,
    );
  }

  void _applyUpsertProgress(HistorySyncEvent event) {
    final bangumiItem = event.bangumiItem;
    final adapterName = event.adapterName;
    final episode = event.episode;
    final road = event.road;
    final progressMs = event.progressMs;
    if (bangumiItem == null ||
        adapterName == null ||
        episode == null ||
        road == null ||
        progressMs == null) {
      throw const FormatException('Invalid upsertProgress history event');
    }
    if (!_isNewerThanClear(event.version)) {
      return;
    }
    final entryKind =
        HistoryEntryKind.normalize(event.entryKind ?? HistoryEntryKind.online);
    final entityKey = History.scopedKey(adapterName, bangumiItem, entryKind);
    final legacyEntityKey = History.legacyKey(adapterName, bangumiItem);
    final deletedVersion = _deletedVersionForUpsert(
      entityKey,
      legacyEntityKey: legacyEntityKey,
      entryKind: entryKind,
    );
    if (deletedVersion != null &&
        HistorySyncVersion.compare(event.version, deletedVersion) <= 0) {
      return;
    }

    final current = histories[entityKey] ??
        History(
          bangumiItem,
          episode,
          adapterName,
          DateTime.fromMillisecondsSinceEpoch(event.updatedAt),
          event.lastSrc ?? '',
          event.lastWatchEpisodeName ?? '',
          entryKind: entryKind,
        );

    final episodePageUrl = event.episodePageUrl ?? '';
    final stableId = event.stableId ?? '';
    final progressMatch = _HistoryEpisodeMatcher.find(
      current,
      episode: episode,
      episodePageUrl: episodePageUrl,
      stableId: stableId,
    );
    final progressBucket = progressMatch?.bucket ??
        _HistoryEpisodeMatcher.bucketForNewProgress(
          current,
          episode: episode,
          episodePageUrl: episodePageUrl,
          stableId: stableId,
        );
    final episodeVersions = progressVersions.putIfAbsent(entityKey, () => {});
    final progressVersion = episodeVersions[progressBucket];
    if (progressVersion == null ||
        HistorySyncVersion.compare(event.version, progressVersion) >= 0) {
      final progress = progressMatch?.progress ??
          Progress(
            episode,
            road,
            progressMs,
            updatedAtMs: event.updatedAt,
            episodePageUrl: episodePageUrl,
            stableId: stableId,
          );
      progress.episode = episode;
      progress.road = road;
      progress.progress = Duration(milliseconds: progressMs);
      progress.updatedAtMs = event.updatedAt;
      progress.episodePageUrl = episodePageUrl;
      if (stableId.isNotEmpty) {
        progress.stableId = stableId;
      }
      current.progresses[progressBucket] = progress;
      episodeVersions[progressBucket] = event.version;
    }
    histories[entityKey] = current;
    deletedVersions.remove(entityKey);
    if (entryKind == HistoryEntryKind.online) {
      deletedVersions.remove(legacyEntityKey);
    }
    if (_shouldApplyLegacyWatchState(event)) {
      _applyUpsertWatchState(event);
    }
  }

  void _applyUpsertWatchState(HistorySyncEvent event) {
    final bangumiItem = event.bangumiItem;
    final adapterName = event.adapterName;
    final episode = event.episode;
    if (bangumiItem == null || adapterName == null || episode == null) {
      throw const FormatException('Invalid upsertWatchState history event');
    }
    if (!_isNewerThanClear(event.version)) {
      return;
    }
    final entryKind =
        HistoryEntryKind.normalize(event.entryKind ?? HistoryEntryKind.online);
    final entityKey = History.scopedKey(adapterName, bangumiItem, entryKind);
    final legacyEntityKey = History.legacyKey(adapterName, bangumiItem);
    final deletedVersion = _deletedVersionForUpsert(
      entityKey,
      legacyEntityKey: legacyEntityKey,
      entryKind: entryKind,
    );
    if (deletedVersion != null &&
        HistorySyncVersion.compare(event.version, deletedVersion) <= 0) {
      return;
    }

    final current = histories[entityKey] ??
        History(
          bangumiItem,
          episode,
          adapterName,
          DateTime.fromMillisecondsSinceEpoch(event.updatedAt),
          event.lastSrc ?? '',
          event.lastWatchEpisodeName ?? '',
          entryKind: entryKind,
          episodePageUrl: event.episodePageUrl ?? '',
          stableId: event.stableId ?? '',
        );

    final itemVersion = itemVersions[entityKey];
    if (itemVersion == null ||
        HistorySyncVersion.compare(event.version, itemVersion) >= 0) {
      current.bangumiItem = bangumiItem;
      current.adapterName = adapterName;
      current.lastWatchEpisode = episode;
      current.lastWatchTime =
          DateTime.fromMillisecondsSinceEpoch(event.updatedAt);
      if ((event.lastSrc ?? '').isNotEmpty) {
        current.lastSrc = event.lastSrc!;
      }
      if ((event.lastWatchEpisodeName ?? '').isNotEmpty) {
        current.lastWatchEpisodeName = event.lastWatchEpisodeName!;
      }
      current.entryKind = entryKind;
      current.episodePageUrl = event.episodePageUrl ?? '';
      current.stableId = event.stableId ?? '';
      itemVersions[entityKey] = event.version;
    }
    histories[entityKey] = current;
    deletedVersions.remove(entityKey);
    if (entryKind == HistoryEntryKind.online) {
      deletedVersions.remove(legacyEntityKey);
    }
  }

  void _applyDelete(HistorySyncEvent event) {
    final rawEntityKey = event.entityKey;
    if (rawEntityKey == null || !_isNewerThanClear(event.version)) {
      return;
    }
    final entityKey = _canonicalExistingEntityKey(rawEntityKey);
    final itemVersion = itemVersions[entityKey];
    final deletedVersion = deletedVersions[entityKey];
    final newerThanItem = itemVersion == null ||
        HistorySyncVersion.compare(event.version, itemVersion) >= 0;
    final newerThanDelete = deletedVersion == null ||
        HistorySyncVersion.compare(event.version, deletedVersion) >= 0;
    if (newerThanItem && newerThanDelete) {
      histories.remove(entityKey);
      itemVersions.remove(entityKey);
      progressVersions.remove(entityKey);
      deletedVersions[entityKey] = event.version;
    }
  }

  void _applyClear(HistorySyncEvent event) {
    if (!_isNewerThanClear(event.version)) {
      return;
    }
    histories.clear();
    itemVersions.clear();
    progressVersions.clear();
    deletedVersions.clear();
    clearVersion = event.version;
  }

  bool _isNewerThanClear(String version) {
    final currentClearVersion = clearVersion;
    return currentClearVersion == null ||
        HistorySyncVersion.compare(version, currentClearVersion) > 0;
  }

  String _canonicalExistingEntityKey(String key) {
    if (histories.containsKey(key) ||
        itemVersions.containsKey(key) ||
        progressVersions.containsKey(key)) {
      return key;
    }
    for (final history in histories.values) {
      if (history.entryKind == HistoryEntryKind.online &&
          History.legacyKey(history.adapterName, history.bangumiItem) == key) {
        return history.key;
      }
    }
    return key;
  }

  String? _deletedVersionForUpsert(
    String entityKey, {
    required String legacyEntityKey,
    required String entryKind,
  }) {
    final scopedVersion = deletedVersions[entityKey];
    if (entryKind != HistoryEntryKind.online) {
      return scopedVersion;
    }
    return _newerVersion(scopedVersion, deletedVersions[legacyEntityKey]);
  }

  String? _newerVersion(String? a, String? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return HistorySyncVersion.compare(a, b) >= 0 ? a : b;
  }

  bool _shouldApplyLegacyWatchState(HistorySyncEvent event) {
    final hasWatchStatePayload = event.carriesWatchState ||
        event.lastSrc != null ||
        event.lastWatchEpisodeName != null;
    return hasWatchStatePayload && !event.eventId.startsWith('local-state:');
  }

  static Map<String, String> _canonicalizeVersionMap(
    Map<String, String> versions,
    String Function(String key) canonicalKey,
  ) {
    final result = <String, String>{};
    for (final entry in versions.entries) {
      final key = canonicalKey(entry.key);
      final existing = result[key];
      if (existing == null ||
          HistorySyncVersion.compare(entry.value, existing) > 0) {
        result[key] = entry.value;
      }
    }
    return result;
  }

  static Map<String, Map<int, String>> _canonicalizeProgressVersionMap(
    Map<String, Map<int, String>> versions,
    String Function(String key) canonicalKey,
  ) {
    final result = <String, Map<int, String>>{};
    for (final entry in versions.entries) {
      final key = canonicalKey(entry.key);
      final target = result.putIfAbsent(key, () => {});
      for (final episodeVersion in entry.value.entries) {
        final existing = target[episodeVersion.key];
        if (existing == null ||
            HistorySyncVersion.compare(episodeVersion.value, existing) > 0) {
          target[episodeVersion.key] = episodeVersion.value;
        }
      }
    }
    return result;
  }
}

class _HistoryEpisodeMatch {
  const _HistoryEpisodeMatch({
    required this.bucket,
    required this.progress,
  });

  final int bucket;
  final Progress progress;
}

class _HistoryEpisodeMatcher {
  static _HistoryEpisodeMatch? find(
    History history, {
    required int episode,
    String episodePageUrl = '',
    String stableId = '',
  }) {
    final id = stableId.trim();
    if (id.isNotEmpty) {
      for (final entry in history.progresses.entries) {
        if (entry.value.stableId == id) {
          return _HistoryEpisodeMatch(
            bucket: entry.key,
            progress: entry.value,
          );
        }
      }
    }

    final pageUrl = episodePageUrl.trim();
    if (pageUrl.isNotEmpty) {
      for (final entry in history.progresses.entries) {
        if (entry.value.episodePageUrl == pageUrl &&
            (id.isEmpty ||
                entry.value.stableId.isEmpty ||
                entry.value.stableId == id)) {
          return _HistoryEpisodeMatch(
            bucket: entry.key,
            progress: entry.value,
          );
        }
      }

      final legacyProgress = history.progresses[episode];
      if (legacyProgress != null &&
          legacyProgress.episode == episode &&
          legacyProgress.episodePageUrl.isEmpty &&
          legacyProgress.stableId.isEmpty) {
        return _HistoryEpisodeMatch(
          bucket: episode,
          progress: legacyProgress,
        );
      }
      for (final entry in history.progresses.entries) {
        final progress = entry.value;
        if (progress.episode == episode &&
            progress.episodePageUrl.isEmpty &&
            progress.stableId.isEmpty) {
          return _HistoryEpisodeMatch(
            bucket: entry.key,
            progress: progress,
          );
        }
      }
      return null;
    }

    if (id.isNotEmpty) {
      return null;
    }

    final progress = history.progresses[episode];
    if (progress != null && progress.episode == episode) {
      return _HistoryEpisodeMatch(bucket: episode, progress: progress);
    }

    for (final entry in history.progresses.entries) {
      if (entry.value.episode == episode) {
        return _HistoryEpisodeMatch(
          bucket: entry.key,
          progress: entry.value,
        );
      }
    }
    return null;
  }

  static int bucketForNewProgress(
    History history, {
    required int episode,
    String episodePageUrl = '',
    String stableId = '',
  }) {
    final pageUrl = episodePageUrl.trim();
    final id = stableId.trim();
    final existing = history.progresses[episode];
    if (existing == null) {
      return episode;
    }
    if (existing.episode == episode &&
        (id.isEmpty || existing.stableId.isEmpty || existing.stableId == id) &&
        (pageUrl.isEmpty ||
            existing.episodePageUrl.isEmpty ||
            existing.episodePageUrl == pageUrl)) {
      return episode;
    }

    var bucket = episode;
    while (history.progresses.containsKey(bucket)) {
      bucket++;
    }
    return bucket;
  }

  _HistoryEpisodeMatcher._();
}

class HistorySyncMerger {
  static HistorySyncSnapshot merge({
    required HistorySyncSnapshot snapshot,
    required Iterable<HistorySyncEvent> events,
  }) {
    final state = HistorySyncState.fromSnapshot(snapshot);
    final sortedEvents = events.toList()
      ..sort((a, b) => HistorySyncVersion.compare(a.version, b.version));
    for (final event in sortedEvents) {
      state.apply(event);
    }
    return state.toSnapshot();
  }

  HistorySyncMerger._();
}

class HistorySyncVersion {
  static String of({
    required int updatedAt,
    required String eventId,
  }) {
    return '${updatedAt.toString().padLeft(16, '0')}|$eventId';
  }

  static int compare(String a, String b) {
    return a.compareTo(b);
  }

  HistorySyncVersion._();
}

class HistorySyncCodec {
  static List<HistorySyncEvent> eventsFromJsonLines(String content) {
    return const LineSplitter()
        .convert(content)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => HistorySyncEvent.fromJson(
              Map<String, dynamic>.from(jsonDecode(line) as Map),
            ))
        .toList();
  }

  static String eventsToJsonLines(Iterable<HistorySyncEvent> events) {
    final lines = events.map((event) => jsonEncode(event.toJson())).join('\n');
    return lines.isEmpty ? '' : '$lines\n';
  }

  static History historyFromJson(Map<String, dynamic> json) {
    final history = History(
      bangumiItemFromJson(
          Map<String, dynamic>.from(json['bangumiItem'] as Map)),
      (json['lastWatchEpisode'] as num).toInt(),
      json['adapterName'] as String,
      DateTime.fromMillisecondsSinceEpoch(
          (json['lastWatchTime'] as num).toInt()),
      json['lastSrc'] as String? ?? '',
      json['lastWatchEpisodeName'] as String? ?? '',
      entryKind: json['entryKind'] as String? ?? HistoryEntryKind.online,
      episodePageUrl: json['episodePageUrl'] as String? ?? '',
      stableId: json['stableId'] as String? ?? '',
    );
    history.progresses = {
      for (final entry
          in Map<String, dynamic>.from(json['progresses'] as Map).entries)
        int.parse(entry.key): progressFromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
    return history;
  }

  static Map<String, dynamic> historyToJson(History history) {
    return {
      'bangumiItem': bangumiItemToJson(history.bangumiItem),
      'lastWatchEpisode': history.lastWatchEpisode,
      'adapterName': history.adapterName,
      'lastWatchTime': history.lastWatchTime.millisecondsSinceEpoch,
      'lastSrc': history.lastSrc,
      'lastWatchEpisodeName': history.lastWatchEpisodeName,
      'entryKind': history.entryKind,
      'episodePageUrl': history.episodePageUrl,
      'stableId': history.stableId,
      'progresses': {
        for (final entry in history.progresses.entries)
          entry.key.toString(): progressToJson(entry.value),
      },
    };
  }

  static Progress progressFromJson(Map<String, dynamic> json) {
    return Progress(
      (json['episode'] as num).toInt(),
      (json['road'] as num).toInt(),
      (json['progressMs'] as num).toInt(),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      episodePageUrl: json['episodePageUrl'] as String? ?? '',
      stableId: json['stableId'] as String? ?? '',
    );
  }

  static Map<String, dynamic> progressToJson(Progress progress) {
    return {
      'episode': progress.episode,
      'road': progress.road,
      'progressMs': progress.progress.inMilliseconds,
      'updatedAtMs': progress.updatedAtMs,
      'episodePageUrl': progress.episodePageUrl,
      'stableId': progress.stableId,
    };
  }

  static BangumiItem bangumiItemFromJson(Map<String, dynamic> json) {
    return BangumiItem(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      name: json['name'] as String? ?? '',
      nameCn: json['nameCn'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      airDate: json['airDate'] as String? ?? '',
      airWeekday: (json['airWeekday'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      images: Map<String, String>.from((json['images'] as Map?) ?? const {}),
      tags: ((json['tags'] as List?) ?? const [])
          .map((tag) =>
              BangumiTag.fromJson(Map<String, dynamic>.from(tag as Map)))
          .toList(),
      alias: ((json['alias'] as List?) ?? const [])
          .map((alias) => alias.toString())
          .toList(),
      ratingScore: (json['ratingScore'] as num?)?.toDouble() ?? 0,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      votesCount: ((json['votesCount'] as List?) ?? const [])
          .map((vote) => (vote as num).toInt())
          .toList(),
      info: json['info'] as String? ?? '',
    );
  }

  static Map<String, dynamic> bangumiItemToJson(BangumiItem item) {
    return {
      'id': item.id,
      'type': item.type,
      'name': item.name,
      'nameCn': item.nameCn,
      'summary': item.summary,
      'airDate': item.airDate,
      'airWeekday': item.airWeekday,
      'rank': item.rank,
      'images': item.images,
      'tags': item.tags.map((tag) => tag.toJson()).toList(),
      'alias': item.alias,
      'ratingScore': item.ratingScore,
      'votes': item.votes,
      'votesCount': item.votesCount,
      'info': item.info,
    };
  }

  HistorySyncCodec._();
}
