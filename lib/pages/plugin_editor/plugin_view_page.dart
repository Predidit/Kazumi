import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/encoding.dart';

class PluginViewPage extends StatefulWidget {
  const PluginViewPage({super.key});

  @override
  State<PluginViewPage> createState() => _PluginViewPageState();
}

class _PluginViewPageState extends State<PluginViewPage> {
  final PluginsController pluginsController = Modular.get<PluginsController>();

  static const WidgetStateProperty<Icon> _switchThumbIcon =
      WidgetStateProperty<Icon>.fromMap(
    <WidgetStatesConstraint, Icon>{
      WidgetState.selected: Icon(Icons.check_rounded),
      WidgetState.any: Icon(Icons.close_rounded),
    },
  );

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
    String pluginText = '';
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('导入规则'),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return TextField(
              onChanged: (value) => pluginText = value,
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
                  try {
                    final plugin = Plugin.fromJson(
                      json.decode(kazumiBase64ToJson(pluginText)),
                    );
                    if (plugin.requiresNewerClient) {
                      KazumiDialog.dismiss();
                      KazumiDialog.showToast(
                        message: '规则需要更高版本客户端',
                      );
                      return;
                    }
                    pluginsController.updatePlugin(plugin);
                    KazumiDialog.dismiss();
                    KazumiDialog.showToast(message: '导入成功');
                  } catch (e) {
                    KazumiDialog.dismiss();
                    KazumiDialog.showToast(message: '导入失败 ${e.toString()}');
                  }
                },
                child: const Text('导入'),
              );
            })
          ],
        );
      },
    );
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  Future<void> _setPluginEnabled(Plugin plugin, bool enabled) async {
    await pluginsController.setPluginEnabled(plugin.name, enabled);
    if (!mounted) return;
    setState(() {});
    KazumiDialog.showToast(
        message: enabled ? '已启用 ${plugin.name}' : '已禁用 ${plugin.name}');
  }

  Future<void> _setSelectedPluginsEnabled(bool enabled) async {
    if (selectedNames.isEmpty) return;
    final names = Set<String>.of(selectedNames);
    await pluginsController.setPluginsEnabled(names, enabled);
    if (!mounted) return;
    setState(() {
      isMultiSelectMode = false;
      selectedNames.clear();
    });
    KazumiDialog.showToast(
        message:
            enabled ? '已启用 ${names.length} 条规则' : '已禁用 ${names.length} 条规则');
  }

  Widget _statusBadge(
    BuildContext context,
    String text, {
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: foregroundColor,
        ),
      ),
    );
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
                    : () => _setSelectedPluginsEnabled(true),
                tooltip: '启用选中规则',
                icon: const Icon(Icons.visibility_outlined),
              ),
              IconButton(
                onPressed: selectedNames.isEmpty
                    ? null
                    : () => _setSelectedPluginsEnabled(false),
                tooltip: '禁用选中规则',
                icon: const Icon(Icons.visibility_off_outlined),
              ),
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
                                onPressed: () async {
                                  await pluginsController
                                      .removePlugins(selectedNames);
                                  if (!mounted) return;
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
                  _handleUpdate();
                },
                tooltip: '更新全部',
                icon: const Icon(Icons.update),
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
                      onReorderItem: (int oldIndex, int newIndex) {
                        pluginsController.onReorder(oldIndex, newIndex);
                      },
                      itemCount: pluginsController.pluginList.length,
                      itemBuilder: (context, index) {
                        var plugin = pluginsController.pluginList[index];
                        final theme = Theme.of(context);
                        final colorScheme = theme.colorScheme;
                        final isEnabled =
                            pluginsController.isPluginEnabled(plugin.name);
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
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              title: Text(
                                plugin.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isEnabled
                                      ? null
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Version: ${plugin.version}',
                                        style: TextStyle(
                                          color: isEnabled
                                              ? Colors.grey
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (canUpdate)
                                        _statusBadge(
                                          context,
                                          '可更新',
                                          backgroundColor:
                                              colorScheme.errorContainer,
                                          foregroundColor:
                                              colorScheme.onErrorContainer,
                                        ),
                                      if (pluginsController.validityTracker
                                          .isSearchValid(plugin.name))
                                        _statusBadge(
                                          context,
                                          '搜索有效',
                                          backgroundColor:
                                              colorScheme.tertiaryContainer,
                                          foregroundColor:
                                              colorScheme.onTertiaryContainer,
                                        ),
                                      if (!isEnabled)
                                        _statusBadge(
                                          context,
                                          '已禁用',
                                          backgroundColor: colorScheme
                                              .surfaceContainerHighest,
                                          foregroundColor:
                                              colorScheme.onSurfaceVariant,
                                        ),
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
    final isEnabled = pluginsController.isPluginEnabled(plugin.name);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (isMultiSelectMode)
        Checkbox(
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
      else ...[
        popupMenuButton(index),
        Tooltip(
          message: isEnabled ? '禁用规则' : '启用规则',
          child: Transform.scale(
            scale: 0.85,
            child: Switch(
              thumbIcon: _switchThumbIcon,
              value: isEnabled,
              onChanged: (value) => _setPluginEnabled(plugin, value),
            ),
          ),
        ),
      ],
      ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle), // 单独的拖拽按钮
      )
    ]);
  }

  Widget popupMenuButton(int index) {
    final plugin = pluginsController.pluginList[index];
    final isEnabled = pluginsController.isPluginEnabled(plugin.name);
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
                KazumiDialog.showToast(message: 'kazumi版本过低, 此规则不兼容当前版本');
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
          onPressed: () => _setPluginEnabled(plugin, !isEnabled),
          child: Container(
            height: 48,
            constraints: BoxConstraints(minWidth: 112),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(isEnabled
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  SizedBox(width: 8),
                  Text(isEnabled ? '禁用' : '启用'),
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
            Modular.to.pushNamed('/settings/plugin/test', arguments: plugin);
          },
          child: Container(
            height: 48,
            constraints: BoxConstraints(minWidth: 112),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.bug_report_outlined),
                  SizedBox(width: 8),
                  Text('测试'),
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
                  jsonToKazumiBase64(json
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
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: jsonToKazumiBase64(
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
            await pluginsController.removePlugin(plugin);
            if (!mounted) return;
            setState(() {});
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
