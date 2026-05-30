import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
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
  void dispose() {
    decoder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(
        title: Text('Hardware decoder'),
      ),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
            title: Text('Selecting an unsupported decoder falls back to software decoding',
                style: TextStyle(fontFamily: fontFamily)),
            tiles: hardwareDecodersList.entries
                .map((e) => SettingsTile<String>.radioTile(
                      title:
                          Text(e.key, style: TextStyle(fontFamily: fontFamily)),
                      description: Text(e.value,
                          style: TextStyle(fontFamily: fontFamily)),
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
    );
  }
}
