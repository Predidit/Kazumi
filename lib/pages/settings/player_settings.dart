import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/player/controller/player_aspect_ratio.dart';
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
  static const double _minPlayerControllerLayerDisappearSeconds = 1;
  static const double _maxPlayerControllerLayerDisappearSeconds = 10;
  static const int _playerControllerLayerDisappearDivisions = 18;

  late double defaultPlaySpeed;
  late double defaultShortcutForwardPlaySpeed;
  late PlayerAspectRatio defaultAspectRatioMode;
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
  late int playerControllerLayerDisappearTime;
  final MenuController playerAspectRatioMenuController = MenuController();
  final MenuController playerLogLevelMenuController = MenuController();

  @override
  void initState() {
    super.initState();
    _loadSettingsFromStorage();
  }

  void _loadSettingsFromStorage() {
    defaultPlaySpeed =
        GStorage.getSetting<double>(SettingsKeys.defaultPlaySpeed);
    defaultShortcutForwardPlaySpeed = GStorage.getSetting<double>(
        SettingsKeys.defaultShortcutForwardPlaySpeed);
    defaultAspectRatioMode = PlayerAspectRatio.fromStorageValue(
      GStorage.getSetting<int>(SettingsKeys.defaultAspectRatioType),
    );
    hAenable = GStorage.getSetting<bool>(SettingsKeys.hAenable);
    androidEnableOpenSLES =
        GStorage.getSetting<bool>(SettingsKeys.androidEnableOpenSLES);
    androidAutoEnterPIP =
        GStorage.getSetting<bool>(SettingsKeys.androidAutoEnterPIP);
    lowMemoryMode = GStorage.getSetting<bool>(SettingsKeys.lowMemoryMode);
    playResume = GStorage.getSetting<bool>(SettingsKeys.playResume);
    privateMode = GStorage.getSetting<bool>(SettingsKeys.privateMode);
    showPlayerError = GStorage.getSetting<bool>(SettingsKeys.showPlayerError);
    playerDebugMode = GStorage.getSetting<bool>(SettingsKeys.playerDebugMode);
    autoPlayNext = GStorage.getSetting<bool>(SettingsKeys.autoPlayNext);
    backgroundPlayback =
        GStorage.getSetting<bool>(SettingsKeys.backgroundPlayback);
    playerDisableAnimations =
        GStorage.getSetting<bool>(SettingsKeys.playerDisableAnimations);
    forceAdBlocker = GStorage.getSetting<bool>(SettingsKeys.forceAdBlocker);
    playerLogLevel = GStorage.getSetting<int>(SettingsKeys.playerLogLevel);

    brightnessVolumeGesture =
        GStorage.getSetting<bool>(SettingsKeys.brightnessVolumeGesture);

    playerButtonSkipTime =
        GStorage.getSetting<int>(SettingsKeys.buttonSkipTime);
    playerArrowKeySkipTime =
        GStorage.getSetting<int>(SettingsKeys.arrowKeySkipTime);

    playerControllerLayerDisappearTime = GStorage.getSetting<int>(
        SettingsKeys.playerControllerLayerDisappearTime);
  }

  Future<void> resetPlayerSettings() async {
    final bool shouldReset = await KazumiDialog.show<bool>(
          builder: (context) => AlertDialog(
            title: const Text('恢复默认播放设置'),
            content: const Text('播放设置、硬件解码器、视频渲染器和超分辨率设置将恢复为默认值。'),
            actions: [
              TextButton(
                onPressed: () => KazumiDialog.dismiss(popWith: false),
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () => KazumiDialog.dismiss(popWith: true),
                child: Text('恢复默认'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldReset) return;

    await GStorage.resetPlayerSettings();
    if (Platform.isAndroid) {
      await PipUtils.setAndroidAutoEnterPIPEnabled(false);
    }
    if (!mounted) return;
    setState(_loadSettingsFromStorage);
    KazumiDialog.showToast(message: '已恢复默认播放设置');
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void updateDefaultPlaySpeed(double speed) {
    GStorage.putSetting<double>(SettingsKeys.defaultPlaySpeed, speed);
    setState(() {
      defaultPlaySpeed = speed;
    });
  }

  void updateDefaultShortcutForwardPlaySpeed(double speed) {
    GStorage.putSetting<double>(
        SettingsKeys.defaultShortcutForwardPlaySpeed, speed);
    setState(() {
      defaultShortcutForwardPlaySpeed = speed;
    });
  }

  void updatePlayerLogLevel(int level) {
    GStorage.putSetting<int>(SettingsKeys.playerLogLevel, level);
    setState(() {
      playerLogLevel = level;
    });
  }

  void updateDefaultAspectRatioMode(PlayerAspectRatio mode) {
    GStorage.putSetting<int>(
      SettingsKeys.defaultAspectRatioType,
      mode.storageValue,
    );
    setState(() {
      defaultAspectRatioMode = mode;
    });
  }

  Future<void> updateButtonSkipTime() async {
    final int? newButtonSkipTime = await _showSkipTimeChangeDialog(
        title: '顶部按钮快进时长', initialValue: playerButtonSkipTime.toString());

    if (newButtonSkipTime != null &&
        newButtonSkipTime != playerButtonSkipTime) {
      GStorage.putSetting<int>(SettingsKeys.buttonSkipTime, newButtonSkipTime);
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

  double get playerControllerLayerDisappearSeconds =>
      (playerControllerLayerDisappearTime / Duration.millisecondsPerSecond)
          .clamp(_minPlayerControllerLayerDisappearSeconds,
              _maxPlayerControllerLayerDisappearSeconds)
          .toDouble();

  String formatPlayerControllerLayerDisappearSeconds(double seconds) {
    if (seconds == seconds.roundToDouble()) {
      return '${seconds.toInt()} 秒';
    }
    return '${seconds.toStringAsFixed(1)} 秒';
  }

  void updatePlayerControllerLayerDisappearSeconds(double seconds) {
    final int newDisappearTime =
        (seconds * Duration.millisecondsPerSecond).round();
    if (newDisappearTime == playerControllerLayerDisappearTime) {
      return;
    }
    GStorage.putSetting<int>(
        SettingsKeys.playerControllerLayerDisappearTime, newDisappearTime);
    setState(() {
      playerControllerLayerDisappearTime = newDisappearTime;
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
        appBar: const SysAppBar(title: Text('播放设置')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    hAenable = value ?? !hAenable;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.hAenable, hAenable);
                    setState(() {});
                  },
                  title: Text('硬件解码', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: hAenable,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await context.pushNamed('/settings/player/decoder');
                  },
                  title:
                      Text('硬件解码器', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('仅在硬件解码启用时生效',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                if (Platform.isAndroid) ...[
                  SettingsTile.navigation(
                    onPressed: (_) async {
                      await context.pushNamed('/settings/player/renderer');
                    },
                    title:
                        Text('视频渲染器', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('选择视频输出方式',
                        style: TextStyle(fontFamily: fontFamily)),
                  ),
                ],
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    lowMemoryMode = value ?? !lowMemoryMode;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.lowMemoryMode, lowMemoryMode);
                    setState(() {});
                  },
                  title:
                      Text('低内存模式', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('禁用高级缓存以减少内存占用',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: lowMemoryMode,
                ),
                if (Platform.isAndroid) ...[
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      androidEnableOpenSLES = value ?? !androidEnableOpenSLES;
                      await GStorage.putSetting<bool>(
                          SettingsKeys.androidEnableOpenSLES,
                          androidEnableOpenSLES);
                      setState(() {});
                    },
                    title:
                        Text('低延迟音频', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('启用OpenSLES音频输出以降低延时',
                        style: TextStyle(fontFamily: fontFamily)),
                    initialValue: androidEnableOpenSLES,
                  ),
                ],
                SettingsTile.navigation(
                  onPressed: (_) async {
                    context.pushNamed('/settings/player/super');
                  },
                  title: Text('超分辨率', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    backgroundPlayback = value ?? !backgroundPlayback;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.backgroundPlayback, backgroundPlayback);
                    setState(() {});
                  },
                  title: Text('后台播放', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('应用退到后台或熄屏时继续播放音频',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: backgroundPlayback,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playResume = value ?? !playResume;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.playResume, playResume);
                    setState(() {});
                  },
                  title: Text('自动跳转', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('跳转到上次播放位置',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: playResume,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    autoPlayNext = value ?? !autoPlayNext;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.autoPlayNext, autoPlayNext);
                    setState(() {});
                  },
                  title: Text('自动连播', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('当前视频播放完毕后自动播放下一集',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: autoPlayNext,
                ),
                if (Platform.isAndroid)
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      androidAutoEnterPIP = value ?? !androidAutoEnterPIP;
                      await GStorage.putSetting<bool>(
                          SettingsKeys.androidAutoEnterPIP,
                          androidAutoEnterPIP);
                      await PipUtils.setAndroidAutoEnterPIPEnabled(
                          androidAutoEnterPIP);
                      setState(() {});
                    },
                    title: Text('自动进入画中画',
                        style: TextStyle(fontFamily: fontFamily)),
                    description: Text('切到后台时，自动进入画中画',
                        style: TextStyle(fontFamily: fontFamily)),
                    initialValue: androidAutoEnterPIP,
                  ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    forceAdBlocker = value ?? !forceAdBlocker;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.forceAdBlocker, forceAdBlocker);
                    setState(() {});
                  },
                  title: Text('广告过滤', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('强制启用HLS广告过滤，忽略规则设置',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: forceAdBlocker,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playerDisableAnimations = value ?? !playerDisableAnimations;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.playerDisableAnimations,
                        playerDisableAnimations);
                    setState(() {});
                  },
                  title: Text('禁用动画', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('禁用播放器内的过渡动画',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: playerDisableAnimations,
                ),
                if (!isDesktop())
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      brightnessVolumeGesture =
                          value ?? !brightnessVolumeGesture;
                      await GStorage.putSetting<bool>(
                          SettingsKeys.brightnessVolumeGesture,
                          brightnessVolumeGesture);
                      setState(() {});
                    },
                    title:
                        Text('滑动手势', style: TextStyle(fontFamily: fontFamily)),
                    description: Text('竖向滑动调节音量和亮度',
                        style: TextStyle(fontFamily: fontFamily)),
                    initialValue: brightnessVolumeGesture,
                  ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    privateMode = value ?? !privateMode;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.privateMode, privateMode);
                    setState(() {});
                  },
                  title: Text('隐身模式', style: TextStyle(fontFamily: fontFamily)),
                  description:
                      Text('不保留观看记录', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: privateMode,
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    showPlayerError = value ?? !showPlayerError;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.showPlayerError, showPlayerError);
                    setState(() {});
                  },
                  title: Text('错误提示', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('显示播放器内部错误提示',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: showPlayerError,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    playerDebugMode = value ?? !playerDebugMode;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.playerDebugMode, playerDebugMode);
                    setState(() {});
                  },
                  title: Text('调试模式', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('记录播放器内部日志',
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
                  title: Text('日志等级', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('播放器内部日志等级',
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
                  title: Text('默认倍速', style: TextStyle(fontFamily: fontFamily)),
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
                  title: Text('默认方向键/长按倍速',
                      style: TextStyle(fontFamily: fontFamily)),
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
                    label: '$playerArrowKeySkipTime秒',
                    onChanged: (value) {
                      final newArrowKeySkipTime = value.toInt();

                      if (value != playerArrowKeySkipTime) {
                        GStorage.putSetting<int>(
                            SettingsKeys.arrowKeySkipTime, newArrowKeySkipTime);
                        setState(() {
                          playerArrowKeySkipTime = newArrowKeySkipTime;
                        });
                      }
                    },
                  ),
                  title: Text('左右方向键的快进/快退秒数',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await updateButtonSkipTime();
                  },
                  title: Text('跳过时长', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('顶栏跳过按钮的秒数',
                      style: TextStyle(fontFamily: fontFamily)),
                  value: Text('$playerButtonSkipTime 秒',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile(
                  title: Text(
                      '播放控制器消失时间：${formatPlayerControllerLayerDisappearSeconds(playerControllerLayerDisappearSeconds)}',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: playerControllerLayerDisappearSeconds,
                    min: _minPlayerControllerLayerDisappearSeconds,
                    max: _maxPlayerControllerLayerDisappearSeconds,
                    divisions: _playerControllerLayerDisappearDivisions,
                    label: formatPlayerControllerLayerDisappearSeconds(
                        playerControllerLayerDisappearSeconds),
                    onChanged: updatePlayerControllerLayerDisappearSeconds,
                  ),
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
                      Text('默认视频比例', style: TextStyle(fontFamily: fontFamily)),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: playerAspectRatioMenuController,
                    builder: (_, __, ___) {
                      return Text(
                        defaultAspectRatioMode.label,
                        style: TextStyle(fontFamily: fontFamily),
                      );
                    },
                    menuChildren: [
                      for (final aspectRatioMode in PlayerAspectRatio.values)
                        MenuItemButton(
                          requestFocusOnHover: false,
                          onPressed: () =>
                              updateDefaultAspectRatioMode(aspectRatioMode),
                          child: Container(
                            height: 48,
                            constraints: BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                aspectRatioMode.label,
                                style: TextStyle(
                                  color: aspectRatioMode ==
                                          defaultAspectRatioMode
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
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) => resetPlayerSettings(),
                  title:
                      Text('恢复默认设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('将播放相关设置恢复为默认值',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
