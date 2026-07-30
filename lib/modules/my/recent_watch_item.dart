import 'package:kazumi/modules/history/history_module.dart';

/// Display snapshot for a continue-watching card.
///
/// Cards read these fields only, so the sole way the list changes is
/// "history changed -> re-derive".
class RecentWatchItem {
  const RecentWatchItem({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.episodeLabel,
    required this.sourceLabel,
    required this.adapterName,
    required this.lastWatchTime,
    required this.history,
  });

  final String id;
  final String title;
  final String coverUrl;
  final String episodeLabel;
  final String sourceLabel;
  final String adapterName;
  final DateTime lastWatchTime;

  /// Handed back to the playback service; cards never read its fields.
  final History history;

  factory RecentWatchItem.from(History history) {
    final bangumiItem = history.bangumiItem;
    final isOffline = HistoryEntryKind.normalize(history.entryKind) ==
        HistoryEntryKind.offline;
    return RecentWatchItem(
      id: history.key,
      title: bangumiItem.nameCn.isEmpty ? bangumiItem.name : bangumiItem.nameCn,
      coverUrl: bangumiItem.images['large'] ?? '',
      episodeLabel: history.lastWatchEpisodeName.isEmpty
          ? '第${history.lastWatchEpisode}话'
          : history.lastWatchEpisodeName,
      sourceLabel: isOffline ? '缓存' : '在线',
      adapterName: history.adapterName,
      lastWatchTime: history.lastWatchTime,
      history: history,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecentWatchItem &&
        other.id == id &&
        other.title == title &&
        other.coverUrl == coverUrl &&
        other.episodeLabel == episodeLabel &&
        other.sourceLabel == sourceLabel &&
        other.adapterName == adapterName &&
        other.lastWatchTime == lastWatchTime;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        coverUrl,
        episodeLabel,
        sourceLabel,
        adapterName,
        lastWatchTime,
      );
}
