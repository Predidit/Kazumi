import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/request/api.dart';

class PluginShopPage extends StatefulWidget {
  const PluginShopPage({super.key});

  @override
  State<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends State<PluginShopPage> {
  Box setting = GStorage.setting;
  bool timeout = false;
  bool loading = false;
  late bool enableGitProxy;
  final PluginsController pluginsController = Modular.get<PluginsController>();

  void onBackPressed(BuildContext context) {
    // Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    enableGitProxy =
        setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
  }

  void _handleRefresh() async {
    if (!loading) {
      setState(() {
        loading = true;
        timeout = false;
      });
      pluginsController.queryPluginHTTPList().then((_) {
        setState(() {
          loading = false;
        });
        if (pluginsController.pluginHTTPList.isEmpty) {
          setState(() {
            timeout = true;
          });
        }
      });
    }
  }

  Widget get pluginHTTPListBody {
    return Observer(builder: (context) {
      return ListView.builder(
        itemCount: pluginsController.pluginHTTPList.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ListTile(
                title: Row(
                  children: [
                    Text(
                      pluginsController.pluginHTTPList[index].name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 1.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Text(
                        pluginsController.pluginHTTPList[index].version,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.surface),
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
                        pluginsController.pluginHTTPList[index].useNativePlayer
                            ? "native"
                            : "webview",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.surface),
                      ),
                    ),
                  ],
                ),
                trailing: TextButton(
                  onPressed: () async {
                    if (pluginsController.pluginStatus(
                            pluginsController.pluginHTTPList[index]) ==
                        'install') {
                      try {
                        SmartDialog.showToast('导入中');
                        var pluginHTTPItem =
                            await pluginsController.queryPluginHTTP(
                                pluginsController.pluginHTTPList[index].name);
                        if (pluginHTTPItem != null) {
                          if (int.parse(pluginHTTPItem.api) > Api.apiLevel) {
                            SmartDialog.showToast('kazumi版本过低, 此规则不兼容当前版本');
                            return;
                          }
                          await pluginsController
                              .savePluginToJsonFile(pluginHTTPItem);
                          await pluginsController.loadPlugins();
                          SmartDialog.showToast('导入成功');
                          setState(() {});
                        }
                      } catch (e) {
                        SmartDialog.showToast('导入规则失败');
                      }
                    }
                    if (pluginsController.pluginStatus(
                            pluginsController.pluginHTTPList[index]) ==
                        'update') {
                      try {
                        SmartDialog.showToast('更新中');
                        var pluginHTTPItem =
                            await pluginsController.queryPluginHTTP(
                                pluginsController.pluginHTTPList[index].name);
                        if (pluginHTTPItem != null) {
                          if (int.parse(pluginHTTPItem.api) > Api.apiLevel) {
                            SmartDialog.showToast('kazumi版本过低, 此规则不兼容当前版本');
                            return;
                          }
                          await pluginsController
                              .savePluginToJsonFile(pluginHTTPItem);
                          await pluginsController.loadPlugins();
                          SmartDialog.showToast('更新成功');
                          setState(() {});
                        }
                      } catch (e) {
                        SmartDialog.showToast('更新规则失败');
                      }
                    }
                  },
                  child: Text(pluginsController.pluginStatus(
                              pluginsController.pluginHTTPList[index]) ==
                          'install'
                      ? '安装'
                      : (pluginsController.pluginStatus(
                                  pluginsController.pluginHTTPList[index]) ==
                              'installed')
                          ? '已安装'
                          : '更新'),
                )),
          );
        },
      );
    });
  }

  Widget get timeoutWidget {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('啊咧（⊙.⊙） 无法访问远程仓库 ${enableGitProxy ? '镜像已启用' : '镜像已禁用'}'),
        const SizedBox(
          height: 10,
        ),
        FilledButton.tonal(
            onPressed: () {
              Modular.to.pushNamed('/settings/other');
            },
            child: Text(enableGitProxy ? '禁用镜像' : '启用镜像')),
        const SizedBox(
          height: 10,
        ),
        FilledButton.tonal(
            onPressed: () {
              _handleRefresh();
            },
            child: const Text('刷新'))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: const Text('规则仓库'),
          actions: [
            IconButton(
                onPressed: () {
                  _handleRefresh();
                },
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: loading
            ? (const Center(child: CircularProgressIndicator()))
            : (pluginsController.pluginHTTPList.isEmpty
                ? timeoutWidget
                : pluginHTTPListBody),
      ),
    );
  }
}
