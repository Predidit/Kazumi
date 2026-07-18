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
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';

String historySourceText(String entryKind) {
  return HistoryEntryKind.normalize(entryKind) == HistoryEntryKind.offline
      ? '缓存'
      : '在线';
}

Future<_HistoryPlaybackOpenResult> _openHistoryPlaybackForEntry({
  required String entryKind,
  required Future<VideoPlaybackArgs?> Function() openOnlinePlayback,
  required Future<VideoPlaybackArgs?> Function() openOfflinePlayback,
}) async {
  if (HistoryEntryKind.normalize(entryKind) == HistoryEntryKind.offline) {
    final args = await openOfflinePlayback();
    return _HistoryPlaybackOpenResult(
      args: args,
      failureMessage: args != null ? null : '未找到可用缓存',
    );
  }

  final args = await openOnlinePlayback();
  return _HistoryPlaybackOpenResult(
    args: args,
    failureMessage: args != null ? null : '在线源不可用，请重新选择播放源',
  );
}

class _HistoryPlaybackOpenResult {
  const _HistoryPlaybackOpenResult({
    required this.args,
    required this.failureMessage,
  });

  final VideoPlaybackArgs? args;
  final String? failureMessage;
}

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
  final PluginsController pluginsController = inject<PluginsController>();
  final CollectController collectController = inject<CollectController>();
  final DownloadController downloadController = inject<DownloadController>();

  RuleCancelToken? _queryRoadsCancelToken;

  @override
  void dispose() {
    _queryRoadsCancelToken?.cancel();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (widget.showDelete) {
      KazumiDialog.showToast(message: '编辑模式');
      return;
    }
    KazumiDialog.showLoading(
      msg: '获取中',
      barrierDismissible: isDesktop(),
      onDismiss: () {
        _queryRoadsCancelToken?.cancel();
      },
    );
    final result = await _openHistoryPlaybackForEntry(
      entryKind: widget.historyItem.entryKind,
      openOnlinePlayback: _openOnlinePlayback,
      openOfflinePlayback: _openOfflinePlayback,
    );
    KazumiDialog.dismiss();
    if (!mounted) return;
    final args = result.args;
    if (args != null) {
      context.pushNamed('/video/', arguments: args);
      return;
    }
    KazumiDialog.showToast(message: result.failureMessage ?? '未找到可用播放入口');
  }

  Future<VideoPlaybackArgs?> _openOnlinePlayback() async {
    if (widget.historyItem.lastSrc.isEmpty) {
      return null;
    }
    Plugin? targetPlugin;
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == widget.historyItem.adapterName) {
        targetPlugin = plugin;
        break;
      }
    }
    if (targetPlugin == null) {
      return null;
    }
    try {
      _queryRoadsCancelToken?.cancel();
      _queryRoadsCancelToken = RuleCancelToken();
      final roads = await targetPlugin.queryChapterRoads(
        widget.historyItem.lastSrc,
        cancelToken: _queryRoadsCancelToken,
      );
      if (roads.isEmpty) {
        return null;
      }
      return OnlineVideoPlaybackArgs(
        bangumiItem: widget.historyItem.bangumiItem,
        plugin: targetPlugin,
        title: widget.historyItem.bangumiItem.nameCn == ''
            ? widget.historyItem.bangumiItem.name
            : widget.historyItem.bangumiItem.nameCn,
        src: widget.historyItem.lastSrc,
        roads: roads,
      );
    } catch (_) {
      KazumiLogger().w("QueryManager: failed to query roads");
      return null;
    }
  }

  Future<VideoPlaybackArgs?> _openOfflinePlayback() async {
    final downloadedEpisodes = downloadController.getCompletedEpisodes(
      widget.historyItem.bangumiItem.id,
      widget.historyItem.adapterName,
    );
    if (downloadedEpisodes.isEmpty) {
      return null;
    }

    DownloadEpisode? targetEpisode;
    if (widget.historyItem.episodePageUrl.isNotEmpty) {
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
      return null;
    }

    final localPath = downloadController.getLocalVideoPath(
      widget.historyItem.bangumiItem.id,
      widget.historyItem.adapterName,
      targetEpisode.episodeNumber,
    );
    if (localPath == null) {
      return null;
    }

    return OfflineVideoPlaybackArgs(
      bangumiItem: widget.historyItem.bangumiItem,
      pluginName: widget.historyItem.adapterName,
      episodeNumber: targetEpisode.episodeNumber,
      road: targetEpisode.road,
      downloadedEpisodes: downloadedEpisodes,
    );
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
        decoration: ShapeDecoration(
          color: colorScheme.errorContainer,
          shape: kazumiSmoothShape(context.design.radiusCompact),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        shape: kazumiSmoothShape(context.design.radiusCompact),
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRSuperellipse(
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
                          context.pushNamed(
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
