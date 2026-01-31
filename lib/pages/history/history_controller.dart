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
      int episode, int road, String adapterName, BangumiItem bangumiItem, Duration progress, String lastSrc, String lastWatchEpisodeName) async {
    await _historyRepository.updateHistory(
      episode: episode,
      road: road,
      adapterName: adapterName,
      bangumiItem: bangumiItem,
      progress: progress,
      lastSrc: lastSrc,
      lastWatchEpisodeName: lastWatchEpisodeName,
    );
    init();
  }

  Progress? lastWatching(BangumiItem bangumiItem, String adapterName) {
    return _historyRepository.getLastWatchingProgress(bangumiItem, adapterName);
  }

  Progress? findProgress(BangumiItem bangumiItem, String adapterName, int episode) {
    return _historyRepository.findProgress(bangumiItem, adapterName, episode);
  }

  Future<void> deleteHistory(History history) async {
    await _historyRepository.deleteHistory(history);
    init();
  }

  Future<void> clearProgress(BangumiItem bangumiItem, String adapterName, int episode) async {
    await _historyRepository.clearProgress(bangumiItem, adapterName, episode);
    init();
  }

  Future<void> clearAll() async {
    await _historyRepository.clearAllHistories();
    histories.clear();
  }
}
