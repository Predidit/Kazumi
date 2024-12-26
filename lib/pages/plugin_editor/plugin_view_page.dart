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
  // 已选中的规则索引集合
  final Set<int> selectedIndices = {};

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
            selectedIndices.clear();
          });
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: isMultiSelectMode
              ? Text('已选择 ${selectedIndices.length} 项')
              : const Text('规则管理'),
          leading: isMultiSelectMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      isMultiSelectMode = false;
                      selectedIndices.clear();
                    });
                  },
                )
              : null,
          actions: [
            if (isMultiSelectMode) ...[
              IconButton(
                onPressed: selectedIndices.isEmpty
                    ? null
                    : () {
                        KazumiDialog.show(
                          builder: (context) => AlertDialog(
                            title: const Text('删除规则'),
                            content: Text(
                                '确定要删除选中的 ${selectedIndices.length} 条规则吗？'),
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
                                  final sortedIndices = selectedIndices.toList()
                                    ..sort((a, b) => b.compareTo(a));
                                  for (final index in sortedIndices) {
                                    pluginsController.deletePluginJsonFile(
                                        pluginsController.pluginList[index]);
                                    pluginsController.pluginList
                                        .removeAt(index);
                                  }
                                  setState(() {
                                    isMultiSelectMode = false;
                                    selectedIndices.clear();
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
              : ListView.builder(
                  itemCount: pluginsController.pluginList.length,
                  itemBuilder: (context, index) {
                    var plugin = pluginsController.pluginList[index];
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
                              selectedIndices.add(index);
                            });
                          }
                        },
                        onTap: () {
                          if (isMultiSelectMode) {
                            setState(() {
                              if (selectedIndices.contains(index)) {
                                selectedIndices.remove(index);
                                if (selectedIndices.isEmpty) {
                                  isMultiSelectMode = false;
                                }
                              } else {
                                selectedIndices.add(index);
                              }
                            });
                          }
                        },
                        selected: selectedIndices.contains(index),
                        selectedTileColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        title: Text(
                          plugin.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Version: ${plugin.version}${canUpdate ? ' （可更新）' : ''}',
                              style: const TextStyle(color: Colors.grey),
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
                                value: selectedIndices.contains(index),
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedIndices.add(index);
                                    } else {
                                      selectedIndices.remove(index);
                                      if (selectedIndices.isEmpty) {
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
                                      KazumiDialog.showToast(message: '规则已是最新');
                                    } else if (state == "updatable") {
                                      KazumiDialog.showLoading(msg: '更新中');
                                      int res = await pluginsController
                                          .tryUpdatePlugin(plugin);
                                      KazumiDialog.dismiss();
                                      if (res == 0) {
                                        KazumiDialog.showToast(message: '更新成功');
                                      } else if (res == 1) {
                                        KazumiDialog.showToast(
                                            message: 'kazumi版本过低, 此规则不兼容当前版本');
                                      } else if (res == 2) {
                                        KazumiDialog.showToast(
                                            message: '更新规则失败');
                                      }
                                    }
                                  } else if (result == 'Delete') {
                                    setState(() {
                                      pluginsController.deletePluginJsonFile(
                                          pluginsController.pluginList[index]);
                                      pluginsController.pluginList
                                          .removeAt(index);
                                    });
                                  } else if (result == 'Edit') {
                                    Modular.to.pushNamed(
                                        '/settings/plugin/editor',
                                        arguments: pluginsController
                                            .pluginList[index]);
                                  } else if (result == 'Share') {
                                    KazumiDialog.show(builder: (context) {
                                      return AlertDialog(
                                        title: const Text('规则链接'),
                                        content: SelectableText(
                                          Utils.jsonToKazumiBase64(json.encode(
                                              pluginsController
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
                                                  text: Utils
                                                      .jsonToKazumiBase64(
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
        }),
      ),
    );
  }
}
