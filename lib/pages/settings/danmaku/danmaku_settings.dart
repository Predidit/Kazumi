import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class DanmakuSettingsPage extends StatefulWidget {
  const DanmakuSettingsPage({super.key});

  @override
  State<DanmakuSettingsPage> createState() => _DanmakuSettingsPageState();
}

class _DanmakuSettingsPageState extends State<DanmakuSettingsPage> {
  Box setting = GStorage.setting;
  late dynamic defaultDanmakuArea;
  late dynamic defaultDanmakuOpacity;
  late dynamic defaultDanmakuFontSize;
  late int defaultDanmakuFontWeight;
  late double defaultDanmakuDuration;
  late double defaultDanmakuLineHeight;
  final PopularController popularController = Modular.get<PopularController>();
  late bool danmakuBorder;
  late bool danmakuTop;
  late bool danmakuBottom;
  late bool danmakuScroll;
  late bool danmakuColor;
  late bool danmakuMassive;
  late bool danmakuDeduplication;
  late bool danmakuBiliBiliSource;
  late bool danmakuGamerSource;
  late bool danmakuDanDanSource;
  late bool danmakuFollowSpeed;

  @override
  void initState() {
    super.initState();
    defaultDanmakuArea =
        setting.get(SettingBoxKey.danmakuArea, defaultValue: 1.0);
    defaultDanmakuOpacity =
        setting.get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0);
    defaultDanmakuFontSize = setting.get(SettingBoxKey.danmakuFontSize,
        defaultValue: (Utils.isCompact()) ? 16.0 : 25.0);
    defaultDanmakuFontWeight =
        setting.get(SettingBoxKey.danmakuFontWeight, defaultValue: 4);
    defaultDanmakuDuration =
        setting.get(SettingBoxKey.danmakuDuration, defaultValue: 8.0);
    defaultDanmakuLineHeight =
        setting.get(SettingBoxKey.danmakuLineHeight, defaultValue: 1.6);
    danmakuBorder =
        setting.get(SettingBoxKey.danmakuBorder, defaultValue: true);
    danmakuTop = setting.get(SettingBoxKey.danmakuTop, defaultValue: true);
    danmakuBottom =
        setting.get(SettingBoxKey.danmakuBottom, defaultValue: false);
    danmakuScroll =
        setting.get(SettingBoxKey.danmakuScroll, defaultValue: true);
    danmakuColor = setting.get(SettingBoxKey.danmakuColor, defaultValue: true);
    danmakuMassive =
        setting.get(SettingBoxKey.danmakuMassive, defaultValue: false);
    danmakuDeduplication = 
        setting.get(SettingBoxKey.danmakuDeduplication, defaultValue: false);
    danmakuBiliBiliSource =
        setting.get(SettingBoxKey.danmakuBiliBiliSource, defaultValue: true);
    danmakuGamerSource =
        setting.get(SettingBoxKey.danmakuGamerSource, defaultValue: true);
    danmakuDanDanSource =
        setting.get(SettingBoxKey.danmakuDanDanSource, defaultValue: true);
    danmakuFollowSpeed =
        setting.get(SettingBoxKey.danmakuFollowSpeed, defaultValue: true);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void updateDanmakuArea(double i) async {
    await setting.put(SettingBoxKey.danmakuArea, i);
    setState(() {
      defaultDanmakuArea = i;
    });
  }

  void updateDanmakuOpacity(double i) async {
    await setting.put(SettingBoxKey.danmakuOpacity, i);
    setState(() {
      defaultDanmakuOpacity = i;
    });
  }

  void updateDanmakuFontSize(double i) async {
    await setting.put(SettingBoxKey.danmakuFontSize, i);
    setState(() {
      defaultDanmakuFontSize = i;
    });
  }

  void updateDanmakuDuration(double i) async {
    await setting.put(SettingBoxKey.danmakuDuration, i);
    setState(() {
      defaultDanmakuDuration = i;
    });
  }

  void updateDanmakuLineHeight(double i) async {
    await setting.put(SettingBoxKey.danmakuLineHeight, i);
    setState(() {
      defaultDanmakuLineHeight = i;
    });
  }

  void updateDanmakuFontWeight(int i) async {
    await setting.put(SettingBoxKey.danmakuFontWeight, i);
    setState(() {
      defaultDanmakuFontWeight = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('弹幕设置')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              title: Text('弹幕来源', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuBiliBiliSource = value ?? !danmakuBiliBiliSource;
                    await setting.put(SettingBoxKey.danmakuBiliBiliSource,
                        danmakuBiliBiliSource);
                    setState(() {});
                  },
                  title: Text('BiliBili', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBiliBiliSource,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuGamerSource = value ?? !danmakuGamerSource;
                    await setting.put(
                        SettingBoxKey.danmakuGamerSource, danmakuGamerSource);
                    setState(() {});
                  },
                  title: Text('Gamer', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuGamerSource,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuDanDanSource = value ?? !danmakuDanDanSource;
                    await setting.put(
                        SettingBoxKey.danmakuDanDanSource, danmakuDanDanSource);
                    setState(() {});
                  },
                  title: Text('DanDan', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuDanDanSource,
                ),
              ],
            ),
            SettingsSection(
              title: Text('弹幕屏蔽', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/danmaku/shield');
                  },
                  title: Text('关键词屏蔽', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('弹幕显示', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  title: Text('弹幕区域', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: defaultDanmakuArea,
                    min: 0,
                    max: 1,
                    divisions: 8,
                    label: '${(defaultDanmakuArea * 100).round()}%',
                    onChanged: (value) {
                      updateDanmakuArea(value);
                    },
                  ),
                ),
                SettingsTile(
                  title: Text('弹幕持续时间', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: defaultDanmakuDuration,
                    min: 2,
                    max: 16,
                    divisions: 14,
                    label: '${defaultDanmakuDuration.round()}',
                    onChanged: (value) {
                      updateDanmakuDuration(value.round().toDouble());
                    },
                  ),
                ),
                SettingsTile(
                  title: Text('弹幕行高', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: defaultDanmakuLineHeight,
                    min: 0,
                    max: 3,
                    divisions: 30,
                    label: defaultDanmakuLineHeight.toStringAsFixed(1),
                    onChanged: (value) {
                      updateDanmakuLineHeight(double.parse(value.toStringAsFixed(1)));
                    },
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuFollowSpeed = value ?? !danmakuFollowSpeed;
                    await setting.put(
                        SettingBoxKey.danmakuFollowSpeed, danmakuFollowSpeed);
                    setState(() {});
                  },
                  title: Text('弹幕跟随视频倍速', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('开启后弹幕速度会随视频倍速而改变', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuFollowSpeed,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuTop = value ?? !danmakuTop;
                    await setting.put(SettingBoxKey.danmakuTop, danmakuTop);
                    setState(() {});
                  },
                  title: Text('顶部弹幕', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuTop,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuBottom = value ?? !danmakuBottom;
                    await setting.put(
                        SettingBoxKey.danmakuBottom, danmakuBottom);
                    setState(() {});
                  },
                  title: Text('底部弹幕', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBottom,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuScroll = value ?? !danmakuScroll;
                    await setting.put(
                        SettingBoxKey.danmakuScroll, danmakuScroll);
                    setState(() {});
                  },
                  title: Text('滚动弹幕', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuScroll,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuMassive = value ?? !danmakuMassive;
                    await setting.put(
                        SettingBoxKey.danmakuMassive, danmakuMassive);
                    setState(() {});
                  },
                  title: Text('海量弹幕', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('弹幕过多时进行叠加绘制', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuMassive,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuDeduplication = value ?? !danmakuDeduplication;
                    await setting.put(
                        SettingBoxKey.danmakuDeduplication, danmakuDeduplication);
                    setState(() {});
                  },
                  title: Text('弹幕去重', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('相同内容弹幕过多时合并为一条弹幕', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuDeduplication,
                ),
              ],
            ),
            SettingsSection(
              title: Text('弹幕样式', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuBorder = value ?? !danmakuBorder;
                    await setting.put(
                        SettingBoxKey.danmakuBorder, danmakuBorder);
                    setState(() {});
                  },
                  title: Text('弹幕描边', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBorder,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuColor = value ?? !danmakuColor;
                    await setting.put(SettingBoxKey.danmakuColor, danmakuColor);
                    setState(() {});
                  },
                  title: Text('弹幕颜色', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuColor,
                ),
                SettingsTile(
                  title: Text('字体大小', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: defaultDanmakuFontSize,
                    min: 10,
                    max: Utils.isCompact() ? 32 : 48,
                    label: '${defaultDanmakuFontSize.floorToDouble()}',
                    onChanged: (value) {
                      updateDanmakuFontSize(value.floorToDouble());
                    },
                  ),
                ),
                SettingsTile(
                  title: Text('字体字重', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: defaultDanmakuFontWeight.toDouble(),
                    min: 1,
                    max: 9,
                    divisions: 8,
                    label: '$defaultDanmakuFontWeight',
                    onChanged: (value) {
                      updateDanmakuFontWeight(value.toInt());
                    },
                  ),
                ),
                SettingsTile(
                  title: Text('弹幕不透明度', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: defaultDanmakuOpacity,
                    min: 0.1,
                    max: 1,
                    label: '${(defaultDanmakuOpacity * 100).round()}%',
                    onChanged: (value) {
                      updateDanmakuOpacity(
                          double.parse(value.toStringAsFixed(2)));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
