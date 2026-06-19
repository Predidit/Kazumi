import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings_sheet.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:kazumi/utils/device.dart';

class DanmakuSettingsSheet extends StatefulWidget {
  final DanmakuController danmakuController;
  final VoidCallback? onUpdateDanmakuSpeed;
  final VoidCallback? onTimelineOffsetChanged;

  const DanmakuSettingsSheet({
    super.key,
    required this.danmakuController,
    this.onUpdateDanmakuSpeed,
    this.onTimelineOffsetChanged,
  });

  @override
  State<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<DanmakuSettingsSheet> {
  late double _danmakuTimeOffset;

  double _readDanmakuTimeOffset() {
    final offset = GStorage.getSetting(SettingsKeys.danmakuTimeOffset);
    return offset.clamp(-60.0, 60.0).toDouble();
  }

  String _formatDanmakuTimeOffset(double value) {
    if (value == 0) {
      return '无偏移';
    }
    final direction = value > 0 ? '延后' : '提前';
    return '$direction ${value.abs().toStringAsFixed(1)} 秒';
  }

  @override
  void initState() {
    super.initState();
    _danmakuTimeOffset = _readDanmakuTimeOffset();
  }

  void showDanmakuShieldSheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 3 / 4,
            maxWidth: (isDesktop() || isTablet())
                ? MediaQuery.of(context).size.width * 9 / 16
                : MediaQuery.of(context).size.width),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) {
          return SafeArea(
            bottom: false,
            child: DanmakuShieldSettingsSheet(),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return SafeArea(
      bottom: false,
      child: SettingsList(
        sections: [
          SettingsSection(
            title: Text('弹幕屏蔽', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) {
                  showDanmakuShieldSheet();
                },
                title: Text('关键词屏蔽', style: TextStyle(fontFamily: fontFamily)),
              ),
            ],
          ),
          SettingsSection(
            title: Text('弹幕样式', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile(
                title: Text('字体大小', style: TextStyle(fontFamily: fontFamily)),
                description: Slider(
                  value: widget.danmakuController.option.fontSize,
                  min: 10,
                  max: isCompact() ? 32 : 48,
                  label:
                      '${widget.danmakuController.option.fontSize.floorToDouble()}',
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            fontSize: value.floorToDouble(),
                          ),
                        ));
                    GStorage.putSetting<double>(
                        SettingsKeys.danmakuFontSize, value.floorToDouble());
                  },
                ),
              ),
              SettingsTile(
                title: Text('弹幕不透明度', style: TextStyle(fontFamily: fontFamily)),
                description: Slider(
                  value: widget.danmakuController.option.opacity,
                  min: 0.1,
                  max: 1,
                  label:
                      '${(widget.danmakuController.option.opacity * 100).round()}%',
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            opacity: value,
                          ),
                        ));
                    GStorage.putSetting<double>(SettingsKeys.danmakuOpacity,
                        double.parse(value.toStringAsFixed(2)));
                  },
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text('弹幕显示', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile(
                title: Text('时间轴偏移', style: TextStyle(fontFamily: fontFamily)),
                description: Slider(
                  value: _danmakuTimeOffset,
                  min: -60,
                  max: 60,
                  divisions: 240,
                  label: _formatDanmakuTimeOffset(_danmakuTimeOffset),
                  onChanged: (value) {
                    final offset = double.parse(value.toStringAsFixed(1));
                    setState(() {
                      _danmakuTimeOffset = offset;
                    });
                    GStorage.putSetting<double>(
                        SettingsKeys.danmakuTimeOffset, offset);
                    widget.onTimelineOffsetChanged?.call();
                  },
                ),
              ),
              SettingsTile(
                title: Text('弹幕区域', style: TextStyle(fontFamily: fontFamily)),
                description: Slider(
                  value: widget.danmakuController.option.area,
                  min: 0,
                  max: 1,
                  divisions: 8,
                  label:
                      '${(widget.danmakuController.option.area * 100).round()}%',
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
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
                title: Text('持续时间', style: TextStyle(fontFamily: fontFamily)),
                description: Slider(
                  value: widget.danmakuController.option.duration.toDouble(),
                  min: 2,
                  max: 16,
                  divisions: 14,
                  label: '${widget.danmakuController.option.duration.round()}',
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            duration: value,
                          ),
                        ));
                    GStorage.putSetting<double>(
                        SettingsKeys.danmakuDuration, value.round().toDouble());
                  },
                ),
              ),
              SettingsTile(
                title: Text('行高', style: TextStyle(fontFamily: fontFamily)),
                description: Slider(
                  value: widget.danmakuController.option.lineHeight,
                  min: 0,
                  max: 3,
                  divisions: 30,
                  label: widget.danmakuController.option.lineHeight
                      .toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            lineHeight: double.parse(value.toStringAsFixed(1)),
                          ),
                        ));
                    GStorage.putSetting<double>(SettingsKeys.danmakuLineHeight,
                        double.parse(value.toStringAsFixed(1)));
                  },
                ),
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bool show = value ?? widget.danmakuController.option.hideTop;
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          hideTop: !show,
                        ),
                      ));
                  GStorage.putSetting<bool>(SettingsKeys.danmakuTop, show);
                },
                title: Text('顶部弹幕', style: TextStyle(fontFamily: fontFamily)),
                initialValue: !widget.danmakuController.option.hideTop,
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bool show =
                      value ?? widget.danmakuController.option.hideBottom;
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          hideBottom: !show,
                        ),
                      ));
                  GStorage.putSetting<bool>(SettingsKeys.danmakuBottom, show);
                },
                title: Text('底部弹幕', style: TextStyle(fontFamily: fontFamily)),
                initialValue: !widget.danmakuController.option.hideBottom,
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bool show =
                      value ?? widget.danmakuController.option.hideScroll;
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          hideScroll: !show,
                        ),
                      ));
                  GStorage.putSetting<bool>(SettingsKeys.danmakuScroll, show);
                },
                title: Text('滚动弹幕', style: TextStyle(fontFamily: fontFamily)),
                initialValue: !widget.danmakuController.option.hideScroll,
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bool followSpeed = value ??
                      !GStorage.getSetting<bool>(
                          SettingsKeys.danmakuFollowSpeed);
                  GStorage.putSetting<bool>(
                      SettingsKeys.danmakuFollowSpeed, followSpeed);
                  widget.onUpdateDanmakuSpeed?.call();
                  setState(() {});
                },
                title: Text('跟随视频倍速', style: TextStyle(fontFamily: fontFamily)),
                description: Text('弹幕速度随视频倍速变化',
                    style: TextStyle(fontFamily: fontFamily)),
                initialValue:
                    GStorage.getSetting<bool>(SettingsKeys.danmakuFollowSpeed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
