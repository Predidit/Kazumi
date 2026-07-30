import 'dart:io';

import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/utils/dandan_credentials.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kazumi/utils/device.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    required this.controller,
  });

  final MyController controller;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final exitBehaviorTitles = <String>['退出 Kazumi', '最小化至托盘', '每次都询问'];
  late dynamic defaultDanmakuArea;
  late dynamic defaultThemeMode;
  late dynamic defaultThemeColor;
  late int exitBehavior = GStorage.getSetting(SettingsKeys.exitBehavior);
  late bool autoUpdate;
  late bool checkPluginUpdateOnStartup;
  double _cacheSizeMB = -1;
  MyController get myController => widget.controller;
  final MenuController menuController = MenuController();

  @override
  void initState() {
    super.initState();
    autoUpdate = GStorage.getSetting(SettingsKeys.autoUpdate);
    checkPluginUpdateOnStartup =
        GStorage.getSetting(SettingsKeys.checkPluginUpdateOnStartup);
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
      child: SettingsDetailScaffold(
        title: const Text('关于'),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: Text('开源'),
              tiles: [
                SettingsTile(
                  leading: Icons.gavel_rounded,
                  onPressed: (_) {
                    context.pushNamed('/settings/about/license');
                  },
                  title: Text('开源许可证'),
                  description: Text('查看所有开源许可证'),
                ),
              ],
            ),
            SettingsSection(
              title: Text('外部链接'),
              tiles: [
                SettingsTile(
                  leading: Icons.home_rounded,
                  onPressed: (_) {
                    launchUrl(Uri.parse(ApiEndpoints.projectUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text('项目主页'),
                ),
                SettingsTile(
                  leading: Icons.code_rounded,
                  onPressed: (_) {
                    launchUrl(Uri.parse(ApiEndpoints.sourceUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text('代码仓库'),
                  value: Text('Github'),
                ),
                SettingsTile(
                  leading: Icons.brush_rounded,
                  onPressed: (_) {
                    launchUrl(Uri.parse(ApiEndpoints.iconUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text('图标创作'),
                  value: Text('Pixiv'),
                ),
                SettingsTile(
                  leading: Icons.menu_book_rounded,
                  onPressed: (_) {
                    launchUrl(Uri.parse(ApiEndpoints.bangumiIndex),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text('番剧索引'),
                  value: Text('Bangumi'),
                ),
                SettingsTile(
                  leading: Icons.image_search_rounded,
                  onPressed: (_) {
                    launchUrl(Uri.parse('https://trace.moe'),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text('以图搜番'),
                  value: Text('trace.moe'),
                ),
                SettingsTile(
                  leading: Icons.subtitles_rounded,
                  onPressed: (_) {
                    launchUrl(Uri.parse(ApiEndpoints.dandanIndex),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text('弹幕来源'),
                  description: Text('ID: ${dandanCredentials['id']}'),
                  value: Text('弹弹play开放平台'),
                ),
              ],
            ),
            SettingsSection(
              title: Text('社区'),
              tiles: [
                SettingsTile(
                  leading: Icons.send_rounded,
                  onPressed: (_) {
                    launchUrl(Uri.parse(ApiEndpoints.telegramGroup),
                        mode: LaunchMode.externalApplication);
                  },
                  title: Text('Telegram'),
                  value: Text('点击加入'),
                ),
              ],
            ),
            if (isDesktop()) // 之后如果有非桌面平台的新选项可以移除
              SettingsSection(
                title: Text('默认行为'),
                tiles: [
                  SettingsTile(
                    leading: Icons.exit_to_app_rounded,
                    onPressed: (_) {
                      if (menuController.isOpen) {
                        menuController.close();
                      } else {
                        menuController.open();
                      }
                    },
                    title: Text('关闭时'),
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
                              GStorage.putSetting(SettingsKeys.exitBehavior, i);
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
              title: Text('存储与日志'),
              tiles: [
                SettingsTile(
                  leading: Icons.receipt_long_rounded,
                  onPressed: (_) {
                    context.pushNamed('/settings/about/logs');
                  },
                  title: Text('错误日志'),
                ),
                SettingsTile(
                  leading: Icons.cleaning_services_rounded,
                  onPressed: (_) {
                    _showCacheDialog();
                  },
                  title: Text('清除缓存'),
                  value: _cacheSizeMB == -1
                      ? Text('统计中...')
                      : Text('${_cacheSizeMB.toStringAsFixed(2)}MB'),
                ),
              ],
            ),
            SettingsSection(
              title: Text('应用更新'),
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.update_rounded,
                  onToggle: (value) async {
                    autoUpdate = value ?? !autoUpdate;
                    await GStorage.putSetting(
                        SettingsKeys.autoUpdate, autoUpdate);
                    setState(() {});
                  },
                  title: Text('启动时检查应用更新'),
                  initialValue: autoUpdate,
                ),
                SettingsTile(
                  leading: Icons.system_update_rounded,
                  onPressed: (_) {
                    myController.checkUpdate();
                  },
                  title: Text('检查应用更新'),
                  value: Text('当前版本 ${ApiEndpoints.version}'),
                ),
              ],
            ),
            SettingsSection(
              title: Text('规则更新'),
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.extension_rounded,
                  onToggle: (value) async {
                    checkPluginUpdateOnStartup =
                        value ?? !checkPluginUpdateOnStartup;
                    await GStorage.putSetting(
                      SettingsKeys.checkPluginUpdateOnStartup,
                      checkPluginUpdateOnStartup,
                    );
                    setState(() {});
                  },
                  title: Text('启动时检查规则更新'),
                  initialValue: checkPluginUpdateOnStartup,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
