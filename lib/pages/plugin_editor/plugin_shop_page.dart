import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/plugin_editor/plugin_catalog_view.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

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

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void _toggleSort() {
    setState(() {
      sortByName = !sortByName;
    });
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
                onPressed: () => catalogKey.currentState?.refresh(),
                tooltip: '刷新规则列表',
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: PluginCatalogView(
          key: catalogKey,
          controller: widget.controller,
          sort: sortByName
              ? PluginCatalogSort.name
              : PluginCatalogSort.lastUpdate,
          errorMessage: '啊咧（⊙.⊙） 无法访问规则仓库',
          onMirrorAction: () => context.pushNamed('/settings/webdav/'),
        ),
      ),
    );
  }
}
