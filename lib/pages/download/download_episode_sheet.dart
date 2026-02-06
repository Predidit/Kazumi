import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';

class DownloadEpisodeSheet extends StatefulWidget {
  final int road;

  const DownloadEpisodeSheet({super.key, required this.road});

  @override
  State<DownloadEpisodeSheet> createState() => _DownloadEpisodeSheetState();
}

class _DownloadEpisodeSheetState extends State<DownloadEpisodeSheet> {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final DownloadController downloadController =
      Modular.get<DownloadController>();

  final Set<int> _selectedEpisodes = {};

  Road get currentRoadData => videoPageController.roadList[widget.road];
  int get episodeCount => currentRoadData.data.length;

  @override
  Widget build(BuildContext context) {
    final record = downloadController.getRecord(
      videoPageController.bangumiItem.id,
      videoPageController.currentPlugin.name,
    );
    final downloadedUrls = <String>{};
    if (record != null) {
      for (final entry in record.episodes.entries) {
        if (entry.value.status == DownloadStatus.completed ||
            entry.value.status == DownloadStatus.downloading ||
            entry.value.status == DownloadStatus.pending) {
          if (entry.value.episodePageUrl.isNotEmpty) {
            downloadedUrls.add(entry.value.episodePageUrl);
          }
        }
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '选择要下载的集数',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '已选 ${_selectedEpisodes.length} 集',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Select all / deselect all
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedEpisodes.clear();
                        for (int i = 1; i <= episodeCount; i++) {
                          final url = currentRoadData.data[i - 1];
                          if (!downloadedUrls.contains(url)) {
                            _selectedEpisodes.add(i);
                          }
                        }
                      });
                    },
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedEpisodes.clear();
                      });
                    },
                    child: const Text('取消全选'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            // Grid
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 56,
                ),
                itemCount: episodeCount,
                itemBuilder: (context, index) {
                  final episodeNumber = index + 1;
                  final episodeUrl = currentRoadData.data[index];
                  final isDownloaded = downloadedUrls.contains(episodeUrl);
                  final isSelected = _selectedEpisodes.contains(episodeNumber);
                  final identifier = currentRoadData.identifier[index];

                  return Material(
                    color: isDownloaded
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5)
                        : isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.onInverseSurface,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: isDownloaded
                          ? null
                          : () {
                              setState(() {
                                if (isSelected) {
                                  _selectedEpisodes.remove(episodeNumber);
                                } else {
                                  _selectedEpisodes.add(episodeNumber);
                                }
                              });
                            },
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                identifier,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDownloaded
                                      ? Theme.of(context).colorScheme.outline
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          if (isDownloaded)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          if (isSelected)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: FilledButton(
                        onPressed: _selectedEpisodes.isEmpty
                            ? null
                            : () => _startBatchDownload(context),
                        child: Text('开始下载(${_selectedEpisodes.length})'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startBatchDownload(BuildContext context) {
    Navigator.pop(context);

    final plugin = videoPageController.currentPlugin;
    final bangumiItem = videoPageController.bangumiItem;

    final sortedEpisodes = _selectedEpisodes.toList()..sort();

    for (final episodeNumber in sortedEpisodes) {
      final episodePageUrl = currentRoadData.data[episodeNumber - 1];
      final identifier = currentRoadData.identifier[episodeNumber - 1];

      downloadController.startDownload(
        bangumiId: bangumiItem.id,
        bangumiName: bangumiItem.nameCn.isNotEmpty
            ? bangumiItem.nameCn
            : bangumiItem.name,
        bangumiCover: bangumiItem.images['large'] ?? '',
        pluginName: plugin.name,
        episodeNumber: episodeNumber,
        episodeName: identifier,
        road: widget.road,
        episodePageUrl: episodePageUrl,
      );
    }

    KazumiDialog.showToast(
      message: '已添加 ${sortedEpisodes.length} 集到下载队列，可在下载管理中查看',
    );
  }
}
