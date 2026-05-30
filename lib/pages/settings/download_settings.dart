import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  Box setting = GStorage.setting;
  late int parallelEpisodes;
  late int parallelSegments;
  late bool downloadDanmaku;

  @override
  void initState() {
    super.initState();
    parallelEpisodes = setting.get(
      SettingBoxKey.downloadParallelEpisodes,
      defaultValue: 2,
    );
    parallelSegments = setting.get(
      SettingBoxKey.downloadParallelSegments,
      defaultValue: 3,
    );
    downloadDanmaku = setting.get(
      SettingBoxKey.downloadDanmaku,
      defaultValue: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(title: Text('Download settings')),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
            title: Text('Concurrency settings', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile(
                title: Text('Simultaneous episode downloads', style: TextStyle(fontFamily: fontFamily)),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download $parallelEpisodes episodes at once',
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                    Slider(
                      value: parallelEpisodes.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$parallelEpisodes',
                      onChanged: (value) {
                        setState(() => parallelEpisodes = value.toInt());
                        setting.put(
                          SettingBoxKey.downloadParallelEpisodes,
                          parallelEpisodes,
                        );
                      },
                    ),
                  ],
                ),
              ),
              SettingsTile(
                title: Text('Segment concurrency', style: TextStyle(fontFamily: fontFamily)),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download $parallelSegments segments per episode at once',
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                    Slider(
                      value: parallelSegments.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$parallelSegments',
                      onChanged: (value) {
                        setState(() => parallelSegments = value.toInt());
                        setting.put(
                          SettingBoxKey.downloadParallelSegments,
                          parallelSegments,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text('Cache settings', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() => downloadDanmaku = value ?? !downloadDanmaku);
                  setting.put(SettingBoxKey.downloadDanmaku, downloadDanmaku);
                },
                title: Text('Cache danmaku', style: TextStyle(fontFamily: fontFamily)),
                description: Text(
                  'Cache danmaku data when downloading videos',
                  style: TextStyle(fontFamily: fontFamily),
                ),
                initialValue: downloadDanmaku,
              ),
            ],
          ),
          SettingsSection(
            title: Text('Notes', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile(
                title: Text('About concurrency settings', style: TextStyle(fontFamily: fontFamily)),
                description: Text(
                  '• Episode concurrency: how many episodes to download at once\n'
                  '• Segment concurrency: how many video segments to download per episode at once\n'
                  '• Higher concurrency can improve speed but may be throttled by the server\n'
                  '• Changes apply to newly started downloads',
                  style: TextStyle(fontFamily: fontFamily),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
