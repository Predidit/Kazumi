import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/plugin_editor/plugin_update_actions.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/encoding.dart';

class PluginViewPage extends StatefulWidget {
  const PluginViewPage({
    super.key,
    required this.controller,
  });

  final PluginsController controller;

  @override
  State<PluginViewPage> createState() => _PluginViewPageState();
}

class _PluginViewPageState extends State<PluginViewPage> {
  PluginsController get pluginsController => widget.controller;

  // 是否处于多选模式
  bool isMultiSelectMode = false;

  // 已选中的规则名称集合
  final Set<String> selectedNames = {};

  Future<void> _handleUpdate() async {
    await updateAllPluginsWithFeedback(
      pluginsController,
      ensureCatalog: true,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    try {
      await pluginsController.onReorder(oldIndex, newIndex);
    } catch (_) {
      KazumiDialog.showToast(message: '保存规则顺序失败');
    }
  }

  void _handleAdd() {
    KazumiDialog.show(builder: (context) {
      return AlertDialog(
        content: SingleChildScrollView(
          // 使用可滚动的SingleChildScrollView包装Column
          child: Column(
            mainAxisSize: MainAxisSize.min, // 设置为MainAxisSize.min以减小高度
            children: [
              ListTile(
                title: const Text('新建规则'),
                onTap: () {
                  KazumiDialog.dismiss();
                  context.pushNamed('/settings/plugin/editor',
                      arguments: Plugin.fromTemplate());
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('从规则仓库导入'),
                onTap: () {
                  KazumiDialog.dismiss();
                  context.pushNamed('/settings/plugin/shop',
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
                    await pluginsController.updatePlugin(plugin);
                    KazumiDialog.dismiss();
                    KazumiDialog.showToast(message: '导入成功');
                  } catch (e, stackTrace) {
                    KazumiLogger().e(
                      'Plugin: failed to import rule link',
                      error: e,
                      stackTrace: stackTrace,
                    );
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadPluginUpdateStatus());
  }

  Future<void> _loadPluginUpdateStatus() async {
    try {
      await pluginsController.ensurePluginCatalog();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      KazumiDialog.showToast(message: '检查规则更新失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isMultiSelectMode,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
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
                                onPressed: () async {
                                  try {
                                    await pluginsController
                                        .removePlugins(selectedNames);
                                  } catch (_) {
                                    KazumiDialog.showToast(message: '删除规则失败');
                                    return;
                                  }
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
                  final colorScheme = Theme.of(context).colorScheme;
                  return ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 0,
                          color: Colors.transparent,
                          child: child,
                        );
                      },
                      onReorderItem: (int oldIndex, int newIndex) {
                        unawaited(_handleReorder(oldIndex, newIndex));
                      },
                      itemCount: pluginsController.pluginList.length,
                      itemBuilder: (context, index) {
                        var plugin = pluginsController.pluginList[index];
                        bool canUpdate =
                            pluginsController.pluginUpdateStatus(plugin) ==
                                PluginUpdateAvailability.updatable;
                        return RuleCard(
                          key: ObjectKey(plugin),
                          title: plugin.name,
                          selected: selectedNames.contains(plugin.name),
                          trailing: pluginCardTrailing(index),
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
                          tags: [
                            RuleTag(
                              label: plugin.version,
                              background: colorScheme.secondaryContainer,
                              foreground: colorScheme.onSecondaryContainer,
                            ),
                            if (canUpdate)
                              RuleTag(
                                label: '可更新',
                                background: colorScheme.errorContainer,
                                foreground: colorScheme.onErrorContainer,
                              ),
                            if (pluginsController.validityTracker
                                .isSearchValid(plugin.name))
                              RuleTag(
                                label: '搜索有效',
                                background: colorScheme.tertiaryContainer,
                                foreground: colorScheme.onTertiaryContainer,
                              ),
                          ],
                        );
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
            try {
              await pluginsController.ensurePluginCatalog();
              if (mounted) {
                setState(() {});
              }
            } catch (_) {
              KazumiDialog.showToast(message: '检查规则更新失败');
              return;
            }
            final state = pluginsController.pluginUpdateStatus(plugin);
            switch (state) {
              case PluginUpdateAvailability.unknown:
                KazumiDialog.showToast(message: '尚未获取规则更新状态');
              case PluginUpdateAvailability.notInCatalog:
                KazumiDialog.showToast(message: '规则仓库中没有当前规则');
              case PluginUpdateAvailability.latest:
                KazumiDialog.showToast(message: '规则已是最新');
              case PluginUpdateAvailability.updatable:
                await updatePluginWithFeedback(
                  pluginsController,
                  plugin.name,
                  installing: false,
                );
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
            context.pushNamed('/settings/plugin/editor', arguments: plugin);
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
            context.pushNamed('/settings/plugin/test', arguments: plugin);
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
            try {
              await pluginsController.removePlugin(plugin);
            } catch (_) {
              KazumiDialog.showToast(message: '删除规则失败');
            }
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
