import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/pages/plugin_editor/plugin_update_actions.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/storage/storage.dart';

enum PluginCatalogSort { lastUpdate, name }

class PluginCatalogView extends StatefulWidget {
  const PluginCatalogView({
    super.key,
    required this.controller,
    this.sort = PluginCatalogSort.lastUpdate,
    this.listPadding = const EdgeInsets.symmetric(horizontal: 8),
    this.showRefreshButton = false,
    this.compactLastUpdate = false,
    this.errorMessage = '无法访问规则仓库',
    this.onMirrorAction,
  });

  final PluginsController controller;
  final PluginCatalogSort sort;
  final EdgeInsetsGeometry listPadding;
  final bool showRefreshButton;
  final bool compactLastUpdate;
  final String errorMessage;
  final VoidCallback? onMirrorAction;

  @override
  State<PluginCatalogView> createState() => PluginCatalogViewState();
}

class PluginCatalogViewState extends State<PluginCatalogView> {
  bool _loading = true;
  bool _loadFailed = false;

  PluginsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (_controller.isPluginCatalogFresh) {
      _loading = false;
    } else {
      unawaited(_loadPluginCatalog());
    }
  }

  Future<void> _loadPluginCatalog({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await _controller.refreshPluginCatalog();
      } else {
        await _controller.ensurePluginCatalog();
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void refresh() {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    unawaited(_loadPluginCatalog(forceRefresh: true));
  }

  Future<void> _toggleGitProxyAndRefresh() async {
    final enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    await GStorage.putSetting(SettingsKeys.enableGitProxy, !enableGitProxy);
    if (!mounted) return;
    refresh();
  }

  void _handleMirrorAction() {
    final onMirrorAction = widget.onMirrorAction;
    if (onMirrorAction != null) {
      onMirrorAction();
      return;
    }
    unawaited(_toggleGitProxyAndRefresh());
  }

  List<PluginHTTPItem> _sortedItems() {
    final items = _controller.pluginHTTPList.toList();
    switch (widget.sort) {
      case PluginCatalogSort.lastUpdate:
        items.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
      case PluginCatalogSort.name:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return items;
  }

  Widget _buildPluginList() {
    return Observer(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      final items = _sortedItems();

      return ListView.builder(
        padding: widget.listPadding,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final status = _controller.pluginStatus(item);
          return RuleCard(
            title: item.name,
            tags: [
              RuleTag(
                label: item.version,
                background: colorScheme.secondaryContainer,
                foreground: colorScheme.onSecondaryContainer,
              ),
              if (item.antiCrawlerEnabled)
                RuleTag(
                  label: 'captcha',
                  background: colorScheme.tertiaryContainer,
                  foreground: colorScheme.onTertiaryContainer,
                ),
            ],
            caption:
                item.lastUpdate > 0 ? _formatLastUpdate(item.lastUpdate) : null,
            trailing: RuleCardActionButton(
              label: switch (status) {
                PluginCatalogItemStatus.install => '安装',
                PluginCatalogItemStatus.installed => '已安装',
                PluginCatalogItemStatus.update => '更新',
              },
              onPressed: status == PluginCatalogItemStatus.installed
                  ? null
                  : () async {
                      final result = await updatePluginWithFeedback(
                        _controller,
                        item.name,
                        installing: status == PluginCatalogItemStatus.install,
                      );
                      if (result == PluginUpdateResult.updated && mounted) {
                        setState(() {});
                      }
                    },
            ),
          );
        },
      );
    });
  }

  String _formatLastUpdate(int millisecondsSinceEpoch) {
    final value =
        DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch).toString();
    if (widget.compactLastUpdate) {
      return value.split(' ')[0];
    }
    return '更新时间: ${value.split('.')[0]}';
  }

  Widget _buildLoadError() {
    final enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    return Center(
      child: GeneralErrorWidget(
        errMsg:
            '${widget.errorMessage}\n${enableGitProxy ? '规则仓库镜像已启用' : '规则仓库镜像已禁用'}',
        actions: [
          GeneralErrorButton(
            onPressed: _handleMirrorAction,
            text: enableGitProxy ? '禁用规则镜像' : '启用规则镜像',
          ),
          GeneralErrorButton(onPressed: refresh, text: '刷新'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadFailed) {
      return _buildLoadError();
    }
    if (_controller.pluginHTTPList.isEmpty) {
      return const Center(child: Text('规则仓库中暂无规则'));
    }
    return _buildPluginList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showRefreshButton) {
      return _buildBody();
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: refresh,
              tooltip: '刷新规则列表',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildBody()),
      ],
    );
  }
}
