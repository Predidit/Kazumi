import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/player/pip_utils.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:kazumi/utils/device.dart';

class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  Box setting = GStorage.setting;
  late double defaultPlaySpeed;
  late double defaultShortcutForwardPlaySpeed;
  late int defaultAspectRatioType;
  late bool hAenable;
  late bool androidEnableOpenSLES;
  late bool androidAutoEnterPIP;
  late bool lowMemoryMode;
  late bool playResume;
  late bool showPlayerError;
  late bool privateMode;
  late bool playerDebugMode;
  late bool playerDisableAnimations;
  late bool forceAdBlocker;
  late bool autoPlayNext;
  late bool backgroundPlayback;
  late bool brightnessVolumeGesture;
  late int playerButtonSkipTime;
  late int playerArrowKeySkipTime;
  late int playerLogLevel;
  final MenuController playerAspectRatioMenuController = MenuController();
  final MenuController playerLogLevelMenuController = MenuController();

  @override
  void initState() {
    super.initState();
    defaultPlaySpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    defaultShortcutForwardPlaySpeed = setting
        .get(SettingBoxKey.defaultShortcutForwardPlaySpeed, defaultValue: 2.0);
    defaultAspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);
    hAenable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    androidEnableOpenSLES =
        setting.get(SettingBoxKey.androidEnableOpenSLES, defaultValue: true);
    androidAutoEnterPIP =
        setting.get(SettingBoxKey.androidAutoEnterPIP, defaultValue: false);
    lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    privateMode = setting.get(SettingBoxKey.privateMode, defaultValue: false);
    showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: true);
    playerDebugMode =
        setting.get(SettingBoxKey.playerDebugMode, defaultValue: false);
    autoPlayNext = setting.get(SettingBoxKey.autoPlayNext, defaultValue: true);
    backgroundPlayback =
        setting.get(SettingBoxKey.backgroundPlayback, defaultValue: false);
    playerDisableAnimations =
        setting.get(SettingBoxKey.playerDisableAnimations, defaultValue: false);
    forceAdBlocker =
        setting.get(SettingBoxKey.forceAdBlocker, defaultValue: false);
    playerLogLevel = setting.get(SettingBoxKey.playerLogLevel, defaultValue: 2);

    brightnessVolumeGesture =
        setting.get(SettingBoxKey.brightnessVolumeGesture, defaultValue: true);

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

  void updateDefaultShortcutForwardPlaySpeed(double speed) {
    setting.put(SettingBoxKey.defaultShortcutForwardPlaySpeed, speed);
    setState(() {
      defaultShortcutForwardPlaySpeed = speed;
    });
  }

  void updatePlayerLogLevel(int level) {
    setting.put(SettingBoxKey.playerLogLevel, level);
    setState(() {
      playerLogLevel = level;
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
        title: 'Top button skip duration', initialValue: playerButtonSkipTime.toString());
    print('New top button skip duration: $newButtonSkipTime');

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
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              final int? newValue = int.tryParse(input);

              if (newValue == null) {
                KazumiDialog.showToast(message: 'Please enter a number');
                return;
              }

              if (newValue <= 0) {
                KazumiDialog.showToast(message: 'Please enter a number greater than 0');
                return;
              }
              // 以新设置的值弹出
              KazumiDialog.dismiss(popWith: newValue);
            },
            child: const Text('OK'),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('Playback settings')),
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
                  title: Text('Hardware decoding', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: hAenable,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await Modular.to.pushNamed('/settings/player/decoder');
                  },
                  title:
                      Text('Hardware decoder', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Only effective when hardware decoding is enabled',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                if (Platform.isAndroid) ...[
                  SettingsTile.navigation(
                    onPressed: (_) async {
                      await Modular.to.pushNamed('/settings/player/renderer');
                    },
                    title:
                        Text('Video renderer', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('Choose the video output method',
                        style: TextStyle(fontFamily: fontFamily)),
                  ),
                ],
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    lowMemoryMode = value ?? !lowMemoryMode;
                    await setting.put(
                        SettingBoxKey.lowMemoryMode, lowMemoryMode);
                    setState(() {});
                  },
                  title:
                      Text('Low memory mode', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Disable advanced caching to reduce memory usage',
                      style: TextStyle(fontFamily: fontFamily)),
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
                    title:
                        Text('Low latency audio', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('Enable OpenSLES audio output to reduce latency',
                        style: TextStyle(fontFamily: fontFamily)),
                    initialValue: androidEnableOpenSLES,
                  ),
                ],
                SettingsTile.navigation(
                  onPressed: (_) async {
                    Modular.to.pushNamed('/settings/player/super');
                  },
                  title: Text('Super resolution', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    backgroundPlayback = value ?? !backgroundPlayback;
                    await setting.put(
                        SettingBoxKey.backgroundPlayback, backgroundPlayback);
                    setState(() {});
                  },
                  title: Text('Background playback', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Keep playing audio when the app is in the background or the screen is off',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: backgroundPlayback,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playResume = value ?? !playResume;
                    await setting.put(SettingBoxKey.playResume, playResume);
                    setState(() {});
                  },
                  title: Text('Auto seek', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Seek to the last playback position',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: playResume,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    autoPlayNext = value ?? !autoPlayNext;
                    await setting.put(SettingBoxKey.autoPlayNext, autoPlayNext);
                    setState(() {});
                  },
                  title: Text('Auto play next', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Automatically play the next episode when the current video finishes',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: autoPlayNext,
                ),
                if (Platform.isAndroid)
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      androidAutoEnterPIP = value ?? !androidAutoEnterPIP;
                      await setting.put(SettingBoxKey.androidAutoEnterPIP,
                          androidAutoEnterPIP);
                      await PipUtils.setAndroidAutoEnterPIPEnabled(
                          androidAutoEnterPIP);
                      setState(() {});
                    },
                    title: Text('Auto enter picture-in-picture',
                        style: TextStyle(fontFamily: fontFamily)),
                    description: Text('Automatically enter picture-in-picture when going to the background',
                        style: TextStyle(fontFamily: fontFamily)),
                    initialValue: androidAutoEnterPIP,
                  ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    forceAdBlocker = value ?? !forceAdBlocker;
                    await setting.put(
                        SettingBoxKey.forceAdBlocker, forceAdBlocker);
                    setState(() {});
                  },
                  title: Text('Ad filtering', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Force-enable HLS ad filtering, ignoring rule settings',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: forceAdBlocker,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playerDisableAnimations = value ?? !playerDisableAnimations;
                    await setting.put(SettingBoxKey.playerDisableAnimations,
                        playerDisableAnimations);
                    setState(() {});
                  },
                  title: Text('Disable animations', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Disable transition animations in the player',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: playerDisableAnimations,
                ),
                if (!isDesktop())
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      brightnessVolumeGesture =
                          value ?? !brightnessVolumeGesture;
                      await setting.put(SettingBoxKey.brightnessVolumeGesture,
                          brightnessVolumeGesture);
                      setState(() {});
                    },
                    title:
                        Text('Swipe gestures', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('Swipe vertically to adjust volume and brightness',
                        style: TextStyle(fontFamily: fontFamily)),
                    initialValue: brightnessVolumeGesture,
                  ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    privateMode = value ?? !privateMode;
                    await setting.put(SettingBoxKey.privateMode, privateMode);
                    setState(() {});
                  },
                  title: Text('Incognito mode', style: TextStyle(fontFamily: fontFamily)),
                  description:
                      Text('Do not keep watch history', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: privateMode,
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    showPlayerError = value ?? !showPlayerError;
                    await setting.put(
                        SettingBoxKey.showPlayerError, showPlayerError);
                    setState(() {});
                  },
                  title: Text('Error notices', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Show player internal error notices',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: showPlayerError,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playerDebugMode = value ?? !playerDebugMode;
                    await setting.put(
                        SettingBoxKey.playerDebugMode, playerDebugMode);
                    setState(() {});
                  },
                  title: Text('Debug mode', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Record player internal logs',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: playerDebugMode,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    if (playerLogLevelMenuController.isOpen) {
                      playerLogLevelMenuController.close();
                    } else {
                      playerLogLevelMenuController.open();
                    }
                  },
                  title: Text('Log level', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Player internal log level',
                      style: TextStyle(fontFamily: fontFamily)),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: playerLogLevelMenuController,
                    builder: (_, __, ___) {
                      return Text(
                        playerLogLevelMap[playerLogLevel] ?? '???',
                      );
                    },
                    menuChildren: [
                      for (final entry in playerLogLevelMap.entries)
                        MenuItemButton(
                          requestFocusOnHover: false,
                          onPressed: () => updatePlayerLogLevel(entry.key),
                          child: Container(
                            height: 48,
                            constraints: BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: entry.key == playerLogLevel
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
            SettingsSection(
              tiles: [
                SettingsTile(
                  title: Text('Default speed', style: TextStyle(fontFamily: fontFamily)),
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
                SettingsTile(
                  title:
                      Text('Default arrow key speed', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: defaultShortcutForwardPlaySpeed,
                    min: 1.25,
                    max: 3,
                    divisions: 7,
                    label: '${defaultShortcutForwardPlaySpeed}x',
                    onChanged: (value) {
                      updateDefaultShortcutForwardPlaySpeed(
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
                    label: '$playerArrowKeySkipTime s',
                    onChanged: (value) {
                      final newArrowKeySkipTime = value.toInt();
                      print('New arrow key skip duration: $newArrowKeySkipTime');

                      if (value != playerArrowKeySkipTime) {
                        setting.put(SettingBoxKey.arrowKeySkipTime,
                            newArrowKeySkipTime);
                        setState(() {
                          playerArrowKeySkipTime = newArrowKeySkipTime;
                        });
                      }
                    },
                  ),
                  title: Text('Skip seconds for the left and right arrow keys',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await updateButtonSkipTime();
                  },
                  title: Text('Skip duration', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Seconds for the top bar skip button',
                      style: TextStyle(fontFamily: fontFamily)),
                  value: Text('$playerButtonSkipTime s',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    if (playerAspectRatioMenuController.isOpen) {
                      playerAspectRatioMenuController.close();
                    } else {
                      playerAspectRatioMenuController.open();
                    }
                  },
                  title:
                      Text('Default aspect ratio', style: TextStyle(fontFamily: fontFamily)),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: playerAspectRatioMenuController,
                    builder: (_, __, ___) {
                      return Text(
                        aspectRatioTypeMap[defaultAspectRatioType] ?? 'Auto',
                        style: TextStyle(fontFamily: fontFamily),
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
                                  fontFamily: fontFamily,
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
