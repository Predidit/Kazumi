import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:logger/logger.dart';

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

  void _handleShare() {
    // 1. 边界处理：无插件时提示，避免复制空内容
    if (pluginsController.pluginList.isEmpty) {
      KazumiDialog.showToast(message: '无可用插件可分享');
      return;
    }

    // 2. 构建规范格式的分享内容
    final StringBuffer shareContent = StringBuffer();

    // 头部信息：标识+总数量
    shareContent.writeln('【Kazumi插件批量分享】');
    shareContent.writeln('总数量：${pluginsController.pluginList.length} 条');
    shareContent.writeln('-------------------');

    // 主体内容：按序号遍历插件，输出名称+Base64
    for (int i = 0; i < pluginsController.pluginList.length; i++) {
      final Plugin plugin = pluginsController.pluginList[i];
      final int order = i + 1; // 序号从1开始，更符合用户习惯
      final String pluginBase64 = Utils.jsonToKazumiBase64(json.encode(plugin.toJson()));

      shareContent.writeln('$order. 插件名称：${plugin.name}');
      shareContent.writeln('Base64编码');
      shareContent.writeln(pluginBase64);
      shareContent.writeln('-------------------'); // 分隔线，提升可读性
    }

    // 尾部说明：指导用户使用（兼容批量导入）
    shareContent.writeln('【使用说明】');
    shareContent.writeln('1. 复制全部内容到「批量从剪贴板导入」功能中，可自动解析');
    shareContent.writeln('2. 若需单个导入，提取对应插件的「Base64编码」部分即可');
    shareContent.writeln('3. 分隔线（-------------------）不影响解析，可保留');

    // 3. 复制到剪贴板
    Clipboard.setData(ClipboardData(text: shareContent.toString())).then((_) {
      // 4. 提示用户复制成功，并说明格式优势
      KazumiDialog.showToast(
        message: '已复制全部插件（规范格式），支持批量导入',
        duration: const Duration(seconds: 2), // 延长提示时间，确保用户看到
      );
    }).catchError((error) {
      // 异常处理：复制失败时提示
      KazumiDialog.showToast(message: '复制失败：${error.toString()}');
    });
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
                title: const Text('单个导入规则'),
                onTap: () {
                  KazumiDialog.dismiss();
                  _showInputDialog();
                },
              ),
              const SizedBox(height: 10),
              // 新增：批量从剪贴板导入
              ListTile(
                title: const Text('批量从剪贴板导入'),
                onTap: () {
                  KazumiDialog.dismiss();
                  _showBatchInputDialog(); // 新增批量导入对话框
                },
              ),
            ],
          ),
        ),
      );
    });
  }
  void _showBatchInputDialog() {
    final TextEditingController textController = TextEditingController();
    KazumiDialog.show(builder: (context) {
      return AlertDialog(
        title: const Text('批量导入规则'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return TextField(
              controller: textController,
              minLines: 5,
              maxLines: null,
              decoration: InputDecoration(
                hintText: '请粘贴多个规则的Base64字符串（含kazumi://前缀），用【换行】或【逗号】分隔',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              keyboardType: TextInputType.multiline,
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
          TextButton(
            onPressed: () async {
              KazumiDialog.dismiss();
              KazumiDialog.showLoading(msg: '批量导入中...');

              final String input = textController.text.trim();
              if (input.isEmpty) {
                KazumiDialog.dismiss();
                KazumiDialog.showToast(message: '请粘贴批量规则字符串');
                return;
              }

              final List<String> base64List = input
                  .split(RegExp(r'[\n,;]')) // 1. 按换行/逗号/分号分割
                  .map((s) => s.trim()) // 2. 去除前后空格（避免复制时误加空格）
                  .where((s) => s.isNotEmpty) // 3. 过滤空字符串
                  .where((s) => s.startsWith('kazumi://')) // 4. 核心：只保留含"kazumi://"前缀的有效Base64
                  .toList();

              // 筛选后仍无有效内容，提示用户
              if (base64List.isEmpty) {
                KazumiDialog.dismiss();
                KazumiDialog.showToast(message: '未识别到有效规则（需含"kazumi://"前缀的Base64）');
                return;
              }

              // 批量解析（逻辑不变，但此时base64List仅含有效内容）
              int successCount = 0;
              final List<String> failLogs = [];
              for (int i = 0; i < base64List.length; i++) {
                final String base64 = base64List[i];
                final int index = i + 1;
                try {
                  print(base64);
                  pluginsController.updatePlugin(Plugin.fromJson(
                      json.decode(Utils.kazumiBase64ToJson(base64))));
                  successCount++;
                } catch (e) {
                  // 错误信息精简，避免过长
                  final errorMsg = e.toString();
                  failLogs.add('第$index条规则：导入失败，详细信息请看日志');
                  KazumiLogger().log(Level.error, '第$index条规则 加载更多失败: $errorMsg');
                }
              }

              KazumiDialog.dismiss();
              _showBatchResultDialog(successCount, base64List.length, failLogs);
            },
            child: const Text('批量导入'),
          ),
        ],
      );
    });
  }
  void _showBatchResultDialog(int successCount, int totalCount, List<String> failLogs) {
    KazumiDialog.show(builder: (context) {
      return AlertDialog(
        title: Text('批量导入完成'),
        // 结果概览
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('总数量：$totalCount 条'),
              Text('成功：$successCount 条'),
              Text('失败：${failLogs.length} 条'),
              // 显示失败详情（如果有失败）
              if (failLogs.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '失败详情：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...failLogs.map((log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    log,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: const Text('确认'),
          ),
        ],
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
              style: TextStyle(color: Theme
                  .of(context)
                  .colorScheme
                  .outline),
            ),
          ),
          StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return TextButton(
                  onPressed: () async {
                    final String msg = textController.text;
                    try {
                      pluginsController.updatePlugin(Plugin.fromJson(
                          json.decode(Utils.kazumiBase64ToJson(msg))));
                      KazumiDialog.showToast(message: '导入成功');
                    } catch (e) {
                      KazumiDialog.dismiss();
                      KazumiDialog.showToast(message: '导入失败 ${e
                          .toString()}');
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
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
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
                    builder: (context) =>
                        AlertDialog(
                          title: const Text('删除规则'),
                          content:
                          Text('确定要删除选中的 ${selectedNames
                              .length} 条规则吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => KazumiDialog.dismiss(),
                              child: Text(
                                '取消',
                                style: TextStyle(
                                    color: Theme
                                        .of(context)
                                        .colorScheme
                                        .outline),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                pluginsController
                                    .removePlugins(selectedNames);
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
            ] else
              ...[
                IconButton(
                  onPressed: () {
                    _handleUpdate();
                  },
                  tooltip: '更新全部',
                  icon: const Icon(Icons.update),
                ),
                IconButton(
                  onPressed: () {
                    _handleShare();
                  },
                  tooltip: '复制全部规则到剪切板',
                  icon: const Icon(Icons.share),
                ),
                IconButton(
                  onPressed: () {
                    _handleAdd();
                  },
                  tooltip: '添加规则',
                  icon: const Icon(Icons.add),
                )
              ],
          ],
        ),
        body: Observer(builder: (context) {
          return pluginsController.pluginList.isEmpty
              ? const Center(
            child: Text('啊咧（⊙.⊙） 没有可用规则的说'),
          )
              : Builder(builder: (context) {
            return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 0,
                    color: Colors.transparent,
                    child: child,
                  );
                },
                onReorder: (int oldIndex, int newIndex) {
                  pluginsController.onReorder(oldIndex, newIndex);
                },
                itemCount: pluginsController.pluginList.length,
                itemBuilder: (context, index) {
                  var plugin = pluginsController.pluginList[index];
                  bool canUpdate =
                      pluginsController.pluginUpdateStatus(plugin) ==
                          'updatable';
                  return Card(
                      key: ValueKey(index),
                      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: ListTile(
                        trailing: pluginCardTrailing(index),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                        selectedTileColor: Theme
                            .of(context)
                            .colorScheme
                            .primaryContainer,
                        title: Text(
                          plugin.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Version: ${plugin.version}',
                                  style:
                                  const TextStyle(color: Colors.grey),
                                ),
                                if (canUpdate) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme
                                          .of(context)
                                          .colorScheme
                                          .errorContainer,
                                      borderRadius:
                                      BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '可更新',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme
                                            .of(context)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                                if (pluginsController.validityTracker
                                    .isSearchValid(plugin.name)) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme
                                          .of(context)
                                          .colorScheme
                                          .tertiaryContainer,
                                      borderRadius:
                                      BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '搜索有效',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme
                                            .of(context)
                                            .colorScheme
                                            .onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ));
                });
          });
        }),
      ),
    );
  }

  Widget pluginCardTrailing(int index) {
    final plugin = pluginsController.pluginList[index];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      isMultiSelectMode
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
          : popupMenuButton(index),
      ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle), // 单独的拖拽按钮
      )
    ]);
  }

  Widget popupMenuButton(int index) {
    final plugin = pluginsController.pluginList[index];
    return MenuAnchor(
      consumeOutsideTap: true,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        return IconButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.more_vert),
        );
      },
      menuChildren: [
        MenuItemButton(
          requestFocusOnHover: false,
          onPressed: () async {
            var state = pluginsController.pluginUpdateStatus(plugin);
            if (state == "nonexistent") {
              KazumiDialog.showToast(message: '规则仓库中没有当前规则');
            } else if (state == "latest") {
              KazumiDialog.showToast(message: '规则已是最新');
            } else if (state == "updatable") {
              KazumiDialog.showLoading(msg: '更新中');
              int res = await pluginsController.tryUpdatePlugin(plugin);
              KazumiDialog.dismiss();
              if (res == 0) {
                KazumiDialog.showToast(message: '更新成功');
              } else if (res == 1) {
                KazumiDialog.showToast(
                    message: 'kazumi版本过低, 此规则不兼容当前版本');
              } else if (res == 2) {
                KazumiDialog.showToast(message: '更新规则失败');
              }
            }
          },
          child: Container(
            height: 48,
            constraints: BoxConstraints(minWidth: 112),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.update_rounded),
                  SizedBox(width: 8),
                  Text('更新'),
                ],
              ),
            ),
          ),
        ),
        MenuItemButton(
          requestFocusOnHover: false,
          onPressed: () {
            Modular.to.pushNamed('/settings/plugin/editor', arguments: plugin);
          },
          child: Container(
            height: 48,
            constraints: BoxConstraints(minWidth: 112),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('编辑'),
                ],
              ),
            ),
          ),
        ),
        MenuItemButton(
          requestFocusOnHover: false,
          onPressed: () {
            KazumiDialog.show(builder: (context) {
              return AlertDialog(
                title: const Text('规则链接'),
                content: SelectableText(
                  Utils.jsonToKazumiBase64(json
                      .encode(pluginsController.pluginList[index].toJson())),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () => KazumiDialog.dismiss(),
                    child: Text(
                      '取消',
                      style: TextStyle(
                          color: Theme
                              .of(context)
                              .colorScheme
                              .outline),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: Utils.jsonToKazumiBase64(
                          json.encode(
                            pluginsController.pluginList[index].toJson(),
                          ),
                        ),
                      ));
                      KazumiDialog.dismiss();
                    },
                    child: const Text('复制到剪贴板'),
                  ),
                ],
              );
            });
          },
          child: Container(
            height: 48,
            constraints: BoxConstraints(minWidth: 112),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text('分享'),
                ],
              ),
            ),
          ),
        ),
        MenuItemButton(
          requestFocusOnHover: false,
          onPressed: () async {
            setState(() {
              pluginsController.removePlugin(plugin);
            });
          },
          child: Container(
            height: 48,
            constraints: BoxConstraints(minWidth: 112),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('删除'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
