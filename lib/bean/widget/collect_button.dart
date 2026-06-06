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
    this.menuController,
  }) {
    isExtended = false;
  }

  CollectButton.extend({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
    this.menuController,
  }) {
    isExtended = true;
  }

  final BangumiItem bangumiItem;
  final Color color;
  late final bool isExtended;
  final void Function()? onOpen;
  final void Function()? onClose;
  final MenuController? menuController;

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

  static const Map<int, String> _typeLabels = {
    0: '未追',
    1: '在看',
    2: '想看',
    3: '搁置',
    4: '看过',
    5: '抛弃',
  };

  static const Map<int, IconData> _typeIcons = {
    0: Icons.favorite_border,
    1: Icons.favorite,
    2: Icons.star_rounded,
    3: Icons.pending_actions,
    4: Icons.done,
    5: Icons.heart_broken,
  };

  @override
  void initState() {
    super.initState();
  }

  String getTypeStringByInt(int collectType) {
    return _typeLabels[collectType] ?? '未追';
  }

  IconData getIconByInt(int collectType) {
    return _typeIcons[collectType] ?? Icons.favorite_border;
  }

  @override
  Widget build(BuildContext context) {
    collectType = collectController.getCollectType(widget.bangumiItem);
    return MenuAnchor(
      controller: widget.menuController,
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
            tooltip: getTypeStringByInt(collectType),
            icon: Icon(
              getIconByInt(collectType),
              color: widget.color,
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            iconSize: 18,
            padding: EdgeInsets.zero,
          );
        }
      },
      menuChildren: List<MenuItemButton>.generate(
        6,
        (int index) => MenuItemButton(
          onPressed: () async {
            if (index != collectType && mounted) {
              await collectController.addCollect(widget.bangumiItem, type: index);
              // 防止状态错误刷新
              if (!mounted) {
                return;
              }
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
