import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/services/storage/history_storage.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';

abstract class IHistoryRepository {
  Stream<void> get changes;

  List<History> getAllHistories();

  History? getHistory(
    String adapterName,
    BangumiItem bangumiItem, {
    String entryKind = HistoryEntryKind.online,
  });

  Future<void> updateHistory({
    required PlaybackHistoryIdentity identity,
    required Duration progress,
    Duration duration = Duration.zero,
  });

  Progress? getLastWatchingProgress(
    BangumiItem bangumiItem,
    String adapterName, {
    String entryKind = HistoryEntryKind.online,
  });

  Progress? findProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
  });

  Future<void> deleteHistory(History history);

  Future<void> clearAllHistories();

  String get syncDeviceId;
  Future<HistorySyncSnapshot> readSyncSnapshot();
  Future<HistorySyncSnapshot> reconcileSyncSnapshot(HistorySyncSnapshot remote);
  Future<void> flushSyncEvents(
      Future<void> Function(Iterable<HistorySyncEvent>) append);
}

class HistoryRepository implements IHistoryRepository {
  HistoryRepository(
      {HistoryStorage? storage, bool Function()? privateModeReader})
      : _storage = storage ?? GStorage.history,
        _privateModeReader = privateModeReader ??
            (() => GStorage.getSetting(SettingsKeys.privateMode));

  final HistoryStorage _storage;
  final bool Function() _privateModeReader;

  @override
  Stream<void> get changes => _storage.changes;

  @override
  List<History> getAllHistories() => _storage.histories.toList()
    ..sort((a, b) => b.lastWatchTime.compareTo(a.lastWatchTime));

  @override
  History? getHistory(String adapterName, BangumiItem bangumiItem,
      {String entryKind = HistoryEntryKind.online}) {
    final key = History.getKey(adapterName, bangumiItem, entryKind: entryKind);
    for (final history in _storage.histories) {
      if (history.key == key) return history;
    }
    return null;
  }

  @override
  Future<void> updateHistory(
      {required PlaybackHistoryIdentity identity,
      required Duration progress,
      Duration duration = Duration.zero}) async {
    if (!identity.canRecord || _privateModeReader()) return;
    if (duration > Duration.zero &&
        progress >= duration - nearEndWatchedThreshold) {
      progress = Duration.zero;
    }
    await _storage.update(identity, progress,
        canRecord: () => !_privateModeReader());
  }

  @override
  Progress? getLastWatchingProgress(BangumiItem bangumiItem, String adapterName,
      {String entryKind = HistoryEntryKind.online}) {
    final history = getHistory(adapterName, bangumiItem, entryKind: entryKind);
    return history?.progresses[history.lastWatchEpisode];
  }

  @override
  Progress? findProgress(
          BangumiItem bangumiItem, String adapterName, int episode,
          {String entryKind = HistoryEntryKind.online}) =>
      getHistory(adapterName, bangumiItem, entryKind: entryKind)
          ?.progresses[episode];

  @override
  Future<void> deleteHistory(History history) => _storage.delete(history);

  @override
  Future<void> clearAllHistories() => _storage.clear();

  @override
  String get syncDeviceId => _storage.deviceId;

  @override
  Future<HistorySyncSnapshot> readSyncSnapshot() => _storage.read();

  @override
  Future<HistorySyncSnapshot> reconcileSyncSnapshot(
          HistorySyncSnapshot remote) =>
      _storage.reconcile(remote);

  @override
  Future<void> flushSyncEvents(
          Future<void> Function(Iterable<HistorySyncEvent>) append) =>
      _storage.flushEvents(append);
}
