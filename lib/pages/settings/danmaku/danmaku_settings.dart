import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/constants.dart';
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
  final PopularController popularController = Modular.get<PopularController>();
  late bool danmakuEnabledByDefault;
  late bool danmakuBorder;
  late bool danmakuTop;
  late bool danmakuBottom;
  late bool danmakuScroll;
  late bool danmakuColor;
  late bool danmakuMassive;
  late bool danmakuBiliBiliSource;
  late bool danmakuGamerSource;
  late bool danmakuDanDanSource;

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
    danmakuEnabledByDefault =
        setting.get(SettingBoxKey.danmakuEnabledByDefault, defaultValue: false);
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
    danmakuBiliBiliSource =
        setting.get(SettingBoxKey.danmakuBiliBiliSource, defaultValue: true);
    danmakuGamerSource =
        setting.get(SettingBoxKey.danmakuGamerSource, defaultValue: true);
    danmakuDanDanSource =
        setting.get(SettingBoxKey.danmakuDanDanSource, defaultValue: true);
  }

  void onBackPressed(BuildContext context) {
    // Navigator.of(context).pop();
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

  void updateDanmakuFontWeight(int i) async {
    await setting.put(SettingBoxKey.danmakuFontWeight, i);
    setState(() {
      defaultDanmakuFontWeight = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('弹幕设置')),
        body: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: SettingsList(
              sections: [
                SettingsSection(
                  title: const Text('弹幕'),
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuEnabledByDefault =
                            value ?? !danmakuEnabledByDefault;
                        await setting.put(SettingBoxKey.danmakuEnabledByDefault,
                            danmakuEnabledByDefault);
                        setState(() {});
                      },
                      title: const Text('默认开启'),
                      description: const Text('默认是否随视频播放弹幕'),
                      initialValue: danmakuEnabledByDefault,
                    ),
                  ],
                ),
                SettingsSection(
                  title: const Text('弹幕来源'),
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuBiliBiliSource = value ?? !danmakuBiliBiliSource;
                        await setting.put(SettingBoxKey.danmakuBiliBiliSource,
                            danmakuBiliBiliSource);
                        setState(() {});
                      },
                      title: const Text('BiliBili'),
                      initialValue: danmakuBiliBiliSource,
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuGamerSource = value ?? !danmakuGamerSource;
                        await setting.put(SettingBoxKey.danmakuGamerSource,
                            danmakuGamerSource);
                        setState(() {});
                      },
                      title: const Text('Gamer'),
                      initialValue: danmakuGamerSource,
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuDanDanSource = value ?? !danmakuDanDanSource;
                        await setting.put(SettingBoxKey.danmakuDanDanSource,
                            danmakuDanDanSource);
                        setState(() {});
                      },
                      title: const Text('DanDan'),
                      initialValue: danmakuDanDanSource,
                    ),
                  ],
                ),
                SettingsSection(
                  title: const Text('弹幕显示'),
                  tiles: [
                    SettingsTile.navigation(
                      onPressed: (_) async {
                        KazumiDialog.show(builder: (context) {
                          return AlertDialog(
                            title: const Text('弹幕区域'),
                            content: StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              return Wrap(
                                spacing: 8,
                                runSpacing: Utils.isDesktop() ? 8 : 0,
                                children: [
                                  for (final double i
                                  in danAreaList) ...<Widget>[
                                    if (i == defaultDanmakuArea) ...<Widget>[
                                      FilledButton(
                                        onPressed: () async {
                                          updateDanmakuArea(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ] else ...[
                                      FilledButton.tonal(
                                        onPressed: () async {
                                          updateDanmakuArea(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ]
                                  ]
                                ],
                              );
                            }),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => KazumiDialog.dismiss(),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  updateDanmakuArea(1.0);
                                  KazumiDialog.dismiss();
                                },
                                child: const Text('默认设置'),
                              ),
                            ],
                          );
                        });
                      },
                      title: const Text('弹幕区域'),
                      value: Text('占据 $defaultDanmakuArea 屏幕'),
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuTop = value ?? !danmakuTop;
                        await setting.put(SettingBoxKey.danmakuTop, danmakuTop);
                        setState(() {});
                      },
                      title: const Text('顶部弹幕'),
                      initialValue: danmakuTop,
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuBottom = value ?? !danmakuBottom;
                        await setting.put(
                            SettingBoxKey.danmakuBottom, danmakuBottom);
                        setState(() {});
                      },
                      title: const Text('底部弹幕'),
                      initialValue: danmakuBottom,
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuScroll = value ?? !danmakuScroll;
                        await setting.put(
                            SettingBoxKey.danmakuScroll, danmakuScroll);
                        setState(() {});
                      },
                      title: const Text('滚动弹幕'),
                      initialValue: danmakuScroll,
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuMassive = value ?? !danmakuMassive;
                        await setting.put(
                            SettingBoxKey.danmakuMassive, danmakuMassive);
                        setState(() {});
                      },
                      title: const Text('海量弹幕'),
                      description: const Text('弹幕过多时进行叠加绘制'),
                      initialValue: danmakuMassive,
                    ),
                  ],
                ),
                SettingsSection(
                  title: const Text('弹幕样式'),
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuBorder = value ?? !danmakuBorder;
                        await setting.put(
                            SettingBoxKey.danmakuBorder, danmakuBorder);
                        setState(() {});
                      },
                      title: const Text('弹幕描边'),
                      initialValue: danmakuBorder,
                    ),
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        danmakuColor = value ?? !danmakuColor;
                        await setting.put(
                            SettingBoxKey.danmakuColor, danmakuColor);
                        setState(() {});
                      },
                      title: const Text('弹幕颜色'),
                      initialValue: danmakuColor,
                    ),
                    SettingsTile.navigation(
                      onPressed: (_) async {
                        KazumiDialog.show(builder: (context) {
                          return AlertDialog(
                            title: const Text('字体大小'),
                            content: StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              return Wrap(
                                spacing: 8,
                                runSpacing: Utils.isDesktop() ? 8 : 0,
                                children: [
                                  for (final double i
                                      in danFontList) ...<Widget>[
                                    if (i ==
                                        defaultDanmakuFontSize) ...<Widget>[
                                      FilledButton(
                                        onPressed: () async {
                                          updateDanmakuFontSize(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ] else ...[
                                      FilledButton.tonal(
                                        onPressed: () async {
                                          updateDanmakuFontSize(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ]
                                  ]
                                ],
                              );
                            }),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => KazumiDialog.dismiss(),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  updateDanmakuFontSize(
                                      (Utils.isCompact()) ? 16.0 : 25.0);
                                  KazumiDialog.dismiss();
                                },
                                child: const Text('默认设置'),
                              ),
                            ],
                          );
                        });
                      },
                      title: const Text('字体大小'),
                      value: Text('$defaultDanmakuFontSize'),
                    ),
                    SettingsTile.navigation(
                      onPressed: (_) async {
                        KazumiDialog.show(builder: (context) {
                          return AlertDialog(
                            title: const Text('字体字重'),
                            content: StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              return Wrap(
                                spacing: 8,
                                runSpacing: Utils.isDesktop() ? 8 : 0,
                                children: [
                                  for (final int i
                                      in danFontWeightList) ...<Widget>[
                                    if (i ==
                                        defaultDanmakuFontWeight) ...<Widget>[
                                      FilledButton(
                                        onPressed: () async {
                                          updateDanmakuFontWeight(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ] else ...[
                                      FilledButton.tonal(
                                        onPressed: () async {
                                          updateDanmakuFontWeight(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ]
                                  ]
                                ],
                              );
                            }),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => KazumiDialog.dismiss(),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  updateDanmakuFontWeight(4);
                                  KazumiDialog.dismiss();
                                },
                                child: const Text('默认设置'),
                              ),
                            ],
                          );
                        });
                      },
                      title: const Text('字体字重'),
                      value: Text('$defaultDanmakuFontWeight'),
                    ),
                    SettingsTile.navigation(
                      onPressed: (_) async {
                        KazumiDialog.show(builder: (context) {
                          return AlertDialog(
                            title: const Text('弹幕不透明度'),
                            content: StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              return Wrap(
                                spacing: 8,
                                runSpacing: Utils.isDesktop() ? 8 : 0,
                                children: [
                                  for (final double i
                                      in danOpacityList) ...<Widget>[
                                    if (i == defaultDanmakuOpacity) ...<Widget>[
                                      FilledButton(
                                        onPressed: () async {
                                          updateDanmakuOpacity(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ] else ...[
                                      FilledButton.tonal(
                                        onPressed: () async {
                                          updateDanmakuOpacity(i);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Text(i.toString()),
                                      ),
                                    ]
                                  ]
                                ],
                              );
                            }),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => KazumiDialog.dismiss(),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  updateDanmakuOpacity(1.0);
                                  KazumiDialog.dismiss();
                                },
                                child: const Text('默认设置'),
                              ),
                            ],
                          );
                        });
                      },
                      title: const Text('弹幕不透明度'),
                      value: Text('$defaultDanmakuOpacity'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
