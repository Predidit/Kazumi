import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/utils/format_utils.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final DownloadController downloadController =
      Modular.get<DownloadController>();

  @override
  void initState() {
    super.initState();
    downloadController.refreshRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('下载管理')),
      body: Observer(builder: (context) {
        if (downloadController.records.isEmpty) {
          return const Center(
            child: Text('暂无离线下载'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: downloadController.records.length,
          itemBuilder: (context, index) {
            final record = downloadController.records[index];
            return _buildRecordCard(record);
          },
        );
      }),
    );
  }

  Widget _buildRecordCard(DownloadRecord record) {
    final episodes = record.episodes.values.toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    final completedCount = downloadController.completedCount(record);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                record.bangumiCover,
                width: 48,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 64,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.movie_outlined),
                ),
              ),
            ),
            title: Text(
              record.bangumiName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '来源: ${record.pluginName} · $completedCount/${episodes.length} 已完成',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDeleteRecord(record);
                } else if (value == 'resume_all') {
                  downloadController.resumeAllDownloads(
                    record.bangumiId,
                    record.pluginName,
                  );
                  KazumiDialog.showToast(message: '已开始恢复下载');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'resume_all',
                  child: Text('开始全部'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除全部'),
                ),
              ],
            ),
          ),
          // Episode list
          ...episodes.map((ep) => _buildEpisodeTile(record, ep)),
        ],
      ),
    );
  }

  Widget _buildEpisodeTile(DownloadRecord record, DownloadEpisode episode) {
    final statusIcon = _getStatusIcon(episode);
    final statusText = _getStatusText(record, episode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          statusIcon,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.episodeName.isNotEmpty
                      ? episode.episodeName
                      : '第${episode.episodeNumber}集',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: episode.status == DownloadStatus.failed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          if (episode.status == DownloadStatus.downloading) ...[
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: episode.progressPercent,
                minHeight: 3,
              ),
            ),
            const SizedBox(width: 8),
          ],
          ..._getActionButtons(record, episode),
        ],
      ),
    );
  }

  Widget _getStatusIcon(DownloadEpisode episode) {
    switch (episode.status) {
      case DownloadStatus.completed:
        return Icon(Icons.offline_pin,
            size: 20, color: Theme.of(context).colorScheme.primary);
      case DownloadStatus.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: episode.progressPercent,
            strokeWidth: 2,
          ),
        );
      case DownloadStatus.failed:
        return Icon(Icons.error_outline,
            size: 20, color: Theme.of(context).colorScheme.error);
      case DownloadStatus.paused:
        return Icon(Icons.pause_circle_outline,
            size: 20, color: Theme.of(context).colorScheme.outline);
      case DownloadStatus.pending:
        return Icon(Icons.hourglass_empty,
            size: 20, color: Theme.of(context).colorScheme.outline);
      case DownloadStatus.resolving:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default:
        return const SizedBox(width: 20, height: 20);
    }
  }

  String _getStatusText(DownloadRecord record, DownloadEpisode episode) {
    switch (episode.status) {
      case DownloadStatus.completed:
        return '已完成  ${formatBytes(episode.totalBytes)}';
      case DownloadStatus.downloading:
        final speed = downloadController.getSpeed(
          record.bangumiId,
          record.pluginName,
          episode.episodeNumber,
        );
        final speedText = speed > 0 ? ' · ${formatSpeed(speed)}' : '';
        return '${(episode.progressPercent * 100).toStringAsFixed(0)}%  '
            '${episode.downloadedSegments}/${episode.totalSegments}$speedText';
      case DownloadStatus.failed:
        return episode.errorMessage.isNotEmpty ? episode.errorMessage : '下载失败';
      case DownloadStatus.paused:
        return '已暂停  ${(episode.progressPercent * 100).toStringAsFixed(0)}%';
      case DownloadStatus.pending:
        return '等待中';
      case DownloadStatus.resolving:
        return '解析视频源中';
      default:
        return '';
    }
  }

  List<Widget> _getActionButtons(
      DownloadRecord record, DownloadEpisode episode) {
    final buttons = <Widget>[];

    switch (episode.status) {
      case DownloadStatus.completed:
        buttons.add(IconButton(
          icon: Icon(Icons.play_circle_outline,
              size: 20, color: Theme.of(context).colorScheme.primary),
          onPressed: () => _playEpisode(record, episode),
          tooltip: '播放',
          visualDensity: VisualDensity.compact,
        ));
        break;
      case DownloadStatus.downloading:
        buttons.add(IconButton(
          icon: const Icon(Icons.pause, size: 20),
          onPressed: () => downloadController.pauseDownload(
            record.bangumiId,
            record.pluginName,
            episode.episodeNumber,
          ),
          tooltip: '暂停',
          visualDensity: VisualDensity.compact,
        ));
        break;
      case DownloadStatus.paused:
        buttons.add(IconButton(
          icon: const Icon(Icons.play_arrow, size: 20),
          onPressed: () => downloadController.retryDownload(
            bangumiId: record.bangumiId,
            pluginName: record.pluginName,
            episodeNumber: episode.episodeNumber,
          ),
          tooltip: '继续',
          visualDensity: VisualDensity.compact,
        ));
        break;
      case DownloadStatus.failed:
        buttons.add(IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: () => downloadController.retryDownload(
            bangumiId: record.bangumiId,
            pluginName: record.pluginName,
            episodeNumber: episode.episodeNumber,
          ),
          tooltip: '重试',
          visualDensity: VisualDensity.compact,
        ));
        break;
      case DownloadStatus.pending:
        buttons.add(IconButton(
          icon: Icon(Icons.priority_high,
              size: 20, color: Theme.of(context).colorScheme.primary),
          onPressed: () {
            downloadController.priorityDownload(
              bangumiId: record.bangumiId,
              pluginName: record.pluginName,
              episodeNumber: episode.episodeNumber,
            );
            KazumiDialog.showToast(message: '已插队优先下载');
          },
          tooltip: '优先下载',
          visualDensity: VisualDensity.compact,
        ));
        break;
      default:
        break;
    }

    buttons.add(IconButton(
      icon: const Icon(Icons.delete_outline, size: 20),
      onPressed: () => _confirmDeleteEpisode(record, episode),
      tooltip: '删除',
      visualDensity: VisualDensity.compact,
    ));

    return buttons;
  }

  void _playEpisode(DownloadRecord record, DownloadEpisode episode) {
    final localPath = downloadController.getLocalVideoPath(
      record.bangumiId,
      record.pluginName,
      episode.episodeNumber,
    );
    if (localPath == null) {
      KazumiDialog.showToast(message: '本地文件不存在');
      return;
    }

    // 构建 BangumiItem
    final bangumiItem = BangumiItem(
      id: record.bangumiId,
      type: 2,
      name: record.bangumiName,
      nameCn: record.bangumiName,
      summary: '',
      airDate: '',
      airWeekday: 0,
      rank: 0,
      images: {'large': record.bangumiCover},
      tags: [],
      alias: [],
      ratingScore: 0.0,
      votes: 0,
      votesCount: [],
      info: '',
    );

    // 获取所有已下载集数（通过 Controller 委托给 Repository 层）
    final downloadedEpisodes = downloadController.getCompletedEpisodes(
      record.bangumiId,
      record.pluginName,
    );

    // 初始化离线模式
    final videoPageController = Modular.get<VideoPageController>();
    videoPageController.initForOfflinePlayback(
      bangumiItem: bangumiItem,
      pluginName: record.pluginName,
      episodeNumber: episode.episodeNumber,
      episodeName: episode.episodeName,
      road: episode.road,
      videoPath: localPath,
      downloadedEpisodes: downloadedEpisodes,
    );

    // 导航到 VideoPage
    Modular.to.pushNamed('/video/');
  }

  void _confirmDeleteEpisode(DownloadRecord record, DownloadEpisode episode) {
    KazumiDialog.show(
      builder: (context) => AlertDialog(
        title: const Text('删除下载'),
        content: Text('确定要删除「${episode.episodeName.isNotEmpty ? episode.episodeName : '第${episode.episodeNumber}集'}」的下载文件吗？'),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              downloadController.deleteEpisode(
                record.bangumiId,
                record.pluginName,
                episode.episodeNumber,
              );
              KazumiDialog.dismiss();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRecord(DownloadRecord record) {
    KazumiDialog.show(
      builder: (context) => AlertDialog(
        title: const Text('删除全部下载'),
        content: Text('确定要删除「${record.bangumiName}」的所有下载文件吗？'),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              downloadController.deleteRecord(
                record.bangumiId,
                record.pluginName,
              );
              KazumiDialog.dismiss();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
