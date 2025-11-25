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
    // 清理空的快捷键设置
    for (final entry in shortcuts.entries) {
      final func = entry.key;
      final keys = entry.value;
      keys.removeWhere((key) => key.isEmpty || key == '...');
      setting.put('shortcut_$func', keys);
    }
    focusNode.dispose();
    super.dispose();
  }
  bool handleShortcutInput(String rawKey) {
    if (listeningFunction == null || listeningIndex == null) return false;

    final func = listeningFunction!;
    final index = listeningIndex!;

    // 冲突规避
    for (final entry in shortcuts.entries) {
      final otherFunc = entry.key;
      final otherKeys = entry.value;

      for (int i = 0; i < otherKeys.length; i++) {
        if (otherFunc == func && i == index) continue;
        if (otherKeys[i] == rawKey) {
          final name = shortcutsChineseName[otherFunc] ?? otherFunc;
          KazumiDialog.showToast(message: "按键已被【$name】占用，请重新输入");
          return true;
        }
      }
    }
    setState(() {
      shortcuts[func]![index] = rawKey;
      listeningFunction = null;
      listeningIndex = null;
    });
    setting.put('shortcut_$func', shortcuts[func]);

    return true;
  }

  void startListening(String func, int index) {
    setState(() {
      listeningFunction = func;
      listeningIndex = index;
      shortcuts[func]![index] = '...';
    });

    Future.delayed(const Duration(milliseconds: 50), () {
      focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        title: Text('快捷键'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '恢复默认',
            onPressed: () {
              setState(() {
                for (final func in shortcuts.keys) {
                  shortcuts[func] = defaultShortcuts[func]?.toList() ?? [];
                  setting.put('shortcut_$func', shortcuts[func]);
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
          canRequestFocus: true,
          skipTraversal: true,
          descendantsAreFocusable: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (listeningFunction == null) return KeyEventResult.ignored;

            final rawKey = event.logicalKey.keyLabel.isNotEmpty
                ? event.logicalKey.keyLabel
                : event.logicalKey.debugName ?? '';

            final handled = handleShortcutInput(rawKey);
            return handled ? KeyEventResult.handled : KeyEventResult.ignored;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children:
              shortcuts.entries.map((entry) {
                final func = entry.key;
                final keys = entry.value;
                return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            shortcutsChineseName[func] ?? func,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              keys.removeWhere((key) => key.isEmpty || key == '...');
                              setState(() => keys.add(''));
                              setting.put('shortcut_$func', keys);
                              startListening(func, keys.length - 1);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            focusNode: FocusNode(canRequestFocus: false),
                          ),
                        ],
                      ),
                      if (keys.isNotEmpty) const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int i = 0; i < keys.length; i++)
                          ActionChip(
                            label: Text(keyAliases[keys[i]] ?? keys[i],),
                            avatar: keys.length >=2 ?Icon(Icons.cancel) :Icon(Icons.edit),
                            onPressed: (keys.length >=2)
                              ?() {
                                setState(() {
                                  keys.removeAt(i);
                                  listeningIndex = null;
                                  if (keys.length >1){
                                    keys.removeWhere((key) => key.isEmpty || key == '...');
                                  }
                                  setting.put('shortcut_$func', keys);
                                });
                              }
                              :() => startListening(func, 0),
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
