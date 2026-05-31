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

  // 是否处于多选模式
  bool isMultiSelectMode = false;

  // 已选中的规则名称集合
  final Set<String> selectedNames = {};

  Future<void> _handleUpdate() async {
    KazumiDialog.showLoading(msg: 'Updating');
    int count = await pluginsController.tryUpdateAllPlugin();
    KazumiDialog.dismiss();
    if (count == 0) {
      KazumiDialog.showToast(message: 'All rules are up to date');
    } else {
      KazumiDialog.showToast(message: 'Updated $count rules');
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
                title: const Text('New rule'),
                onTap: () {
                  KazumiDialog.dismiss();
                  Modular.to.pushNamed('/settings/plugin/editor',
                      arguments: Plugin.fromTemplate());
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('Import from rule repository'),
                onTap: () {
                  KazumiDialog.dismiss();
                  Modular.to.pushNamed('/settings/plugin/shop',
                      arguments: Plugin.fromTemplate());
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('Import from clipboard'),
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
          title: const Text('Import rule'),
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
                'Cancel',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return TextButton(
                onPressed: () async {
                  try {
                    pluginsController.updatePlugin(Plugin.fromJson(
                        json.decode(kazumiBase64ToJson(pluginText))));
                    KazumiDialog.showToast(message: 'Import succeeded');
                  } catch (e) {
                    KazumiDialog.dismiss();
                    KazumiDialog.showToast(message: 'Import failed ${e.toString()}');
                  }
                  KazumiDialog.dismiss();
                },
                child: const Text('Import'),
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
              ? Text('${selectedNames.length} selected')
              : const Text('Rule management'),
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
                            title: const Text('Delete rule'),
                            content:
                                Text('Delete the ${selectedNames.length} selected rules?'),
                            actions: [
                              TextButton(
                                onPressed: () => KazumiDialog.dismiss(),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                      color: Theme.of(context)
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
                                child: const Text('Delete'),
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
                tooltip: 'Update all',
                icon: const Icon(Icons.update),
              ),
              IconButton(
                onPressed: () {
                  _handleAdd();
                },
                tooltip: 'Add rule',
                icon: const Icon(Icons.add),
              )
            ],
          ],
        ),
        body: Observer(builder: (context) {
          return pluginsController.pluginList.isEmpty
              ? const Center(
                  child: Text('Oops (⊙.⊙) no rules available'),
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .errorContainer,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Update available',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .tertiaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Search works',
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
              KazumiDialog.showToast(message: 'This rule is not in the rule repository');
            } else if (state == "latest") {
              KazumiDialog.showToast(message: 'Rule is up to date');
            } else if (state == "updatable") {
              KazumiDialog.showLoading(msg: 'Updating');
              int res = await pluginsController.tryUpdatePlugin(plugin);
              KazumiDialog.dismiss();
              if (res == 0) {
                KazumiDialog.showToast(message: 'Update succeeded');
              } else if (res == 1) {
                KazumiDialog.showToast(message: 'Akiora version is too low, this rule is not compatible with the current version');
              } else if (res == 2) {
                KazumiDialog.showToast(message: 'Failed to update rule');
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
                  Text('Update'),
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
                  Text('Edit'),
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
                  Text('Test'),
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
                title: const Text('Rule link'),
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
                      'Cancel',
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
                    child: const Text('Copy to clipboard'),
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
                  Text('Share'),
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
                  Text('Delete'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
