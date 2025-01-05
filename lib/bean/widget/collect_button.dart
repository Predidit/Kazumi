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

  String getTypeStringByInt(int collectType){
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
    return PopupMenuButton(
      tooltip: '',
      child: widget.withRounder
          ? NonClickableIconButton(
              icon: getIconByInt(collectType),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                getIconByInt(collectType),
                color: Colors.white,
              ),
            ),
      itemBuilder: (context) {
        return List.generate(
          6,
          (i) => PopupMenuItem(
            value: i,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(getIconByInt(i)),
                Text(' ${getTypeStringByInt(i)}'),
              ],
            ),
          ),
        );
      },
      onSelected: (value) {
        if (value != collectType && mounted) {
          collectController.addCollect(widget.bangumiItem, type: value);
          setState(() {});
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
    final Color effectiveIconColor =
        iconColor ?? Theme.of(context).colorScheme.onSecondaryContainer;
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
