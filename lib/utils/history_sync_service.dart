import 'dart:io';

import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:path_provider/path_provider.dart';

class HistorySyncService {
  static const int compactLocalLogThresholdBytes = 1024 * 1024;

  HistorySyncService._internal();

  static final HistorySyncService _instance = HistorySyncService._internal();

  factory HistorySyncService() => _instance;

  Future<String> getDeviceId() async {
    final setting = GStorage.setting;
    final existing = setting
        .get(SettingBoxKey.historySyncDeviceId, defaultValue: '')
        .toString();
    if (existing.isNotEmpty) {
      return existing;
    }
    final deviceId = HistorySyncDevice.generateDeviceId();
    await setting.put(SettingBoxKey.historySyncDeviceId, deviceId);
    return deviceId;
  }

  Future<void> appendUpsertProgress({
    required History history,
    required int episode,
    required int road,
    required int progressMs,
    int? updatedAt,
  }) async {
    final event = HistorySyncEvent.upsertProgress(
      deviceId: await getDeviceId(),
      seq: await _nextSeq(),
      history: history,
      episode: episode,
      road: road,
      progressMs: progressMs,
      updatedAt: updatedAt ?? history.lastWatchTime.millisecondsSinceEpoch,
    );
    await appendEvent(event);
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

  Future<void> appendEvent(HistorySyncEvent event) async {
    final file = await localChangeLogFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      HistorySyncCodec.eventsToJsonLines([event]),
      mode: FileMode.append,
      flush: true,
    );
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
    final setting = GStorage.setting;
    final value = setting.get(
      SettingBoxKey.historySyncSequence,
      defaultValue: 0,
    );
    final next = value is int ? value + 1 : 1;
    await setting.put(SettingBoxKey.historySyncSequence, next);
    return next;
  }

  Future<void> appendSafely(Future<void> Function() append) async {
    final webDavEnable =
        GStorage.setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    final historySyncEnable = GStorage.setting.get(
      SettingBoxKey.webDavEnableHistory,
      defaultValue: false,
    );
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
