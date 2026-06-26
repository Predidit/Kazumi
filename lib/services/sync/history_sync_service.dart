import 'dart:io';

import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:path_provider/path_provider.dart';

class HistorySyncService {
  static const int compactLocalLogThresholdBytes = 1024 * 1024;

  HistorySyncService._internal();

  static final HistorySyncService _instance = HistorySyncService._internal();

  factory HistorySyncService() => _instance;

  Future<String> getDeviceId() async {
    final existing = GStorage.getSetting(SettingsKeys.historySyncDeviceId);
    if (existing.isNotEmpty) {
      return existing;
    }
    final deviceId = HistorySyncDevice.generateDeviceId();
    await GStorage.putSetting(SettingsKeys.historySyncDeviceId, deviceId);
    return deviceId;
  }

  Future<void> appendUpsertProgress({
    required History history,
    required int episode,
    required int road,
    required int progressMs,
    required String episodePageUrl,
    int? updatedAt,
  }) async {
    final deviceId = await getDeviceId();
    final effectiveUpdatedAt =
        updatedAt ?? history.lastWatchTime.millisecondsSinceEpoch;
    final progressSeq = await _nextSeq();
    final watchStateSeq = await _nextSeq();
    final events = [
      HistorySyncEvent.upsertProgress(
        deviceId: deviceId,
        seq: progressSeq,
        history: history,
        episode: episode,
        road: road,
        progressMs: progressMs,
        updatedAt: effectiveUpdatedAt,
        episodePageUrl: episodePageUrl,
      ),
      HistorySyncEvent.upsertWatchState(
        deviceId: deviceId,
        seq: watchStateSeq,
        history: history,
        episode: episode,
        updatedAt: effectiveUpdatedAt,
      ),
    ];
    await appendEvents(events);
  }

  Future<void> appendEvent(HistorySyncEvent event) async {
    await appendEvents([event]);
  }

  Future<void> appendEvents(Iterable<HistorySyncEvent> events) async {
    final file = await localChangeLogFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      HistorySyncCodec.eventsToJsonLines(events),
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<void> appendDeleteHistory(History history) async {
    final event = HistorySyncEvent.deleteHistory(
      deviceId: await getDeviceId(),
      seq: await _nextSeq(),
      entityKey: history.key,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await appendEvent(event);
  }

  Future<void> appendClearAll() async {
    final event = HistorySyncEvent.clearAll(
      deviceId: await getDeviceId(),
      seq: await _nextSeq(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await appendEvent(event);
  }

  Future<List<HistorySyncEvent>> readLocalEvents() async {
    final file = await localChangeLogFile();
    if (!await file.exists()) {
      return [];
    }
    final content = await file.readAsString();
    return HistorySyncCodec.eventsFromJsonLines(content);
  }

  Future<String> readLocalEventLines() async {
    final file = await localChangeLogFile();
    if (!await file.exists()) {
      return '';
    }
    return file.readAsString();
  }

  Future<void> replaceLocalEvents(Iterable<HistorySyncEvent> events) async {
    final file = await localChangeLogFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      HistorySyncCodec.eventsToJsonLines(events),
      flush: true,
    );
  }

  Future<bool> shouldCompactLocalLog() async {
    final file = await localChangeLogFile();
    if (!await file.exists()) {
      return false;
    }
    return file.lengthSync() > compactLocalLogThresholdBytes;
  }

  HistorySyncSnapshot buildSnapshotFromLocal() {
    return HistorySyncSnapshot.fromHistories(
        GStorage.histories.values.toList());
  }

  static List<HistorySyncEvent> buildStateEventsFromHistories(
    Iterable<History> histories,
  ) {
    final events = <HistorySyncEvent>[];
    for (final history in histories) {
      history.entryKind = HistoryEntryKind.normalize(history.entryKind);
      for (final entry in history.progresses.entries) {
        final progress = entry.value;
        final updatedAt = progress.effectiveUpdatedAtMs(history.lastWatchTime);
        events.add(
          HistorySyncEvent(
            eventId:
                'local-state:${history.key}:${entry.key}:${progress.episode}:${progress.road}',
            deviceId: 'local-state',
            seq: 0,
            op: HistorySyncOp.upsertProgress,
            updatedAt: updatedAt,
            entityKey: history.key,
            bangumiItem: history.bangumiItem,
            adapterName: history.adapterName,
            episode: progress.episode,
            road: progress.road,
            progressMs: progress.progress.inMilliseconds,
            lastSrc: history.lastSrc,
            lastWatchEpisodeName: history.lastWatchEpisodeName,
            entryKind: history.entryKind,
            episodePageUrl: progress.episodePageUrl,
          ),
        );
      }
      events.add(
        HistorySyncEvent(
          eventId: 'local-state:${history.key}:watch-state',
          deviceId: 'local-state',
          seq: 0,
          op: HistorySyncOp.upsertWatchState,
          updatedAt: history.lastWatchTime.millisecondsSinceEpoch,
          entityKey: history.key,
          bangumiItem: history.bangumiItem,
          adapterName: history.adapterName,
          episode: history.lastWatchEpisode,
          lastSrc: history.lastSrc,
          lastWatchEpisodeName: history.lastWatchEpisodeName,
          entryKind: history.entryKind,
          episodePageUrl: history.episodePageUrl,
          carriesWatchState: true,
        ),
      );
    }
    return events;
  }

  Future<void> applySnapshotToLocal(HistorySyncSnapshot snapshot) async {
    await GStorage.histories.clear();
    for (final history in snapshot.histories) {
      await GStorage.histories.put(history.key, history);
    }
    await GStorage.histories.flush();
  }

  Future<File> localChangeLogFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/webdavTemp/history.local.jsonl');
  }

  Future<int> _nextSeq() async {
    final value = GStorage.getSetting(SettingsKeys.historySyncSequence);
    final next = value + 1;
    await GStorage.putSetting(SettingsKeys.historySyncSequence, next);
    return next;
  }

  Future<void> appendSafely(Future<void> Function() append) async {
    final webDavEnable = GStorage.getSetting(SettingsKeys.webDavEnable);
    final historySyncEnable =
        GStorage.getSetting(SettingsKeys.webDavEnableHistory);
    if (webDavEnable != true || historySyncEnable != true) {
      return;
    }
    try {
      await append();
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'HistorySync: failed to append local change',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
