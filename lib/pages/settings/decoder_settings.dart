import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/constants.dart';

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 25, top: 10, bottom: 5),
            child: Text(
              '选择不受支持的解码器将回退到软件解码',
              textAlign: TextAlign.left,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: ListView(
              children: hardwareDecodersList.entries
                  .map((e) => RadioListTile<String>(
                        title: Text(e.key),
                        subtitle: Text(e.value),
                        value: e.key,
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
          ),
        ],
      ),
    );
  }
}
