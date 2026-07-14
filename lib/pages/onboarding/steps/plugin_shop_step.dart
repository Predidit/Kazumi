import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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
      final textTheme = Theme.of(context).textTheme;
      final sortedList = pluginsController.pluginHTTPList.toList()
        ..sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));

      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: sortedList.length,
        itemBuilder: (context, index) {
          final item = sortedList[index];
          final status = pluginsController.pluginStatus(item);
          return Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item.name, style: textTheme.titleMedium),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoChip(
                      label: item.version,
                      background: colorScheme.secondaryContainer,
                      foreground: colorScheme.onSecondaryContainer,
                    ),
                    if (item.antiCrawlerEnabled)
                      _InfoChip(
                        label: 'captcha',
                        background: colorScheme.tertiaryContainer,
                        foreground: colorScheme.onTertiaryContainer,
                      ),
                    if (item.lastUpdate > 0)
                      Text(
                        DateTime.fromMillisecondsSinceEpoch(item.lastUpdate)
                            .toString()
                            .split(' ')[0],
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              trailing: status == PluginCatalogItemStatus.installed
                  ? Text(
                      '已安装',
                      style: textTheme.labelLarge
                          ?.copyWith(color: colorScheme.outline),
                    )
                  : FilledButton.tonal(
                      onPressed: () async {
                        final result = await updatePluginWithFeedback(
                          pluginsController,
                          item.name,
                          installing:
                              status == PluginCatalogItemStatus.install,
                        );
                        if (result == PluginUpdateResult.updated && mounted) {
                          setState(() {});
                        }
                      },
                      child: Text(status == PluginCatalogItemStatus.install
                          ? '安装'
                          : '更新'),
                    ),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style:
            Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
