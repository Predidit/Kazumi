import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
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
  void dispose() {
    superResolutionType.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(
        title: Text('Super resolution'),
      ),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
              title: Text('Super resolution requires hardware decoding. If it still does not work after enabling hardware decoding, try switching the video renderer to gpu',
                  style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile<String>.radioTile(
                  title: Text("OFF", style: TextStyle(fontFamily: fontFamily)),
                  description: Text("Super resolution disabled by default",
                      style: TextStyle(fontFamily: fontFamily)),
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
                  title: Text("Efficiency",
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text("Anime4K-based super resolution enabled by default (performance first)",
                      style: TextStyle(fontFamily: fontFamily)),
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
                  title:
                      Text("Quality", style: TextStyle(fontFamily: fontFamily)),
                  description: Text("Anime4K-based super resolution enabled by default (quality first)",
                      style: TextStyle(fontFamily: fontFamily)),
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
            title: Text('Default behavior', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile.switchTile(
                title: Text('Disable prompt', style: TextStyle(fontFamily: fontFamily)),
                description: Text('Disable the prompt shown each time super resolution is enabled',
                    style: TextStyle(fontFamily: fontFamily)),
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
