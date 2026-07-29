import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/settings/settings_list.dart';

class RendererSettings extends StatefulWidget {
  const RendererSettings({super.key});

  @override
  State<RendererSettings> createState() => _RendererSettingsState();
}

class _RendererSettingsState extends State<RendererSettings> {
  late final ValueNotifier<String> renderer = ValueNotifier<String>(
    GStorage.getSetting<String>(SettingsKeys.androidVideoRenderer),
  );

  @override
  void dispose() {
    renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(
        title: Text('视频渲染器'),
      ),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsRadioSection<String>(
            title: Text('选择合适的渲染器以获得最佳播放体验'),
            groupValue: renderer.value,
            onChanged: (String? value) {
              if (value != null) {
                GStorage.putSetting<String>(
                    SettingsKeys.androidVideoRenderer, value);
                setState(() {
                  renderer.value = value;
                });
              }
            },
            tiles: androidVideoRenderersList.entries
                .map((e) => SettingsTile<String>.radioTile(
                      title: Text(e.key),
                      description: Text(e.value),
                      radioValue: e.key,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
