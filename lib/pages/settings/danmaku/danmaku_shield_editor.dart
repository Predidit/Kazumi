import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/pages/my/my_controller.dart';

class DanmakuShieldEditor extends StatefulWidget {
  const DanmakuShieldEditor({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
  });

  final MyController controller;
  final EdgeInsetsGeometry padding;

  @override
  State<DanmakuShieldEditor> createState() => _DanmakuShieldEditorState();
}

class _DanmakuShieldEditorState extends State<DanmakuShieldEditor> {
  MyController get myController => widget.controller;
  final TextEditingController textEditingController = TextEditingController();

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  void _addRule() {
    final rule = textEditingController.text.trim();
    if (rule.isEmpty) return;
    final previousCount = myController.shieldList.length;
    myController.addShieldList(rule);
    if (myController.shieldList.length > previousCount) {
      textEditingController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: widget.padding,
      children: [
        ContentSection(
          title: '添加规则',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: textEditingController,
              decoration: InputDecoration(
                hintText: '关键词或 /正则表达式/',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                suffixIcon: IconButton(
                  tooltip: '添加规则',
                  onPressed: _addRule,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              onSubmitted: (_) => _addRule(),
            ),
            const SizedBox(height: 8),
            Text('包含关键词的弹幕会被隐藏。用 / / 包裹正则表达式。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ]),
        ),
        const SizedBox(height: 24),
        Observer(builder: (context) {
          final rules = myController.shieldList.toList();
          if (rules.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('还没有屏蔽规则',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            );
          }
          return ContentSection.group(
            title: '已添加 · ${rules.length}',
            children: [
              for (final rule in rules)
                ListTile(
                  title: Text(rule),
                  subtitle: rule.startsWith('/') && rule.endsWith('/')
                      ? const Text('正则表达式')
                      : null,
                  trailing: IconButton(
                    tooltip: '删除规则',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => myController.removeShieldList(rule),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}
