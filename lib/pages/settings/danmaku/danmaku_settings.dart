import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:kazumi/utils/device.dart';

class DanmakuSettingsPage extends StatefulWidget {
  const DanmakuSettingsPage({super.key});

  @override
  State<DanmakuSettingsPage> createState() => _DanmakuSettingsPageState();
}

class _DanmakuSettingsPageState extends State<DanmakuSettingsPage> {
  late final bool compactLayout;
  late double defaultDanmakuArea;
  late double defaultDanmakuOpacity;
  late double defaultDanmakuFontSize;
  late int defaultDanmakuFontWeight;
  late double defaultDanmakuDuration;
  late double defaultDanmakuLineHeight;
  late double defaultdanmakuBorderSize;
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
    compactLayout = isCompact();
    _loadSettingsFromStorage();
  }

  void _loadSettingsFromStorage() {
    final settingContext = SettingContext(compactLayout: compactLayout);
    defaultDanmakuArea = GStorage.getSetting(SettingsKeys.danmakuArea);
    defaultDanmakuOpacity = GStorage.getSetting(SettingsKeys.danmakuOpacity);
    defaultDanmakuFontSize = GStorage.getSetting<double>(
        SettingsKeys.danmakuFontSize,
        context: settingContext);
    defaultDanmakuFontWeight =
        GStorage.getSetting(SettingsKeys.danmakuFontWeight);
    defaultDanmakuDuration = GStorage.getSetting(SettingsKeys.danmakuDuration);
    defaultDanmakuLineHeight =
        GStorage.getSetting(SettingsKeys.danmakuLineHeight);
    danmakuBorder = GStorage.getSetting(SettingsKeys.danmakuBorder);
    defaultdanmakuBorderSize =
        GStorage.getSetting(SettingsKeys.danmakuBorderSize);
    danmakuTop = GStorage.getSetting(SettingsKeys.danmakuTop);
    danmakuBottom = GStorage.getSetting(SettingsKeys.danmakuBottom);
    danmakuScroll = GStorage.getSetting(SettingsKeys.danmakuScroll);
    danmakuColor = GStorage.getSetting(SettingsKeys.danmakuColor);
    danmakuMassive = GStorage.getSetting(SettingsKeys.danmakuMassive);
    danmakuDeduplication =
        GStorage.getSetting<bool>(SettingsKeys.danmakuDeduplication);
    danmakuBiliBiliSource =
        GStorage.getSetting<bool>(SettingsKeys.danmakuBiliBiliSource);
    danmakuGamerSource =
        GStorage.getSetting<bool>(SettingsKeys.danmakuGamerSource);
    danmakuDanDanSource =
        GStorage.getSetting<bool>(SettingsKeys.danmakuDanDanSource);
    danmakuFollowSpeed =
        GStorage.getSetting<bool>(SettingsKeys.danmakuFollowSpeed);
  }

  Future<void> resetDanmakuSettings() async {
    final bool shouldReset = await KazumiDialog.show<bool>(
          builder: (context) => AlertDialog(
            title: const Text('恢复默认弹幕设置'),
            content: const Text('弹幕来源、显示和样式设置将恢复为默认值，关键词屏蔽列表不会被清空。'),
            actions: [
              TextButton(
                onPressed: () => KazumiDialog.dismiss(popWith: false),
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () => KazumiDialog.dismiss(popWith: true),
                child: Text('恢复默认'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldReset) return;

    await GStorage.resetDanmakuSettings();
    if (!mounted) return;
    setState(_loadSettingsFromStorage);
    KazumiDialog.showToast(message: '已恢复默认弹幕设置');
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void updateDanmakuArea(double i) async {
    await GStorage.putSetting<double>(SettingsKeys.danmakuArea, i);
    setState(() {
      defaultDanmakuArea = i;
    });
  }

  void updateDanmakuOpacity(double i) async {
    await GStorage.putSetting<double>(SettingsKeys.danmakuOpacity, i);
    setState(() {
      defaultDanmakuOpacity = i;
    });
  }

  void updateDanmakuFontSize(double i) async {
    await GStorage.putSetting<double>(SettingsKeys.danmakuFontSize, i);
    setState(() {
      defaultDanmakuFontSize = i;
    });
  }

  void updateDanmakuDuration(double i) async {
    await GStorage.putSetting<double>(SettingsKeys.danmakuDuration, i);
    setState(() {
      defaultDanmakuDuration = i;
    });
  }

  void updateDanmakuLineHeight(double i) async {
    await GStorage.putSetting<double>(SettingsKeys.danmakuLineHeight, i);
    setState(() {
      defaultDanmakuLineHeight = i;
    });
  }

  void updateDanmakuFontWeight(int i) async {
    await GStorage.putSetting<int>(SettingsKeys.danmakuFontWeight, i);
    setState(() {
      defaultDanmakuFontWeight = i;
    });
  }

  void updateDanmakuBorderSize(double i) async {
    await GStorage.putSetting<double>(SettingsKeys.danmakuBorderSize, i);
    setState(() {
      defaultdanmakuBorderSize = i;
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
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuBiliBiliSource,
                        danmakuBiliBiliSource);
                    setState(() {});
                  },
                  title: Text('BiliBili',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBiliBiliSource,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuGamerSource = value ?? !danmakuGamerSource;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuGamerSource, danmakuGamerSource);
                    setState(() {});
                  },
                  title:
                      Text('Gamer', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuGamerSource,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuDanDanSource = value ?? !danmakuDanDanSource;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuDanDanSource, danmakuDanDanSource);
                    setState(() {});
                  },
                  title:
                      Text('弹弹play', style: TextStyle(fontFamily: fontFamily)),
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
                  title:
                      Text('关键词屏蔽', style: TextStyle(fontFamily: fontFamily)),
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
                  title:
                      Text('弹幕持续时间', style: TextStyle(fontFamily: fontFamily)),
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
                      updateDanmakuLineHeight(
                          double.parse(value.toStringAsFixed(1)));
                    },
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuFollowSpeed = value ?? !danmakuFollowSpeed;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuFollowSpeed, danmakuFollowSpeed);
                    setState(() {});
                  },
                  title: Text('弹幕跟随视频倍速',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('开启后弹幕速度会随视频倍速而改变',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuFollowSpeed,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuTop = value ?? !danmakuTop;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuTop, danmakuTop);
                    setState(() {});
                  },
                  title: Text('顶部弹幕', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuTop,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuBottom = value ?? !danmakuBottom;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuBottom, danmakuBottom);
                    setState(() {});
                  },
                  title: Text('底部弹幕', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBottom,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuScroll = value ?? !danmakuScroll;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuScroll, danmakuScroll);
                    setState(() {});
                  },
                  title: Text('滚动弹幕', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuScroll,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuMassive = value ?? !danmakuMassive;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuMassive, danmakuMassive);
                    setState(() {});
                  },
                  title: Text('海量弹幕', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('弹幕过多时进行叠加绘制',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuMassive,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuDeduplication = value ?? !danmakuDeduplication;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuDeduplication,
                        danmakuDeduplication);
                    setState(() {});
                  },
                  title: Text('弹幕去重', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('相同内容弹幕过多时合并为一条弹幕',
                      style: TextStyle(fontFamily: fontFamily)),
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
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuBorder, danmakuBorder);
                    setState(() {});
                  },
                  title: Text('弹幕描边', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBorder,
                ),
                SettingsTile(
                  title:
                      Text('弹幕描边粗细', style: TextStyle(fontFamily: fontFamily)),
                  description: Slider(
                    value: defaultdanmakuBorderSize,
                    min: 0.1,
                    max: 3,
                    divisions: 29,
                    label: defaultdanmakuBorderSize.toStringAsFixed(1),
                    onChanged: (value) {
                      updateDanmakuBorderSize(
                          double.parse(value.toStringAsFixed(1)));
                    },
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuColor = value ?? !danmakuColor;
                    await GStorage.putSetting<bool>(
                        SettingsKeys.danmakuColor, danmakuColor);
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
                    max: isCompact() ? 32 : 48,
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
                  title:
                      Text('弹幕不透明度', style: TextStyle(fontFamily: fontFamily)),
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
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) => resetDanmakuSettings(),
                  title:
                      Text('恢复默认设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('将弹幕相关设置恢复为默认值',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
