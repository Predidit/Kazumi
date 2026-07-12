import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings_sheet.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_time_offset_sheet.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:kazumi/utils/device.dart';

enum _DanmakuSettingsDestination {
  timeOffset,
}

Future<void> showDanmakuSettingsSheet({
  required BuildContext context,
  required DanmakuController danmakuController,
  VoidCallback? onUpdateDanmakuSpeed,
  VoidCallback? onTimelineOffsetChanged,
}) async {
  final destination =
      await showAdaptiveBottomSheet<_DanmakuSettingsDestination>(
    context: context,
    builder: (context) {
      return _DanmakuSettingsSheet(
        danmakuController: danmakuController,
        onUpdateDanmakuSpeed: onUpdateDanmakuSpeed,
      );
    },
  );

  if (!context.mounted ||
      destination != _DanmakuSettingsDestination.timeOffset) {
    return;
  }

  await showAdaptiveBottomSheet<void>(
    context: context,
    builder: (context) {
      return DanmakuTimeOffsetSheet(
        onTimelineOffsetChanged: onTimelineOffsetChanged,
      );
    },
  );
}

class _DanmakuSettingsSheet extends StatefulWidget {
  final DanmakuController danmakuController;
  final VoidCallback? onUpdateDanmakuSpeed;

  const _DanmakuSettingsSheet({
    required this.danmakuController,
    this.onUpdateDanmakuSpeed,
  });

  @override
  State<_DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<_DanmakuSettingsSheet> {
  void _showDanmakuShieldSheet() {
    showAdaptiveBottomSheet<void>(
      context: context,
      builder: (context) => const DanmakuShieldSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return SafeArea(
      bottom: false,
      child: Scaffold(
        body: Column(
          children: [
            MaterialBottomSheetHeader(
              title: '弹幕设置',
              description: '调整弹幕显示、样式与屏蔽规则',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SettingsList(
                sections: [
                  SettingsSection(
                    title:
                        Text('弹幕屏蔽', style: TextStyle(fontFamily: fontFamily)),
                    tiles: [
                      SettingsTile.navigation(
                        onPressed: (_) {
                          _showDanmakuShieldSheet();
                        },
                        title: Text('关键词屏蔽',
                            style: TextStyle(fontFamily: fontFamily)),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title:
                        Text('弹幕样式', style: TextStyle(fontFamily: fontFamily)),
                    tiles: [
                      SettingsTile(
                        title: Text('字体大小',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Slider(
                          value: widget.danmakuController.option.fontSize,
                          min: 10,
                          max: isCompact() ? 32 : 48,
                          label:
                              '${widget.danmakuController.option.fontSize.floorToDouble()}',
                          onChanged: (value) {
                            setState(
                                () => widget.danmakuController.updateOption(
                                      widget.danmakuController.option.copyWith(
                                        fontSize: value.floorToDouble(),
                                      ),
                                    ));
                            GStorage.putSetting<double>(
                                SettingsKeys.danmakuFontSize,
                                value.floorToDouble());
                          },
                        ),
                      ),
                      SettingsTile(
                        title: Text('弹幕不透明度',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Slider(
                          value: widget.danmakuController.option.opacity,
                          min: 0.1,
                          max: 1,
                          label:
                              '${(widget.danmakuController.option.opacity * 100).round()}%',
                          onChanged: (value) {
                            setState(
                                () => widget.danmakuController.updateOption(
                                      widget.danmakuController.option.copyWith(
                                        opacity: value,
                                      ),
                                    ));
                            GStorage.putSetting<double>(
                                SettingsKeys.danmakuOpacity,
                                double.parse(value.toStringAsFixed(2)));
                          },
                        ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title:
                        Text('弹幕显示', style: TextStyle(fontFamily: fontFamily)),
                    tiles: [
                      SettingsTile.navigation(
                        onPressed: (context) {
                          Navigator.of(context)
                              .pop(_DanmakuSettingsDestination.timeOffset);
                        },
                        title: Text('时间轴偏移',
                            style: TextStyle(fontFamily: fontFamily)),
                        value: Text(
                          formatDanmakuTimeOffset(
                            normalizeDanmakuTimeOffset(
                              GStorage.getSetting<double>(
                                  SettingsKeys.danmakuTimeOffset),
                            ),
                          ),
                          style: TextStyle(fontFamily: fontFamily),
                        ),
                      ),
                      SettingsTile(
                        title: Text('弹幕区域',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Slider(
                          value: widget.danmakuController.option.area,
                          min: 0,
                          max: 1,
                          divisions: 8,
                          label:
                              '${(widget.danmakuController.option.area * 100).round()}%',
                          onChanged: (value) {
                            setState(
                                () => widget.danmakuController.updateOption(
                                      widget.danmakuController.option.copyWith(
                                        area: value,
                                      ),
                                    ));
                            GStorage.putSetting<double>(
                                SettingsKeys.danmakuArea, value);
                          },
                        ),
                      ),
                      SettingsTile(
                        title: Text('持续时间',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Slider(
                          value: widget.danmakuController.option.duration
                              .toDouble(),
                          min: 2,
                          max: 16,
                          divisions: 14,
                          label:
                              '${widget.danmakuController.option.duration.round()}',
                          onChanged: (value) {
                            setState(
                                () => widget.danmakuController.updateOption(
                                      widget.danmakuController.option.copyWith(
                                        duration: value,
                                      ),
                                    ));
                            GStorage.putSetting<double>(
                                SettingsKeys.danmakuDuration,
                                value.round().toDouble());
                          },
                        ),
                      ),
                      SettingsTile(
                        title: Text('行高',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Slider(
                          value: widget.danmakuController.option.lineHeight,
                          min: 0,
                          max: 3,
                          divisions: 30,
                          label: widget.danmakuController.option.lineHeight
                              .toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() =>
                                widget.danmakuController.updateOption(
                                  widget.danmakuController.option.copyWith(
                                    lineHeight:
                                        double.parse(value.toStringAsFixed(1)),
                                  ),
                                ));
                            GStorage.putSetting<double>(
                                SettingsKeys.danmakuLineHeight,
                                double.parse(value.toStringAsFixed(1)));
                          },
                        ),
                      ),
                      SettingsTile.switchTile(
                        onToggle: (value) {
                          bool show =
                              value ?? widget.danmakuController.option.hideTop;
                          setState(() => widget.danmakuController.updateOption(
                                widget.danmakuController.option.copyWith(
                                  hideTop: !show,
                                ),
                              ));
                          GStorage.putSetting<bool>(
                              SettingsKeys.danmakuTop, show);
                        },
                        title: Text('顶部弹幕',
                            style: TextStyle(fontFamily: fontFamily)),
                        initialValue: !widget.danmakuController.option.hideTop,
                      ),
                      SettingsTile.switchTile(
                        onToggle: (value) {
                          bool show = value ??
                              widget.danmakuController.option.hideBottom;
                          setState(() => widget.danmakuController.updateOption(
                                widget.danmakuController.option.copyWith(
                                  hideBottom: !show,
                                ),
                              ));
                          GStorage.putSetting<bool>(
                              SettingsKeys.danmakuBottom, show);
                        },
                        title: Text('底部弹幕',
                            style: TextStyle(fontFamily: fontFamily)),
                        initialValue:
                            !widget.danmakuController.option.hideBottom,
                      ),
                      SettingsTile.switchTile(
                        onToggle: (value) {
                          bool show = value ??
                              widget.danmakuController.option.hideScroll;
                          setState(() => widget.danmakuController.updateOption(
                                widget.danmakuController.option.copyWith(
                                  hideScroll: !show,
                                ),
                              ));
                          GStorage.putSetting<bool>(
                              SettingsKeys.danmakuScroll, show);
                        },
                        title: Text('滚动弹幕',
                            style: TextStyle(fontFamily: fontFamily)),
                        initialValue:
                            !widget.danmakuController.option.hideScroll,
                      ),
                      SettingsTile.switchTile(
                        onToggle: (value) {
                          bool followSpeed = value ??
                              !GStorage.getSetting<bool>(
                                  SettingsKeys.danmakuFollowSpeed);
                          GStorage.putSetting<bool>(
                              SettingsKeys.danmakuFollowSpeed, followSpeed);
                          widget.onUpdateDanmakuSpeed?.call();
                          setState(() {});
                        },
                        title: Text('跟随视频倍速',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Text('弹幕速度随视频倍速变化',
                            style: TextStyle(fontFamily: fontFamily)),
                        initialValue: GStorage.getSetting<bool>(
                            SettingsKeys.danmakuFollowSpeed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
