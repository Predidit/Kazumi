import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/utils/storage.dart';

class HistoryController {
  late var storedHistories = GStorage.histories;

  List<History> get histories {
    var temp = storedHistories.values.toList();
    temp.sort(
      (a, b) =>
          b.lastWatchTime.millisecondsSinceEpoch -
          a.lastWatchTime.millisecondsSinceEpoch,
    );
    return temp;
  }

  void updateHistory(
      int episode, int road, String adapterName, BangumiItem bangumiItem, Duration progress) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem)) ??
        History(bangumiItem, episode, adapterName, DateTime.now());
    history.lastWatchEpisode = episode;
    history.lastWatchTime = DateTime.now();

    var prog = history.progresses[episode];
    if (prog == null) {
      history.progresses[episode] =
          Progress(episode, road, progress.inMilliseconds);
    } else {
      prog.progress = progress;
    }

    storedHistories.put(history.key, history);
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
  }

  void clearProgress(BangumiItem bangumiItem, String adapterName, int episode) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem));
    history!.progresses[episode]!.progress = Duration.zero;
  }
}
