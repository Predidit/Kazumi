import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:mobx/mobx.dart';

part 'history_controller.g.dart';

class HistoryController = _HistoryController with _$HistoryController;

abstract class _HistoryController with Store {
  _HistoryController(this._historyRepository);

  final IHistoryRepository _historyRepository;

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
  }) {
    return _historyRepository.findProgress(
      bangumiItem,
      adapterName,
      episode,
      entryKind: entryKind,
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
  }) async {
    await _historyRepository.clearProgress(
      bangumiItem,
      adapterName,
      episode,
      entryKind: entryKind,
    );
    init();
  }

  Future<void> clearAll() async {
    await _historyRepository.clearAllHistories();
    histories.clear();
  }
}
