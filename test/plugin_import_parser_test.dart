import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/plugin/plugin_import_parser.dart';
import 'package:kazumi/utils/encoding.dart';

void main() {
  Plugin plugin(String name) {
    return Plugin.fromTemplate()
      ..name = name
      ..version = '1.0';
  }

  String linkFor(Plugin value) {
    return jsonToKazumiBase64(jsonEncode(value.toJson()));
  }

  group('PluginImportParser', () {
    test('keeps single-link import backward compatible', () {
      final result = PluginImportParser.parse(linkFor(plugin('single')));

      expect(result.plugins.single.name, 'single');
      expect(result.failureCount, 0);
    });

    test('imports multiple Kazumi links from text', () {
      final result = PluginImportParser.parse(
        '${linkFor(plugin('one'))}\n${linkFor(plugin('two'))}',
      );

      expect(result.plugins.map((item) => item.name), ['one', 'two']);
      expect(result.failureCount, 0);
      expect(result.duplicateCount, 0);
    });

    test('imports a JSON array of rules', () {
      final result = PluginImportParser.parse(
        jsonEncode([plugin('one').toJson(), plugin('two').toJson()]),
      );

      expect(result.plugins.map((item) => item.name), ['one', 'two']);
      expect(result.failureCount, 0);
    });

    test('keeps valid links when another link is invalid', () {
      final result = PluginImportParser.parse(
        '${linkFor(plugin('valid'))}\nkazumi://not-base64!',
      );

      expect(result.plugins.single.name, 'valid');
      expect(result.failureCount, 1);
    });

    test('keeps the last duplicate rule', () {
      final first = plugin('same')..version = '1.0';
      final second = plugin('SAME')..version = '2.0';
      final result = PluginImportParser.parse(
        '${linkFor(first)}\n${linkFor(second)}',
      );

      expect(result.plugins.single.version, '2.0');
      expect(result.duplicateCount, 1);
    });

    test('rejects unsupported JSON values', () {
      final result = PluginImportParser.parse('[42, null]');

      expect(result.plugins, isEmpty);
      expect(result.failureCount, 2);
    });

    test('imports all parsed rules with one persistence write', () async {
      var writeCount = 0;
      late String persistedJson;
      final controller = PluginsController(
        pluginJsonWriter: (jsonData) async {
          writeCount++;
          persistedJson = jsonData;
        },
      );

      await controller.updatePlugins([plugin('one'), plugin('two')]);

      expect(writeCount, 1);
      expect(controller.pluginList.map((item) => item.name), ['one', 'two']);
      expect(
        (jsonDecode(persistedJson) as List)
            .map((item) => (item as Map<String, dynamic>)['name']),
        ['one', 'two'],
      );
    });
  });
}
