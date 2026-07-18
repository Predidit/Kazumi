import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/design_system/kazumi_settings.dart';

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
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SysAppBar(
        title: Text('视频渲染器'),
      ),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
            title: Text('选择合适的渲染器以获得最佳播放体验',
                style: TextStyle(fontFamily: fontFamily)),
            tiles: androidVideoRenderersList.entries
                .map((e) => SettingsTile<String>.radioTile(
                      title:
                          Text(e.key, style: TextStyle(fontFamily: fontFamily)),
                      description: Text(e.value,
                          style: TextStyle(fontFamily: fontFamily)),
                      radioValue: e.key,
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
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
