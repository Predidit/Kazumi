import 'package:card_settings_ui/tile/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/utils/bangumi.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:url_launcher/url_launcher.dart';

class BangumiEditorPage extends StatefulWidget {
  const BangumiEditorPage({super.key});

  @override
  State<BangumiEditorPage> createState() => _BangumiEditorPageState();
}

class _BangumiEditorPageState extends State<BangumiEditorPage> {
  final TextEditingController bangumiTokenController = TextEditingController();
  Box setting = GStorage.setting;
  bool passwordVisible = false;
  bool isVerifying = false;
  late bool bangumiImmediateSyncToastEnable;
  late int syncPriority;
  bool syncCollectiblesing = false;
  final MenuController syncPriorityMenuController = MenuController();

  @override
  void initState() {
    super.initState();
    bangumiTokenController.text = setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');
    bangumiImmediateSyncToastEnable = setting.get(
      SettingBoxKey.bangumiImmediateSyncToastEnable,
      defaultValue: true,
    );
    syncPriority = setting.get(SettingBoxKey.bangumiSyncPriority, defaultValue: 1);
  }

  @override
  void dispose() {
    bangumiTokenController.dispose();
    super.dispose();
  }

  void updateSyncPriority(int value) {
    setting.put(SettingBoxKey.bangumiSyncPriority, value);
    setState(() {
      syncPriority = value;
    });
  }

  Future<void> syncWithProgress() async {
    final ValueNotifier<double?> progressValue = ValueNotifier<double?>(null);
    final ValueNotifier<String> progressText =
        ValueNotifier<String>('准备同步 Bangumi 状态...');

    try {
      setState(() {
        syncCollectiblesing = true;
      });

      KazumiDialog.show(
        clickMaskDismiss: false,
        builder: (context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bangumi 同步进行中',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<String>(
                      valueListenable: progressText,
                      builder: (_, value, __) => Text(value),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<double?>(
                      valueListenable: progressValue,
                      builder: (_, value, __) => LinearProgressIndicator(value: value),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final bangumi = Bangumi();
      await bangumi.ping();
      await bangumi.syncCollectibles(
        force: true,
        onProgress: (message, current, total) {
          progressText.value = total > 0 ? '$message ($current/$total)' : message;
          if (total > 0) {
            progressValue.value = (current / total).clamp(0.0, 1.0);
          } else {
            progressValue.value = null;
          }
        },
      );
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi同步失败 $e');
    } finally {
      progressValue.dispose();
      progressText.dispose();
      if (KazumiDialog.observer.hasKazumiDialog) {
        KazumiDialog.dismiss();
      }
      if (mounted) {
        setState(() {
          syncCollectiblesing = false;
        });
      }
    }
  }

  Future<void> backup() async {
    final bangumi = Bangumi();
    if (bangumi.initialized) {
      bangumi.backup();
    } else {
      KazumiDialog.showToast(message: 'Bangumi 未启用或配置错误');
    }
  }

  /// 复原数据
  Future<void> openFileRestore() async {
    var bangumi = Bangumi();
    try {
      await bangumi.ping();
      try {
        await bangumi.openFolderRestore();
        KazumiDialog.showToast(message: '文件夹已打开');
      } catch (e) {
        KazumiDialog.showToast(message: '文件夹打开失败 ${e.toString()}');
      }
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi访问失败 ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(title: Text('Bangumi 高级配置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: Column(
              children: [
                TextField(
                  controller: bangumiTokenController,
                  obscureText: !passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'bangumi Access Token',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          passwordVisible = !passwordVisible;
                        });
                      },
                      icon: Icon(passwordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    bangumiImmediateSyncToastEnable =
                        value ?? !bangumiImmediateSyncToastEnable;
                    await setting.put(
                      SettingBoxKey.bangumiImmediateSyncToastEnable,
                      bangumiImmediateSyncToastEnable,
                    );
                    if (mounted) {
                      setState(() {});
                    }
                  }, 
                  title: Text('即时同步提示', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('点击追番按钮触发即时同步时显示提示'),
                  initialValue: bangumiImmediateSyncToastEnable,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    if (syncPriorityMenuController.isOpen) {
                      syncPriorityMenuController.close();
                    } else {
                      syncPriorityMenuController.open();
                    }
                  },
                  title: Text('同步优先级', style: TextStyle(fontFamily: fontFamily)),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: syncPriorityMenuController,
                    builder: (context, controller, child) => Text(
                      BangumiSyncPriority.fromValue(syncPriority).label,
                      style: TextStyle(fontFamily: fontFamily)
                    ),
                    menuChildren: [
                      for (final entry in BangumiSyncPriority.values)
                        MenuItemButton(
                          requestFocusOnHover: false,
                          onPressed: () => updateSyncPriority(entry.value),
                          child: Container(
                            height: 48,
                            constraints: BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                entry.label,
                                style: TextStyle(
                                  color: entry.value == syncPriority
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            )
                          )
                        )
                    ]
                  ),
                ),
                SettingsTile(
                  trailing: syncCollectiblesing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  onPressed: (_) async {
                    await syncWithProgress();
                  },
                  title: Text("立即同步状态"),
                  description: Text('仅同步状态不一致条目'),
                ),
                SettingsTile(
                  onPressed: (_) async {
                    try {
                      await backup();
                      KazumiDialog.showToast(message: "备份成功");
                    } catch (e) {
                      KazumiDialog.showToast(message: "备份失败 ${e.toString()}");
                    }
                  },
                  title: Text("立即备份"),
                  description: Text("会覆盖上次的备份"),
                ),
                SettingsTile(
                  // trailing: const Icon(Icons.delete),
                  onPressed: (_) async {
                    setting.put(SettingBoxKey.bangumiLastSyncUsername, "");
                    await openFileRestore();
                  },
                  title: Text('手动进行复原收藏', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('目前不支持多用户备份。', style: TextStyle(fontFamily: fontFamily)),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://next.bgm.tv/demo/access-token');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      KazumiDialog.showToast(message: '无法打开链接');
                    }
                  },
                  child: Text(
                    '你可以点击此处前往 Bangumi 生成 Access Token',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontFamily: fontFamily,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isVerifying ? null : () async {
          final token = bangumiTokenController.text;
          if (token.isEmpty) {
            KazumiDialog.showToast(message: 'Access Token 不能为空');
            return;
          }
          setState(() {
            isVerifying = true;
          });
          await setting.put(
            SettingBoxKey.bangumiAccessToken, token);
          final bangumi = Bangumi();
          bool initSuccess = true;
          if (!bangumi.initialized || bangumi.token != token) {
            try {
              await bangumi.init();
            } catch (e) {
              initSuccess = false;
              KazumiDialog.showToast(message: '验证失败：${e.toString()}');
              await setting.put(SettingBoxKey.bangumiSyncEnable, false);
            }
            if (initSuccess) {
              KazumiDialog.showToast(message: '配置成功, 开始测试');
              try {
                await bangumi.ping();
                KazumiDialog.showToast(message: '测试成功');
              } catch (e) {
                KazumiDialog.showToast(message: '测试失败 ${e.toString()}');
                await setting.put(SettingBoxKey.bangumiSyncEnable, false);
              }
            }
          }
          if (!mounted) return;
          setState(() {
            isVerifying = false;
          });
        },
        child: const Icon(Icons.save),
      ),
    );
  }
}
