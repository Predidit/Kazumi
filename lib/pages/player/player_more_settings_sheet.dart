import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/timed_shutdown_service.dart';

class PlayerMoreSettingsSheet extends StatelessWidget {
  const PlayerMoreSettingsSheet({
    super.key,
    required this.playerController,
    required this.isSidebar,
    required this.showPictureInPictureAction,
    required this.onSuperResolutionChange,
    required this.onTimedShutdownExpired,
    required this.onShowDanmakuSwitch,
    required this.onTogglePictureInPicture,
    required this.onShowVideoInfo,
    required this.onRemoteCast,
    required this.onExternalPlay,
    required this.onShowSyncPlayRoomCreateDialog,
    required this.onShowSyncPlayEndPointSwitchDialog,
    this.onPlaybackSpeedChange,
    this.onRequestCloseSidebar,
  });

  final PlayerController playerController;
  final bool isSidebar;
  final bool showPictureInPictureAction;
  final Future<void> Function(int shaderIndex) onSuperResolutionChange;
  final VoidCallback onTimedShutdownExpired;
  final VoidCallback onShowDanmakuSwitch;
  final VoidCallback onTogglePictureInPicture;
  final VoidCallback onShowVideoInfo;
  final VoidCallback onRemoteCast;
  final VoidCallback onExternalPlay;
  final VoidCallback onShowSyncPlayRoomCreateDialog;
  final VoidCallback onShowSyncPlayEndPointSwitchDialog;
  final Future<void> Function(double speed)? onPlaybackSpeedChange;
  final VoidCallback? onRequestCloseSidebar;

  static const List<double> _quickSpeeds = [1.0, 1.5, 2.0, 3.0];
  static const int _timedShutdownCustom = 999;
  static const List<int> _timedShutdownPresetMinutes = [0, 15, 30, 60];
  static const double _quickActionSpacing = 6;
  static const double _quickActionItemHeight = 64;
  static const double _quickActionRowHeight = _quickActionItemHeight;

  Future<void> _applyPlaybackSpeed(double speed) {
    final callback = onPlaybackSpeedChange ?? playerController.setPlaybackSpeed;
    return callback(speed);
  }

  int _nearestSpeedIndex(double speed) {
    int nearestIndex = 0;
    double minDiff = (defaultPlaySpeedList.first - speed).abs();
    for (int i = 1; i < defaultPlaySpeedList.length; i++) {
      final double diff = (defaultPlaySpeedList[i] - speed).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  int _timedShutdownSelection(int setMinutes) {
    if (!_timedShutdownPresetMinutes.contains(setMinutes)) {
      return _timedShutdownCustom;
    }
    return setMinutes;
  }

  void _onTimedShutdownSelectionChanged(int selection) {
    if (selection == _timedShutdownCustom) {
      TimedShutdownService.showCustomTimerDialog(
        onExpired: onTimedShutdownExpired,
      );
      return;
    }

    if (selection == 0) {
      TimedShutdownService().cancel();
      return;
    }

    TimedShutdownService().start(
      selection,
      onExpired: onTimedShutdownExpired,
    );
    KazumiDialog.showToast(
      message:
          '已设置 ${TimedShutdownService().formatMinutesToDisplay(selection)} 后定时关闭',
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (isSidebar) {
          onRequestCloseSidebar?.call();
        }
        onPressed();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: isSidebar ? Colors.white : null),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isSidebar ? Colors.white : null),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final theme = Theme.of(context);
    final panelTheme = isSidebar
        ? theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              surfaceContainerLowest: Color(0xCC000000),
              surfaceContainerHigh: Color(0xCC000000),
            ),
          )
        : theme;

    return SafeArea(
      bottom: false,
      child: Theme(
        data: panelTheme,
        child: Observer(
          builder: (context) {
            final int speedIndex =
                _nearestSpeedIndex(playerController.playerSpeed);
            final double currentSpeed = defaultPlaySpeedList[speedIndex];
            final bool inSyncPlayRoom =
                playerController.syncplayRoom.trim().isNotEmpty;

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
                            color: isSidebar
                                ? Color(0xCC000000)
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
                                        onPressed: onShowVideoInfo,
                                      ),
                                      if (showPictureInPictureAction)
                                        (
                                          icon:
                                              Icons.picture_in_picture_rounded,
                                          label: '画中画',
                                          onPressed: onTogglePictureInPicture,
                                        ),
                                      (
                                        icon: Icons.cast_rounded,
                                        label: '远程投屏',
                                        onPressed: onRemoteCast,
                                      ),
                                      (
                                        icon: Icons.open_in_new_rounded,
                                        label: '外部播放',
                                        onPressed: onExternalPlay,
                                      ),
                                    ].asMap().entries.expand((entry) {
                                      final index = entry.key;
                                      final item = entry.value;
                                      return <Widget>[
                                        if (index > 0)
                                          const SizedBox(
                                            width: _quickActionSpacing,
                                          ),
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
                        '倍速 ${playerController.playerSpeed.toStringAsFixed(2)}x',
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
                          onSuperResolutionChange(shaderIndex);
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
                      description: Text(
                        inSyncPlayRoom
                            ? playerController.syncplayRoom
                            : '未加入房间',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          color: isSidebar ? Colors.white70 : null,
                        ),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          if (inSyncPlayRoom) {
                            await playerController.exitSyncPlayRoom();
                            return;
                          }
                          onShowSyncPlayRoomCreateDialog();
                        },
                        child: Text(
                          inSyncPlayRoom ? '断开连接' : '加入房间',
                          style: TextStyle(fontFamily: fontFamily),
                        ),
                      ),
                    ),
                    SettingsTile(
                      title: Text('网络延迟',
                          style: TextStyle(fontFamily: fontFamily)),
                      description: Text(
                        '${playerController.syncplayClientRtt}ms',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          color: isSidebar ? Colors.white70 : null,
                        ),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: onShowSyncPlayEndPointSwitchDialog,
                        child: Text(
                          '切换服务器',
                          style: TextStyle(fontFamily: fontFamily),
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
}
