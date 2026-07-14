import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/plugin_editor/plugin_update_actions.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';

class PluginShopPage extends StatefulWidget {
  const PluginShopPage({
    super.key,
    required this.controller,
  });

  final PluginsController controller;

  @override
  State<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends State<PluginShopPage> {
  bool loadFailed = false;
  bool loading = true;
  late bool enableGitProxy;

  // 排序方式状态：false=按更新时间排序，true=按名称排序
  bool sortByName = false;
  PluginsController get pluginsController => widget.controller;

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    if (pluginsController.isPluginCatalogFresh) {
      loading = false;
    } else {
      unawaited(_loadPluginCatalog());
    }
  }

  Future<void> _loadPluginCatalog({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await pluginsController.refreshPluginCatalog();
      } else {
        await pluginsController.ensurePluginCatalog();
      }
      if (!mounted) return;
      setState(() {
        loading = false;
        loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadFailed = true;
      });
    }
  }

  // 刷新规则列表
  void _handleRefresh() {
    if (loading) return;
    setState(() {
      loading = true;
      loadFailed = false;
      enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    });
    unawaited(_loadPluginCatalog(forceRefresh: true));
  }

  // 切换排序方式
  void _toggleSort() {
    setState(() {
      sortByName = !sortByName;
    });
  }

  Widget get pluginHTTPListBody {
    return Observer(builder: (context) {
      // 创建列表副本用于排序
      final sortedList = pluginsController.pluginHTTPList.toList();

      // 排序规则：
      // 1. 按名称排序：忽略大小写的字母顺序
      // 2. 按时间排序：更新时间降序（最新的在前面）
      if (sortByName) {
        sortedList.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else {
        sortedList.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
      }

      final colorScheme = Theme.of(context).colorScheme;
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: sortedList.length,
        itemBuilder: (context, index) {
          final item = sortedList[index];
          final status = pluginsController.pluginStatus(item);
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
            caption: item.lastUpdate > 0
                ? '更新时间: ${DateTime.fromMillisecondsSinceEpoch(item.lastUpdate).toString().split('.')[0]}'
                : null,
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
                        pluginsController,
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

  Widget get loadErrorWidget {
    return Center(
      child: GeneralErrorWidget(
        errMsg:
            '啊咧（⊙.⊙） 无法访问规则仓库\n${enableGitProxy ? '规则仓库镜像已启用' : '规则仓库镜像已禁用'}',
        actions: [
          GeneralErrorButton(
            onPressed: () {
              context.pushNamed('/settings/webdav/');
            },
            text: enableGitProxy ? '禁用规则镜像' : '启用规则镜像',
          ),
          GeneralErrorButton(
            onPressed: () {
              _handleRefresh();
            },
            text: '刷新',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: const Text('规则仓库'),
          actions: [
            IconButton(
                onPressed: _toggleSort,
                tooltip: sortByName ? '按名称排序' : '按更新时间排序',
                icon:
                    Icon(sortByName ? Icons.sort_by_alpha : Icons.access_time)),
            IconButton(
                onPressed: () {
                  _handleRefresh();
                },
                tooltip: '刷新规则列表',
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : loadFailed
                ? loadErrorWidget
                : pluginsController.pluginHTTPList.isEmpty
                    ? const Center(child: Text('规则仓库中暂无规则'))
                    : pluginHTTPListBody,
      ),
    );
  }
}
