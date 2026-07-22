import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';

class DownloadEpisodeSheet extends StatefulWidget {
  final int road;
  final VideoPageController videoPageController;

  const DownloadEpisodeSheet({
    super.key,
    required this.road,
    required this.videoPageController,
  });

  @override
  State<DownloadEpisodeSheet> createState() => _DownloadEpisodeSheetState();
}

class _DownloadEpisodeSheetState extends State<DownloadEpisodeSheet> {
  VideoPageController get videoPageController => widget.videoPageController;
  final DownloadController downloadController = inject<DownloadController>();

  final Set<int> _selectedEpisodes = {};

  Road get currentRoadData => videoPageController.roadList[widget.road];
  int get episodeCount => currentRoadData.data.length;

  Set<String> _collectDownloadedUrls() {
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
    return downloadedUrls;
  }

  @override
  Widget build(BuildContext context) {
    final downloadedUrls = _collectDownloadedUrls();
    final selectableEpisodes = <int>[
      for (int i = 1; i <= episodeCount; i++)
        if (!downloadedUrls.contains(currentRoadData.data[i - 1])) i,
    ];
    final downloadedCount = episodeCount - selectableEpisodes.length;
    final allSelected = selectableEpisodes.isNotEmpty &&
        _selectedEpisodes.length == selectableEpisodes.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            MaterialBottomSheetHeader(
              title: '下载选集',
              description: downloadedCount > 0
                  ? '共 $episodeCount 集 · $downloadedCount 集已加入下载'
                  : '共 $episodeCount 集',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
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
                  return _EpisodeTile(
                    identifier: currentRoadData.identifier[index],
                    isDownloaded: isDownloaded,
                    isSelected: isSelected,
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
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: selectableEpisodes.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _selectedEpisodes.clear();
                                if (!allSelected) {
                                  _selectedEpisodes.addAll(selectableEpisodes);
                                }
                              });
                            },
                      icon: Icon(allSelected
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded),
                      // 用透明的最宽文案占位，切换文本时按钮宽度保持稳定。
                      label: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Opacity(opacity: 0, child: Text('取消全选')),
                          Text(allSelected ? '取消全选' : '全选'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _selectedEpisodes.isEmpty
                            ? null
                            : () => _startBatchDownload(context),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(_selectedEpisodes.isEmpty
                            ? '开始下载'
                            : '下载 ${_selectedEpisodes.length} 集'),
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

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.identifier,
    required this.isDownloaded,
    required this.isSelected,
    this.onTap,
  });

  final String identifier;
  final bool isDownloaded;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isDownloaded
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : isSelected
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerLow;
    final foregroundColor = isDownloaded
        ? colorScheme.outline
        : isSelected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    identifier,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: foregroundColor,
                    ),
                  ),
                ),
              ),
              if (isDownloaded)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    Icons.download_done_rounded,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                )
              else
                Positioned(
                  top: 4,
                  right: 4,
                  child: AnimatedScale(
                    scale: isSelected ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
