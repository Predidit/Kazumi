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
import 'package:logger/logger.dart';

// 视频历史记录卡片 - 水平布局
class BangumiHistoryCardV extends StatefulWidget {
  const BangumiHistoryCardV(
      {super.key, required this.historyItem, this.showDelete = true});

  final History historyItem;
  final bool showDelete;

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

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (widget.showDelete) {
            KazumiDialog.showToast(
              message: '编辑模式',
            );
            return;
          }
          KazumiDialog.showLoading(msg: '获取中');
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
          } catch (e) {
            KazumiLogger().log(Level.warning, e.toString());
            KazumiDialog.dismiss();
            KazumiDialog.showToast(message: '网络资源获取失败 ${e.toString()}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 0.65,
                child: LayoutBuilder(builder: (context, boxConstraints) {
                  final double maxWidth = boxConstraints.maxWidth;
                  final double maxHeight = boxConstraints.maxHeight;
                  return NetworkImgLayer(
                    src: widget.historyItem.bangumiItem.images['large'] ?? '',
                    width: maxWidth,
                    height: maxHeight,
                  );
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
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
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
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
      ),
    );
  }
}
