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

  static final RegExp _ruleLinkPayloadPrefixPattern = RegExp(
    r'^[A-Za-z0-9+/_=%\-\s]+',
  );
  static final RegExp _whitespacePattern = RegExp(r'\s+');

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
      final segments = findKazumiRuleLinkSegments(value).toList();
      if (segments.isEmpty) {
        failures.add('未找到有效的 JSON 或 kazumi:// 规则链接');
      } else {
        for (var index = 0; index < segments.length; index++) {
          final segment = segments[index];
          _parseRuleLinkSegment(
            segment.scheme,
            segment.rawPayload,
            index + 1,
            parsed,
            failures,
          );
        }
      }
    }

    final uniquePlugins = <String, Plugin>{};
    var duplicateCount = 0;
    for (final plugin in parsed) {
      final key = pluginNameKey(plugin.name);
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

  static void _parseRuleLinkSegment(
    String scheme,
    String rawPayload,
    int index,
    List<Plugin> plugins,
    List<String> failures,
  ) {
    try {
      final entry = _decodeRuleEntry(scheme, rawPayload);
      _parseEntry(entry, index, plugins, failures);
    } catch (error) {
      failures.add('第 $index 条：$error');
    }
  }

  static Map<String, dynamic> _decodeRuleEntry(
    String scheme,
    String rawPayload,
  ) {
    final payload = _ruleLinkPayloadPrefixPattern
        .firstMatch(rawPayload)
        ?.group(0)
        ?.trimRight();
    if (payload == null || payload.isEmpty) {
      throw const FormatException('Missing payload in Kazumi rule link');
    }

    final candidates = <String>[payload];
    final whitespaceMatches = _whitespacePattern.allMatches(payload).toList();
    for (final whitespaceMatch in whitespaceMatches.reversed) {
      final candidate = payload.substring(0, whitespaceMatch.start).trimRight();
      if (candidate.isNotEmpty && candidate != candidates.last) {
        candidates.add(candidate);
      }
    }

    FormatException? firstError;
    for (final candidate in candidates) {
      try {
        final decoded = json.decode(kazumiBase64ToJson('$scheme$candidate'));
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        firstError ??=
            const FormatException('规则链接内容必须是 JSON object');
      } on FormatException catch (error) {
        firstError ??= error;
        // Try a shorter prefix in case prose follows the rule link.
      }
    }
    throw firstError ?? const FormatException('Invalid Kazumi rule link');
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
