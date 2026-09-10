import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/pages/plugin_editor/plugin_update_actions.dart';
import 'package:kazumi/pages/plugin_editor/rule_dialogs.dart';
import 'package:kazumi/pages/plugin_editor/rule_management_widgets.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/plugin/plugin_import_parser.dart';

class PluginViewPage extends StatefulWidget {
  const PluginViewPage({super.key, required this.controller});
  final PluginsController controller;

  @override
  State<PluginViewPage> createState() => _PluginViewPageState();
}

class _PluginViewPageState extends State<PluginViewPage> {
  PluginsController get _controller => widget.controller;
  final _search = TextEditingController();
  final Set<String> _selected = {};
  final Set<String> _updatingNames = {};
  bool _selecting = false;
  bool _updatesOnly = false;
  bool _updating = false;
  bool _deleting = false;
  bool _catalogFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUpdateStatus());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadUpdateStatus() async {
    try {
      await _controller.ensurePluginCatalog();
      if (mounted) setState(() => _catalogFailed = false);
    } catch (_) {
      if (mounted) setState(() => _catalogFailed = true);
    }
  }

  Future<void> _updateAll() async {
    if (_updating) return;
    setState(() => _updating = true);
    await updateAllPluginsWithFeedback(_controller, ensureCatalog: true);
    if (mounted) {
      setState(() {
        _updating = false;
        _catalogFailed = !_controller.isPluginCatalogFresh;
      });
    }
  }

  Future<void> _add() async {
    final source = await showRuleAddDialog(context);
    if (!mounted || source == null) return;
    switch (source) {
      case RuleAddSource.catalog:
        context.pushNamed('/settings/plugin/shop');
      case RuleAddSource.create:
        context.pushNamed('/settings/plugin/editor',
            arguments: Plugin.fromTemplate());
      case RuleAddSource.clipboard:
        String? initialValue;
        try {
          initialValue = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        } catch (_) {
          initialValue = null;
        }
        if (mounted) {
          await showRuleImportDialog(context, _controller,
              initialValue: initialValue ?? '');
        }
      case RuleAddSource.file:
        await _importFromFile();
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['json'],
          withData: true);
      if (result == null) return;
      final file = result.files.single;
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw const FileSystemException('无法读取所选文件');
      final parsed = PluginImportParser.parse(utf8.decode(bytes));
      if (parsed.plugins.isEmpty) {
        KazumiDialog.showToast(
            message: parsed.failures.isEmpty
                ? '文件中没有可导入的规则'
                : parsed.failures.first);
        return;
      }
      await _controller.updatePlugins(parsed.plugins);
      KazumiDialog.showToast(
          message: '已导入 ${parsed.plugins.length} 条规则，'
              '跳过重复 ${parsed.duplicateCount} 条，失败 ${parsed.failureCount} 条');
    } catch (error, stackTrace) {
      KazumiLogger().e('Plugin: failed to import rules from file',
          error: error, stackTrace: stackTrace);
      KazumiDialog.showToast(message: '导入规则文件失败：$error');
    }
  }

  void _leaveSelection() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _toggleSelection(String name) => setState(() {
        if (!_selected.add(name)) _selected.remove(name);
      });

  Future<void> _delete(Set<String> names) async {
    if (_deleting || names.isEmpty) return;
    setState(() => _deleting = true);
    final confirmed = await confirmRuleDeletion(context, names);
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _deleting = false);
      return;
    }
    try {
      await _controller.removePlugins(names);
      if (mounted) _leaveSelection();
      KazumiDialog.showToast(message: '已删除 ${names.length} 条规则');
    } catch (_) {
      KazumiDialog.showToast(message: '删除规则失败，请重试');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    try {
      await _controller.onReorder(oldIndex, newIndex);
    } catch (_) {
      KazumiDialog.showToast(message: '保存规则顺序失败');
    }
  }

  Future<void> _updateOne(Plugin plugin) async {
    if (_updating || !_updatingNames.add(plugin.name)) return;
    setState(() {});
    try {
      await _controller.ensurePluginCatalog();
      final state = _controller.pluginUpdateStatus(plugin);
      if (state == PluginUpdateAvailability.updatable) {
        await updatePluginWithFeedback(_controller, plugin.name,
            installing: false);
      } else {
        KazumiDialog.showToast(
            message: state == PluginUpdateAvailability.notInCatalog
                ? '规则仓库中没有当前规则'
                : '规则已是最新');
      }
    } catch (_) {
      KazumiDialog.showToast(message: '检查规则更新失败');
    } finally {
      if (mounted) setState(() => _updatingNames.remove(plugin.name));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selecting) _leaveSelection();
        },
        child: SettingsDetailScaffold(
          title: Text(_selecting ? '已选择 ${_selected.length} 条' : '规则管理'),
          leading: _selecting
              ? IconButton(
                  tooltip: '退出多选',
                  onPressed: _leaveSelection,
                  icon: const Icon(Icons.close_rounded))
              : null,
          actions: [
            if (_selecting)
              IconButton(
                tooltip: '删除所选规则',
                onPressed: _selected.isEmpty || _deleting
                    ? null
                    : () => _delete(Set.of(_selected)),
                icon: const Icon(Icons.delete_outline_rounded),
              )
            else
              IconButton(
                tooltip: '批量选择',
                onPressed: () => setState(() => _selecting = true),
                icon: const Icon(Icons.checklist_rounded),
              ),
            const SizedBox(width: 8),
          ],
          body: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Observer(builder: (context) {
                  final colors = Theme.of(context).colorScheme;
                  final all = _controller.pluginList.toList();
                  final updates = all
                      .where((p) =>
                          _controller.pluginUpdateStatus(p) ==
                          PluginUpdateAvailability.updatable)
                      .length;
                  final query = _search.text.trim().toLowerCase();
                  final visible = all
                      .where((p) =>
                          (p.name.toLowerCase().contains(query) ||
                              p.baseUrl.toLowerCase().contains(query)) &&
                          (!_updatesOnly ||
                              _controller.pluginUpdateStatus(p) ==
                                  PluginUpdateAvailability.updatable))
                      .toList();
                  final canReorder =
                      query.isEmpty && !_updatesOnly && !_selecting;
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) => Material(
                        elevation: 0, color: Colors.transparent, child: child),
                    onReorderItem: (oldIndex, newIndex) =>
                        unawaited(_reorder(oldIndex, newIndex)),
                    header: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RulePageIntro(
                          title: '我的规则',
                          description: '管理你的番剧来源。拖动调整搜索顺序，点按规则进行编辑。',
                          icon: Icons.extension_rounded,
                          actions: [
                            FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(120, 48)),
                                onPressed: _add,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('添加规则')),
                            FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(120, 48)),
                                onPressed: () =>
                                    context.pushNamed('/settings/plugin/shop'),
                                icon: const Icon(Icons.travel_explore_rounded),
                                label: const Text('规则仓库')),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: ruleInputDecoration(context,
                              hint: '搜索名称或站点',
                              prefix: const Icon(Icons.search_rounded),
                              suffix: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '清除搜索',
                                      onPressed: () => setState(_search.clear),
                                      icon: const Icon(Icons.close_rounded))),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilterChip(
                                label: Text('全部 ${all.length}'),
                                selected: !_updatesOnly,
                                onSelected: (_) =>
                                    setState(() => _updatesOnly = false)),
                            FilterChip(
                                label: Text('可更新 $updates'),
                                selected: _updatesOnly,
                                onSelected: (value) =>
                                    setState(() => _updatesOnly = value)),
                            TextButton.icon(
                                onPressed:
                                    _updating || _updatingNames.isNotEmpty
                                        ? null
                                        : _updateAll,
                                icon: _updating
                                    ? const LoadingIndicator(size: 20)
                                    : const Icon(Icons.sync_rounded, size: 20),
                                label: Text(_updating ? '正在更新' : '更新全部')),
                            if (_selecting)
                              TextButton(
                                  onPressed: () => setState(() {
                                        if (visible.every((p) =>
                                            _selected.contains(p.name))) {
                                          _selected.removeAll(
                                              visible.map((p) => p.name));
                                        } else {
                                          _selected.addAll(
                                              visible.map((p) => p.name));
                                        }
                                      }),
                                  child: Text(visible.isNotEmpty &&
                                          visible.every(
                                              (p) => _selected.contains(p.name))
                                      ? '取消全选'
                                      : '全选当前列表')),
                          ],
                        ),
                        if (_catalogFailed)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('暂时无法检查更新，已安装的规则仍可使用。',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: colors.onSurfaceVariant))),
                        const SizedBox(height: 8),
                      ],
                    ),
                    footer: visible.isEmpty
                        ? GeneralEmptyState(
                            icon: all.isEmpty
                                ? Icons.extension_rounded
                                : Icons.search_off_rounded,
                            title: all.isEmpty
                                ? '还没有安装规则'
                                : _updatesOnly && query.isEmpty
                                    ? '没有可更新的规则'
                                    : '没有符合条件的规则',
                            actions: [
                              if (all.isEmpty)
                                StateActionButton.tonal(
                                    onPressed: () => context
                                        .pushNamed('/settings/plugin/shop'),
                                    icon: Icons.travel_explore_rounded,
                                    text: '浏览规则仓库')
                              else
                                StateActionButton.tonal(
                                    onPressed: () => setState(() {
                                          _search.clear();
                                          _updatesOnly = false;
                                        }),
                                    text: '显示全部规则'),
                            ],
                          )
                        : null,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final plugin = visible[index];
                      final actualIndex = all.indexOf(plugin);
                      final updatable =
                          _controller.pluginUpdateStatus(plugin) ==
                              PluginUpdateAvailability.updatable;
                      return RuleCard(
                        key: ValueKey(plugin.name),
                        title: plugin.name,
                        subtitle: Uri.tryParse(plugin.baseUrl)?.host ??
                            plugin.baseUrl,
                        selected: _selected.contains(plugin.name),
                        onTap: () {
                          if (_selecting) {
                            _toggleSelection(plugin.name);
                          } else {
                            context.pushNamed('/settings/plugin/editor',
                                arguments: plugin);
                          }
                        },
                        onLongPress: () => setState(() {
                          _selecting = true;
                          _selected.add(plugin.name);
                        }),
                        tags: [
                          RuleTag(
                              label: plugin.version,
                              background: colors.surfaceContainerHighest,
                              foreground: colors.onSurfaceVariant),
                          if (updatable)
                            RuleTag(
                                label: '可更新',
                                background: colors.secondaryContainer,
                                foreground: colors.onSecondaryContainer),
                          if (_controller.validityTracker
                              .isSearchValid(plugin.name))
                            RuleTag(
                                label: '搜索通过',
                                background: colors.tertiaryContainer,
                                foreground: colors.onTertiaryContainer),
                        ],
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_selecting)
                            Checkbox(
                                value: _selected.contains(plugin.name),
                                semanticLabel: '选择 ${plugin.name}',
                                onChanged: (_) => _toggleSelection(plugin.name))
                          else if (_updatingNames.contains(plugin.name))
                            const Padding(
                                padding: EdgeInsets.all(12),
                                child: LoadingIndicator(size: 24))
                          else
                            _menu(plugin, actualIndex),
                          if (canReorder)
                            Tooltip(
                              message: '拖动排序',
                              child: ReorderableDragStartListener(
                                index: index,
                                child: const SizedBox.square(
                                    dimension: 48,
                                    child: Icon(Icons.drag_indicator_rounded)),
                              ),
                            ),
                        ]),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      );

  Widget _menu(Plugin plugin, int index) => MenuAnchor(
        consumeOutsideTap: true,
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
        builder: (context, controller, child) => IconButton(
            tooltip: '${plugin.name} 的更多操作',
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.more_horiz_rounded)),
        menuChildren: [
          MenuItemButton(
              leadingIcon: const Icon(Icons.edit_outlined),
              onPressed: () => context.pushNamed('/settings/plugin/editor',
                  arguments: plugin),
              child: const Text('编辑规则')),
          MenuItemButton(
              leadingIcon: const Icon(Icons.bug_report_outlined),
              onPressed: () =>
                  context.pushNamed('/settings/plugin/test', arguments: plugin),
              child: const Text('测试规则')),
          MenuItemButton(
              leadingIcon: const Icon(Icons.sync_rounded),
              onPressed: _updating ? null : () => _updateOne(plugin),
              child: const Text('检查更新')),
          MenuItemButton(
              leadingIcon: const Icon(Icons.ios_share_rounded),
              onPressed: () => showRuleShareDialog(context, plugin),
              child: const Text('分享规则')),
          const Divider(),
          MenuItemButton(
              leadingIcon: const Icon(Icons.arrow_upward_rounded),
              onPressed: index == 0 ? null : () => _reorder(index, index - 1),
              child: const Text('上移')),
          MenuItemButton(
              leadingIcon: const Icon(Icons.arrow_downward_rounded),
              onPressed: index == _controller.pluginList.length - 1
                  ? null
                  : () => _reorder(index, index + 1),
              child: const Text('下移')),
          const Divider(),
          MenuItemButton(
              leadingIcon: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error),
              onPressed: _deleting ? null : () => _delete({plugin.name}),
              child: Text('删除规则',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      );
}
