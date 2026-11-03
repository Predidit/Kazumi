import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/pages/plugin_editor/rule_management_widgets.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/plugin/plugin_import_parser.dart';
import 'package:kazumi/utils/encoding.dart';

enum RuleAddSource { catalog, clipboard, file, create }

Future<RuleAddSource?> showRuleAddDialog(BuildContext context) =>
    KazumiDialog.show<RuleAddSource>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return _RuleDialog(
          title: '添加规则',
          icon: Icons.add_circle_outline_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('选择一种方式，添加新的番剧来源。'),
              const SizedBox(height: 20),
              for (final option in [
                (
                  RuleAddSource.catalog,
                  Icons.travel_explore_rounded,
                  '浏览规则仓库',
                  '发现并安装社区规则'
                ),
                (
                  RuleAddSource.clipboard,
                  Icons.content_paste_rounded,
                  '从剪贴板导入',
                  '粘贴规则链接或 JSON'
                ),
                (
                  RuleAddSource.file,
                  Icons.file_open_outlined,
                  '从文件导入',
                  '读取本地 JSON 规则文件'
                ),
                (
                  RuleAddSource.create,
                  Icons.edit_note_rounded,
                  '新建规则',
                  '从模板开始编写'
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: option.$1 == RuleAddSource.catalog
                        ? colors.secondaryContainer
                        : colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(
                        option.$1 == RuleAddSource.catalog ? 20 : 12),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      minVerticalPadding: 14,
                      leading: Icon(option.$2, color: colors.onSurfaceVariant),
                      title: Text(option.$3),
                      subtitle: Text(option.$4),
                      trailing:
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                      onTap: () => Navigator.of(context).pop(option.$1),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消')),
          ],
        );
      },
    );

Future<bool> confirmRuleDeletion(
        BuildContext context, Set<String> names) async =>
    await KazumiDialog.show<bool>(
      context: context,
      builder: (context) => _RuleDialog(
        title: names.length == 1 ? '删除这条规则？' : '删除 ${names.length} 条规则？',
        icon: Icons.delete_outline_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(names.take(5).join('、') + (names.length > 5 ? ' 等' : ''),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text('删除后将不再使用这些来源搜索番剧。你可以稍后重新导入规则。'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('保留')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> showRuleShareDialog(BuildContext context, Plugin plugin) async {
  final link = jsonToKazumiBase64(jsonEncode(plugin.toJson()));
  await KazumiDialog.show<void>(
    context: context,
    builder: (context) => _RuleDialog(
      title: '分享规则',
      icon: Icons.ios_share_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plugin.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('复制规则链接，对方可在「添加规则」中从剪贴板导入。'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16)),
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: SelectableText(link,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭')),
        FilledButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('复制链接'),
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: link));
              if (!context.mounted) return;
              KazumiDialog.dismiss(context: context);
              KazumiDialog.showToast(message: '规则链接已复制');
            } catch (_) {
              if (context.mounted) {
                KazumiDialog.showToast(context: context, message: '复制失败，请重试');
              }
            }
          },
        ),
      ],
    ),
  );
}

Future<void> showRuleImportDialog(
  BuildContext context,
  PluginsController controller, {
  String initialValue = '',
}) =>
    KazumiDialog.show<void>(
      context: context,
      clickMaskDismiss: false,
      builder: (context) =>
          _RuleImportDialog(controller: controller, initialValue: initialValue),
    );

class _RuleImportDialog extends StatefulWidget {
  const _RuleImportDialog(
      {required this.controller, required this.initialValue});
  final PluginsController controller;
  final String initialValue;

  @override
  State<_RuleImportDialog> createState() => _RuleImportDialogState();
}

class _RuleImportDialogState extends State<_RuleImportDialog> {
  late final _text = TextEditingController(text: widget.initialValue);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_saving) return;
    final result = PluginImportParser.parse(_text.text);
    if (result.plugins.isEmpty) {
      setState(() => _error = result.failures.isEmpty
          ? '没有识别到规则，请粘贴规则链接或 JSON。'
          : result.failures.first);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.updatePlugins(result.plugins);
      if (!mounted) return;
      KazumiDialog.dismiss(context: context);
      KazumiDialog.showToast(
          message: '已导入 ${result.plugins.length} 条规则'
              '，跳过重复 ${result.duplicateCount} 条，失败 ${result.failureCount} 条');
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，内容已保留，请重试。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: _RuleDialog(
          title: '导入规则',
          icon: Icons.content_paste_go_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('支持多条 kazumi:// 链接、单条 JSON 或 JSON 数组。同名规则会被替换。'),
              const SizedBox(height: 20),
              TextField(
                controller: _text,
                enabled: !_saving,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() => _error = null),
                decoration: ruleInputDecoration(context,
                        label: '规则内容', hint: '在这里粘贴规则链接或 JSON')
                    .copyWith(
                        alignLabelWithHint: true,
                        errorText: _error,
                        errorMaxLines: 4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: _saving || _text.text.trim().isEmpty ? null : _import,
              icon: _saving
                  ? const LoadingIndicator(size: 20)
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_saving ? '正在导入' : '导入规则'),
            ),
          ],
        ),
      );
}

class _RuleDialog extends StatelessWidget {
  const _RuleDialog({
    required this.title,
    required this.icon,
    required this.content,
    required this.actions,
  });

  final String title;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      constraints: const BoxConstraints(maxWidth: 560),
      insetPadding: const EdgeInsets.all(24),
      scrollable: true,
      icon: Icon(icon, color: colors.secondary, size: 32),
      title: Text(title),
      content: SizedBox(width: 480, child: content),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actionsOverflowButtonSpacing: 8,
      actions: actions,
    );
  }
}
