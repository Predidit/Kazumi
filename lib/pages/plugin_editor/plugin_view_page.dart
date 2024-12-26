import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class PluginViewPage extends StatefulWidget {
  const PluginViewPage({super.key});

  @override
  State<PluginViewPage> createState() => _PluginViewPageState();
}

class _PluginViewPageState extends State<PluginViewPage> {
  final PluginsController pluginsController = Modular.get<PluginsController>();
  // 是否处于多选模式
  bool isMultiSelectMode = false;
  // 已选中的规则名称集合
  final Set<String> selectedNames = {};
  // 排序方式状态：false=按安装时间排序，true=按名称排序
  bool sortByName = false;

  Future<void> _handleUpdate() async {
    KazumiDialog.showLoading(msg: '更新中');
    int count = await pluginsController.tryUpdateAllPlugin();
    KazumiDialog.dismiss();
    if (count == 0) {
      KazumiDialog.showToast(message: '所有规则已是最新');
    } else {
      KazumiDialog.showToast(message: '更新成功 $count 条');
    }
  }

  void _handleAdd() {
    KazumiDialog.show(builder: (context) {
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
                  KazumiDialog.dismiss();
                  Modular.to.pushNamed('/settings/plugin/editor',
                      arguments: Plugin.fromTemplate());
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('从规则仓库导入'),
                onTap: () {
                  KazumiDialog.dismiss();
                  Modular.to.pushNamed('/settings/plugin/shop',
                      arguments: Plugin.fromTemplate());
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('从剪贴板导入'),
                onTap: () {
                  KazumiDialog.dismiss();
                  _showInputDialog();
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showInputDialog() {
    final TextEditingController textController = TextEditingController();
    KazumiDialog.show(builder: (context) {
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
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return TextButton(
              onPressed: () async {
                final String msg = textController.text;
                try {
                  await pluginsController.tryInstallPlugin(Plugin.fromJson(
                      json.decode(Utils.kazumiBase64ToJson(msg))));
                  KazumiDialog.showToast(message: '导入成功');
                } catch (e) {
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(message: '导入失败 ${e.toString()}');
                }
                KazumiDialog.dismiss();
              },
              child: const Text('导入'),
            );
          })
        ],
      );
    });
  }

  void onBackPressed(BuildContext context) {
    // Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    return PopScope(
      canPop: !isMultiSelectMode,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (isMultiSelectMode) {
          setState(() {
            isMultiSelectMode = false;
            selectedNames.clear();
          });
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: isMultiSelectMode
              ? Text('已选择 ${selectedNames.length} 项')
              : const Text('规则管理'),
          leading: isMultiSelectMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      isMultiSelectMode = false;
                      selectedNames.clear();
                    });
                  },
                )
              : null,
          actions: [
            if (isMultiSelectMode) ...[
              IconButton(
                onPressed: selectedNames.isEmpty
                    ? null
                    : () {
                        KazumiDialog.show(
                          builder: (context) => AlertDialog(
                            title: const Text('删除规则'),
                            content:
                                Text('确定要删除选中的 ${selectedNames.length} 条规则吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => KazumiDialog.dismiss(),
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
                                  // 从大到小排序，这样删除时不会影响前面的索引
                                  final sortedNames = selectedNames.toList()
                                    ..sort((a, b) => b.compareTo(a));
                                  for (final name in sortedNames) {
                                    final plugin = pluginsController.pluginList
                                        .firstWhere((p) => p.name == name);
                                    pluginsController
                                        .deletePluginJsonFile(plugin);
                                    pluginsController.pluginList
                                        .removeWhere((p) => p.name == name);
                                  }
                                  setState(() {
                                    isMultiSelectMode = false;
                                    selectedNames.clear();
                                  });
                                  KazumiDialog.dismiss();
                                },
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                      },
                icon: const Icon(Icons.delete),
              ),
            ] else ...[
              IconButton(
                  onPressed: () {
                    setState(() {
                      sortByName = !sortByName;
                    });
                  },
                  tooltip: sortByName ? '按名称排序' : '按安装时间排序',
                  icon: Icon(
                      sortByName ? Icons.sort_by_alpha : Icons.access_time)),
              IconButton(
                  onPressed: () {
                    _handleUpdate();
                  },
                  tooltip: '更新全部',
                  icon: const Icon(Icons.update)),
              IconButton(
                  onPressed: () {
                    _handleAdd();
                  },
                  tooltip: '添加规则',
                  icon: const Icon(Icons.add))
            ],
          ],
        ),
        body: Observer(builder: (context) {
          return pluginsController.pluginList.isEmpty
              ? const Center(
                  child: Text('啊咧（⊙.⊙） 没有可用规则的说'),
                )
              : Builder(builder: (context) {
                  // 创建列表副本用于排序
                  var sortedList = List.from(pluginsController.pluginList);
                  // 排序规则：
                  // 1. 按名称排序：忽略大小写的字母顺序
                  // 2. 按时间排序：安装时间降序（最新的在前面）
                  if (sortByName) {
                    sortedList.sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  } else {
                    sortedList
                        .sort((a, b) => b.installTime.compareTo(a.installTime));
                  }

                  return ListView.builder(
                    itemCount: sortedList.length,
                    itemBuilder: (context, index) {
                      var plugin = sortedList[index];
                      bool canUpdate =
                          pluginsController.pluginUpdateStatus(plugin) ==
                              'updatable';
                      return Card(
                        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: ListTile(
                          onLongPress: () {
                            if (!isMultiSelectMode) {
                              setState(() {
                                isMultiSelectMode = true;
                                selectedNames.add(plugin.name);
                              });
                            }
                          },
                          onTap: () {
                            if (isMultiSelectMode) {
                              setState(() {
                                if (selectedNames.contains(plugin.name)) {
                                  selectedNames.remove(plugin.name);
                                  if (selectedNames.isEmpty) {
                                    isMultiSelectMode = false;
                                  }
                                } else {
                                  selectedNames.add(plugin.name);
                                }
                              });
                            }
                          },
                          selected: selectedNames.contains(plugin.name),
                          selectedTileColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          title: Text(
                            plugin.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Version: ${plugin.version}${canUpdate ? ' （可更新）' : ''}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  if (pluginsController.validityTracker
                                      .isSearchValid(plugin.name)) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '搜索有效',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (plugin.installTime > 0) ...[
                                Text(
                                  '安装时间: ${DateTime.fromMillisecondsSinceEpoch(plugin.installTime).toString().split('.')[0]}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                          trailing: isMultiSelectMode
                              ? Checkbox(
                                  value: selectedNames.contains(plugin.name),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        selectedNames.add(plugin.name);
                                      } else {
                                        selectedNames.remove(plugin.name);
                                        if (selectedNames.isEmpty) {
                                          isMultiSelectMode = false;
                                        }
                                      }
                                    });
                                  },
                                )
                              : PopupMenuButton<String>(
                                  onSelected: (String result) async {
                                    if (result == 'Update') {
                                      var state = pluginsController
                                          .pluginUpdateStatus(plugin);
                                      if (state == "nonexistent") {
                                        KazumiDialog.showToast(
                                            message: '规则仓库中没有当前规则');
                                      } else if (state == "latest") {
                                        KazumiDialog.showToast(
                                            message: '规则已是最新');
                                      } else if (state == "updatable") {
                                        KazumiDialog.showLoading(msg: '更新中');
                                        int res = await pluginsController
                                            .tryUpdatePlugin(plugin);
                                        KazumiDialog.dismiss();
                                        if (res == 0) {
                                          KazumiDialog.showToast(
                                              message: '更新成功');
                                        } else if (res == 1) {
                                          KazumiDialog.showToast(
                                              message:
                                                  'kazumi版本过低, 此规则不兼容当前版本');
                                        } else if (res == 2) {
                                          KazumiDialog.showToast(
                                              message: '更新规则失败');
                                        }
                                      }
                                    } else if (result == 'Delete') {
                                      setState(() {
                                        pluginsController
                                            .deletePluginJsonFile(plugin);
                                        pluginsController.pluginList
                                            .removeWhere(
                                                (p) => p.name == plugin.name);
                                      });
                                    } else if (result == 'Edit') {
                                      Modular.to.pushNamed(
                                          '/settings/plugin/editor',
                                          arguments: plugin);
                                    } else if (result == 'Share') {
                                      KazumiDialog.show(builder: (context) {
                                        return AlertDialog(
                                          title: const Text('规则链接'),
                                          content: SelectableText(
                                            Utils.jsonToKazumiBase64(
                                                json.encode(pluginsController
                                                    .pluginList[index]
                                                    .toJson())),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  KazumiDialog.dismiss(),
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
                                                Clipboard.setData(ClipboardData(
                                                    text: Utils.jsonToKazumiBase64(
                                                        json.encode(
                                                            pluginsController
                                                                .pluginList[
                                                                    index]
                                                                .toJson()))));
                                                KazumiDialog.dismiss();
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
                                      value: 'Update',
                                      child: Text('更新'),
                                    ),
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
                });
        }),
      ),
    );
  }
}
