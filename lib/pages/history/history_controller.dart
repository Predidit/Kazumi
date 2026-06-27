import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:mobx/mobx.dart';

part 'history_controller.g.dart';

class HistoryController = _HistoryController with _$HistoryController;

abstract class _HistoryController with Store {
  final _historyRepository = Modular.get<IHistoryRepository>();

  @observable
  ObservableList<History> histories = ObservableList<History>();

  void init() {
    final temp = _historyRepository.getAllHistories();
    histories.clear();
    histories.addAll(temp);
  }

  Future<void> updateHistory(
      PlaybackHistoryIdentity identity, Duration progress) async {
    await _historyRepository.updateHistory(
      identity: identity,
      progress: progress,
    );
    init();
  }

  Progress? lastWatching(
    BangumiItem bangumiItem,
    String adapterName, {
    String entryKind = HistoryEntryKind.online,
  }) {
    return _historyRepository.getLastWatchingProgress(
      bangumiItem,
      adapterName,
      entryKind: entryKind,
    );
  }

  Progress? findProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
    String episodePageUrl = '',
  }) {
    return _historyRepository.findProgress(
      bangumiItem,
      adapterName,
      episode,
      entryKind: entryKind,
      episodePageUrl: episodePageUrl,
    );
  }

  void migrateProgressPageUrls({
    required BangumiItem bangumiItem,
    required String adapterName,
    String entryKind = HistoryEntryKind.online,
    required String Function(int road, int episode) resolveCurrentPageUrl,
  }) {
    _historyRepository.migrateProgressPageUrls(
      adapterName: adapterName,
      bangumiItem: bangumiItem,
      entryKind: entryKind,
      resolveCurrentPageUrl: resolveCurrentPageUrl,
    );
  }

  Future<void> deleteHistory(History history) async {
    await _historyRepository.deleteHistory(history);
    init();
  }

  Future<void> clearProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
    String episodePageUrl = '',
  }) async {
    await _historyRepository.clearProgress(
      bangumiItem,
      adapterName,
      episode,
      entryKind: entryKind,
      episodePageUrl: episodePageUrl,
    );
    init();
  }

  Future<void> clearAll() async {
    await _historyRepository.clearAllHistories();
    histories.clear();
  }
}
