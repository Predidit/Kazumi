import 'package:card_settings_ui/tile/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/initial_sync_mode.dart';
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
  final MenuController defaultPageMenuController = MenuController();
  late bool updateEnanbe;
  late bool downloadEnable;
  late bool deleteEnable;
  late bool debugEnable;
  late int syncMode;

  @override
  void initState() {
    super.initState();
    bangumiTokenController.text = setting.get(SettingBoxKey.bangumiAccessToken, defaultValue: '');
    updateEnanbe = setting.get(SettingBoxKey.bangumiUpdateEnable, defaultValue: true);
    downloadEnable = setting.get(SettingBoxKey.bangumiDownloadEnable, defaultValue: true);
    deleteEnable = setting.get(SettingBoxKey.bangumiDeleteEnable, defaultValue: false);
    debugEnable = setting.get(SettingBoxKey.bangumiSyncDebug, defaultValue: true);
    syncMode = setting.get(SettingBoxKey.bangumiFirstSyncMode, defaultValue: 0);
  }

  @override
  void dispose() {
    bangumiTokenController.dispose();
    super.dispose();
  }

  void updateSyncMode(int mode) {
    setting.put(SettingBoxKey.bangumiFirstSyncMode, mode);
    setState(() {
      syncMode = mode;
    });
  }

  Future<void> update() async {
    final bangumi = Bangumi();
    if (bangumi.initialized) {
      try { 
        await bangumi.ping();
        try {
          await bangumi.update();
        } catch (e) {
          KazumiDialog.showToast(message: "Bangumi上传失败");
        }
      } catch (e) {
        KazumiDialog.showToast(message: "Bangumi连接失败");
      }
    } else {
      KazumiDialog.showToast(message: "Bangumi 未启用同步或配置错误");
    }
  }

  Future<void> download() async {
    final bangumi = Bangumi();
    if (bangumi.initialized) {
      try {
        await bangumi.ping();
        try {
          await bangumi.download();
        } catch (e) {
          KazumiDialog.showToast(message: "Bangumi下载失败 ${e.toString()}");
        }
      } catch (e) {
        KazumiDialog.showToast(message: 'Bangumi连接失败');
      }
    } else {
      KazumiDialog.showToast(message: 'Bangumi 未启用同步或配置错误');
    }
  }

  Future<void> backup() async {
    final bangumi = Bangumi();
    if (debugEnable && bangumi.initialized) {
      bangumi.backup();
    } else {
      KazumiDialog.showToast(message: 'Bangumi 未启用或配置错误或未启用debug');
    }
  }

  // ({bool updateEnable, bool downloadEnable}) getUpdateAndDownloadSet() {
  //   final update = setting.get(SettingBoxKey.bangumiUpdateEnable, defaultValue: true);
  //   final download = setting.get(SettingBoxKey.bangumiDownloadEnable, defaultValue: true);
  //   return (updateEnable: update, downloadEnable: download);
  // }

  /// 复原数据
  Future<void> openFileRestore() async {
    if (debugEnable) {
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
    } else {
      KazumiDialog.showToast(message: '请先开启调试模式再尝试复原');
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
                    final syncEnable = setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
                    updateEnanbe = value ?? !updateEnanbe;
                    if (syncEnable && !(updateEnanbe && downloadEnable)) {
                      await setting.put(SettingBoxKey.bangumiSyncEnable, false);
                    }
                    await setting.put(
                      SettingBoxKey.bangumiUpdateEnable, updateEnanbe);
                    setState(() {});
                  },
                  title: Text('允许上传', style: TextStyle(fontFamily: fontFamily)), 
                  initialValue: updateEnanbe,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final syncEnable = setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
                    downloadEnable = value ?? !downloadEnable;
                    if (syncEnable && !(updateEnanbe && downloadEnable)) {
                      await setting.put(SettingBoxKey.bangumiSyncEnable, false);
                    }
                    await setting.put(
                        SettingBoxKey.bangumiDownloadEnable, downloadEnable);
                    setState(() {});
                  },
                  title: Text('允许下载', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: downloadEnable,
                ),
                SettingsTile.switchTile(
                  enabled: false,
                  onToggle: (value) async {
                    // FUTURE
                  },
                  title: Text('允许同步时，删除本地收藏', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: deleteEnable,
                ),
                SettingsTile.switchTile(
                  enabled: false,
                  onToggle: (value) async {
                    setState(() {
                      debugEnable = value ?? !debugEnable;
                    });
                    await setting.put(
                      SettingBoxKey.bangumiSyncDebug, debugEnable
                    );
                  }, 
                  title: Text('调试模式', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('开启后，进行第一次bgm同步前，会备份数据'),
                  initialValue: debugEnable, 
                ),
                SettingsTile.navigation(
                  description: Text('暂未生效'),
                  enabled: false,
                  onPressed: (_) async {
                    if (defaultPageMenuController.isOpen) {
                      defaultPageMenuController.close();
                    } else {
                      defaultPageMenuController.open();
                    }
                  },
                  title: Text('第一次同步收藏的 优先级', style: TextStyle(fontFamily: fontFamily)),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: defaultPageMenuController,
                    builder: (context, controller, child) => Text(
                      InitialSyncMode.fromInt(syncMode).label,
                      style: TextStyle(fontFamily: fontFamily)
                    ),
                    menuChildren: [
                      for (final entry in InitialSyncMode.values)
                        MenuItemButton(
                          requestFocusOnHover: false,
                          onPressed: () => updateSyncMode(entry.value),
                          child: Container(
                            height: 48,
                            constraints: BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                entry.label,
                                style: TextStyle(
                                  color: entry.value == syncMode
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
                  trailing: const Icon(Icons.cloud_upload_rounded),
                  onPressed: (_) async {
                    await update();
                  },
                  title: Text("手动上传"),
                ),
                SettingsTile(
                  trailing: const Icon(Icons.cloud_download_rounded),
                  onPressed: (_) async {
                    await download();
                  },
                  title: Text("手动下载"),
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
          if (!bangumi.initialized || bangumi.token != token) {
            try {
              await bangumi.init();
            } catch (e) {
              KazumiDialog.showToast(message: '验证失败：${e.toString()}');
              await setting.put(SettingBoxKey.bangumiSyncEnable, false);
            }
            KazumiDialog.showToast(message: '配置成功, 开始测试');
            try {
              await bangumi.ping();
              KazumiDialog.showToast(message: '测试成功');
            } catch (e) {
              KazumiDialog.showToast(message: '测试失败 ${e.toString()}');
              await setting.put(SettingBoxKey.bangumiSyncEnable, false);
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
