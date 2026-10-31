import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

Plugin _plugin(String name, {String version = '1.0'}) => Plugin.fromTemplate()
  ..name = name
  ..version = version;

PluginHTTPItem _item(String name, {String version = '1.0'}) => PluginHTTPItem(
  name: name,
  version: version,
  useNativePlayer: true,
  author: '',
  lastUpdate: 0,
);

void main() {
  test(
    'downloads missing rules and updates older rules with one write',
    () async {
      final downloaded = <String>[];
      final writes = <String>[];
      final controller = PluginsController(
        catalogLoader: () async => [
          _item('new'),
          _item('older', version: '2.0'),
          _item('latest'),
          _item('ahead'),
        ],
        pluginLoader: (name) async {
          downloaded.add(name);
          return _plugin(name, version: name == 'older' ? '2.0' : '1.0');
        },
        pluginJsonWriter: (json) async => writes.add(json),
      );
      final custom = _plugin('custom');
      controller.pluginList.addAll([
        _plugin('OLDER'),
        _plugin('latest'),
        _plugin('ahead', version: '3.0'),
        custom,
      ]);

      final result = await controller.tryDownloadAllPlugins();

      expect(downloaded, ['new', 'older']);
      expect(result.candidates, 2);
      expect(result.updated, 2);
      expect(result.failed, 0);
      expect(writes, hasLength(1));
      expect(jsonDecode(writes.single), hasLength(5));
      expect(controller.pluginList.first.version, '2.0');
      expect(controller.pluginList[2].version, '3.0');
      expect(controller.pluginList[3], same(custom));

      final repeated = await controller.tryDownloadAllPlugins();
      expect(repeated.hasNoCandidates, isTrue);
      expect(downloaded, hasLength(2));
      expect(writes, hasLength(1));
    },
  );

  test(
    'keeps successful downloads when other rules fail or are incompatible',
    () async {
      final controller = PluginsController(
        catalogLoader: () async => [
          for (final name in ['ok', 'offline', 'future', 'mismatch', 'stale'])
            _item(name, version: '2.0'),
        ],
        pluginLoader: (name) async => switch (name) {
          'offline' => throw StateError('offline'),
          'future' => _plugin(name)..api = '999',
          'mismatch' => _plugin('unexpected'),
          _ => _plugin(name),
        },
        pluginJsonWriter: (_) async {},
        errorReporter: (_, _, _) {},
      );
      controller.pluginList.add(_plugin('stale'));

      final result = await controller.tryDownloadAllPlugins();

      expect(result.candidates, 5);
      expect(result.updated, 1);
      expect(result.failed, 2);
      expect(result.requiresNewerClient, 1);
      expect(result.notNewer, 1);
      expect(controller.pluginList.map((p) => p.name), ['stale', 'ok']);
    },
  );

  test('rolls back the entire batch when saving fails', () async {
    final controller = PluginsController(
      catalogLoader: () async => [_item('new'), _item('old', version: '2.0')],
      pluginLoader: (name) async => _plugin(name, version: '2.0'),
      pluginJsonWriter: (_) async => throw StateError('disk full'),
      errorReporter: (_, _, _) {},
    );
    final original = _plugin('old');
    controller.pluginList.add(original);

    await expectLater(controller.tryDownloadAllPlugins(), throwsStateError);

    expect(controller.pluginList, [original]);
    expect(original.version, '1.0');
  });

  test('shares simultaneous requests and deduplicates catalog names', () async {
    final download = Completer<Plugin>();
    var downloads = 0;
    var writes = 0;
    final controller = PluginsController(
      catalogLoader: () async => [_item('same'), _item('SAME')],
      pluginLoader: (name) {
        downloads++;
        return download.future;
      },
      pluginJsonWriter: (_) async => writes++,
    );

    final first = controller.tryDownloadAllPlugins();
    final second = controller.tryDownloadAllPlugins();
    expect(second, same(first));
    download.complete(_plugin('same'));
    await Future.wait([first, second]);

    expect(downloads, 1);
    expect(writes, 1);
    expect(controller.pluginList.single.name, 'SAME');
  });

  test(
    'limits concurrent downloads to four and preserves catalog order',
    () async {
      final firstWave = Completer<void>();
      final release = Completer<void>();
      var active = 0;
      var maxActive = 0;
      final names = List.generate(10, (i) => 'rule-$i');
      final controller = PluginsController(
        catalogLoader: () async => names.map(_item).toList(),
        pluginLoader: (name) async {
          active++;
          if (active > maxActive) maxActive = active;
          if (active == 4 && !firstWave.isCompleted) firstWave.complete();
          await release.future;
          active--;
          return _plugin(name);
        },
        pluginJsonWriter: (_) async {},
      );

      final downloading = controller.tryDownloadAllPlugins();
      await firstWave.future;
      expect(active, 4);
      release.complete();
      final result = await downloading;

      expect(maxActive, 4);
      expect(result.updated, 10);
      expect(controller.pluginList.map((p) => p.name), names);
    },
  );

  test(
    'can retry after catalog failure without changing installed rules',
    () async {
      var attempts = 0;
      final controller = PluginsController(
        catalogLoader: () async {
          if (attempts++ == 0) throw StateError('offline');
          return [_item('new')];
        },
        pluginLoader: (name) async => _plugin(name),
        pluginJsonWriter: (_) async {},
        errorReporter: (_, _, _) {},
      );

      await expectLater(controller.tryDownloadAllPlugins(), throwsStateError);
      expect(controller.pluginList, isEmpty);
      expect((await controller.tryDownloadAllPlugins()).updated, 1);
    },
  );

  test('empty catalogs do not write rules', () async {
    final controller = PluginsController(
      catalogLoader: () async => [],
      pluginLoader: (_) async => throw StateError('unexpected download'),
      pluginJsonWriter: (_) async => fail('unexpected write'),
    );

    expect((await controller.tryDownloadAllPlugins()).hasNoCandidates, isTrue);
  });

  test('update all continues to update installed rules only', () async {
    final controller = PluginsController(
      catalogLoader: () async => [_item('new'), _item('old', version: '2.0')],
      pluginLoader: (name) async => _plugin(name, version: '2.0'),
      pluginJsonWriter: (_) async {},
    );
    controller.pluginList.add(_plugin('old'));

    final result = await controller.tryUpdateAllPlugin();

    expect(result.updated, 1);
    expect(controller.pluginList.single.name, 'old');
    expect(controller.pluginList.single.version, '2.0');
  });
}
