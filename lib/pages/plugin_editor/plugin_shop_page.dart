import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/plugin_editor/plugin_catalog_view.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/config/rules_repository_config.dart';
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
  final catalogKey = GlobalKey<PluginCatalogViewState>();
  bool sortByName = false;

  void _toggleSort() {
    setState(() {
      sortByName = !sortByName;
    });
  }

  Future<void> _configureRepository() async {
    final currentUrl = GStorage.getSetting(SettingsKeys.ruleRepositoryUrl);
    final result = await KazumiDialog.show<String>(
      context: context,
      builder: (_) => _RepositoryDialog(
        initialUrl: currentUrl,
      ),
    );
    if (result == null) return;

    try {
      final normalized = RulesRepositoryConfig.normalizeForStorage(result);
      await GStorage.putSetting(SettingsKeys.ruleRepositoryUrl, normalized);
      widget.controller.invalidatePluginCatalog();
      final refreshed = await catalogKey.currentState?.refresh() ?? false;
      if (!mounted) return;
      KazumiDialog.showToast(
        context: context,
        message: refreshed
            ? (normalized.isEmpty ? '已恢复官方规则仓库' : '已切换规则仓库')
            : '仓库地址已保存，但目录加载失败',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      KazumiDialog.showToast(context: context, message: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        title: const Text('规则仓库'),
        actions: [
          IconButton(
            onPressed: _configureRepository,
            tooltip: '设置规则仓库',
            icon: const Icon(Icons.storage_rounded),
          ),
          IconButton(
              onPressed: _toggleSort,
              tooltip: sortByName ? '按名称排序' : '按更新时间排序',
              icon: Icon(sortByName ? Icons.sort_by_alpha : Icons.access_time)),
          IconButton(
              onPressed: () => catalogKey.currentState?.refresh(),
              tooltip: '刷新规则列表',
              icon: const Icon(Icons.refresh))
        ],
      ),
      body: PluginCatalogView(
        key: catalogKey,
        controller: widget.controller,
        sort:
            sortByName ? PluginCatalogSort.name : PluginCatalogSort.lastUpdate,
        errorMessage: '啊咧（⊙.⊙） 无法访问规则仓库',
      ),
    );
  }
}

class _RepositoryDialog extends StatefulWidget {
  const _RepositoryDialog({required this.initialUrl});

  final String initialUrl;

  @override
  State<_RepositoryDialog> createState() => _RepositoryDialogState();
}

class _RepositoryDialogState extends State<_RepositoryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置规则仓库'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('仅添加你信任的仓库。第三方规则会访问其声明的网站和接口。'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '仓库地址',
                hintText: ApiEndpoints.pluginShop,
                helperText: '填写包含 index.json 的目录，或直接粘贴 index.json URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: const Text('恢复官方仓库'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
