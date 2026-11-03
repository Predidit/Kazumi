import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/plugin_editor/plugin_catalog_view.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/config/rules_repository_config.dart';
import 'package:kazumi/services/storage/storage.dart';

class PluginShopPage extends StatefulWidget {
  const PluginShopPage({super.key, required this.controller});
  final PluginsController controller;

  @override
  State<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends State<PluginShopPage> {
  final _catalogKey = GlobalKey<PluginCatalogViewState>();
  bool _configuring = false;

  Future<void> _configureRepository() async {
    if (_configuring) return;
    setState(() => _configuring = true);
    try {
      final result = await KazumiDialog.show<String>(
        context: context,
        builder: (_) => _RepositoryDialog(
          initialUrl: GStorage.getSetting(SettingsKeys.ruleRepositoryUrl),
        ),
      );
      if (result == null || !mounted) return;
      final normalized = RulesRepositoryConfig.normalizeForStorage(result);
      await GStorage.putSetting(SettingsKeys.ruleRepositoryUrl, normalized);
      widget.controller.invalidatePluginCatalog();
      if (!mounted) return;
      final refreshed = await _catalogKey.currentState?.refresh() ?? false;
      if (!mounted) return;
      KazumiDialog.showToast(
        context: context,
        message: refreshed
            ? (normalized.isEmpty ? '已恢复官方规则仓库' : '已切换规则仓库')
            : '仓库地址已保存，但目录加载失败',
      );
    } on FormatException catch (error) {
      if (mounted) {
        KazumiDialog.showToast(context: context, message: error.message);
      }
    } catch (_) {
      if (mounted) {
        KazumiDialog.showToast(context: context, message: '保存规则仓库失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _configuring = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
    title: const Text('规则仓库'),
    actions: [
      IconButton(
        onPressed: _configuring ? null : _configureRepository,
        tooltip: '设置规则仓库',
        icon: const Icon(Icons.storage_rounded),
      ),
    ],
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: PluginCatalogView(
            key: _catalogKey,
            controller: widget.controller,
          ),
        ),
      ),
    ),
  );
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
