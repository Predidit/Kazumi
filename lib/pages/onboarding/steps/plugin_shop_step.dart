import 'package:flutter/material.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';
import 'package:kazumi/pages/plugin_editor/plugin_catalog_view.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

class PluginShopStep extends StatelessWidget {
  const PluginShopStep({
    super.key,
    required this.controller,
  });

  final PluginsController controller;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      leading: const OnboardingStepIcon(icon: Icons.travel_explore_rounded),
      title: '添加规则',
      subtitle: '规则提供番剧搜索源，可稍后在 设置 → 规则管理 中调整',
      child: PluginCatalogView(
        controller: controller,
        listPadding: EdgeInsets.zero,
        showRefreshButton: true,
        compactLastUpdate: true,
      ),
    );
  }
}
