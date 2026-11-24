import 'package:flutter/material.dart';

import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/bean/widget/split_list_selector.dart';
import 'package:kazumi/modules/roads/road_module.dart';

class EpisodeRoadPickerSheet extends StatelessWidget {
  const EpisodeRoadPickerSheet({
    super.key,
    required this.roads,
    required this.roadName,
    required this.visibleRoad,
  });

  final List<Road> roads;
  final String Function(int index) roadName;
  final int visibleRoad;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MaterialBottomSheetHeader(
          title: '选择播放线路',
          description: '共 ${roads.length} 条线路',
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: roads.length,
            separatorBuilder: (_, _) => const SizedBox(height: splitListRowGap),
            itemBuilder: (context, index) {
              final name = roadName(index);
              final count = roads[index].data.length;
              return SplitListOptionRow(
                key: ValueKey('road-option-$index'),
                badge: (index + 1).toString().padLeft(2, '0'),
                title: name,
                subtitle: '$count 集',
                semanticsLabel: '$name，$count 集',
                first: index == 0,
                last: index == roads.length - 1,
                selected: index == visibleRoad,
                showSelectedCheck: true,
                onTap: () => Navigator.of(context).pop(index),
              );
            },
          ),
        ),
      ],
    );
  }
}
