import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_settings.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class DanmakuSettingsSheet extends StatefulWidget {
  final DanmakuController danmakuController;
  final VoidCallback? onUpdateDanmakuSpeed;

  const DanmakuSettingsSheet({
    super.key,
    required this.danmakuController,
    this.onUpdateDanmakuSpeed,
  });

  @override
  State<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<DanmakuSettingsSheet> {
  Box setting = GStorage.setting;

  void showDanmakuShieldSheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 3 / 4,
            maxWidth: (Utils.isDesktop() || Utils.isTablet())
                ? MediaQuery.of(context).size.width * 9 / 16
                : MediaQuery.of(context).size.width),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) {
          return SafeArea(
            bottom: false,
            child: DanmakuShieldSettings(),
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
                  max: Utils.isCompact() ? 32 : 48,
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
                    setting.put(SettingBoxKey.danmakuOpacity,
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
                    setting.put(SettingBoxKey.danmakuArea, value);
                  },
                ),
              ),
              SettingsTile(title: Text('持续时间', style: TextStyle(fontFamily: fontFamily)),
                description: Slider(
                  value: widget.danmakuController.option.duration.toDouble(),
                  min: 2,
                  max: 16,
                  divisions: 14,
                  label:
                      '${widget.danmakuController.option.duration.round()}',
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            duration: value,
                          ),
                        ));
                    setting.put(SettingBoxKey.danmakuDuration, value.round().toDouble());
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
                  label: widget.danmakuController.option.lineHeight.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() => widget.danmakuController.updateOption(
                          widget.danmakuController.option.copyWith(
                            lineHeight: double.parse(value.toStringAsFixed(1)),
                          ),
                        ));
                    setting.put(SettingBoxKey.danmakuLineHeight, double.parse(value.toStringAsFixed(1)));
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
                title: Text('顶部弹幕', style: TextStyle(fontFamily: fontFamily)),
                initialValue: !widget.danmakuController.option.hideTop,
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bool show = value ?? widget.danmakuController.option.hideBottom;
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          hideBottom: !show,
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuBottom, show);
                },
                title: Text('底部弹幕', style: TextStyle(fontFamily: fontFamily)),
                initialValue: !widget.danmakuController.option.hideBottom,
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bool show = value ?? widget.danmakuController.option.hideScroll;
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          hideScroll: !show,
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuScroll, show);
                },
                title: Text('滚动弹幕', style: TextStyle(fontFamily: fontFamily)),
                initialValue: !widget.danmakuController.option.hideScroll,
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  bool followSpeed = value ?? !setting.get(SettingBoxKey.danmakuFollowSpeed, defaultValue: true);
                  setting.put(SettingBoxKey.danmakuFollowSpeed, followSpeed);
                  widget.onUpdateDanmakuSpeed?.call();
                  setState(() {});
                },
                title: Text('跟随视频倍速', style: TextStyle(fontFamily: fontFamily)),
                description: Text('弹幕速度随视频倍速变化', style: TextStyle(fontFamily: fontFamily)),
                initialValue: setting.get(SettingBoxKey.danmakuFollowSpeed, defaultValue: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
