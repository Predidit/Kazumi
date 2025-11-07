import 'dart:io';

import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/mortis.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final exitBehaviorTitles = <String>['退出 Kazumi', '最小化至托盘', '每次都询问'];
  late dynamic defaultDanmakuArea;
  late dynamic defaultThemeMode;
  late dynamic defaultThemeColor;
  Box setting = GStorage.setting;
  late int exitBehavior =
      setting.get(SettingBoxKey.exitBehavior, defaultValue: 2);
  late bool autoUpdate;
  double _cacheSizeMB = -1;
  final MyController myController = Modular.get<MyController>();
  final MenuController menuController = MenuController();

  @override
  void initState() {
    super.initState();
    autoUpdate = setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    _getCacheSize();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  Future<Directory> _getCacheDir() async {
    Directory tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/libCachedImageData');
  }

  Future<void> _getCacheSize() async {
    Directory cacheDir = await _getCacheDir();

    if (await cacheDir.exists()) {
      int totalSizeBytes = await _getTotalSizeOfFilesInDir(cacheDir);
      double totalSizeMB = (totalSizeBytes / (1024 * 1024));

      if (mounted) {
        setState(() {
          _cacheSizeMB = totalSizeMB;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _cacheSizeMB = 0.0;
        });
      }
    }
  }

  Future<int> _getTotalSizeOfFilesInDir(final Directory directory) async {
    final List<FileSystemEntity> children = directory.listSync();
    int total = 0;

    try {
      for (final FileSystemEntity child in children) {
        if (child is File) {
          final int length = await child.length();
          total += length;
        } else if (child is Directory) {
          total += await _getTotalSizeOfFilesInDir(child);
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _clearCache() async {
    final Directory libCacheDir = await _getCacheDir();
    await libCacheDir.delete(recursive: true);
    _getCacheSize();
  }

  void _showCacheDialog() {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('缓存管理'),
          content: const Text('缓存为番剧封面, 清除后加载时需要重新下载,确认要清除缓存吗?'),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  _clearCache();
                } catch (_) {}
                KazumiDialog.dismiss();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('关于')),
        // backgroundColor: Colors.transparent,
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/about/license');
                  },
                  title: const Text('开源许可证'),
                  description: const Text('查看所有开源许可证'),
                ),
              ],
            ),
            SettingsSection(
              title: const Text('外部链接'),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.projectUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: const Text('项目主页'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.sourceUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: const Text('代码仓库'),
                  value: const Text('Github'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.iconUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: const Text('图标创作'),
                  value: const Text('Pixiv'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.bangumiIndex),
                        mode: LaunchMode.externalApplication);
                  },
                  title: const Text('番剧索引'),
                  value: const Text('Bangumi'),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    launchUrl(Uri.parse(Api.dandanIndex),
                        mode: LaunchMode.externalApplication);
                  },
                  title: const Text('弹幕来源'),
                  description: Text('ID: ${mortis['id']}'),
                  value: const Text('DanDanPlay'),
                ),
              ],
            ),
            if (Utils.isDesktop()) // 之后如果有非桌面平台的新选项可以移除
              SettingsSection(
                title: const Text('默认行为'),
                tiles: [
                  SettingsTile.navigation(
                    onPressed: (_) {
                      if (menuController.isOpen) {
                        menuController.close();
                      } else {
                        menuController.open();
                      }
                    },
                    title: const Text('关闭时'),
                    value: MenuAnchor(
                      consumeOutsideTap: true,
                      controller: menuController,
                      builder: (_, __, ___) {
                        return Text(exitBehaviorTitles[exitBehavior]);
                      },
                      menuChildren: [
                        for (int i = 0; i < 3; i++)
                          MenuItemButton(
                            requestFocusOnHover: false,
                            onPressed: () {
                              exitBehavior = i;
                              setting.put(SettingBoxKey.exitBehavior, i);
                              setState(() {});
                            },
                            child: Container(
                              height: 48,
                              constraints: BoxConstraints(minWidth: 112),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  exitBehaviorTitles[i],
                                  style: TextStyle(
                                    color: i == exitBehavior
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/about/logs');
                  },
                  title: const Text('错误日志'),
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    _showCacheDialog();
                  },
                  title: const Text('清除缓存'),
                  value: _cacheSizeMB == -1
                      ? const Text('统计中...')
                      : Text('${_cacheSizeMB.toStringAsFixed(2)}MB'),
                ),
              ],
            ),
            SettingsSection(
              title: const Text('应用更新'),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    autoUpdate = value ?? !autoUpdate;
                    await setting.put(SettingBoxKey.autoUpdate, autoUpdate);
                    setState(() {});
                  },
                  title: const Text('自动更新'),
                  initialValue: autoUpdate,
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    myController.checkUpdate();
                  },
                  title: const Text('检查更新'),
                  value: const Text('当前版本 ${Api.version}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
