import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';

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
  final HistoryController historyController = Modular.get<HistoryController>();
  final CollectController collectController = Modular.get<CollectController>();

  Future<void> _onTap() async {
    if (widget.showDelete) {
      KazumiDialog.showToast(message: '编辑模式');
      return;
    }
    KazumiDialog.showLoading(
      msg: '获取中',
      barrierDismissible: Utils.isDesktop(),
      onDismiss: () {
        videoPageController.cancelQueryRoads();
      },
    );
    bool flag = false;
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == widget.historyItem.adapterName) {
        videoPageController.currentPlugin = plugin;
        flag = true;
        break;
      }
    }
    if (!flag) {
      KazumiDialog.dismiss();
      KazumiDialog.showToast(message: '未找到关联番剧源');
      return;
    }
    videoPageController.bangumiItem = widget.historyItem.bangumiItem;
    videoPageController.title =
        widget.historyItem.bangumiItem.nameCn == ''
            ? widget.historyItem.bangumiItem.name
            : widget.historyItem.bangumiItem.nameCn;
    videoPageController.src = widget.historyItem.lastSrc;
    try {
      await videoPageController.queryRoads(widget.historyItem.lastSrc,
          videoPageController.currentPlugin.name);
      KazumiDialog.dismiss();
      Modular.to.pushNamed('/video/');
    } catch (_) {
      KazumiLogger().w("QueryManager: failed to query roads");
      KazumiDialog.dismiss();
    }
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
    final String episodeText =
        widget.historyItem.lastWatchEpisodeName.isEmpty
            ? '第${widget.historyItem.lastWatchEpisode}话'
            : widget.historyItem.lastWatchEpisodeName;

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
                                widget.historyItem.adapterName,
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
                              Utils.formatTimestampToRelativeTime(
                                  widget.historyItem.lastWatchTime.millisecondsSinceEpoch ~/ 1000),
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
