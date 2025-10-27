import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CollectButton extends StatefulWidget {
  CollectButton({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = false;
  }

  CollectButton.extend({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = true;
  }

  final BangumiItem bangumiItem;
  final Color color;
  late final bool isExtended;
  final void Function()? onOpen;
  final void Function()? onClose;

  @override
  State<CollectButton> createState() => _CollectButtonState();
}

class _CollectButtonState extends State<CollectButton> {
  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  late int collectType;
  final CollectController collectController = Modular.get<CollectController>();

  @override
  void initState() {
    super.initState();
  }

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
  Widget build(BuildContext context) {
    collectType = collectController.getCollectType(widget.bangumiItem);
    return MenuAnchor(
      consumeOutsideTap: true,
      onClose: widget.onClose,
      onOpen: widget.onOpen,
      crossAxisUnconstrained: false,
      builder: (_, MenuController controller, __) {
        if (widget.isExtended) {
          return FilledButton.icon(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Icon(getIconByInt(collectType)),
            label: Text(getTypeStringByInt(collectType)),
          );
        } else {
          return IconButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Icon(
              getIconByInt(collectType),
              color: widget.color,
            ),
          );
        }
      },
      menuChildren: List<MenuItemButton>.generate(
        6,
        (int index) => MenuItemButton(
          onPressed: () {
            if (index != collectType && mounted) {
              collectController.addCollect(widget.bangumiItem, type: index);
              setState(() {});
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
  }
}
