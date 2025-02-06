import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';

class DanmakuSettingsSheet extends StatefulWidget {
  final DanmakuController danmakuController;
  const DanmakuSettingsSheet({super.key, required this.danmakuController});

  @override
  State<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<DanmakuSettingsSheet> {
  Box setting = GStorage.setting;

  Widget get danmakuFontSettingsBody {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 0, 0),
          child: Text('弹幕字号'),
        ),
        Slider(
          value: widget.danmakuController.option.fontSize,
          min: 10,
          max: Utils.isCompact() ? 32 : 48,
          divisions: Utils.isCompact() ? 22 : 38,
          label: widget.danmakuController.option.fontSize.toString(),
          onChanged: (value) {
            setState(() => widget.danmakuController.updateOption(
                  widget.danmakuController.option.copyWith(
                    fontSize: value,
                  ),
                ));
            setting.put(SettingBoxKey.danmakuFontSize, value);
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 0, 0),
          child: Text('弹幕区域'),
        ),
        Slider(
          value: widget.danmakuController.option.area,
          min: 0,
          max: 1,
          divisions: 4,
          label: '${(widget.danmakuController.option.area * 100).round()}%',
          onChanged: (value) {
            setState(() => widget.danmakuController.updateOption(
                  widget.danmakuController.option.copyWith(
                    area: value,
                  ),
                ));
            setting.put(SettingBoxKey.danmakuArea, value);
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 0, 0),
          child: Text('弹幕不透明度'),
        ),
        Slider(
          value: widget.danmakuController.option.opacity,
          min: 0.1,
          max: 1,
          divisions: 9,
          label: '${(widget.danmakuController.option.opacity * 100).round()}%',
          onChanged: (value) {
            setState(() => widget.danmakuController.updateOption(
                  widget.danmakuController.option.copyWith(
                    opacity: value,
                  ),
                ));
            setting.put(SettingBoxKey.danmakuOpacity,
                double.parse(value.toStringAsFixed(1)));
          },
        ),
      ],
    );
  }

  Widget get danmakuHideSettingsBody {
    return ListView(
      children: [
        ListTile(
          title: const Text('隐藏滚动弹幕'),
          trailing: Switch(
            value: widget.danmakuController.option.hideScroll,
            onChanged: (value) {
              setState(() => widget.danmakuController.updateOption(
                    widget.danmakuController.option.copyWith(
                      hideScroll: value,
                    ),
                  ));
              setting.put(SettingBoxKey.danmakuScroll, !value);
            },
          ),
        ),
        ListTile(
          title: const Text('隐藏顶部弹幕'),
          trailing: Switch(
            value: widget.danmakuController.option.hideTop,
            onChanged: (value) {
              setState(() => widget.danmakuController.updateOption(
                    widget.danmakuController.option.copyWith(
                      hideTop: value,
                    ),
                  ));
              setting.put(SettingBoxKey.danmakuTop, !value);
            },
          ),
        ),
        ListTile(
          title: const Text('隐藏底部弹幕'),
          trailing: Switch(
            value: widget.danmakuController.option.hideBottom,
            onChanged: (value) {
              setState(() => widget.danmakuController.updateOption(
                    widget.danmakuController.option.copyWith(
                      hideBottom: value,
                    ),
                  ));
              setting.put(SettingBoxKey.danmakuBottom, !value);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: [
                    Tab(text: '字体设置'),
                    Tab(text: '屏蔽设置'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [danmakuFontSettingsBody, danmakuHideSettingsBody],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
