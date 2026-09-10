import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_editor.dart';

class DanmakuShieldSettings extends StatelessWidget {
  final MyController controller;

  const DanmakuShieldSettings({required this.controller, super.key});

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('屏蔽规则'),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: DanmakuShieldEditor(
              controller: controller,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      );
}
