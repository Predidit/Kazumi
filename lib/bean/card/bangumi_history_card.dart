import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/history/history_module.dart';
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
    this.showDelete = true,
    this.cardHeight = 120,
    this.cardWidth,
  });

  final History historyItem;
  final bool showDelete;
  final double cardHeight;
  final double? cardWidth;

  @override
  State<BangumiHistoryCardV> createState() => _BangumiHistoryCardVState();
}

class _BangumiHistoryCardVState extends State<BangumiHistoryCardV> {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final HistoryController historyController = Modular.get<HistoryController>();

  Widget propertyChip({
    required String title,
    required String value,
    bool showTitle = false,
  }) {
    final message = '$title: $value';
    return Chip(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      side: BorderSide.none,
      label: Text(
        showTitle ? message : value,
        style: Theme.of(context).textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget buildImage(
      BuildContext context, String imageUrl, double width, double height) {
    final borderRadius = BorderRadius.circular(16);
    Widget img = NetworkImgLayer(
      src: imageUrl,
      width: width,
      height: height,
    );
    img = ClipRRect(
      borderRadius: borderRadius,
      child: img,
    );
    return img;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double borderRadius = 18;
    final double imageWidth = widget.cardHeight * 0.7;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () async {
          if (widget.showDelete) {
            KazumiDialog.showToast(
              message: '编辑模式',
            );
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
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildImage(
                context,
                widget.historyItem.bangumiItem.images['large'] ?? '',
                imageWidth,
                widget.cardHeight),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      widget.historyItem.bangumiItem.nameCn == ''
                          ? widget.historyItem.bangumiItem.name
                          : widget.historyItem.bangumiItem.nameCn,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        propertyChip(
                          title: '来源',
                          value: widget.historyItem.adapterName,
                          showTitle: true,
                        ),
                        propertyChip(
                          title: '看到',
                          value: widget.historyItem.lastWatchEpisodeName.isEmpty
                              ? '第${widget.historyItem.lastWatchEpisode}话'
                              : widget.historyItem.lastWatchEpisodeName,
                          showTitle: true,
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!widget.showDelete) ...[
                  CollectButton(
                    onClose: () {
                      FocusScope.of(context).unfocus();
                    },
                    bangumiItem: widget.historyItem.bangumiItem,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.open_in_new,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
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
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    onPressed: () {
                      historyController.deleteHistory(widget.historyItem);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
