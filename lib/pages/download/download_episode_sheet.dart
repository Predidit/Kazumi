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

  final Set<int> _selectedListIndexes = {};

  Road get currentRoadData => videoPageController.roadList[widget.road];
  int get episodeCount => currentRoadData.data.length;

  @override
  Widget build(BuildContext context) {
    final record = downloadController.getRecord(
      videoPageController.bangumiItem.id,
      videoPageController.currentPlugin.name,
    );
    final downloadedLegacyUrls = <({String pageUrl, int road})>{};
    final downloadedStableIds = <({String stableId, int road})>{};
    if (record != null) {
      for (final entry in record.episodes.entries) {
        if (entry.value.status == DownloadStatus.completed ||
            entry.value.status == DownloadStatus.downloading ||
            entry.value.status == DownloadStatus.pending) {
          final stableId = entry.value.stableId;
          if (stableId.isNotEmpty) {
            downloadedStableIds.add((
              stableId: stableId,
              road: entry.value.road,
            ));
          }
          if (stableId.isEmpty && entry.value.episodePageUrl.isNotEmpty) {
            downloadedLegacyUrls.add((
              pageUrl: entry.value.episodePageUrl,
              road: entry.value.road,
            ));
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
                    '已选 ${_selectedListIndexes.length} 集',
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
                        _selectedListIndexes.clear();
                        for (int i = 1; i <= episodeCount; i++) {
                          final identity = currentRoadData.data[i - 1];
                          if (!isDownloadedEpisodeIdentity(
                            identity,
                            downloadedStableIds: downloadedStableIds,
                            downloadedLegacyUrls: downloadedLegacyUrls,
                          )) {
                            _selectedListIndexes.add(i);
                          }
                        }
                      });
                    },
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedListIndexes.clear();
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
                  final listIndex = index + 1;
                  final identity = currentRoadData.data[index];
                  final isDownloaded = isDownloadedEpisodeIdentity(
                    identity,
                    downloadedStableIds: downloadedStableIds,
                    downloadedLegacyUrls: downloadedLegacyUrls,
                  );
                  final isSelected = _selectedListIndexes.contains(listIndex);
                  final identifier = identity.title;

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
                                  _selectedListIndexes.remove(listIndex);
                                } else {
                                  _selectedListIndexes.add(listIndex);
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
                        onPressed: _selectedListIndexes.isEmpty
                            ? null
                            : () => _startBatchDownload(context),
                        child: Text('开始下载(${_selectedListIndexes.length})'),
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

    final sortedListIndexes = _selectedListIndexes.toList()..sort();

    for (final listIndex in sortedListIndexes) {
      final identity = currentRoadData.data[listIndex - 1];
      final episodePageUrl = identity.pageUrl;
      final identifier = identity.title;
      final episodeNumber = downloadEpisodeNumberForSelection(
        listIndex: listIndex,
        identity: identity,
      );

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
        stableId: identity.stableId,
      );
    }

    KazumiDialog.showToast(
      message: '已添加 ${sortedListIndexes.length} 集到下载队列，可在下载管理中查看',
    );
  }
}

bool isDownloadedEpisodeIdentity(
  EpisodeIdentity identity, {
  required Set<({String stableId, int road})> downloadedStableIds,
  required Set<({String pageUrl, int road})> downloadedLegacyUrls,
}) {
  return (identity.stableId.isNotEmpty &&
          downloadedStableIds.contains((
            stableId: identity.stableId,
            road: identity.roadIndex,
          ))) ||
      downloadedLegacyUrls.contains((
        pageUrl: identity.pageUrl,
        road: identity.roadIndex,
      ));
}

int downloadEpisodeNumberForSelection({
  required int listIndex,
  required EpisodeIdentity identity,
}) {
  final ordinal = identity.ordinal;
  return ordinal != null && ordinal > 0 ? ordinal : listIndex;
}
