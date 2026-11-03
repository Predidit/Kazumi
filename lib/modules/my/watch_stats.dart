import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/history/history_module.dart';

final class WatchStats {
  const WatchStats({
    this.watchedEpisodeCount = 0,
    this.watchedBangumiCount = 0,
    this.downloadTaskCount = 0,
  });

  final int watchedEpisodeCount;
  final int watchedBangumiCount;
  final int downloadTaskCount;

  @override
  bool operator ==(Object other) =>
      other is WatchStats &&
      other.watchedEpisodeCount == watchedEpisodeCount &&
      other.watchedBangumiCount == watchedBangumiCount &&
      other.downloadTaskCount == downloadTaskCount;

  @override
  int get hashCode => Object.hash(
        watchedEpisodeCount,
        watchedBangumiCount,
        downloadTaskCount,
      );

  factory WatchStats.from({
    required List<History> histories,
    required List<DownloadRecord> downloadRecords,
  }) {
    // Deduplicate episodes across rules and online/offline histories.
    final watchedEpisodes = <(int, int)>{};
    final watchedBangumiIds = <int>{};
    for (final history in histories) {
      if (history.progresses.isEmpty) continue;
      final bangumiId = history.bangumiItem.id;
      watchedBangumiIds.add(bangumiId);
      for (final episode in history.progresses.keys) {
        watchedEpisodes.add((bangumiId, episode));
      }
    }

    return WatchStats(
      watchedEpisodeCount: watchedEpisodes.length,
      watchedBangumiCount: watchedBangumiIds.length,
      // Count every download task, regardless of status.
      downloadTaskCount: downloadRecords.fold(
        0,
        (count, record) => count + record.episodes.length,
      ),
    );
  }
}
