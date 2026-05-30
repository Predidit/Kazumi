import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:hive_ce/hive.dart';
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
  Box setting = GStorage.setting;
  late dynamic defaultDanmakuArea;
  late dynamic defaultDanmakuOpacity;
  late dynamic defaultDanmakuFontSize;
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
    defaultDanmakuArea =
        setting.get(SettingBoxKey.danmakuArea, defaultValue: 1.0);
    defaultDanmakuOpacity =
        setting.get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0);
    defaultDanmakuFontSize = setting.get(SettingBoxKey.danmakuFontSize,
        defaultValue: (isCompact()) ? 16.0 : 25.0);
    defaultDanmakuFontWeight =
        setting.get(SettingBoxKey.danmakuFontWeight, defaultValue: 4);
    defaultDanmakuDuration =
        setting.get(SettingBoxKey.danmakuDuration, defaultValue: 8.0);
    defaultDanmakuLineHeight =
        setting.get(SettingBoxKey.danmakuLineHeight, defaultValue: 1.6);
    danmakuBorder =
        setting.get(SettingBoxKey.danmakuBorder, defaultValue: true);
    defaultdanmakuBorderSize =
        setting.get(SettingBoxKey.danmakuBorderSize, defaultValue: 1.5);
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

  void updateDanmakuBorderSize(double i) async {
    await setting.put(SettingBoxKey.danmakuBorderSize, i);
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
        appBar: const SysAppBar(title: Text('Danmaku settings')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              title: Text('Danmaku source', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuBiliBiliSource = value ?? !danmakuBiliBiliSource;
                    await setting.put(SettingBoxKey.danmakuBiliBiliSource,
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
                    await setting.put(
                        SettingBoxKey.danmakuGamerSource, danmakuGamerSource);
                    setState(() {});
                  },
                  title:
                      Text('Gamer', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuGamerSource,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuDanDanSource = value ?? !danmakuDanDanSource;
                    await setting.put(
                        SettingBoxKey.danmakuDanDanSource, danmakuDanDanSource);
                    setState(() {});
                  },
                  title:
                      Text('DanDan', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuDanDanSource,
                ),
              ],
            ),
            SettingsSection(
              title: Text('Danmaku blocking', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/danmaku/shield');
                  },
                  title:
                      Text('Keyword blocking', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('Danmaku display', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  title: Text('Danmaku area', style: TextStyle(fontFamily: fontFamily)),
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
                      Text('Danmaku duration', style: TextStyle(fontFamily: fontFamily)),
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
                  title: Text('Danmaku line height', style: TextStyle(fontFamily: fontFamily)),
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
                    await setting.put(
                        SettingBoxKey.danmakuFollowSpeed, danmakuFollowSpeed);
                    setState(() {});
                  },
                  title: Text('Danmaku follows playback speed',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('When enabled, danmaku speed changes with playback speed',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuFollowSpeed,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuTop = value ?? !danmakuTop;
                    await setting.put(SettingBoxKey.danmakuTop, danmakuTop);
                    setState(() {});
                  },
                  title: Text('Top danmaku', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuTop,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuBottom = value ?? !danmakuBottom;
                    await setting.put(
                        SettingBoxKey.danmakuBottom, danmakuBottom);
                    setState(() {});
                  },
                  title: Text('Bottom danmaku', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBottom,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuScroll = value ?? !danmakuScroll;
                    await setting.put(
                        SettingBoxKey.danmakuScroll, danmakuScroll);
                    setState(() {});
                  },
                  title: Text('Scrolling danmaku', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuScroll,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuMassive = value ?? !danmakuMassive;
                    await setting.put(
                        SettingBoxKey.danmakuMassive, danmakuMassive);
                    setState(() {});
                  },
                  title: Text('Massive danmaku', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Overlap danmaku when there are too many',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuMassive,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuDeduplication = value ?? !danmakuDeduplication;
                    await setting.put(SettingBoxKey.danmakuDeduplication,
                        danmakuDeduplication);
                    setState(() {});
                  },
                  title: Text('Danmaku deduplication', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Merge identical danmaku into one when there are too many',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuDeduplication,
                ),
              ],
            ),
            SettingsSection(
              title: Text('Danmaku style', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    danmakuBorder = value ?? !danmakuBorder;
                    await setting.put(
                        SettingBoxKey.danmakuBorder, danmakuBorder);
                    setState(() {});
                  },
                  title: Text('Danmaku outline', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuBorder,
                ),
                SettingsTile(
                  title:
                      Text('Danmaku outline thickness', style: TextStyle(fontFamily: fontFamily)),
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
                    await setting.put(SettingBoxKey.danmakuColor, danmakuColor);
                    setState(() {});
                  },
                  title: Text('Danmaku color', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: danmakuColor,
                ),
                SettingsTile(
                  title: Text('Font size', style: TextStyle(fontFamily: fontFamily)),
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
                  title: Text('Font weight', style: TextStyle(fontFamily: fontFamily)),
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
                      Text('Danmaku opacity', style: TextStyle(fontFamily: fontFamily)),
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
