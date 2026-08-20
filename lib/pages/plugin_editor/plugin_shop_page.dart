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
    final textController = TextEditingController(text: currentUrl);
    final result = await KazumiDialog.show<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                controller: textController,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: '仓库地址',
                  hintText: ApiEndpoints.pluginShop,
                  helperText: '填写包含 index.json 的目录，或直接粘贴 index.json URL',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(''),
            child: const Text('恢复官方仓库'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result == null) return;

    try {
      final normalized = RulesRepositoryConfig.normalizeForStorage(result);
      await GStorage.putSetting(SettingsKeys.ruleRepositoryUrl, normalized);
      catalogKey.currentState?.refresh();
      if (!mounted) return;
      KazumiDialog.showToast(
        context: context,
        message: normalized.isEmpty ? '已恢复官方规则仓库' : '已切换规则仓库',
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
