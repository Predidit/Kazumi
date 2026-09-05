import 'package:flutter/material.dart';

import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';

Future<DanmakuDestination?> showDanmakuDestinationSheet(BuildContext context) {
  return showAdaptiveBottomSheet<DanmakuDestination>(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MaterialBottomSheetHeader(
          title: '发送到',
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: materialBottomSheetContentPadding,
            child: SplitListGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: const Text('一起看聊天室'),
                  subtitle: const Text('与同房间的朋友聊天'),
                  onTap: () =>
                      Navigator.of(context).pop(DanmakuDestination.chatRoom),
                ),
                ListTile(
                  leading: const Icon(Icons.subtitles_outlined),
                  title: const Text('视频弹幕'),
                  subtitle: const Text('发送至远程弹幕库'),
                  onTap: () => Navigator.of(context)
                      .pop(DanmakuDestination.remoteDanmaku),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
