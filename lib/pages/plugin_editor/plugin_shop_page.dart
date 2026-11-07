import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/plugin_editor/plugin_catalog_view.dart';
import 'package:kazumi/pages/plugin_editor/rule_dialogs.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

class PluginShopPage extends StatefulWidget {
  const PluginShopPage({super.key, required this.controller});
  final PluginsController controller;

  @override
  State<PluginShopPage> createState() => _PluginShopPageState();
}

class _PluginShopPageState extends State<PluginShopPage> {
  Future<void> _editRepository() async {
    await showRuleRepositoryDialog(context, widget.controller);
    // A changed repository remounts the catalog through its key.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('规则仓库'),
        actions: [
          IconButton(
            onPressed: _editRepository,
            tooltip: '规则仓库地址',
            icon: const Icon(Icons.link_rounded),
          ),
        ],
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: PluginCatalogView(
                key: ValueKey(widget.controller.ruleRepository),
                controller: widget.controller,
              ),
            ),
          ),
        ),
      );
}
