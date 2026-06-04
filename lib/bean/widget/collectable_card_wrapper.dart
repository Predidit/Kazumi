import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/widget/collect_button.dart';

class CollectableCardWrapper extends StatefulWidget {
  const CollectableCardWrapper({
    super.key,
    required this.bangumiItem,
    required this.child,
  });

  final BangumiItem bangumiItem;
  final Widget child;

  @override
  State<CollectableCardWrapper> createState() => _CollectableCardWrapperState();
}

class _CollectableCardWrapperState extends State<CollectableCardWrapper> {
  final MenuController menuController = MenuController();

  void _openMenu() {
    if (!menuController.isOpen) {
      menuController.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        GestureDetector(
          onLongPress: _openMenu,
          onSecondaryTap: _openMenu,
          child: widget.child,
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withAlpha(180),
              shape: BoxShape.circle,
            ),
            child: CollectButton(
              bangumiItem: widget.bangumiItem,
              color: colorScheme.onSurface.withAlpha(180),
              menuController: menuController,
            ),
          ),
        ),
      ],
    );
  }
}
