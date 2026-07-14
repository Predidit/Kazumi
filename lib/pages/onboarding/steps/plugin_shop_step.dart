import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';
import 'package:kazumi/pages/plugin_editor/plugin_update_actions.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/storage/storage.dart';

class PluginShopStep extends StatefulWidget {
  const PluginShopStep({
    super.key,
    required this.controller,
  });

  final PluginsController controller;

  @override
  State<PluginShopStep> createState() => _PluginShopStepState();
}

class _PluginShopStepState extends State<PluginShopStep> {
  bool loading = true;
  bool loadFailed = false;

  PluginsController get pluginsController => widget.controller;

  @override
  void initState() {
    super.initState();
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

  void _handleRefresh() {
    if (loading) return;
    setState(() {
      loading = true;
      loadFailed = false;
    });
    unawaited(_loadPluginCatalog(forceRefresh: true));
  }

  Future<void> _toggleGitProxyAndRefresh() async {
    final enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    await GStorage.putSetting(SettingsKeys.enableGitProxy, !enableGitProxy);
    if (!mounted) return;
    _handleRefresh();
  }

  Widget get pluginListBody {
    return Observer(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      final sortedList = pluginsController.pluginHTTPList.toList()
        ..sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));

      return ListView.builder(
        padding: EdgeInsets.zero,
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
                ? DateTime.fromMillisecondsSinceEpoch(item.lastUpdate)
                    .toString()
                    .split(' ')[0]
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
    final enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    return Center(
      child: GeneralErrorWidget(
        errMsg:
            '无法访问规则仓库\n${enableGitProxy ? '规则仓库镜像已启用' : '规则仓库镜像已禁用'}',
        actions: [
          GeneralErrorButton(
            onPressed: () {
              unawaited(_toggleGitProxyAndRefresh());
            },
            text: enableGitProxy ? '禁用规则镜像' : '启用规则镜像',
          ),
          GeneralErrorButton(
            onPressed: _handleRefresh,
            text: '刷新',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      leading: const OnboardingStepIcon(icon: Icons.travel_explore_rounded),
      title: '添加规则',
      subtitle: '规则提供番剧搜索源，可稍后在 设置 → 规则管理 中调整',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _handleRefresh,
                tooltip: '刷新规则列表',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : loadFailed
                    ? loadErrorWidget
                    : pluginsController.pluginHTTPList.isEmpty
                        ? const Center(child: Text('规则仓库中暂无规则'))
                        : pluginListBody,
          ),
        ],
      ),
    );
  }
}
