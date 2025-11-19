import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:kazumi/utils/utils.dart';

class ControlSettingsPage extends StatefulWidget {
  const ControlSettingsPage({super.key});

  @override
  State<ControlSettingsPage> createState() => _ControlSettingsPageState();
}

class _ControlSettingsPageState extends State<ControlSettingsPage> {
  Box setting = GStorage.setting;
  late bool touchBetter;


  @override  void initState() {
    super.initState();

    touchBetter = setting.get(SettingBoxKey.touchBetter, defaultValue: !Utils.isDesktop());

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('操作设置')),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
            title: const Text('快捷键'),
            tiles: [
              SettingsTile.navigation(
                title: const Text('键盘快捷键'),
                onPressed: (_) {
                  Modular.to.pushNamed('/settings/control/keyboard');  
                },
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  touchBetter = value ?? !touchBetter;
                  await setting.put(
                      SettingBoxKey.touchBetter, touchBetter);
                  setState(() {});
                },
                title: const Text('触摸优化'),
                initialValue: touchBetter,
              ),
            ]
          ),
        ],
      ),
    );
  }
}
