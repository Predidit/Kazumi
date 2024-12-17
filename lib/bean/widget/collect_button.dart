import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CollectButton extends StatefulWidget {
  const CollectButton(
      {super.key, required this.bangumiItem, this.withRounder = true});
  final BangumiItem bangumiItem;
  final bool withRounder;

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

  @override
  Widget build(BuildContext context) {
    collectType = collectController.getCollectType(widget.bangumiItem);
    return PopupMenuButton(
      tooltip: '',
      child: widget.withRounder
          ? NonClickableIconButton(
              icon: () {
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
              }(),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                () {
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
                }(),
                color: Colors.white,
              ),
            ),
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.favorite_border), Text(" 未追")],
            ),
          ),
          PopupMenuItem(
            value: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.favorite), Text(" 在看")],
            ),
          ),
          PopupMenuItem(
            value: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.star_rounded), Text(" 想看")],
            ),
          ),
          PopupMenuItem(
            value: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.pending_actions), Text(" 搁置")],
            ),
          ),
          PopupMenuItem(
            value: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.done), Text(" 看过")],
            ),
          ),
          PopupMenuItem(
            value: 5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.heart_broken), Text(" 抛弃")],
            ),
          ),
        ];
      },
      onSelected: (value) {
        if (value != collectType && mounted) {
          collectController.addCollect(widget.bangumiItem, type: value);
          setState(() {
            collectType = value;
          });
        }
      },
    );
  }
}

class NonClickableIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final double padding;

  const NonClickableIconButton({
    super.key,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.padding = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveBackgroundColor =
        backgroundColor ?? Theme.of(context).colorScheme.secondaryContainer;
    final Color effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: effectiveIconColor),
    );
  }
}
