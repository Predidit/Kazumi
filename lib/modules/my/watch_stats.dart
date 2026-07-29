import 'package:flutter/foundation.dart' show mapEquals;
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/history/history_module.dart';

/// Device-local viewing stats, derived from history, collect and download data.
class WatchStats {
  const WatchStats({
    this.collectedCount = 0,
    this.collectCounts = const {},
    this.watchedEpisodeCount = 0,
    this.watchedBangumiCount = 0,
    this.downloadTaskCount = 0,
    this.downloadBangumiCount = 0,
    this.downloadedBytes = 0,
    this.lastWatchTime,
    this.lastWatchName,
  });

  final int collectedCount;
  final Map<CollectType, int> collectCounts;
  final int watchedEpisodeCount;
  final int watchedBangumiCount;
  final int downloadTaskCount;
  final int downloadBangumiCount;
  final int downloadedBytes;
  final DateTime? lastWatchTime;
  final String? lastWatchName;

  /// Playback rewrites history every second, so equality lets the observable
  /// stay quiet unless a number actually moved.
  @override
  bool operator ==(Object other) {
    return other is WatchStats &&
        other.collectedCount == collectedCount &&
        mapEquals(other.collectCounts, collectCounts) &&
        other.watchedEpisodeCount == watchedEpisodeCount &&
        other.watchedBangumiCount == watchedBangumiCount &&
        other.downloadTaskCount == downloadTaskCount &&
        other.downloadBangumiCount == downloadBangumiCount &&
        other.downloadedBytes == downloadedBytes &&
        other.lastWatchTime == lastWatchTime &&
        other.lastWatchName == lastWatchName;
  }

  // collectCounts is covered by ==; leaving it out only widens buckets.
  @override
  int get hashCode => Object.hash(
        collectedCount,
        watchedEpisodeCount,
        watchedBangumiCount,
        downloadTaskCount,
        downloadBangumiCount,
        downloadedBytes,
        lastWatchTime,
        lastWatchName,
      );

  /// Episodes are keyed by bangumi and number, so watching one through several
  /// rules or both online and offline still counts once.
  factory WatchStats.from({
    required List<History> histories,
    required List<CollectedBangumi> collectibles,
    required List<DownloadRecord> downloadRecords,
  }) {
    final watchedEpisodeKeys = <String>{};
    final watchedBangumiIds = <int>{};
    History? lastWatched;

    for (final history in histories) {
      if (history.progresses.isEmpty) {
        continue;
      }
      final bangumiId = history.bangumiItem.id;
      watchedBangumiIds.add(bangumiId);
      if (lastWatched == null ||
          lastWatched.lastWatchTime.isBefore(history.lastWatchTime)) {
        lastWatched = history;
      }
      for (final episode in history.progresses.keys) {
        watchedEpisodeKeys.add('$bangumiId::$episode');
      }
    }

    var collectedCount = 0;
    final collectCounts = <CollectType, int>{};
    for (final collectible in collectibles) {
      final type = CollectType.fromValue(collectible.type);
      if (!type.isCollected) {
        continue;
      }
      collectedCount++;
      collectCounts[type] = (collectCounts[type] ?? 0) + 1;
    }

    // Counts every task rather than only completed ones: tasks change when the
    // user adds or removes them on a page that covers the my page, whereas an
    // episode finishing happens in the background, where nothing tells the my
    // page to re-derive. totalBytes holds bytes already on disk, so summing it
    // across unfinished tasks still reports real usage.
    var downloadTaskCount = 0;
    var downloadBangumiCount = 0;
    var downloadedBytes = 0;
    for (final record in downloadRecords) {
      if (record.episodes.isEmpty) {
        continue;
      }
      downloadBangumiCount++;
      for (final episode in record.episodes.values) {
        downloadTaskCount++;
        downloadedBytes += episode.totalBytes;
      }
    }

    return WatchStats(
      collectedCount: collectedCount,
      collectCounts: collectCounts,
      watchedEpisodeCount: watchedEpisodeKeys.length,
      watchedBangumiCount: watchedBangumiIds.length,
      downloadTaskCount: downloadTaskCount,
      downloadBangumiCount: downloadBangumiCount,
      downloadedBytes: downloadedBytes,
      lastWatchTime: lastWatched?.lastWatchTime,
      lastWatchName: lastWatched == null
          ? null
          : (lastWatched.bangumiItem.nameCn.isEmpty
              ? lastWatched.bangumiItem.name
              : lastWatched.bangumiItem.nameCn),
    );
  }
}
