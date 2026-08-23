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

    test('imports a link with an uppercase scheme', () {
      final link = linkFor(plugin('uppercase'))
          .replaceFirst('kazumi://', 'KAZUMI://');

      final result = PluginImportParser.parse(link);

      expect(result.plugins.single.name, 'uppercase');
      expect(result.failureCount, 0);
    });

    test('imports a rule link wrapped across lines', () {
      final link = linkFor(plugin('wrapped'));
      final splitAt = link.length ~/ 2;
      final wrapped = '${link.substring(0, splitAt)}\n'
          '  ${link.substring(splitAt)}';

      final result = PluginImportParser.parse(wrapped);

      expect(result.plugins.single.name, 'wrapped');
      expect(result.failureCount, 0);
    });

    test('does not merge adjacent wrapped rule links', () {
      String wrap(String link) {
        final splitAt = link.length ~/ 2;
        return '${link.substring(0, splitAt)}\n${link.substring(splitAt)}';
      }

      final result = PluginImportParser.parse(
        '${wrap(linkFor(plugin('one')))}\n'
        '${wrap(linkFor(plugin('two')))}',
      );

      expect(result.plugins.map((item) => item.name), ['one', 'two']);
      expect(result.failureCount, 0);
    });

    test('ignores prose after a rule link', () {
      final link = linkFor(plugin('shared'));

      final chineseResult = PluginImportParser.parse('$link 谢谢分享');
      final englishResult = PluginImportParser.parse('$link thanks');

      expect(chineseResult.plugins.single.name, 'shared');
      expect(chineseResult.failureCount, 0);
      expect(englishResult.plugins.single.name, 'shared');
      expect(englishResult.failureCount, 0);
    });

    test('imports a percent-encoded link followed by prose', () {
      final link = linkFor(plugin('encoded'));
      final payload = link.substring('kazumi://'.length);
      final firstByte = payload.codeUnitAt(0)
          .toRadixString(16)
          .padLeft(2, '0')
          .toUpperCase();
      final encodedPayload = '%$firstByte${payload.substring(1)}';

      expect(encodedPayload, isNot(payload));

      final result = PluginImportParser.parse(
        'kazumi:$encodedPayload thanks',
      );

      expect(result.plugins.single.name, 'encoded');
      expect(result.failureCount, 0);
    });

    test('imports links separated by punctuation', () {
      final result = PluginImportParser.parse(
        '${linkFor(plugin('one'))}、${linkFor(plugin('two'))}',
      );

      expect(result.plugins.map((item) => item.name), ['one', 'two']);
      expect(result.failureCount, 0);
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

    test('keeps valid links when a decoded link is not an object', () {
      final result = PluginImportParser.parse(
        '${jsonToKazumiBase64(jsonEncode([42]))}\n'
        '${linkFor(plugin('valid'))}',
      );

      expect(result.plugins.single.name, 'valid');
      expect(result.failureCount, 1);
    });

    test('keeps valid links after malformed percent encoding', () {
      final result = PluginImportParser.parse(
        'kazumi://%zz\n${linkFor(plugin('valid'))}',
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
  });

  group('PluginsController.updatePlugins', () {
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

    test('batch update replaces an installed rule case-insensitively',
        () async {
      var writeCount = 0;
      final controller = PluginsController(
        pluginJsonWriter: (_) async => writeCount++,
      );
      controller.pluginList.add(plugin('same')..version = '1.0');

      await controller.updatePlugins([plugin('SAME')..version = '2.0']);

      expect(writeCount, 1);
      expect(controller.pluginList, hasLength(1));
      expect(controller.pluginList.single.name, 'SAME');
      expect(controller.pluginList.single.version, '2.0');
    });

    test('batch update rolls back all rules when persistence fails', () async {
      final controller = PluginsController(
        pluginJsonWriter: (_) async => throw StateError('write failed'),
        errorReporter: (_, __, ___) {},
      );
      controller.pluginList.add(plugin('installed'));

      await expectLater(
        controller.updatePlugins([plugin('one'), plugin('two')]),
        throwsStateError,
      );

      expect(controller.pluginList.map((item) => item.name), ['installed']);
    });
  });
}
