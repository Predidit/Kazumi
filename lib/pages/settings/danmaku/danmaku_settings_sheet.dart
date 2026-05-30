import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
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
  Box setting = GStorage.setting;
  late double _danmakuTimeOffset;

  double _readDanmakuTimeOffset() {
    final offset =
        setting.get(SettingBoxKey.danmakuTimeOffset, defaultValue: 0.0);
    if (offset is num) {
      return offset.toDouble().clamp(-60.0, 60.0).toDouble();
    }
    return 0.0;
  }

  String _formatDanmakuTimeOffset(double value) {
    if (value == 0) {
      return 'No offset';
    }
    final direction = value > 0 ? 'Delay' : 'Advance';
    return '$direction ${value.abs().toStringAsFixed(1)} s';
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
            title: Text('Danmaku blocking', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) {
                  showDanmakuShieldSheet();
                },
                title: Text('Keyword blocking', style: TextStyle(fontFamily: fontFamily)),
              ),
            ],
          ),
          SettingsSection(
            title: Text('Danmaku style', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile(
                title: Text('Font size', style: TextStyle(fontFamily: fontFamily)),
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
                    setting.put(
                        SettingBoxKey.danmakuFontSize, value.floorToDouble());
                  },
                ),
              ),
              SettingsTile(
                title: Text('Danmaku opacity', style: TextStyle(fontFamily: fontFamily)),
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
                    setting.put(SettingBoxKey.danmakuOpacity,
                        double.parse(value.toStringAsFixed(2)));
                  },
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text('Danmaku display', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile(
                title: Text('Timeline offset', style: TextStyle(fontFamily: fontFamily)),
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
                    setting.put(SettingBoxKey.danmakuTimeOffset, offset);
                    widget.onTimelineOffsetChanged?.call();
                  },
                ),
              ),
              SettingsTile(
                title: Text('Danmaku area', style: TextStyle(fontFamily: fontFamily)),
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
                    setting.put(SettingBoxKey.danmakuArea, value);
                  },
                ),
              ),
              SettingsTile(
                title: Text('Duration', style: TextStyle(fontFamily: fontFamily)),
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
                    setting.put(SettingBoxKey.danmakuDuration,
                        value.round().toDouble());
                  },
                ),
              ),
              SettingsTile(
                title: Text('Line height', style: TextStyle(fontFamily: fontFamily)),
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
                    setting.put(SettingBoxKey.danmakuLineHeight,
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
                  setting.put(SettingBoxKey.danmakuTop, show);
                },
                title: Text('Top danmaku', style: TextStyle(fontFamily: fontFamily)),
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
                  setting.put(SettingBoxKey.danmakuBottom, show);
                },
                title: Text('Bottom danmaku', style: TextStyle(fontFamily: fontFamily)),
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
                  setting.put(SettingBoxKey.danmakuScroll, show);
                },
                title: Text('Scrolling danmaku', style: TextStyle(fontFamily: fontFamily)),
                initialValue: !widget.danmakuController.option.hideScroll,
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bool followSpeed = value ??
                      !setting.get(SettingBoxKey.danmakuFollowSpeed,
                          defaultValue: true);
                  setting.put(SettingBoxKey.danmakuFollowSpeed, followSpeed);
                  widget.onUpdateDanmakuSpeed?.call();
                  setState(() {});
                },
                title: Text('Follow playback speed', style: TextStyle(fontFamily: fontFamily)),
                description: Text('Danmaku speed changes with playback speed',
                    style: TextStyle(fontFamily: fontFamily)),
                initialValue: setting.get(SettingBoxKey.danmakuFollowSpeed,
                    defaultValue: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
