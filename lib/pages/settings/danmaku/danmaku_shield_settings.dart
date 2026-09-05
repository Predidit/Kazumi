import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_editor.dart';

class DanmakuShieldSettings extends StatelessWidget {
  const DanmakuShieldSettings({super.key});

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('屏蔽规则'),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: DanmakuShieldEditor(
              controller: inject<MyController>(),
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      );
}
