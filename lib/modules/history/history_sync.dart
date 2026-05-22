import 'dart:convert';
import 'dart:math';

import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';

enum HistorySyncOp {
  upsertProgress('upsertProgress'),
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
      lastSrc: history.lastSrc,
      lastWatchEpisodeName: history.lastWatchEpisodeName,
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
      final version = HistorySyncVersion.of(
        updatedAt: history.lastWatchTime.millisecondsSinceEpoch,
        eventId: 'local-import:${history.key}',
      );
      itemVersions[history.key] = version;
      progressVersions[history.key] = {
        for (final entry in history.progresses.entries) entry.key: version,
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
    final progressJson = Map<String, dynamic>.from(
      (json['progressVersions'] as Map?) ?? const {},
    );
    return HistorySyncSnapshot(
      generatedAt: (json['generatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      histories: ((json['histories'] as List?) ?? const [])
          .map((item) => HistorySyncCodec.historyFromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      itemVersions: Map<String, String>.from(
        (json['itemVersions'] as Map?) ?? const {},
      ),
      progressVersions: {
        for (final entry in progressJson.entries)
          entry.key: (Map<String, dynamic>.from(entry.value as Map)).map(
            (episode, version) => MapEntry(int.parse(episode), '$version'),
          ),
      },
      deletedVersions: Map<String, String>.from(
        (json['deletedVersions'] as Map?) ?? const {},
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
    return HistorySyncState._(
      histories: {
        for (final history in snapshot.histories) history.key: history
      },
      itemVersions: snapshot.itemVersions,
      progressVersions: snapshot.progressVersions,
      deletedVersions: snapshot.deletedVersions,
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
        _applyUpsert(event);
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

  void _applyUpsert(HistorySyncEvent event) {
    final entityKey = event.entityKey;
    final bangumiItem = event.bangumiItem;
    final adapterName = event.adapterName;
    final episode = event.episode;
    final road = event.road;
    final progressMs = event.progressMs;
    if (entityKey == null ||
        bangumiItem == null ||
        adapterName == null ||
        episode == null ||
        road == null ||
        progressMs == null) {
      throw const FormatException('Invalid upsertProgress history event');
    }
    if (!_isNewerThanClear(event.version)) {
      return;
    }
    final deletedVersion = deletedVersions[entityKey];
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
      itemVersions[entityKey] = event.version;
    }

    final episodeVersions = progressVersions.putIfAbsent(entityKey, () => {});
    final progressVersion = episodeVersions[episode];
    if (progressVersion == null ||
        HistorySyncVersion.compare(event.version, progressVersion) >= 0) {
      current.progresses[episode] = Progress(episode, road, progressMs);
      episodeVersions[episode] = event.version;
    }
    histories[entityKey] = current;
    deletedVersions.remove(entityKey);
  }

  void _applyDelete(HistorySyncEvent event) {
    final entityKey = event.entityKey;
    if (entityKey == null || !_isNewerThanClear(event.version)) {
      return;
    }
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
    );
  }

  static Map<String, dynamic> progressToJson(Progress progress) {
    return {
      'episode': progress.episode,
      'road': progress.road,
      'progressMs': progress.progress.inMilliseconds,
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
