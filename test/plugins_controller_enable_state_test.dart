import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

void main() {
  group('plugin enable state', () {
    late PluginsController controller;

    setUp(() {
      controller = PluginsController();
      controller.pluginList.addAll([
        _plugin('alpha', version: '1'),
        _plugin('beta', version: '1'),
        _plugin('gamma', version: '1'),
      ]);
    });

    test('defaults to all plugins enabled in list order', () {
      expect(controller.enabledPlugins.map((plugin) => plugin.name), [
        'alpha',
        'beta',
        'gamma',
      ]);
    });

    test('disables and re-enables a plugin without changing order', () async {
      await controller.setPluginEnabled('beta', false, persist: false);

      expect(controller.isPluginEnabled('beta'), isFalse);
      expect(controller.enabledPlugins.map((plugin) => plugin.name), [
        'alpha',
        'gamma',
      ]);

      await controller.setPluginEnabled('beta', true, persist: false);

      expect(controller.isPluginEnabled('beta'), isTrue);
      expect(controller.enabledPlugins.map((plugin) => plugin.name), [
        'alpha',
        'beta',
        'gamma',
      ]);
    });

    test('removing plugins clears matching disabled state', () async {
      await controller.loadPluginEnabledState(
        disabledNames: ['beta', 'missing'],
        persist: false,
      );

      expect(controller.disabledPluginNames, {'beta'});

      await controller.removePlugins({'alpha', 'beta'}, persist: false);

      expect(controller.pluginList.map((plugin) => plugin.name), ['gamma']);
      expect(controller.disabledPluginNames, isEmpty);
    });

    test('updating an installed plugin preserves disabled state', () async {
      await controller.setPluginEnabled('beta', false, persist: false);

      controller.updatePlugin(_plugin('beta', version: '2'), persist: false);

      expect(controller.pluginList.singleWhere((p) => p.name == 'beta').version,
          '2');
      expect(controller.isPluginEnabled('beta'), isFalse);
    });

    test('plugin JSON does not include local enable state', () async {
      await controller.setPluginEnabled('beta', false, persist: false);

      final json = controller.pluginList
          .singleWhere((plugin) => plugin.name == 'beta')
          .toJson();

      expect(json.containsKey('enabled'), isFalse);
      expect(json.containsKey('disabled'), isFalse);
      expect(json.containsKey('disabledPluginNames'), isFalse);
    });
  });
}

Plugin _plugin(String name, {required String version}) {
  return Plugin.fromJson({
    'api': '7',
    'type': 'anime',
    'name': name,
    'version': version,
    'muliSources': true,
    'useWebview': true,
    'useNativePlayer': true,
    'usePost': false,
    'useLegacyParser': false,
    'adBlocker': false,
    'userAgent': '',
    'baseURL': 'https://example.com/',
    'searchURL': 'https://example.com/search?q=@keyword',
    'searchList': '//li',
    'searchName': '//a',
    'searchResult': '//a',
    'chapterRoads': '//ul',
    'chapterResult': '//a',
    'referer': '',
  });
}
