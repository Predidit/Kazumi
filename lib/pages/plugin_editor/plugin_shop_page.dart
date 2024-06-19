import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';

class PluginShopPage extends StatefulWidget {
  const PluginShopPage({super.key});

  @override
  State<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends State<PluginShopPage> {
  dynamic navigationBarState;
  Box setting = GStorage.setting;
  late bool enableGitProxy;
  final PluginsController pluginsController = Modular.get<PluginsController>();

  void onBackPressed(BuildContext context) {
    // Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    enableGitProxy = setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
    if (Platform.isAndroid || Platform.isIOS) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(
          title: Text('规则仓库'),
        ),
        body: Observer(builder: (context) {
          return pluginsController.pluginHTTPList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('啊咧（⊙.⊙） 无法访问远程仓库 ${enableGitProxy ? '镜像已启用' : '镜像已禁用'}'),
                      TextButton(
                          onPressed: () {
                            Modular.to.pushNamed('/tab/my/other');
                          },
                          child: Text(enableGitProxy ? '禁用镜像' : '启用镜像'))
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: pluginsController.pluginHTTPList.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                pluginsController.pluginHTTPList[index].name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 1.0),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: Text(
                                  '${pluginsController.pluginHTTPList[index].version}',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface),
                                ),
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 1.0),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: Text(
                                  pluginsController
                                          .pluginHTTPList[index].useNativePlayer
                                      ? "native"
                                      : "webview",
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface),
                                ),
                              ),
                            ],
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              if (pluginsController.pluginStatus(
                                      pluginsController
                                          .pluginHTTPList[index]) ==
                                  'install') {
                                try {
                                  SmartDialog.showToast('导入中');
                                  var pluginHTTPItem = await pluginsController
                                      .queryPluginHTTP(pluginsController
                                          .pluginHTTPList[index].name);
                                  if (pluginHTTPItem != null) {
                                    await pluginsController
                                        .savePluginToJsonFile(pluginHTTPItem);
                                    pluginsController.loadPlugins();
                                    SmartDialog.showToast('导入成功');
                                    setState(() {});
                                  }
                                } catch (e) {
                                  SmartDialog.showToast('导入规则失败');
                                }
                              }
                              if (pluginsController.pluginStatus(
                                      pluginsController
                                          .pluginHTTPList[index]) ==
                                  'update') {
                                try {
                                  SmartDialog.showToast('更新中');
                                  var pluginHTTPItem = await pluginsController
                                      .queryPluginHTTP(pluginsController
                                          .pluginHTTPList[index].name);
                                  if (pluginHTTPItem != null) {
                                    await pluginsController
                                        .savePluginToJsonFile(pluginHTTPItem);
                                    pluginsController.loadPlugins();
                                    SmartDialog.showToast('更新成功');
                                    setState(() {});
                                  }
                                } catch (e) {
                                  SmartDialog.showToast('更新规则失败');
                                }
                              }
                            },
                            child: Text(pluginsController.pluginStatus(
                                        pluginsController
                                            .pluginHTTPList[index]) ==
                                    'install'
                                ? '安装'
                                : (pluginsController.pluginStatus(
                                            pluginsController
                                                .pluginHTTPList[index]) ==
                                        'installed')
                                    ? '已安装'
                                    : '更新'),
                          )),
                    );
                  },
                );
        }),
      ),
    );
  }
}
