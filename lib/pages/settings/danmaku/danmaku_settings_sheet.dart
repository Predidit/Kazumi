import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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
          return DanmakuShieldSettings();
        });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsList(
      sections: [
        SettingsSection(
          title: const Text('弹幕屏蔽'),
          tiles: [
            SettingsTile.navigation(
              onPressed: (_) {
                showDanmakuShieldSheet();
              },
              title: const Text('关键词屏蔽'),
            ),
          ],
        ),
        SettingsSection(
          title: const Text('弹幕样式'),
          tiles: [
            SettingsTile(
              title: const Text('字体大小'),
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
              title: const Text('弹幕不透明度'),
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
          title: const Text('弹幕显示'),
          tiles: [
            SettingsTile(
              title: const Text('弹幕区域'),
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
            SettingsTile(title: const Text('持续时间'),
              description: Slider(
                value: widget.danmakuController.option.duration.toDouble(),
                min: 4,
                max: 16,
                divisions: 12,
                label:
                    '${widget.danmakuController.option.duration.round()}',
                onChanged: (value) {
                  setState(() => widget.danmakuController.updateOption(
                        widget.danmakuController.option.copyWith(
                          duration: value.round(),
                        ),
                      ));
                  setting.put(SettingBoxKey.danmakuDuration, value.round().toDouble());
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
              title: const Text('顶部弹幕'),
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
              title: const Text('底部弹幕'),
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
              title: const Text('滚动弹幕'),
              initialValue: !widget.danmakuController.option.hideScroll,
            ),
            SettingsTile.switchTile(
              onToggle: (value) async {
                bool followSpeed = value ?? !setting.get(SettingBoxKey.danmakuFollowSpeed, defaultValue: true);
                setting.put(SettingBoxKey.danmakuFollowSpeed, followSpeed);
                widget.onUpdateDanmakuSpeed?.call();
                setState(() {});
              },
              title: const Text('跟随视频倍速'),
              description: const Text('弹幕速度随视频倍速变化'),
              initialValue: setting.get(SettingBoxKey.danmakuFollowSpeed, defaultValue: true),
            ),
          ],
        ),
      ],
    );
  }
}
