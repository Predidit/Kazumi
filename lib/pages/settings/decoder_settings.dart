import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class DecoderSettings extends StatefulWidget {
  const DecoderSettings({super.key});

  @override
  State<DecoderSettings> createState() => _DecoderSettingsState();
}

class _DecoderSettingsState extends State<DecoderSettings> {
  late final Box setting = GStorage.setting;
  late final ValueNotifier<String> decoder = ValueNotifier<String>(
    setting.get(SettingBoxKey.hardwareDecoder, defaultValue: 'auto-safe'),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('硬件解码器'),
      ),
      body: Center(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
          child: SettingsList(
            sections: [
              SettingsSection(
                title: const Text('选择不受支持的解码器将回退到软件解码'),
                tiles: hardwareDecodersList.entries
                    .map((e) => SettingsTile<String>.radioTile(
                          title: Text(e.key),
                          description: Text(e.value),
                          radioValue: e.key,
                          groupValue: decoder.value,
                          onChanged: (String? value) {
                            if (value != null) {
                              setting.put(SettingBoxKey.hardwareDecoder, value);
                              setState(() {
                                decoder.value = value;
                              });
                            }
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
