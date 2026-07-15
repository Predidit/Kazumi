import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/utils/format.dart';

const Duration _kExpandDuration = Duration(milliseconds: 250);
const Curve _kExpandCurve = Curves.easeInOutCubic;

/// Rounded tonal card for one bangumi download record: cover, title,
/// source tag, aggregate progress and a collapsible episode list.
class DownloadRecordCard extends StatelessWidget {
  const DownloadRecordCard({
    super.key,
    required this.record,
    required this.expanded,
    required this.onToggle,
    required this.onResumeAll,
    required this.onDeleteAll,
    required this.totalSpeed,
    required this.episodeTileBuilder,
  });

  final DownloadRecord record;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onResumeAll;
  final VoidCallback onDeleteAll;
  final double totalSpeed;

  /// Builds the episode rows; only invoked while [expanded], so collapsed
  /// cards skip sorting and tile construction entirely.
  final List<Widget> Function() episodeTileBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final episodes = record.episodes.values;
    final totalCount = episodes.length;
    final completedCount =
        episodes.where((e) => e.status == DownloadStatus.completed).length;
    final activeCount = episodes
        .where((e) =>
            e.status == DownloadStatus.downloading ||
            e.status == DownloadStatus.resolving ||
            e.status == DownloadStatus.pending)
        .length;
    final aggregateProgress = totalCount == 0
        ? 0.0
        : episodes.fold<double>(
              0,
              (sum, e) =>
                  sum +
                  (e.status == DownloadStatus.completed
                      ? 1.0
                      : e.progressPercent),
            ) /
            totalCount;
    final allCompleted = completedCount >= totalCount;

    var meta = '$completedCount/$totalCount 已完成';
    if (activeCount > 0) {
      meta += ' · $activeCount 项进行中';
      if (totalSpeed > 0) {
        meta += ' · ${formatSpeed(totalSpeed)}';
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NetworkImgLayer(
                    src: record.bangumiCover,
                    width: 56,
                    height: 75,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.bangumiName,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            RuleTag(
                              label: record.pluginName,
                              background: colorScheme.secondaryContainer,
                              foreground: colorScheme.onSecondaryContainer,
                            ),
                            Text(
                              meta,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: '更多操作',
                    onSelected: (value) {
                      if (value == 'resume_all') {
                        onResumeAll();
                      } else if (value == 'delete') {
                        onDeleteAll();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'resume_all',
                        child: Text('全部开始'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '全部删除',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: _kExpandDuration,
                      curve: _kExpandCurve,
                      child: Icon(
                        Icons.expand_more,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!allCompleted)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, expanded ? 4 : 16),
              child: LinearProgressIndicator(value: aggregateProgress),
            ),
          AnimatedSize(
            duration: _kExpandDuration,
            curve: _kExpandCurve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(children: episodeTileBuilder()),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// One episode row inside [DownloadRecordCard]: tonal status badge,
/// episode name, status line, optional full-width progress bar and actions.
class DownloadEpisodeTile extends StatelessWidget {
  const DownloadEpisodeTile({
    super.key,
    required this.episode,
    required this.statusText,
    this.actions = const [],
    this.onPlay,
  });

  final DownloadEpisode episode;
  final String statusText;
  final List<Widget> actions;

  /// Non-null only for completed episodes; makes the whole row tappable.
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isError = episode.status == DownloadStatus.failed;
    final showProgress = episode.status == DownloadStatus.downloading ||
        (episode.status == DownloadStatus.paused &&
            episode.progressPercent > 0);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            _EpisodeStatusBadge(episode: episode),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.episodeName.isNotEmpty
                        ? episode.episodeName
                        : '第${episode.episodeNumber}集',
                    style: textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: textTheme.bodySmall?.copyWith(
                      color: isError
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: episode.progressPercent),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Circular tonal badge showing the episode download status.
class _EpisodeStatusBadge extends StatelessWidget {
  const _EpisodeStatusBadge({required this.episode});

  final DownloadEpisode episode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color background;
    Widget child;
    switch (episode.status) {
      case DownloadStatus.completed:
        background = colorScheme.secondaryContainer;
        child = Icon(
          Icons.check_rounded,
          size: 18,
          color: colorScheme.onSecondaryContainer,
        );
        break;
      case DownloadStatus.downloading:
        background = Colors.transparent;
        child = SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            value: episode.progressPercent,
            strokeWidth: 2.5,
          ),
        );
        break;
      case DownloadStatus.resolving:
        background = Colors.transparent;
        child = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
        break;
      case DownloadStatus.failed:
        background = colorScheme.errorContainer;
        child = Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: colorScheme.onErrorContainer,
        );
        break;
      case DownloadStatus.paused:
        background = colorScheme.surfaceContainerHighest;
        child = Icon(
          Icons.pause_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        );
        break;
      case DownloadStatus.pending:
      default:
        background = colorScheme.surfaceContainerHighest;
        child = Icon(
          Icons.schedule_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        );
        break;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Center(child: child),
    );
  }
}

/// Empty state for the download page, following the onboarding badge idiom.
class DownloadEmptyState extends StatelessWidget {
  const DownloadEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.download_rounded,
            size: 32,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '暂无下载内容',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '缓存的番剧会显示在这里，随时离线观看',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
