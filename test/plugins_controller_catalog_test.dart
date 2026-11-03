import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins.dart';

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
    expect(loadCount, 2);

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

  test(
    'obsolete catalog failures join the current repository request',
    () async {
      final firstLoad = Completer<List<PluginHTTPItem>>();
      final secondLoad = Completer<List<PluginHTTPItem>>();
      var loadCount = 0;
      var reportedErrors = 0;
      final controller = PluginsController(
        catalogLoader: () =>
            ++loadCount == 1 ? firstLoad.future : secondLoad.future,
        errorReporter: (_, _, _) => reportedErrors++,
      );
      final initialRefresh = controller.refreshPluginCatalog();
      controller.invalidatePluginCatalog();
      final repositoryRefresh = controller.refreshPluginCatalog();
      firstLoad.completeError(StateError('old repository is unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(loadCount, 2);
      expect(reportedErrors, 0);
      secondLoad.complete([catalogItem('new')]);
      expect((await initialRefresh).single.name, 'new');
      expect((await repositoryRefresh).single.name, 'new');
      expect(controller.pluginHTTPList.single.name, 'new');
    },
  );

  test('invalidation after catalog completion starts a new request', () async {
    var loadCount = 0;
    final controller = PluginsController(
      catalogLoader: () async => [catalogItem('repository-${++loadCount}')],
    );
    await controller.refreshPluginCatalog();
    expect(controller.isPluginCatalogFresh, isTrue);
    controller.invalidatePluginCatalog();
    expect(controller.isPluginCatalogFresh, isFalse);
    final refreshed = await controller.refreshPluginCatalog();
    expect(loadCount, 2);
    expect(refreshed.single.name, 'repository-2');
    expect(controller.pluginHTTPList.single.name, 'repository-2');
  });

  test('repository switch discards an in-flight rule installation', () async {
    final download = Completer<Plugin>();
    final started = Completer<void>();
    var writes = 0;
    final controller = PluginsController(
      pluginLoader: (_) {
        started.complete();
        return download.future;
      },
      pluginJsonWriter: (_) async {
        writes++;
      },
    );
    final installing = controller.tryUpdatePluginByName('demo');
    await started.future;
    controller.invalidatePluginCatalog();
    download.complete(Plugin.fromJson({'name': 'demo', 'version': '1.0'}));
    expect(await installing, PluginUpdateResult.failed);
    expect(controller.pluginList, isEmpty);
    expect(writes, 0);
  });

  test('repository switch cancels a queued rule installation', () async {
    final download = Completer<Plugin>();
    final started = Completer<void>();
    var loads = 0;
    final controller = PluginsController(
      pluginLoader: (_) {
        loads++;
        started.complete();
        return download.future;
      },
      pluginJsonWriter: (_) async {},
    );
    final first = controller.tryUpdatePluginByName('first');
    await started.future;
    final queued = controller.tryUpdatePluginByName('second');
    controller.invalidatePluginCatalog();
    download.complete(Plugin.fromJson({'name': 'first', 'version': '1.0'}));
    expect(await first, PluginUpdateResult.failed);
    expect(await queued, PluginUpdateResult.failed);
    expect(loads, 1);
    expect(controller.pluginList, isEmpty);
  });

  test(
    'repository switch discards a batch and stops subsequent downloads',
    () async {
      final downloads = <String, Completer<Plugin>>{};
      final started = Completer<void>();
      var writes = 0;
      final names = List.generate(5, (index) => 'rule-$index');
      final controller = PluginsController(
        catalogLoader: () async => names.map(catalogItem).toList(),
        pluginLoader: (name) {
          final download = Completer<Plugin>();
          downloads[name] = download;
          if (downloads.length == 4) started.complete();
          return download.future;
        },
        pluginJsonWriter: (_) async {
          writes++;
        },
      );
      controller.pluginList.addAll(
        names.map((name) => Plugin.fromJson({'name': name, 'version': '0.1'})),
      );
      final updating = controller.tryUpdateAllPlugin();
      await started.future;
      controller.invalidatePluginCatalog();
      for (final entry in downloads.entries) {
        entry.value.complete(
          Plugin.fromJson({'name': entry.key, 'version': '1.0'}),
        );
      }
      final result = await updating;
      expect(result.candidates, 5);
      expect(result.updated, 0);
      expect(result.failed, 5);
      expect(downloads.length, 4);
      expect(
        controller.pluginList.every((plugin) => plugin.version == '0.1'),
        isTrue,
      );
      expect(writes, 0);
    },
  );
}
