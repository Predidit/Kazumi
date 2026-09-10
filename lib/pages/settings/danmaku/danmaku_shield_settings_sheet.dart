import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_editor.dart';

class DanmakuShieldSettingsSheet extends StatelessWidget {
  final MyController controller;

  const DanmakuShieldSettingsSheet({required this.controller, super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            MaterialBottomSheetHeader(
              title: '屏蔽规则',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: DanmakuShieldEditor(controller: controller),
            ),
          ],
        ),
      );
}
