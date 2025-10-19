import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  Box setting = GStorage.setting;
  late double defaultPlaySpeed;
  late int defaultAspectRatioType;
  late bool hAenable;
  late bool androidEnableOpenSLES;
  late bool lowMemoryMode;
  late bool playResume;
  late bool showPlayerError;
  late bool privateMode;
  late bool playerDebugMode;
  late bool playerDisableAnimations;
  late int playerButtonSkipTime;
  late int playerArrowKeySkipTime;
  final MenuController menuController = MenuController();

  @override
  void initState() {
    super.initState();
    defaultPlaySpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    defaultAspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);
    hAenable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    androidEnableOpenSLES =
        setting.get(SettingBoxKey.androidEnableOpenSLES, defaultValue: true);
    lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    privateMode = setting.get(SettingBoxKey.privateMode, defaultValue: false);
    showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: true);
    playerDebugMode =
        setting.get(SettingBoxKey.playerDebugMode, defaultValue: false);
    playerDisableAnimations =
        setting.get(SettingBoxKey.playerDisableAnimations, defaultValue: false);

    playerButtonSkipTime =
        setting.get(SettingBoxKey.buttonSkipTime, defaultValue: 80);
    playerArrowKeySkipTime =
        setting.get(SettingBoxKey.arrowKeySkipTime, defaultValue: 10);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void updateDefaultPlaySpeed(double speed) {
    setting.put(SettingBoxKey.defaultPlaySpeed, speed);
    setState(() {
      defaultPlaySpeed = speed;
    });
  }

  void updateDefaultAspectRatioType(int type) {
    setting.put(SettingBoxKey.defaultAspectRatioType, type);
    setState(() {
      defaultAspectRatioType = type;
    });
  }

  Future<void> updateButtonSkipTime() async {
    final int? newButtonSkipTime = await _showSkipTimeChangeDialog(
        title: '顶部按钮快进时长', initialValue: playerButtonSkipTime.toString());
    print('新设置的顶部按钮快进时长: $newButtonSkipTime');

    if (newButtonSkipTime != null &&
        newButtonSkipTime != playerButtonSkipTime) {
      setting.put(SettingBoxKey.buttonSkipTime, newButtonSkipTime);
      setState(() {
        playerButtonSkipTime = newButtonSkipTime;
      });
    }
  }

  Future<int?> _showSkipTimeChangeDialog(
      {required String title, required String initialValue}) async {
    return KazumiDialog.show<int>(builder: (context) {
      String input = "";
      return AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return TextField(
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // 只允许输入数字
            ],
            decoration: InputDecoration(
              floatingLabelBehavior:
                  FloatingLabelBehavior.never, // 控制label的显示方式
              labelText: initialValue,
            ),
            onChanged: (value) {
              input = value;
            },
          );
        }),
        actions: <Widget>[
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final int? newValue = int.tryParse(input);

              if (newValue == null) {
                KazumiDialog.showToast(message: '请输入数字');
                return;
              }

              if (newValue <= 0) {
                KazumiDialog.showToast(message: '请输入大于0的数字');
                return;
              }
              // 以新设置的值弹出
              KazumiDialog.dismiss(popWith: newValue);
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('播放设置')),
        body: SettingsList(
          maxWidth: 1000,
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
                  onPressed: (_) async {
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
                if (Platform.isAndroid) ...[
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      androidEnableOpenSLES = value ?? !androidEnableOpenSLES;
                      await setting.put(SettingBoxKey.androidEnableOpenSLES,
                          androidEnableOpenSLES);
                      setState(() {});
                    },
                    title: const Text('低延迟音频'),
                    description: const Text('启用OpenSLES音频输出以降低延时'),
                    initialValue: androidEnableOpenSLES,
                  ),
                ],
                SettingsTile.navigation(
                  onPressed: (_) async {
                    Modular.to.pushNamed('/settings/player/super');
                  },
                  title: const Text('超分辨率'),
                ),
              ],
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
                    playerDisableAnimations = value ?? !playerDisableAnimations;
                    await setting.put(SettingBoxKey.playerDisableAnimations,
                        playerDisableAnimations);
                    setState(() {});
                  },
                  title: const Text('禁用动画'),
                  description: const Text('禁用播放器内的过渡动画'),
                  initialValue: playerDisableAnimations,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    showPlayerError = value ?? !showPlayerError;
                    await setting.put(
                        SettingBoxKey.showPlayerError, showPlayerError);
                    setState(() {});
                  },
                  title: const Text('错误提示'),
                  description: const Text('显示播放器内部错误提示'),
                  initialValue: showPlayerError,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playerDebugMode = value ?? !playerDebugMode;
                    await setting.put(
                        SettingBoxKey.playerDebugMode, playerDebugMode);
                    setState(() {});
                  },
                  title: const Text('调试模式'),
                  description: const Text('记录播放器内部日志'),
                  initialValue: playerDebugMode,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    privateMode = value ?? !privateMode;
                    await setting.put(SettingBoxKey.privateMode, privateMode);
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
                SettingsTile(
                  title: const Text('默认倍速'),
                  description: Slider(
                    value: defaultPlaySpeed,
                    min: 0.25,
                    max: 3,
                    divisions: 11,
                    label: '${defaultPlaySpeed}x',
                    onChanged: (value) {
                      updateDefaultPlaySpeed(
                          double.parse(value.toStringAsFixed(2)));
                    },
                  ),
                ),
                SettingsTile.navigation(
                  description: Slider(
                    value: playerArrowKeySkipTime.toDouble(),
                    min: 0,
                    max: 15,
                    divisions: 15,
                    label: '$playerArrowKeySkipTime秒',
                    onChanged: (value) {
                      final newArrowKeySkipTime = value.toInt();
                      print('新设置的方向键快进/快退时长: $newArrowKeySkipTime');

                      if (value != playerArrowKeySkipTime) {
                        setting.put(SettingBoxKey.arrowKeySkipTime,
                            newArrowKeySkipTime);
                        setState(() {
                          playerArrowKeySkipTime = newArrowKeySkipTime;
                        });
                      }
                    },
                  ),
                  title: const Text('左右方向键的快进/快退秒数'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await updateButtonSkipTime();
                  },
                  title: const Text('跳过时长'),
                  description: const Text('顶栏跳过按钮的秒数'),
                  value: Text('$playerButtonSkipTime 秒'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    if (menuController.isOpen) {
                      menuController.close();
                    } else {
                      menuController.open();
                    }
                  },
                  title: const Text('默认视频比例'),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: menuController,
                    builder: (_, __, ___) {
                      return Text(
                        aspectRatioTypeMap[defaultAspectRatioType] ?? '自动',
                      );
                    },
                    menuChildren: [
                      for (final entry in aspectRatioTypeMap.entries)
                        MenuItemButton(
                          requestFocusOnHover: false,
                          onPressed: () =>
                              updateDefaultAspectRatioType(entry.key),
                          child: Container(
                            height: 48,
                            constraints: BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: entry.key == defaultAspectRatioType
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
