import 'dart:convert';

import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/utils/encoding.dart';

class PluginImportParseResult {
  const PluginImportParseResult({
    required this.plugins,
    required this.failures,
    required this.duplicateCount,
  });

  final List<Plugin> plugins;
  final List<String> failures;
  final int duplicateCount;

  int get failureCount => failures.length;
}

class PluginImportParser {
  const PluginImportParser._();

  static final RegExp _ruleLinkPattern = RegExp(
    r'kazumi:(?://)?[A-Za-z0-9+/_=%-]+',
    caseSensitive: false,
  );

  static PluginImportParseResult parse(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return const PluginImportParseResult(
        plugins: [],
        failures: ['导入内容为空'],
        duplicateCount: 0,
      );
    }

    final parsed = <Plugin>[];
    final failures = <String>[];
    Object? jsonValue;
    var decodedAsJson = false;
    try {
      jsonValue = json.decode(value);
      decodedAsJson = true;
    } on FormatException {
      // Share links and text files are parsed below.
    }

    if (decodedAsJson) {
      if (jsonValue is List) {
        for (var index = 0; index < jsonValue.length; index++) {
          _parseEntry(jsonValue[index], index + 1, parsed, failures);
        }
      } else {
        _parseEntry(jsonValue, 1, parsed, failures);
      }
    } else {
      final matches = _ruleLinkPattern.allMatches(value).toList();
      if (matches.isEmpty) {
        failures.add('未找到有效的 JSON 或 kazumi:// 规则链接');
      } else {
        for (var index = 0; index < matches.length; index++) {
          _parseEntry(matches[index].group(0), index + 1, parsed, failures);
        }
      }
    }

    final uniquePlugins = <String, Plugin>{};
    var duplicateCount = 0;
    for (final plugin in parsed) {
      final key = plugin.name.toLowerCase();
      if (uniquePlugins.containsKey(key)) {
        duplicateCount++;
      }
      uniquePlugins[key] = plugin;
    }

    return PluginImportParseResult(
      plugins: List.unmodifiable(uniquePlugins.values),
      failures: List.unmodifiable(failures),
      duplicateCount: duplicateCount,
    );
  }

  static void _parseEntry(
    Object? entry,
    int index,
    List<Plugin> plugins,
    List<String> failures,
  ) {
    try {
      late final Plugin plugin;
      if (entry is Map) {
        plugin = Plugin.fromJson(Map<String, dynamic>.from(entry));
      } else if (entry is String) {
        final decoded = json.decode(kazumiBase64ToJson(entry));
        if (decoded is! Map) {
          throw const FormatException('规则链接内容必须是 JSON object');
        }
        plugin = Plugin.fromJson(Map<String, dynamic>.from(decoded));
      } else {
        throw const FormatException('规则必须是 JSON object 或 kazumi:// 链接');
      }

      if (plugin.name.trim().isEmpty) {
        throw const FormatException('规则名称不能为空');
      }
      if (plugin.requiresNewerClient) {
        throw const FormatException('规则需要更高版本客户端');
      }
      plugins.add(plugin);
    } catch (error) {
      failures.add('第 $index 条：$error');
    }
  }
}
