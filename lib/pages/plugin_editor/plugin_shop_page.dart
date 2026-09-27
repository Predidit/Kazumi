import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/plugin_editor/plugin_catalog_view.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

class PluginShopPage extends StatelessWidget {
  const PluginShopPage({super.key, required this.controller});
  final PluginsController controller;

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('规则仓库'),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: PluginCatalogView(controller: controller),
            ),
          ),
        ),
      );
}
