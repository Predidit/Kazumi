import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings_sheet.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_time_offset_sheet.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/utils/device.dart';

enum _DanmakuSettingsDestination {
  timeOffset,
}

Future<void> showDanmakuSettingsSheet({
  required BuildContext context,
  required DanmakuController danmakuController,
  required VoidCallback onUpdateDanmakuSpeed,
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
  final VoidCallback onUpdateDanmakuSpeed;

  const _DanmakuSettingsSheet({
    required this.danmakuController,
    required this.onUpdateDanmakuSpeed,
  });

  @override
  State<_DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<_DanmakuSettingsSheet> {
  /// The stored duration, before playback speed scales it. The running option
  /// carries the scaled value, so it can't back this slider.
  late double _duration;

  DanmakuOption get _option => widget.danmakuController.option;

  @override
  void initState() {
    super.initState();
    _duration = GStorage.getSetting(SettingsKeys.danmakuDuration);
  }

  void _applyOption(DanmakuOption option) {
    setState(() => widget.danmakuController.updateOption(option));
  }

  void _showDanmakuShieldSheet() {
    showAdaptiveBottomSheet<void>(
      context: context,
      builder: (context) => const DanmakuShieldSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    title: Text('弹幕屏蔽'),
                    tiles: [
                      SettingsTile(
                        leading: Icons.block_rounded,
                        onPressed: (_) {
                          _showDanmakuShieldSheet();
                        },
                        title: Text('关键词屏蔽'),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: Text('弹幕样式'),
                    tiles: [
                      SettingsSliderTile(
                        leading: Icons.format_size_rounded,
                        title: Text('字体大小'),
                        value: _option.fontSize,
                        min: 10,
                        max: isCompact() ? 32 : 48,
                        valueLabel: '${_option.fontSize.floor()}',
                        onChanged: (value) {
                          final fontSize = value.floorToDouble();
                          _applyOption(_option.copyWith(fontSize: fontSize));
                          GStorage.putSetting<double>(
                              SettingsKeys.danmakuFontSize, fontSize);
                        },
                      ),
                      SettingsSliderTile(
                        leading: Icons.opacity_rounded,
                        title: Text('弹幕不透明度'),
                        value: _option.opacity,
                        min: 0.1,
                        max: 1,
                        valueLabel: '${(_option.opacity * 100).round()}%',
                        onChanged: (value) {
                          _applyOption(_option.copyWith(opacity: value));
                          GStorage.putSetting<double>(
                              SettingsKeys.danmakuOpacity,
                              double.parse(value.toStringAsFixed(2)));
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: Text('弹幕显示'),
                    tiles: [
                      SettingsTile(
                        leading: Icons.schedule_rounded,
                        onPressed: (context) {
                          Navigator.of(context)
                              .pop(_DanmakuSettingsDestination.timeOffset);
                        },
                        title: Text('时间轴偏移'),
                        value: Text(
                          formatDanmakuTimeOffset(
                            normalizeDanmakuTimeOffset(
                              GStorage.getSetting<double>(
                                  SettingsKeys.danmakuTimeOffset),
                            ),
                          ),
                        ),
                      ),
                      SettingsSliderTile(
                        leading: Icons.crop_free_rounded,
                        title: Text('弹幕区域'),
                        value: _option.area,
                        min: 0,
                        max: 1,
                        divisions: 8,
                        valueLabel: '${(_option.area * 100).round()}%',
                        onChanged: (value) {
                          _applyOption(_option.copyWith(area: value));
                          GStorage.putSetting<double>(
                              SettingsKeys.danmakuArea, value);
                        },
                      ),
                      SettingsSliderTile(
                        leading: Icons.timer_rounded,
                        title: Text('持续时间'),
                        value: _duration,
                        min: 2,
                        max: 16,
                        divisions: 14,
                        valueLabel: '${_duration.round()} 秒',
                        onChanged: (value) {
                          final duration = value.roundToDouble();
                          setState(() => _duration = duration);
                          GStorage.putSetting<double>(
                              SettingsKeys.danmakuDuration, duration);
                          widget.onUpdateDanmakuSpeed();
                        },
                      ),
                      SettingsSliderTile(
                        leading: Icons.format_line_spacing_rounded,
                        title: Text('行高'),
                        value: _option.lineHeight,
                        min: 0,
                        max: 3,
                        divisions: 30,
                        valueLabel: _option.lineHeight.toStringAsFixed(1),
                        onChanged: (value) {
                          final lineHeight =
                              double.parse(value.toStringAsFixed(1));
                          _applyOption(
                              _option.copyWith(lineHeight: lineHeight));
                          GStorage.putSetting<double>(
                              SettingsKeys.danmakuLineHeight, lineHeight);
                        },
                      ),
                      SettingsTile.switchTile(
                        leading: Icons.vertical_align_top_rounded,
                        onToggle: (value) {
                          final show = value ?? _option.hideTop;
                          _applyOption(_option.copyWith(hideTop: !show));
                          GStorage.putSetting<bool>(
                              SettingsKeys.danmakuTop, show);
                        },
                        title: Text('顶部弹幕'),
                        initialValue: !_option.hideTop,
                      ),
                      SettingsTile.switchTile(
                        leading: Icons.vertical_align_bottom_rounded,
                        onToggle: (value) {
                          final show = value ?? _option.hideBottom;
                          _applyOption(_option.copyWith(hideBottom: !show));
                          GStorage.putSetting<bool>(
                              SettingsKeys.danmakuBottom, show);
                        },
                        title: Text('底部弹幕'),
                        initialValue: !_option.hideBottom,
                      ),
                      SettingsTile.switchTile(
                        leading: Icons.swap_horiz_rounded,
                        onToggle: (value) {
                          final show = value ?? _option.hideScroll;
                          _applyOption(_option.copyWith(hideScroll: !show));
                          GStorage.putSetting<bool>(
                              SettingsKeys.danmakuScroll, show);
                        },
                        title: Text('滚动弹幕'),
                        initialValue: !_option.hideScroll,
                      ),
                      SettingsTile.switchTile(
                        leading: Icons.speed_rounded,
                        onToggle: (value) {
                          bool followSpeed = value ??
                              !GStorage.getSetting<bool>(
                                  SettingsKeys.danmakuFollowSpeed);
                          GStorage.putSetting<bool>(
                              SettingsKeys.danmakuFollowSpeed, followSpeed);
                          widget.onUpdateDanmakuSpeed();
                          setState(() {});
                        },
                        title: Text('跟随视频倍速'),
                        description: Text('弹幕速度随视频倍速变化'),
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
