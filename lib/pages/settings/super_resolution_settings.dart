import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class SuperResolutionSettings extends StatefulWidget {
  const SuperResolutionSettings({super.key});

  @override
  State<SuperResolutionSettings> createState() =>
      _SuperResolutionSettingsState();
}

class _SuperResolutionSettingsState extends State<SuperResolutionSettings> {
  late final Box setting = GStorage.setting;
  late bool promptOnEnable;
  late final ValueNotifier<String> superResolutionType = ValueNotifier<String>(
    setting
        .get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1)
        .toString(),
  );

  @override
  void initState() {
    super.initState();
    promptOnEnable =
        setting.get(SettingBoxKey.superResolutionWarn, defaultValue: false);
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(
        title: Text('超分辨率'),
      ),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
              title: Text(
                  '超分辨率需要启用硬件解码, 若启用硬件解码后仍然不生效, 尝试切换视频渲染器为 gpu', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile<String>.radioTile(
                  title: Text("OFF", style: TextStyle(fontFamily: fontFamily)),
                  description: Text("默认禁用超分辨率", style: TextStyle(fontFamily: fontFamily)),
                  radioValue: "1",
                  groupValue: superResolutionType.value,
                  onChanged: (String? value) {
                    if (value != null) {
                      setting.put(SettingBoxKey.defaultSuperResolutionType,
                          int.tryParse(value) ?? 1);
                      setState(() {
                        superResolutionType.value = value;
                      });
                    }
                  },
                ),
                SettingsTile<String>.radioTile(
                  title: Text("Efficiency", style: TextStyle(fontFamily: fontFamily)),
                  description: Text("默认启用基于Anime4K的超分辨率 (效率优先)", style: TextStyle(fontFamily: fontFamily)),
                  radioValue: "2",
                  groupValue: superResolutionType.value,
                  onChanged: (String? value) {
                    if (value != null) {
                      setting.put(SettingBoxKey.defaultSuperResolutionType,
                          int.tryParse(value) ?? 1);
                      setState(() {
                        superResolutionType.value = value;
                      });
                    }
                  },
                ),
                SettingsTile<String>.radioTile(
                  title: Text("Quality", style: TextStyle(fontFamily: fontFamily)),
                  description: Text("默认启用基于Anime4K的超分辨率 (质量优先)", style: TextStyle(fontFamily: fontFamily)),
                  radioValue: "3",
                  groupValue: superResolutionType.value,
                  onChanged: (String? value) {
                    if (value != null) {
                      setting.put(SettingBoxKey.defaultSuperResolutionType,
                          int.tryParse(value) ?? 1);
                      setState(() {
                        superResolutionType.value = value;
                      });
                    }
                  },
                )
              ]),
          SettingsSection(
            title: Text('默认行为', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile.switchTile(
                title: Text('关闭提示', style: TextStyle(fontFamily: fontFamily)),
                description: Text('关闭每次启用超分辨率时的提示', style: TextStyle(fontFamily: fontFamily)),
                initialValue: promptOnEnable,
                onToggle: (value) async {
                  promptOnEnable = value ?? !promptOnEnable;
                  await setting.put(
                      SettingBoxKey.superResolutionWarn, promptOnEnable);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
