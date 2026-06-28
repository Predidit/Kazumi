import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/date_time.dart';

String historySourceText(String entryKind) {
  return HistoryEntryKind.normalize(entryKind) == HistoryEntryKind.offline
      ? '缓存'
      : '在线';
}

Future<HistoryPlaybackOpenResult> openHistoryPlaybackForEntry({
  required String entryKind,
  required Future<bool> Function() openOnlinePlayback,
  required Future<bool> Function() openOfflinePlayback,
}) async {
  if (HistoryEntryKind.normalize(entryKind) == HistoryEntryKind.offline) {
    final opened = await openOfflinePlayback();
    return HistoryPlaybackOpenResult(
      opened: opened,
      failureMessage: opened ? null : '未找到可用缓存',
    );
  }

  final opened = await openOnlinePlayback();
  return HistoryPlaybackOpenResult(
    opened: opened,
    failureMessage: opened ? null : '在线源不可用，请重新选择播放源',
  );
}

class HistoryPlaybackOpenResult {
  const HistoryPlaybackOpenResult({
    required this.opened,
    required this.failureMessage,
  });

  final bool opened;
  final String? failureMessage;
}

// 视频历史记录卡片 - 水平布局
class BangumiHistoryCardV extends StatefulWidget {
  const BangumiHistoryCardV({
    super.key,
    required this.historyItem,
    this.showDelete = false,
    this.onDeleted,
  });

  final History historyItem;
  final bool showDelete;
  final VoidCallback? onDeleted;

  @override
  State<BangumiHistoryCardV> createState() => _BangumiHistoryCardVState();
}

class _BangumiHistoryCardVState extends State<BangumiHistoryCardV> {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final CollectController collectController = Modular.get<CollectController>();
  final DownloadController downloadController =
      Modular.get<DownloadController>();

  Future<void> _onTap() async {
    if (widget.showDelete) {
      KazumiDialog.showToast(message: '编辑模式');
      return;
    }
    KazumiDialog.showLoading(
      msg: '获取中',
      barrierDismissible: isDesktop(),
      onDismiss: () {
        videoPageController.cancelQueryRoads();
      },
    );
    final result = await openHistoryPlaybackForEntry(
      entryKind: widget.historyItem.entryKind,
      openOnlinePlayback: _openOnlinePlayback,
      openOfflinePlayback: _openOfflinePlayback,
    );
    KazumiDialog.dismiss();
    if (result.opened) {
      Modular.to.pushNamed('/video/');
      return;
    }
    KazumiDialog.showToast(message: result.failureMessage ?? '未找到可用播放入口');
  }

  Future<bool> _openOnlinePlayback() async {
    if (widget.historyItem.lastSrc.isEmpty) {
      return false;
    }
    Plugin? targetPlugin;
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == widget.historyItem.adapterName) {
        targetPlugin = plugin;
        break;
      }
    }
    if (targetPlugin == null) {
      return false;
    }
    videoPageController.bangumiItem = widget.historyItem.bangumiItem;
    videoPageController.currentPlugin = targetPlugin;
    videoPageController.title = widget.historyItem.bangumiItem.nameCn == ''
        ? widget.historyItem.bangumiItem.name
        : widget.historyItem.bangumiItem.nameCn;
    videoPageController.src = widget.historyItem.lastSrc;
    try {
      await videoPageController.queryRoads(
        widget.historyItem.lastSrc,
        targetPlugin.name,
      );
      return true;
    } catch (_) {
      KazumiLogger().w("QueryManager: failed to query roads");
      return false;
    }
  }

  Future<bool> _openOfflinePlayback() async {
    final downloadedEpisodes = downloadController.getCompletedEpisodes(
      widget.historyItem.bangumiItem.id,
      widget.historyItem.adapterName,
    );
    if (downloadedEpisodes.isEmpty) {
      return false;
    }

    DownloadEpisode? targetEpisode;
    final progressStableId = _lastWatchProgress(widget.historyItem)?.stableId;
    final stableId = widget.historyItem.stableId.trim().isNotEmpty
        ? widget.historyItem.stableId.trim()
        : progressStableId ?? '';
    if (stableId.isNotEmpty) {
      for (final episode in downloadedEpisodes) {
        if (episode.stableId == stableId) {
          targetEpisode = episode;
          break;
        }
      }
    }
    if (targetEpisode == null && widget.historyItem.episodePageUrl.isNotEmpty) {
      for (final episode in downloadedEpisodes) {
        if (episode.episodePageUrl == widget.historyItem.episodePageUrl) {
          targetEpisode = episode;
          break;
        }
      }
    }
    targetEpisode ??= _episodeByNumber(
      downloadedEpisodes,
      widget.historyItem.lastWatchEpisode,
    );
    if (targetEpisode == null) {
      return false;
    }

    final localPath = downloadController.getLocalVideoPathForEpisode(
      targetEpisode,
    );
    if (localPath == null) {
      return false;
    }

    videoPageController.initForOfflinePlayback(
      bangumiItem: widget.historyItem.bangumiItem,
      pluginName: widget.historyItem.adapterName,
      episodeNumber: targetEpisode.episodeNumber,
      stableId: targetEpisode.stableId,
      road: targetEpisode.road,
      downloadedEpisodes: downloadedEpisodes,
    );
    return true;
  }

  Progress? _lastWatchProgress(History history) {
    final topStableId = history.stableId.trim();
    if (topStableId.isNotEmpty) {
      for (final progress in history.progresses.values) {
        if (progress.stableId == topStableId) {
          return progress;
        }
      }
    }

    final topUrl = history.episodePageUrl.trim();
    if (topUrl.isNotEmpty) {
      for (final progress in history.progresses.values) {
        if (progress.episodePageUrl == topUrl) {
          return progress;
        }
      }
    }

    final keyedProgress = history.progresses[history.lastWatchEpisode];
    if (keyedProgress != null &&
        keyedProgress.episode == history.lastWatchEpisode) {
      return keyedProgress;
    }

    for (final progress in history.progresses.values) {
      if (progress.episode == history.lastWatchEpisode) {
        return progress;
      }
    }
    return null;
  }

  DownloadEpisode? _episodeByNumber(
    List<DownloadEpisode> episodes,
    int episodeNumber,
  ) {
    for (final episode in episodes) {
      if (episode.episodeNumber == episodeNumber) {
        return episode;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double imageWidth = 80;
    final double imageHeight = 108;
    final String title = widget.historyItem.bangumiItem.nameCn == ''
        ? widget.historyItem.bangumiItem.name
        : widget.historyItem.bangumiItem.nameCn;
    final String episodeText = widget.historyItem.lastWatchEpisodeName.isEmpty
        ? '第${widget.historyItem.lastWatchEpisode}话'
        : widget.historyItem.lastWatchEpisodeName;
    final String sourceText = historySourceText(widget.historyItem.entryKind);

    return Dismissible(
      key: ValueKey(widget.historyItem.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        widget.onDeleted?.call();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NetworkImgLayer(
                    src: widget.historyItem.bangumiItem.images['large'] ?? '',
                    width: imageWidth,
                    height: imageHeight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: imageHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                episodeText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.extension_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$sourceText · ${widget.historyItem.adapterName}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatTimestampToRelativeTime(widget.historyItem
                                      .lastWatchTime.millisecondsSinceEpoch ~/
                                  1000),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.showDelete) ...[
                      Observer(
                        builder: (context) {
                          collectController.collectibles.length;
                          return CollectButton(
                            onClose: () {
                              FocusScope.of(context).unfocus();
                            },
                            bangumiItem: widget.historyItem.bangumiItem,
                            color: colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.open_in_new,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: '番剧详情',
                        onPressed: () {
                          Modular.to.pushNamed(
                            '/info/',
                            arguments: widget.historyItem.bangumiItem,
                          );
                        },
                      ),
                    ],
                    if (widget.showDelete)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: colorScheme.error,
                        ),
                        tooltip: '删除记录',
                        onPressed: () {
                          widget.onDeleted?.call();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
