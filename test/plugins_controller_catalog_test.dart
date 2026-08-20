import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

void main() {
  PluginHTTPItem catalogItem(String name) {
    return PluginHTTPItem(
      name: name,
      version: '1.0',
      useNativePlayer: false,
      author: 'test',
      lastUpdate: 0,
    );
  }

  test('repository invalidation retries an active catalog request', () async {
    final firstLoad = Completer<List<PluginHTTPItem>>();
    final secondLoad = Completer<List<PluginHTTPItem>>();
    var loadCount = 0;
    final controller = PluginsController(
      catalogLoader: () {
        loadCount++;
        return loadCount == 1 ? firstLoad.future : secondLoad.future;
      },
    );

    final initialRefresh = controller.refreshPluginCatalog();
    expect(loadCount, 1);

    controller.invalidatePluginCatalog();
    final repositoryRefresh = controller.refreshPluginCatalog();
    firstLoad.complete([catalogItem('old')]);
    await Future<void>.delayed(Duration.zero);

    expect(loadCount, 2);
    expect(controller.pluginHTTPList, isEmpty);

    secondLoad.complete([catalogItem('new')]);
    expect((await initialRefresh).single.name, 'new');
    expect((await repositoryRefresh).single.name, 'new');
    expect(controller.pluginHTTPList.single.name, 'new');
    expect(controller.isPluginCatalogFresh, isTrue);
  });
}
