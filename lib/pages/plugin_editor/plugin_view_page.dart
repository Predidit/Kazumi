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
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:provider/provider.dart';

class PluginViewPage extends StatefulWidget {
  const PluginViewPage({super.key});

  @override
  State<PluginViewPage> createState() => _PluginViewPageState();
}

class _PluginViewPageState extends State<PluginViewPage> {
  dynamic navigationBarState;
  final PluginsController pluginsController = Modular.get<PluginsController>();

  _handleAdd() {
    SmartDialog.show(
        useAnimation: false,
        builder: (context) {
          return AlertDialog(
            // contentPadding: EdgeInsets.zero, // 设置为零以减小内边距
            content: SingleChildScrollView(
              // 使用可滚动的SingleChildScrollView包装Column
              child: Column(
                mainAxisSize: MainAxisSize.min, // 设置为MainAxisSize.min以减小高度
                children: [
                  ListTile(
                    title: const Text('新建规则'),
                    onTap: () {
                      SmartDialog.dismiss();
                      Modular.to.pushNamed('/tab/my/plugin/editor',
                          arguments: Plugin.fromTemplate());
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    title: const Text('从规则仓库导入'),
                    onTap: () {
                      SmartDialog.dismiss();
                      Modular.to.pushNamed('/tab/my/plugin/shop',
                          arguments: Plugin.fromTemplate());
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    title: const Text('从剪贴板导入'),
                    onTap: () {
                      SmartDialog.dismiss();
                      _showInputDialog();
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }

  _showInputDialog() {
    final TextEditingController textController = TextEditingController();
    SmartDialog.show(
        useAnimation: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('导入规则'),
            content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return TextField(
                controller: textController,
              );
            }),
            actions: [
              TextButton(
                onPressed: () => SmartDialog.dismiss(),
                child: Text(
                  '取消',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                return TextButton(
                  onPressed: () async {
                    final String msg = textController.text;
                    try {
                      await pluginsController.savePluginToJsonFile(
                          Plugin.fromJson(
                              json.decode(Utils.kazumiBase64ToJson(msg))));
                      SmartDialog.showToast('导入成功');
                    } catch (e) {
                      SmartDialog.dismiss();
                      SmartDialog.showToast('导入失败 ${e.toString()}');
                    }
                    pluginsController.loadPlugins();
                    SmartDialog.dismiss();
                  },
                  child: const Text('导入'),
                );
              })
            ],
          );
        });
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.showNavigate();
    // Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    if (Utils.isCompact()) {
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
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: const Text('规则管理'),
          actions: [
            (Utils.isCompact()) ? IconButton(
                onPressed: () {
                  _handleAdd();
                },
                icon: const Icon(Icons.add)) : Container()
          ],
        ),
        body: Observer(builder: (context) {
          return pluginsController.pluginList.isEmpty
              ? const Center(
                  child: Text('啊咧（⊙.⊙） 没有可用规则的说'),
                )
              : ListView.builder(
                  itemCount: pluginsController.pluginList.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: ListTile(
                        title: Text(
                          pluginsController.pluginList[index].name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Version: ${pluginsController.pluginList[index].version}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (String result) {
                            if (result == 'Delete') {
                              setState(() {
                                pluginsController.deletePluginJsonFile(
                                    pluginsController.pluginList[index]);
                                pluginsController.pluginList.removeAt(index);
                              });
                            } else if (result == 'Edit') {
                              Modular.to.pushNamed('/tab/my/plugin/editor',
                                  arguments:
                                      pluginsController.pluginList[index]);
                            } else if (result == 'Share') {
                              SmartDialog.show(
                                  useAnimation: false,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('规则链接'),
                                      content: SelectableText(
                                        Utils.jsonToKazumiBase64(json.encode(
                                            pluginsController.pluginList[index]
                                                .toJson())),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              SmartDialog.dismiss(),
                                          child: Text(
                                            '取消',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Utils.copyToClipboard(
                                                Utils.jsonToKazumiBase64(json
                                                    .encode(pluginsController
                                                        .pluginList[index]
                                                        .toJson())));
                                            SmartDialog.dismiss();
                                          },
                                          child: const Text('复制到剪贴板'),
                                        ),
                                      ],
                                    );
                                  });
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'Edit',
                              child: Text('编辑'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'Share',
                              child: Text('分享'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'Delete',
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
        }),
        floatingActionButton: (!Utils.isCompact()) ? FloatingActionButton(
          onPressed: () {
            _handleAdd();
          },
          child: const Icon(Icons.add),
        ) : null,
      ),
    );
  }
}
