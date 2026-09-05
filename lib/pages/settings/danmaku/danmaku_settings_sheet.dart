import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';

import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/connected_tabs.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings_sheet.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_time_offset_sheet.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';

enum _DanmakuSettingsDestination {
  timeOffset,
  shield,
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

  if (!context.mounted || destination == null) return;
  await showAdaptiveBottomSheet<void>(
    context: context,
    builder: (context) => switch (destination) {
      _DanmakuSettingsDestination.shield => const DanmakuShieldSettingsSheet(),
      _DanmakuSettingsDestination.timeOffset => DanmakuTimeOffsetSheet(
          onTimelineOffsetChanged: onTimelineOffsetChanged,
        ),
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
  // The slider uses stored duration, before playback speed scales it.
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          MaterialBottomSheetHeader(
            title: '弹幕设置',
            onClose: () => Navigator.of(context).pop(),
          ),
          const ConnectedTabs(
              padding: materialBottomSheetTabsPadding, labels: ['外观', '播放']),
          Expanded(
              child: TabBarView(children: [
            ListView(
              key: const PageStorageKey('danmaku-appearance'),
              padding: materialBottomSheetContentPadding,
              children: [
                ContentSection.group(title: '显示效果', children: [
                  SettingsSliderTile(
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
                    title: Text('不透明度'),
                    value: _option.opacity,
                    min: 0.1,
                    max: 1,
                    valueLabel: '${(_option.opacity * 100).round()}%',
                    onChanged: (value) {
                      _applyOption(_option.copyWith(opacity: value));
                      GStorage.putSetting<double>(SettingsKeys.danmakuOpacity,
                          double.parse(value.toStringAsFixed(2)));
                    },
                  ),
                  SettingsSliderTile(
                    title: Text('显示区域'),
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
                    title: Text('行间距'),
                    value: _option.lineHeight,
                    min: 0,
                    max: 3,
                    divisions: 30,
                    valueLabel: _option.lineHeight.toStringAsFixed(1),
                    onChanged: (value) {
                      final lineHeight = double.parse(value.toStringAsFixed(1));
                      _applyOption(_option.copyWith(lineHeight: lineHeight));
                      GStorage.putSetting<double>(
                          SettingsKeys.danmakuLineHeight, lineHeight);
                    },
                  ),
                ]),
                const SizedBox(height: 24),
                ContentSection(
                  title: '弹幕类型',
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    _typeChip('滚动', !_option.hideScroll, (show) {
                      _applyOption(_option.copyWith(hideScroll: !show));
                      GStorage.putSetting<bool>(
                          SettingsKeys.danmakuScroll, show);
                    }),
                    _typeChip('顶部', !_option.hideTop, (show) {
                      _applyOption(_option.copyWith(hideTop: !show));
                      GStorage.putSetting<bool>(SettingsKeys.danmakuTop, show);
                    }),
                    _typeChip('底部', !_option.hideBottom, (show) {
                      _applyOption(_option.copyWith(hideBottom: !show));
                      GStorage.putSetting<bool>(
                          SettingsKeys.danmakuBottom, show);
                    }),
                  ]),
                ),
              ],
            ),
            ListView(
              key: const PageStorageKey('danmaku-playback'),
              padding: materialBottomSheetContentPadding,
              children: [
                ContentSection.group(title: '速度', children: [
                  SettingsSliderTile(
                    title: Text('停留时间'),
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
                  SettingsTile.switchTile(
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
                    initialValue: GStorage.getSetting<bool>(
                        SettingsKeys.danmakuFollowSpeed),
                  ),
                ]),
                const SizedBox(height: 24),
                ContentSection.group(title: '校准与过滤', children: [
                  SettingsTile(
                    leading: Icons.sync_rounded,
                    title: const Text('时间校准'),
                    description: Text(formatDanmakuTimeOffset(
                      normalizeDanmakuTimeOffset(GStorage.getSetting<double>(
                          SettingsKeys.danmakuTimeOffset)),
                    )),
                    onPressed: (context) => Navigator.of(context)
                        .pop(_DanmakuSettingsDestination.timeOffset),
                  ),
                  SettingsTile(
                    leading: Icons.filter_alt_outlined,
                    title: const Text('屏蔽规则'),
                    description: const Text('关键词与正则表达式'),
                    onPressed: (context) => Navigator.of(context)
                        .pop(_DanmakuSettingsDestination.shield),
                  ),
                ]),
              ],
            ),
          ])),
        ],
      ),
    );
  }

  Widget _typeChip(String label, bool selected, ValueChanged<bool> onSelected) {
    return FilterChip(
        label: Text(label), selected: selected, onSelected: onSelected);
  }
}
