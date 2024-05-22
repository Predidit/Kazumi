import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:provider/provider.dart';

class PluginShopPage extends StatefulWidget {
  const PluginShopPage({super.key});

  @override
  State<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends State<PluginShopPage> {
  late NavigationBarState navigationBarState;
  final PluginsController pluginsController = Modular.get<PluginsController>();

  void onBackPressed(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: const Text('规则仓库'),
        ),
        body: Observer(builder: (context) {
          return pluginsController.pluginHTTPList.isEmpty
              ? const Center(
                  child: Text('啊咧（⊙.⊙） 没有可用规则的说'),
                )
              : ListView.builder(
                  itemCount: pluginsController.pluginHTTPList.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(
                          pluginsController.pluginHTTPList[index].name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Version: ${pluginsController.pluginHTTPList[index].version}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: 
                        TextButton(
                          onPressed: () async {
                            if (pluginsController.pluginStatus(pluginsController.pluginHTTPList[index]) == 'install') {
                              try {
                                SmartDialog.showToast('导入中');
                                var pluginHTTPItem = await pluginsController.queryPluginHTTP(pluginsController.pluginHTTPList[index].name);
                                if (pluginHTTPItem != null) {
                                  await pluginsController.savePluginToJsonFile(pluginHTTPItem);
                                  pluginsController.loadPlugins();
                                  SmartDialog.showToast('导入成功');
                                }
                              } catch (e) {
                                SmartDialog.showToast('导入规则失败');
                              }
                            }
                            if (pluginsController.pluginStatus(pluginsController.pluginHTTPList[index]) == 'update') {
                              try {
                                SmartDialog.showToast('更新中');
                                var pluginHTTPItem = await pluginsController.queryPluginHTTP(pluginsController.pluginHTTPList[index].name);
                                if (pluginHTTPItem != null) {
                                  await pluginsController.savePluginToJsonFile(pluginHTTPItem);
                                  pluginsController.loadPlugins();
                                  SmartDialog.showToast('更新成功');
                                }
                              } catch (e) {
                                SmartDialog.showToast('更新规则失败');
                              }
                            }
                          },
                          child: Text(
                            pluginsController.pluginStatus(pluginsController.pluginHTTPList[index]) == 'install' ? '安装' : (pluginsController.pluginStatus(pluginsController.pluginHTTPList[index]) == 'installed') ? '已安装' : '更新'
                        ),)
                      ),
                    );
                  },
                );
        }),
      ),
    );
  }
}
