import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:mobx/mobx.dart';

part 'history_controller.g.dart';

class HistoryController = _HistoryController with _$HistoryController;

abstract class _HistoryController with Store {
  var storedHistories = GStorage.histories;

  @observable
  ObservableList<History> histories = ObservableList<History>(); 

  void init() {
    var temp = storedHistories.values.toList();
    temp.sort(
      (a, b) =>
          b.lastWatchTime.millisecondsSinceEpoch -
          a.lastWatchTime.millisecondsSinceEpoch,
    );
    histories.clear();
    histories.addAll(temp);
  }

  void updateHistory(
      int episode, int road, String adapterName, BangumiItem bangumiItem, Duration progress, String lastSrc) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem)) ??
        History(bangumiItem, episode, adapterName, DateTime.now(), lastSrc);
    history.lastWatchEpisode = episode;
    history.lastWatchTime = DateTime.now();
    if (lastSrc != '') {
      history.lastSrc = lastSrc;
    }

    var prog = history.progresses[episode];
    if (prog == null) {
      history.progresses[episode] =
          Progress(episode, road, progress.inMilliseconds);
    } else {
      prog.progress = progress;
    }

    storedHistories.put(history.key, history);
    init();
  }

  Progress? lastWatching(BangumiItem bangumiItem, String adapterName) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem));
    return history?.progresses[history.lastWatchEpisode];
  }

  Progress? findProgress(BangumiItem bangumiItem, String adapterName, int episode) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem));
    return history?.progresses[episode];
  }

  void deleteHistory(History history) {
    storedHistories.delete(history.key);
    init();
  }

  void clearProgress(BangumiItem bangumiItem, String adapterName, int episode) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem));
    history!.progresses[episode]!.progress = Duration.zero;
    init();
  }

  void clearAll() {
    GStorage.histories.clear();
    histories.clear();
    // init();
  }
}
