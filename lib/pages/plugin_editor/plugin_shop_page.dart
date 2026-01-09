import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';

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

  // 排序方式状态：false=按更新时间排序，true=按名称排序
  bool sortByName = false;
  final PluginsController pluginsController = Modular.get<PluginsController>();

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    enableGitProxy =
        setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
  }

  // 刷新规则列表
  void _handleRefresh() async {
    if (!loading) {
      setState(() {
        loading = true;
        timeout = false;
      });
      enableGitProxy =
          setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
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

  // 切换排序方式
  void _toggleSort() {
    setState(() {
      sortByName = !sortByName;
    });
  }

  Widget get pluginHTTPListBody {
    return Observer(builder: (context) {
      // 创建列表副本用于排序
      var sortedList = List.from(pluginsController.pluginHTTPList);

      // 排序规则：
      // 1. 按名称排序：忽略大小写的字母顺序
      // 2. 按时间排序：更新时间降序（最新的在前面）
      if (sortByName) {
        sortedList.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else {
        sortedList.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
      }

      return ListView.builder(
        itemCount: sortedList.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ListTile(
                title: Row(
                  children: [
                    Text(
                      sortedList[index].name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Text(
                            sortedList[index].version,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.surface),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Text(
                            sortedList[index].useNativePlayer
                                ? "native"
                                : "webview",
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.surface),
                          ),
                        ),
                      ],
                    ),
                    if (sortedList[index].lastUpdate > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '更新时间: ${DateTime.fromMillisecondsSinceEpoch(sortedList[index].lastUpdate).toString().split('.')[0]}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                trailing: TextButton(
                  onPressed: () async {
                    if (pluginsController.pluginStatus(sortedList[index]) ==
                        'install') {
                      KazumiDialog.showToast(message: '导入中');
                      int res = await pluginsController
                          .tryUpdatePluginByName(sortedList[index].name);
                      if (res == 0) {
                        KazumiDialog.showToast(message: '导入成功');
                        setState(() {});
                      } else if (res == 1) {
                        KazumiDialog.showToast(
                            message: 'kazumi版本过低, 此规则不兼容当前版本');
                      } else if (res == 2) {
                        KazumiDialog.showToast(message: '导入规则失败');
                      }
                    }
                    if (pluginsController.pluginStatus(sortedList[index]) ==
                        'update') {
                      KazumiDialog.showToast(message: '更新中');
                      int res = await pluginsController
                          .tryUpdatePluginByName(sortedList[index].name);
                      if (res == 0) {
                        KazumiDialog.showToast(message: '更新成功');
                        setState(() {});
                      } else if (res == 1) {
                        KazumiDialog.showToast(
                            message: 'kazumi版本过低, 此规则不兼容当前版本');
                      } else if (res == 2) {
                        KazumiDialog.showToast(message: '更新规则失败');
                      }
                    }
                  },
                  child: Text(pluginsController
                              .pluginStatus(sortedList[index]) ==
                          'install'
                      ? '安装'
                      : (pluginsController.pluginStatus(sortedList[index]) ==
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
      child: GeneralErrorWidget(
        errMsg: '啊咧（⊙.⊙） 无法访问远程仓库\n${enableGitProxy ? '镜像已启用' : '镜像已禁用'}',
        actions: [
          GeneralErrorButton(
            onPressed: () {
              Modular.to.pushNamed('/settings/webdav/');
            },
            text: enableGitProxy ? '禁用镜像' : '启用镜像',
          ),
          GeneralErrorButton(
            onPressed: () {
              _handleRefresh();
            },
            text: '刷新',
          ),
        ],
      ),
    );
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
                onPressed: _toggleSort,
                tooltip: sortByName ? '按名称排序' : '按更新时间排序',
                icon:
                    Icon(sortByName ? Icons.sort_by_alpha : Icons.access_time)),
            IconButton(
                onPressed: () {
                  _handleRefresh();
                },
                tooltip: '刷新规则列表',
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
