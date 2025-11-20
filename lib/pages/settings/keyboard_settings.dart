import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';


class KeyboardSettingsPage extends StatefulWidget {
  const KeyboardSettingsPage({super.key});

  @override
  State<KeyboardSettingsPage> createState() => _KeyboardSettingsPageState();
}

class _KeyboardSettingsPageState extends State<KeyboardSettingsPage> {
  Box setting = GStorage.setting;

  String? listeningFunction;
  int? listeningIndex;
  late Map<String, List<String>> shortcuts;

  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();    
    // 根据默认快捷键生成可用快捷键列表，并读取已设置值
    shortcuts = {
      for (var key in defaultShortcuts.keys)
        key: (setting.get('shortcut_$key', 
                defaultValue: defaultShortcuts[key]?.toList() ?? <String>[]) 
              ?.cast<String>() ?? [])
    };
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void startListening(String func, int index) {
    setState(() {
      listeningFunction = func;
      listeningIndex = index;
      shortcuts[func]![index] = '按键中...';
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      focusNode.requestFocus();
    });
  }

  void saveShortcuts(String func) {
    setting.put('shortcut_$func', shortcuts[func]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        title: Text('键盘快捷键'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '恢复默认',
            onPressed: () {
              setState(() {
                for (final func in shortcuts.keys) {
                  shortcuts[func] = defaultShortcuts[func]?.toList() ?? [];
                  saveShortcuts(func);
                }
              });
            },
          ),
        ],
      
      ),
      body: FocusScope(
        autofocus: true,
        child: Focus(
          focusNode: focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (listeningFunction == null || listeningIndex == null) return KeyEventResult.ignored;

            if (event is KeyDownEvent) {
              // 捕获原始按键值
              String keyLabel = event.logicalKey.keyLabel.isNotEmpty
                  ? event.logicalKey.keyLabel
                  : event.logicalKey.debugName ?? '';

              final func = listeningFunction!;
              final index = listeningIndex!;
              bool conflict = false;
              String conflictFunc = "";

              for (final entry in shortcuts.entries) {
                final otherFunc = entry.key;
                final otherKeys = entry.value;

                for (int i = 0; i < otherKeys.length; i++) {
                  if (otherFunc == func && i == index) continue;
                  if (otherKeys[i] == keyLabel) {
                    conflict = true;
                    conflictFunc = shortcutsChineseName[otherFunc] ?? otherFunc;
                    break;
                  }
                }
                if (conflict) break;
              }
                if (conflict) {
                  KazumiDialog.showToast(message: "按键已被【$conflictFunc】占用，请重新输入");
                  // 不退出监听，不保存，不覆盖，保持“按键中...”
                  return KeyEventResult.handled;
                }

              setState(() {
                shortcuts[func]![listeningIndex!] = keyLabel; // 保存原始按键值
                listeningFunction = null;
                listeningIndex = null;
              });
              saveShortcuts(func);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: shortcuts.entries.map((entry) {
              final func = entry.key;
              final keys = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortcutsChineseName[func] ?? func,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int i = 0; i < keys.length; i++)
                            GestureDetector(
                              onLongPress: () {
                                setState(() {
                                  keys.removeAt(i);
                                });
                                saveShortcuts(func);
                              },
                              child: ActionChip(
                                label: Text(
                                  keys[i].isEmpty
                                      ? '未设置'
                                      : (keyAliases[keys[i]] ?? keys[i]), // 仅显示别名
                                ),
                                onPressed: () => startListening(func, i),
                                avatar: const Icon(Icons.edit),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                focusNode: FocusNode(canRequestFocus: false),
                              ),
                            ),
                          // 添加新快捷键
                          ActionChip(
                            label: const Text("+"),
                            onPressed: () {
                              setState(() {
                                keys.add('');
                              });
                            },
                            focusNode: FocusNode(canRequestFocus: false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
