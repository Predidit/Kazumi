import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

class CollectButton extends StatefulWidget {
  CollectButton({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
    this.focusNode,
  }) {
    isExtended = false;
  }

  CollectButton.extend({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
    this.focusNode,
  }) {
    isExtended = true;
  }

  final BangumiItem bangumiItem;
  final Color color;
  late final bool isExtended;
  final void Function()? onOpen;
  final void Function()? onClose;
  final FocusNode? focusNode;

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
  final CollectController collectController = inject<CollectController>();
  final _menuController = MenuController();
  final _menuFocusNodes = List.generate(
      6, (index) => FocusNode(debugLabel: 'TV collection menu $index'));
  LocalHistoryEntry? _menuHistory;
  bool _disposing = false;

  void _onMenuOpen() {
    if (TvMode.enabled) {
      final route = ModalRoute.of(context);
      if (route != null && _menuHistory == null) {
        _menuHistory = LocalHistoryEntry(onRemove: () {
          _menuHistory = null;
          if (!_disposing && _menuController.isOpen) _menuController.close();
        });
        route.addLocalHistoryEntry(_menuHistory!);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_menuController.isOpen) return;
        _menuFocusNodes[collectType.clamp(0, 5)].requestFocus();
      });
    }
    widget.onOpen?.call();
  }

  void _onMenuClose() {
    final entry = _menuHistory;
    _menuHistory = null;
    entry?.remove();
    if (!_disposing && TvMode.enabled) widget.focusNode?.requestFocus();
    widget.onClose?.call();
  }

  @override
  void dispose() {
    _disposing = true;
    _menuHistory?.remove();
    for (final node in _menuFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

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
      controller: _menuController,
      childFocusNode: widget.focusNode,
      consumeOutsideTap: true,
      onClose: _onMenuClose,
      onOpen: _onMenuOpen,
      crossAxisUnconstrained: false,
      builder: (_, MenuController controller, __) {
        if (widget.isExtended) {
          return FilledButton.icon(
            focusNode: widget.focusNode,
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
            focusNode: widget.focusNode,
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
          );
        }
      },
      menuChildren: List<MenuItemButton>.generate(
        6,
        (int index) => MenuItemButton(
          focusNode: TvMode.enabled ? _menuFocusNodes[index] : null,
          onPressed: () async {
            if (index != collectType && mounted) {
              await collectController.addCollect(widget.bangumiItem,
                  type: index);
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
