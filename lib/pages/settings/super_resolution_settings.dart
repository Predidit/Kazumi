import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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
  late final ValueNotifier<String> superResolutionType = ValueNotifier<String>(
    setting
        .get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1)
        .toString(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('超分辨率'),
      ),
      body: Center(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
          child: SettingsList(
            sections: [
              SettingsSection(title: const Text('若超分辨率没有生效, 请禁用硬件解码'), tiles: [
                SettingsTile<String>.radioTile(
                  title: const Text("OFF"),
                  description: const Text("默认禁用超分辨率"),
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
                  title: const Text("Anime4K"),
                  description: const Text("默认启用基于Anime4K的超分辨率"),
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
                )
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
