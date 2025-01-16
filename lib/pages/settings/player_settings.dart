import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  Box setting = GStorage.setting;
  late double defaultPlaySpeed;
  late bool hAenable;
  late bool lowMemoryMode;
  late bool playResume;
  late bool privateMode;

  @override
  void initState() {
    super.initState();
    defaultPlaySpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    hAenable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    privateMode = setting.get(SettingBoxKey.privateMode, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    // Navigator.of(context).pop();
  }

  void updateDefaultPlaySpeed(double speed) {
    setting.put(SettingBoxKey.defaultPlaySpeed, speed);
    setState(() {
      defaultPlaySpeed = speed;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('播放设置')),
        body: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: SettingsList(
              sections: [
                SettingsSection(
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        hAenable = value ?? !hAenable;
                        await setting.put(SettingBoxKey.hAenable, hAenable);
                        setState(() {});
                      },
                      title: const Text('硬件解码'),
                      initialValue: hAenable,
                    ),
                    SettingsTile.navigation(
                      onPressed: (value) async {
                        await Modular.to.pushNamed('/settings/player/decoder');
                      },
                      title: const Text('硬件解码器'),
                      description: const Text('仅在硬件解码启用时生效'),
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        lowMemoryMode = value ?? !lowMemoryMode;
                        await setting.put(
                            SettingBoxKey.lowMemoryMode, lowMemoryMode);
                        setState(() {});
                      },
                      title: const Text('低内存模式'),
                      description: const Text('禁用高级缓存以减少内存占用'),
                      initialValue: lowMemoryMode,
                    ),
                    SettingsTile.navigation(
                      onPressed: (_) async {
                        Modular.to.pushNamed('/settings/player/super');
                      },
                      title: const Text('超分辨率'),
                    ),
                  ],
                  bottomInfo: const Text('超分辨率仅适用桌面平台'),
                ),
                SettingsSection(
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        playResume = value ?? !playResume;
                        await setting.put(SettingBoxKey.playResume, playResume);
                        setState(() {});
                      },
                      title: const Text('自动跳转'),
                      description: const Text('跳转到上次播放位置'),
                      initialValue: playResume,
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        privateMode = value ?? !privateMode;
                        await setting.put(
                            SettingBoxKey.privateMode, privateMode);
                        setState(() {});
                      },
                      title: const Text('隐身模式'),
                      description: const Text('不保留观看记录'),
                      initialValue: privateMode,
                    ),
                  ],
                ),
                SettingsSection(
                  tiles: [
                    SettingsTile.navigation(
                      onPressed: (_) async {
                        KazumiDialog.show(builder: (context) {
                          return AlertDialog(
                            title: const Text('默认倍速'),
                            content: StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              final List<double> playSpeedList;
                              playSpeedList = defaultPlaySpeedList;
                              return Wrap(
                                spacing: 8,
                                runSpacing: Utils.isDesktop() ? 8 : 0,
                                children: [
                                  for (final double i
                                      in playSpeedList) ...<Widget>[
                                    if (i == defaultPlaySpeed) ...<Widget>[
                                      FilledButton(
                                        onPressed: () async {
                                          updateDefaultPlaySpeed(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ] else ...[
                                      FilledButton.tonal(
                                        onPressed: () async {
                                          updateDefaultPlaySpeed(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ]
                                  ]
                                ],
                              );
                            }),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => KazumiDialog.dismiss(),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  updateDefaultPlaySpeed(1.0);
                                  KazumiDialog.dismiss();
                                },
                                child: const Text('默认设置'),
                              ),
                            ],
                          );
                        });
                      },
                      title: const Text('默认倍速'),
                      value: Text('$defaultPlaySpeed'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
