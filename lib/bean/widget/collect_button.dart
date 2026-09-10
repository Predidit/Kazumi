import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';

class CollectButton extends StatelessWidget {
  final CollectController controller;

  const CollectButton({
    required this.controller,
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) : isExtended = false;

  const CollectButton.extend({
    required this.controller,
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) : isExtended = true;

  final BangumiItem bangumiItem;
  final Color color;
  final bool isExtended;
  final void Function()? onOpen;
  final void Function()? onClose;

  String getTypeStringByInt(int collectType) {
    switch (collectType) {
      case 1:
        return "在看";
      case 2:
        return "想看";
      case 3:
        return "搁置";
      case 4:
        return "看过";
      case 5:
        return "抛弃";
      default:
        return "未追";
    }
  }

  IconData getIconByInt(int collectType) {
    switch (collectType) {
      case 1:
        return Icons.favorite;
      case 2:
        return Icons.star_rounded;
      case 3:
        return Icons.pending_actions;
      case 4:
        return Icons.done;
      case 5:
        return Icons.heart_broken;
      default:
        return Icons.favorite_border;
    }
  }

  @override
  Widget build(BuildContext context) => Observer(builder: (context) {
        final activity = controller.activity;
        final busy = activity.blocks(bangumiItem.id);
        final collectType = controller.getCollectType(bangumiItem);
        return MenuAnchor(
          consumeOutsideTap: true,
          onClose: onClose,
          onOpen: onOpen,
          crossAxisUnconstrained: false,
          builder: (_, MenuController controller, __) {
            if (isExtended) {
              return FilledButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(getIconByInt(collectType)),
                label: Text(getTypeStringByInt(collectType)),
              );
            } else {
              return IconButton(
                onPressed: busy
                    ? null
                    : () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                tooltip: busy
                    ? (activity.isSyncing ? '正在同步收藏' : '正在更新收藏')
                    : getTypeStringByInt(collectType),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        getIconByInt(collectType),
                        color: color,
                      ),
              );
            }
          },
          menuChildren: List<MenuItemButton>.generate(
            6,
            (int index) => MenuItemButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (controller.activity.blocks(bangumiItem.id) ||
                          index == collectType) {
                        return;
                      }
                      try {
                        await controller.addCollect(bangumiItem, type: index);
                      } catch (_) {
                        if (context.mounted) {
                          KazumiDialog.showToast(
                              context: context, message: '修改收藏状态失败，请重试');
                        }
                      }
                    },
              child: Container(
                height: 48,
                constraints: BoxConstraints(minWidth: 112),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        getIconByInt(index),
                        color: index == collectType
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      SizedBox(width: 4),
                      Text(
                        ' ${getTypeStringByInt(index)}',
                        style: TextStyle(
                          color: index == collectType
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
}
