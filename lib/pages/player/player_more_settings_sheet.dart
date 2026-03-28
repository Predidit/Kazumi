import 'dart:io';

import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/pip_utils.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/timed_shutdown_service.dart';
import 'package:kazumi/utils/utils.dart';

class PlayerMoreSettingsSheet extends StatefulWidget {
  const PlayerMoreSettingsSheet({
    super.key,
    required this.playerController,
    required this.isSidebar,
    required this.showPictureInPictureAction,
    required this.onSuperResolutionChange,
    required this.onTimedShutdownExpired,
    required this.onShowDanmakuSwitch,
    required this.onShowVideoInfo,
    required this.onRemoteCast,
    required this.onExternalPlay,
    required this.onShowSyncPlayRoomCreateDialog,
    required this.onShowSyncPlayEndPointSwitchDialog,
    this.onCreateSyncPlayRoom,
    this.onShowTimedShutdownCustomPanel,
    this.onPlaybackSpeedChange,
    this.onRequestCloseSidebar,
  });

  final PlayerController playerController;
  final bool isSidebar;
  final bool showPictureInPictureAction;
  final Future<void> Function(int shaderIndex) onSuperResolutionChange;
  final VoidCallback onTimedShutdownExpired;
  final VoidCallback onShowDanmakuSwitch;
  final VoidCallback onShowVideoInfo;
  final VoidCallback onRemoteCast;
  final VoidCallback onExternalPlay;
  final VoidCallback onShowSyncPlayRoomCreateDialog;
  final VoidCallback onShowSyncPlayEndPointSwitchDialog;
  final Future<void> Function(String room, String username)?
      onCreateSyncPlayRoom;
  final VoidCallback? onShowTimedShutdownCustomPanel;
  final Future<void> Function(double speed)? onPlaybackSpeedChange;
  final VoidCallback? onRequestCloseSidebar;

  @override
  State<PlayerMoreSettingsSheet> createState() =>
      _PlayerMoreSettingsSheetState();
}

class _PlayerMoreSettingsSheetState extends State<PlayerMoreSettingsSheet> {
  static const List<double> _quickSpeeds = [1.0, 1.5, 2.0, 3.0];
  static const int _timedShutdownCustom = 999;
  static const List<int> _timedShutdownPresetMinutes = [0, 15, 30, 60];
  static const double _quickActionSpacing = 6;
  static const double _quickActionItemHeight = 64;
  static const double _quickActionRowHeight = _quickActionItemHeight;

  final GlobalKey<FormState> _joinRoomFormKey = GlobalKey<FormState>();
  final TextEditingController _joinRoomController = TextEditingController();
  final TextEditingController _joinUsernameController = TextEditingController();
  final VideoPageController _videoPageController =
      Modular.get<VideoPageController>();

  bool _showJoinRoomTile = false;
  bool _joiningSyncPlayRoom = false;

  @override
  void dispose() {
    _joinRoomController.dispose();
    _joinUsernameController.dispose();
    super.dispose();
  }

  Future<void> _applyPlaybackSpeed(double speed) {
    final callback = widget.onPlaybackSpeedChange ??
        widget.playerController.setPlaybackSpeed;
    return callback(speed);
  }

  bool get _showBrightnessSlider =>
      !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

  Future<void> _applyBrightness(double value) async {
    final double brightness = value.clamp(0.0, 1.0);
    widget.playerController.brightness = brightness;
    try {
      await ScreenBrightnessPlatform.instance
          .setApplicationScreenBrightness(brightness);
    } catch (_) {}
  }

  Future<void> _togglePictureInPicture() async {
    if (Utils.isDesktop()) {
      if (_videoPageController.isPip) {
        await PipUtils.exitDesktopPIPWindow();
      } else {
        await PipUtils.enterDesktopPIPWindow();
      }
      _videoPageController.isPip = !_videoPageController.isPip;
      return;
    }

    if (!Platform.isAndroid) {
      return;
    }

    final bool supported = await PipUtils.isAndroidPIPSupported();
    if (!supported) {
      KazumiDialog.showToast(message: '当前设备不支持画中画');
      return;
    }
    await PipUtils.updateAndroidPIPActions(
      playing: widget.playerController.playing,
      danmakuEnabled: widget.playerController.danmakuOn,
    );
    final bool entered = await PipUtils.enterAndroidPIPWindow();
    if (!entered) {
      KazumiDialog.showToast(message: '进入画中画失败');
    }
  }

  int _timedShutdownSelection(int setMinutes) {
    if (!_timedShutdownPresetMinutes.contains(setMinutes)) {
      return _timedShutdownCustom;
    }
    return setMinutes;
  }

  void _onTimedShutdownSelectionChanged(int selection) {
    if (selection == _timedShutdownCustom) {
      if (widget.isSidebar && widget.onShowTimedShutdownCustomPanel != null) {
        widget.onShowTimedShutdownCustomPanel!.call();
        return;
      }
      TimedShutdownService.showCustomTimerDialog(
        onExpired: widget.onTimedShutdownExpired,
      );
      return;
    }

    if (selection == 0) {
      TimedShutdownService().cancel();
      return;
    }

    TimedShutdownService().start(
      selection,
      onExpired: widget.onTimedShutdownExpired,
    );
    KazumiDialog.showToast(
      message:
          '已设置 ${TimedShutdownService().formatMinutesToDisplay(selection)} 后定时关闭',
    );
  }

  Future<void> _submitJoinRoom() async {
    if (_joiningSyncPlayRoom) {
      return;
    }

    final formState = _joinRoomFormKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final String room = _joinRoomController.text.trim();
    final String username = _joinUsernameController.text.trim();

    if (widget.onCreateSyncPlayRoom == null) {
      widget.onShowSyncPlayRoomCreateDialog();
      return;
    }

    setState(() {
      _joiningSyncPlayRoom = true;
    });
    try {
      await widget.onCreateSyncPlayRoom!(room, username);
      if (!mounted) {
        return;
      }
      if (widget.playerController.syncplayRoom.trim().isNotEmpty) {
        _joinRoomController.clear();
        _joinUsernameController.clear();
        setState(() {
          _showJoinRoomTile = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _joiningSyncPlayRoom = false;
        });
      }
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        onPressed();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontFamily = theme.textTheme.bodyMedium?.fontFamily;
    final panelTheme = widget.isSidebar
        ? theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              surfaceContainerLowest: const Color(0xCC000000),
              surfaceContainerHigh: const Color(0xCC000000),
            ),
          )
        : theme;

    return SafeArea(
      left: false,
      top: false,
      bottom: false,
      child: Theme(
        data: panelTheme,
        child: Observer(
          builder: (context) {
            final playerController = widget.playerController;
            int speedIndex =
                defaultPlaySpeedList.indexOf(playerController.playerSpeed);
            if (speedIndex < 0) {
              speedIndex = defaultPlaySpeedList.indexOf(1.0);
              if (speedIndex < 0) {
                speedIndex = 0;
              }
            }
            final double currentSpeed = defaultPlaySpeedList[speedIndex];
            final bool inSyncPlayRoom =
                playerController.syncplayRoom.trim().isNotEmpty;
            final double sliderVolume =
                playerController.volume.clamp(0.0, 100.0).toDouble();
            final double sliderBrightness =
                playerController.brightness.clamp(0.0, 1.0).toDouble();

            final String selectedSyncPlayEndPoint = (GStorage.setting.get(
                  SettingBoxKey.syncPlayEndPoint,
                  defaultValue: defaultSyncPlayEndPoint,
                ) as String?) ??
                defaultSyncPlayEndPoint;
            final List<String> syncPlayEndPoints =
                List<String>.from(defaultSyncPlayEndPoints);
            if (!syncPlayEndPoints.contains(selectedSyncPlayEndPoint)) {
              syncPlayEndPoints.add(selectedSyncPlayEndPoint);
            }

            return SettingsList(
              sections: [
                SettingsSection(
                  tiles: [
                    CustomSettingsTile(
                      child: (info) {
                        return ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(info.isTopTile ? 20 : 3),
                            bottom: Radius.circular(info.isBottomTile ? 20 : 3),
                          ),
                          child: Material(
                            color: widget.isSidebar
                                ? const Color(0xCC000000)
                                : theme.brightness == Brightness.dark
                                    ? theme.colorScheme.surfaceContainerHigh
                                    : theme.colorScheme.surfaceContainerLowest,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: SizedBox(
                                height: _quickActionRowHeight,
                                child: Row(
                                  children: [
                                    ...[
                                      (
                                        icon: Icons.info_outline_rounded,
                                        label: '视频详情',
                                        onPressed: widget.onShowVideoInfo,
                                      ),
                                      if (widget.showPictureInPictureAction)
                                        (
                                          icon:
                                              Icons.picture_in_picture_rounded,
                                          label: '画中画',
                                          onPressed: () {
                                            if (widget.isSidebar) {
                                              widget.onRequestCloseSidebar
                                                  ?.call();
                                            }
                                            _togglePictureInPicture();
                                          },
                                        ),
                                      (
                                        icon: Icons.cast_rounded,
                                        label: '远程投屏',
                                        onPressed: () {
                                          if (widget.isSidebar) {
                                            widget.onRequestCloseSidebar
                                                ?.call();
                                          }
                                          widget.onRemoteCast();
                                        },
                                      ),
                                      (
                                        icon: Icons.open_in_new_rounded,
                                        label: '外部播放',
                                        onPressed: () {
                                          if (widget.isSidebar) {
                                            widget.onRequestCloseSidebar
                                                ?.call();
                                          }
                                          widget.onExternalPlay();
                                        },
                                      ),
                                    ].asMap().entries.expand((entry) {
                                      final int index = entry.key;
                                      final item = entry.value;
                                      return <Widget>[
                                        if (index > 0)
                                          const SizedBox(
                                              width: _quickActionSpacing),
                                        Expanded(
                                          child: _buildQuickActionButton(
                                            icon: item.icon,
                                            label: item.label,
                                            onPressed: item.onPressed,
                                          ),
                                        ),
                                      ];
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  title: Text('画面设置', style: TextStyle(fontFamily: fontFamily)),
                  tiles: [
                    SettingsTile(
                      title: Text(
                        '倍速 ${playerController.playerSpeed}x',
                        style: TextStyle(fontFamily: fontFamily),
                      ),
                      description: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Slider(
                            min: 0,
                            max: (defaultPlaySpeedList.length - 1).toDouble(),
                            divisions: defaultPlaySpeedList.length - 1,
                            value: speedIndex.toDouble(),
                            label: '${currentSpeed.toStringAsFixed(2)}x',
                            onChanged: (value) {
                              final int index = value.round();
                              final double speed = defaultPlaySpeedList[index];
                              if (speed == playerController.playerSpeed) {
                                return;
                              }
                              _applyPlaybackSpeed(speed);
                            },
                          ),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 8,
                            children: _quickSpeeds.map((speed) {
                              final bool isSelected =
                                  (playerController.playerSpeed - speed).abs() <
                                      0.001;
                              return ActionChip(
                                label: Text('${speed.toStringAsFixed(1)}x'),
                                onPressed: () {
                                  if (isSelected) {
                                    return;
                                  }
                                  _applyPlaybackSpeed(speed);
                                },
                                backgroundColor: isSelected
                                    ? theme.colorScheme.primaryContainer
                                    : null,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : null,
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                    if (_showBrightnessSlider)
                      SettingsTile(
                        title: Text(
                          '亮度 ${(sliderBrightness * 100).toInt()}%',
                          style: TextStyle(fontFamily: fontFamily),
                        ),
                        description: Slider(
                          min: 0.0,
                          max: 1.0,
                          value: sliderBrightness,
                          label: '${(sliderBrightness * 100).toInt()}%',
                          onChanged: _applyBrightness,
                        ),
                      ),
                    SettingsTile(
                      title: Text(
                        '音量 ${sliderVolume.toInt()}%',
                        style: TextStyle(fontFamily: fontFamily),
                      ),
                      description: Slider(
                        min: 0.0,
                        max: 100.0,
                        value: sliderVolume,
                        label: '${sliderVolume.toInt()}%',
                        onChanged: playerController.setVolume,
                      ),
                    ),
                    SettingsTile(
                      title: Text('视频比例',
                          style: TextStyle(fontFamily: fontFamily)),
                      trailing: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: aspectRatioTypeMap.entries
                            .map(
                              (entry) => ButtonSegment<int>(
                                value: entry.key,
                                label: Text(entry.value),
                              ),
                            )
                            .toList(growable: false),
                        selected: <int>{playerController.aspectRatioType},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) {
                            return;
                          }
                          playerController.aspectRatioType = selection.first;
                        },
                      ),
                    ),
                    SettingsTile(
                      title: Text('超分辨率',
                          style: TextStyle(fontFamily: fontFamily)),
                      trailing: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(value: 1, label: Text('关闭')),
                          ButtonSegment<int>(value: 2, label: Text('效率')),
                          ButtonSegment<int>(value: 3, label: Text('质量')),
                        ],
                        selected: <int>{playerController.superResolutionType},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) {
                            return;
                          }
                          final int shaderIndex = selection.first;
                          if (shaderIndex ==
                              playerController.superResolutionType) {
                            return;
                          }
                          widget.onSuperResolutionChange(shaderIndex);
                        },
                      ),
                    ),
                    SettingsTile(
                      title: ValueListenableBuilder<int>(
                        valueListenable:
                            TimedShutdownService().remainingSecondsNotifier,
                        builder: (context, remainingSeconds, _) {
                          final String titleText = remainingSeconds > 0
                              ? '定时关闭（剩余 ${TimedShutdownService().formatRemainingTime()}）'
                              : '定时关闭';
                          return Text(
                            titleText,
                            style: TextStyle(fontFamily: fontFamily),
                          );
                        },
                      ),
                      description: ValueListenableBuilder<int>(
                        valueListenable:
                            TimedShutdownService().setMinutesNotifier,
                        builder: (context, setMinutes, _) {
                          final int selectedTimedShutdownValue =
                              _timedShutdownSelection(setMinutes);
                          return Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<int>(
                                  showSelectedIcon: false,
                                  segments: const <ButtonSegment<int>>[
                                    ButtonSegment<int>(
                                        value: 0, label: Text('关闭')),
                                    ButtonSegment<int>(
                                        value: 15, label: Text('15分')),
                                    ButtonSegment<int>(
                                        value: 30, label: Text('30分')),
                                    ButtonSegment<int>(
                                        value: 60, label: Text('60分')),
                                    ButtonSegment<int>(
                                      value: _timedShutdownCustom,
                                      label: Text('更多'),
                                    ),
                                  ],
                                  selected: <int>{selectedTimedShutdownValue},
                                  onSelectionChanged: (selection) {
                                    if (selection.isEmpty) {
                                      return;
                                    }
                                    _onTimedShutdownSelectionChanged(
                                      selection.first,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  title: Text('一起看', style: TextStyle(fontFamily: fontFamily)),
                  tiles: [
                    SettingsTile(
                      title: Text('当前房间',
                          style: TextStyle(fontFamily: fontFamily)),
                      onPressed: inSyncPlayRoom
                          ? null
                          : (_) {
                              setState(() {
                                _showJoinRoomTile = !_showJoinRoomTile;
                              });
                            },
                      description: Text(
                        inSyncPlayRoom
                            ? playerController.syncplayRoom
                            : '未加入房间',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          color: Theme.of(context).colorScheme.onSurface
                        ),
                      ),
                      trailing: inSyncPlayRoom
                          ? FilledButton.tonal(
                              onPressed: () async {
                                await playerController.exitSyncPlayRoom();
                              },
                              child: Text(
                                '退出房间',
                                style: TextStyle(fontFamily: fontFamily),
                              ),
                            )
                          : Icon(
                              _showJoinRoomTile
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                    ),
                    if (!inSyncPlayRoom && _showJoinRoomTile)
                      SettingsTile(
                        title: Text(
                          '加入房间',
                          style: TextStyle(
                            fontFamily: fontFamily,
                          ),
                        ),
                        description: Form(
                          key: _joinRoomFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _joinRoomController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  labelText: '房间号',
                                  hintText: '6-10位数字',
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface
                                  ),
                                  hintStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请输入房间号';
                                  }
                                  final regex = RegExp(r'^[0-9]{6,10}$');
                                  if (!regex.hasMatch(value)) {
                                    return '房间号需要6到10位数字';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _joinUsernameController,
                                decoration: InputDecoration(
                                  labelText: '用户名',
                                  hintText: '4-12位英文字母',
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface
                                  ),
                                  hintStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请输入用户名';
                                  }
                                  final regex = RegExp(r'^[a-zA-Z]{4,12}$');
                                  if (!regex.hasMatch(value)) {
                                    return '用户名必须为4到12位英文字母';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  onPressed: _joiningSyncPlayRoom
                                      ? null
                                      : _submitJoinRoom,
                                  icon: _joiningSyncPlayRoom
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Theme.of(context).colorScheme.onSurface
                                          ),
                                        )
                                      : const Icon(Icons.login_rounded),
                                  label: Text(
                                    _joiningSyncPlayRoom ? '连接中...' : '加入房间',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SettingsTile(
                      title:
                          Text('服务器', style: TextStyle(fontFamily: fontFamily)),
                      description: Text(
                        '网络延迟 ${playerController.syncplayClientRtt}ms',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: SizedBox(
                        width: 180,
                        child: DropdownButtonHideUnderline(
                          child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                  ),
                                  child: _buildSyncPlayEndPointDropdown(
                                    fontFamily: fontFamily,
                                    dropdownValue: selectedSyncPlayEndPoint,
                                    syncPlayEndPoints: syncPlayEndPoints,
                                    isSidebar: true,
                                  ),
                                )
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSyncPlayEndPointDropdown({
    required String? fontFamily,
    required String dropdownValue,
    required List<String> syncPlayEndPoints,
    required bool isSidebar,
  }) {
    const String customOption = '自定义服务器';
    final List<String> options = <String>[...syncPlayEndPoints, customOption];
    final String value = options.contains(dropdownValue)
        ? dropdownValue
        : defaultSyncPlayEndPoint;

    Future<void> handleChanged(String? selected) async {
      if (selected == null || selected == value) {
        return;
      }
      if (widget.playerController.syncplayController != null) {
        KazumiDialog.showToast(message: 'SyncPlay: 请先退出当前房间再切换服务器');
        return;
      }

      if (selected == customOption) {
        final TextEditingController serverTextController =
            TextEditingController();
        KazumiDialog.show(
          builder: (context) {
            return AlertDialog(
              title: const Text('设置自定义服务器'),
              content: TextField(
                controller: serverTextController,
                decoration: const InputDecoration(hintText: '请输入服务器地址'),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: KazumiDialog.dismiss,
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final String customEndpoint =
                        serverTextController.text.trim();
                    if (customEndpoint.isEmpty) {
                      KazumiDialog.showToast(message: '服务器地址不能为空或重复');
                      return;
                    }
                    KazumiDialog.dismiss();
                    GStorage.setting.put(
                      SettingBoxKey.syncPlayEndPoint,
                      customEndpoint,
                    );
                    setState(() {});
                    KazumiDialog.showToast(message: '服务器已切换为 $customEndpoint');
                  },
                  child: const Text('确认'),
                ),
              ],
            );
          },
        );
        return;
      }

      GStorage.setting.put(SettingBoxKey.syncPlayEndPoint, selected);
      setState(() {});
      KazumiDialog.showToast(message: '服务器已切换为 $selected');
    }

    return DropdownButton<String>(
      isExpanded: true,
      value: value,
      dropdownColor: Theme.of(context).colorScheme.surface,
      iconEnabledColor: Theme.of(context).colorScheme.onSurface,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      items: options
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        handleChanged(value);
      },
    );
  }
}
