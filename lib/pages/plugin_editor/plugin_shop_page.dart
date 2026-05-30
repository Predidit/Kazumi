import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/storage/storage.dart';

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
                        if (sortedList[index].antiCrawlerEnabled) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            child: Text(
                              'captcha',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onTertiary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (sortedList[index].lastUpdate > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Updated: ${DateTime.fromMillisecondsSinceEpoch(sortedList[index].lastUpdate).toString().split('.')[0]}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                trailing: TextButton(
                  onPressed: () async {
                    if (pluginsController.pluginStatus(sortedList[index]) ==
                        'install') {
                      KazumiDialog.showToast(message: 'Importing');
                      int res = await pluginsController
                          .tryUpdatePluginByName(sortedList[index].name);
                      if (res == 0) {
                        KazumiDialog.showToast(message: 'Import succeeded');
                        setState(() {});
                      } else if (res == 1) {
                        KazumiDialog.showToast(
                            message: 'Kazumi version is too low, this rule is not compatible with the current version');
                      } else if (res == 2) {
                        KazumiDialog.showToast(message: 'Failed to import rule');
                      }
                    }
                    if (pluginsController.pluginStatus(sortedList[index]) ==
                        'update') {
                      KazumiDialog.showToast(message: 'Updating');
                      int res = await pluginsController
                          .tryUpdatePluginByName(sortedList[index].name);
                      if (res == 0) {
                        KazumiDialog.showToast(message: 'Update succeeded');
                        setState(() {});
                      } else if (res == 1) {
                        KazumiDialog.showToast(
                            message: 'Kazumi version is too low, this rule is not compatible with the current version');
                      } else if (res == 2) {
                        KazumiDialog.showToast(message: 'Failed to update rule');
                      }
                    }
                  },
                  child: Text(pluginsController
                              .pluginStatus(sortedList[index]) ==
                          'install'
                      ? 'Install'
                      : (pluginsController.pluginStatus(sortedList[index]) ==
                              'installed')
                          ? 'Installed'
                          : 'Update'),
                )),
          );
        },
      );
    });
  }

  Widget get timeoutWidget {
    return Center(
      child: GeneralErrorWidget(
        errMsg: 'Oh no (⊙.⊙) Cannot access the remote repository\n${enableGitProxy ? 'Mirror enabled' : 'Mirror disabled'}',
        actions: [
          GeneralErrorButton(
            onPressed: () {
              Modular.to.pushNamed('/settings/webdav/');
            },
            text: enableGitProxy ? 'Disable mirror' : 'Enable mirror',
          ),
          GeneralErrorButton(
            onPressed: () {
              _handleRefresh();
            },
            text: 'Refresh',
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
          title: const Text('Rule repository'),
          actions: [
            IconButton(
                onPressed: _toggleSort,
                tooltip: sortByName ? 'Sort by name' : 'Sort by update time',
                icon:
                    Icon(sortByName ? Icons.sort_by_alpha : Icons.access_time)),
            IconButton(
                onPressed: () {
                  _handleRefresh();
                },
                tooltip: 'Refresh rule list',
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
