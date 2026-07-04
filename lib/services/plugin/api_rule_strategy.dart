import 'dart:convert';

import 'package:json_path/json_path.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart';
import 'package:kazumi/utils/episode_url.dart';

class ApiRuleFormatException implements Exception {
  const ApiRuleFormatException(this.message);

  final String message;

  @override
  String toString() => 'ApiRuleFormatException: $message';
}

class RestrictedJsonPath {
  const RestrictedJsonPath._();

  static void validate(String expression) {
    if (expression.isEmpty || !expression.startsWith(r'$')) {
      throw ApiRuleFormatException('JSONPath 必须以 \$ 开头: $expression');
    }
    var index = 1;
    while (index < expression.length) {
      final char = expression[index];
      if (char == '.') {
        index++;
        final start = index;
        while (index < expression.length &&
            RegExp(r'[A-Za-z0-9_$-]').hasMatch(expression[index])) {
          index++;
        }
        if (index == start) {
          throw ApiRuleFormatException('不支持的 JSONPath: $expression');
        }
        continue;
      }
      if (char == '[') {
        final end = _findBracketEnd(expression, index);
        final content = expression.substring(index + 1, end).trim();
        final isIndex = RegExp(r'^\d+$').hasMatch(content);
        final isWildcard = content == '*';
        final isQuoted = content.length >= 2 &&
            ((content.startsWith("'") && content.endsWith("'")) ||
                (content.startsWith('"') && content.endsWith('"')));
        if (!isIndex && !isWildcard && !isQuoted) {
          throw ApiRuleFormatException('不支持的 JSONPath 片段: [$content]');
        }
        index = end + 1;
        continue;
      }
      throw ApiRuleFormatException('不支持的 JSONPath: $expression');
    }
  }

  static int _findBracketEnd(String expression, int start) {
    String? quote;
    var escaped = false;
    for (var i = start + 1; i < expression.length; i++) {
      final char = expression[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (quote != null) {
        if (char == quote) quote = null;
        continue;
      }
      if (char == "'" || char == '"') {
        quote = char;
        continue;
      }
      if (char == ']') return i;
    }
    throw ApiRuleFormatException('JSONPath 缺少 ]: $expression');
  }

  static List<Object?> read(dynamic document, String expression) {
    validate(expression);
    try {
      return JsonPath(expression).readValues(document).toList();
    } catch (error) {
      throw ApiRuleFormatException('JSONPath 解析失败 $expression: $error');
    }
  }

  static Object? readFirst(dynamic document, String expression) {
    final values = read(document, expression);
    return values.isEmpty ? null : values.first;
  }
}

/// Executes API request templates and parses supported JSON response shapes.
class ApiRuleStrategy {
  const ApiRuleStrategy();

  dynamic decodeResponse(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException catch (error) {
      throw ApiRuleFormatException('API 响应不是有效 JSON: ${error.message}');
    }
  }

  PreparedRuleRequest prepareRequest(
    ApiRequestConfig config,
    Map<String, Object?> variables,
  ) {
    final method = config.method.toUpperCase();
    if (method != 'GET' && method != 'POST') {
      throw ApiRuleFormatException('仅支持 GET/POST，当前为 $method');
    }
    if (config.url.trim().isEmpty) {
      throw const ApiRuleFormatException('API 请求 URL 不能为空');
    }
    final url = _renderTemplate(config.url.trim(), variables, encode: true);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ApiRuleFormatException('API 请求 URL 无效: $url');
    }
    return PreparedRuleRequest(
      method: method,
      url: url,
      headers: _renderMap(config.headers, variables),
      query: _renderMap(config.query, variables),
      bodyType: config.bodyType,
      body: _renderValue(config.body, variables),
      includeCookies: true,
    );
  }

  RuleSearchParseResult parseSearch(String raw, ApiSearchConfig config) {
    final document = decodeResponse(raw);
    final nodes = RestrictedJsonPath.read(document, config.listPath);
    final results = <SearchItem>[];
    final fragments = <String>[];
    final diagnostics = <String>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      try {
        final name = _stringValue(
          RestrictedJsonPath.readFirst(node, config.namePath),
        );
        final source = _stringValue(
          RestrictedJsonPath.readFirst(node, config.sourcePath),
        );
        if (name.isEmpty || source.isEmpty) {
          diagnostics.add('搜索节点 $index 缺少名称或来源，已跳过');
          continue;
        }
        results.add(SearchItem(name: name, src: source));
        fragments.add(jsonEncode(node));
      } catch (error) {
        diagnostics.add('搜索节点 $index 解析失败: $error');
      }
    }
    return RuleSearchParseResult(
      items: results,
      matchedFragments: fragments,
      diagnostics: diagnostics,
    );
  }

  RuleChapterParseResult parseChapters(
    String raw,
    ApiChapterConfig config, {
    required String source,
    required String baseUrl,
  }) {
    final document = decodeResponse(raw);
    final rootVariables = <String, Object?>{'source': source};
    for (final entry in config.variables.entries) {
      final value = RestrictedJsonPath.readFirst(document, entry.value);
      if (value == null) {
        throw ApiRuleFormatException(
          '章节响应变量 ${entry.key} 未匹配到值: ${entry.value}',
        );
      }
      rootVariables[entry.key] = value;
    }
    final diagnostics = <String>[];
    final roads = config.format == ApiChapterFormat.delimited
        ? _parseDelimited(
            document,
            config,
            rootVariables,
            baseUrl,
            diagnostics,
          )
        : _parseNested(
            document,
            config,
            rootVariables,
            baseUrl,
            diagnostics,
          );
    final fragments = config.format == ApiChapterFormat.delimited
        ? <String>[raw]
        : _chapterFragments(document, config);
    return RuleChapterParseResult(
      roads: roads,
      matchedFragments: fragments,
      diagnostics: diagnostics,
    );
  }

  List<String> _chapterFragments(
    dynamic document,
    ApiChapterConfig config,
  ) {
    if (config.roadsPath.trim().isEmpty) return <String>[jsonEncode(document)];
    return RestrictedJsonPath.read(document, config.roadsPath)
        .map(jsonEncode)
        .toList();
  }

  List<Road> _parseNested(
    dynamic document,
    ApiChapterConfig config,
    Map<String, Object?> rootVariables,
    String baseUrl,
    List<String> diagnostics,
  ) {
    final hasRoads = config.roadsPath.trim().isNotEmpty;
    final roadNodes = hasRoads
        ? RestrictedJsonPath.read(document, config.roadsPath)
        : <Object?>[document];
    final roads = <Road>[];
    for (var roadIndex = 0; roadIndex < roadNodes.length; roadIndex++) {
      final roadNode = roadNodes[roadIndex];
      try {
        final roadName = hasRoads && config.roadNamePath.trim().isNotEmpty
            ? _stringValue(
                RestrictedJsonPath.readFirst(roadNode, config.roadNamePath),
              )
            : '';
        final episodeNodes = RestrictedJsonPath.read(
          roadNode,
          config.episodesPath,
        );
        final urls = <String>[];
        final names = <String>[];
        for (var episodeIndex = 0;
            episodeIndex < episodeNodes.length;
            episodeIndex++) {
          try {
            final episodeNode = episodeNodes[episodeIndex];
            final episodeName = _stringValue(
              RestrictedJsonPath.readFirst(
                episodeNode,
                config.episodeNamePath,
              ),
            );
            final rawUrl = config.episodeUrlPath.trim().isEmpty
                ? ''
                : _stringValue(
                    RestrictedJsonPath.readFirst(
                      episodeNode,
                      config.episodeUrlPath,
                    ),
                  );
            final pageUrl = _resolveEpisodeUrl(
              config,
              rootVariables,
              rawUrl: rawUrl,
              roadIndex: roadIndex,
              episodeIndex: episodeIndex,
              baseUrl: baseUrl,
            );
            if (pageUrl.isEmpty) {
              diagnostics.add(
                '线路 $roadIndex 的剧集节点 $episodeIndex 缺少 URL，已跳过',
              );
              continue;
            }
            urls.add(pageUrl);
            names.add(
              episodeName.isEmpty ? '第${episodeIndex + 1}集' : episodeName,
            );
          } catch (error) {
            diagnostics.add(
              '线路 $roadIndex 的剧集节点 $episodeIndex 解析失败: $error',
            );
          }
        }
        if (urls.isEmpty) {
          diagnostics.add('线路节点 $roadIndex 没有有效剧集，已跳过');
          continue;
        }
        roads.add(
          Road(
            name: roadName.isEmpty
                ? '${config.defaultRoadName}${roadIndex + 1}'
                : roadName,
            data: urls,
            identifier: names,
          ),
        );
      } catch (error) {
        diagnostics.add('线路节点 $roadIndex 解析失败: $error');
      }
    }
    return roads;
  }

  List<Road> _parseDelimited(
    dynamic document,
    ApiChapterConfig config,
    Map<String, Object?> rootVariables,
    String baseUrl,
    List<String> diagnostics,
  ) {
    if (config.roadNamesPath.isEmpty || config.roadEpisodesPath.isEmpty) {
      throw const ApiRuleFormatException('分隔格式必须配置线路名和线路内容路径');
    }
    if (config.roadSeparator.isEmpty ||
        config.episodeSeparator.isEmpty ||
        config.fieldSeparator.isEmpty) {
      throw const ApiRuleFormatException('分隔符不能为空');
    }
    final namesValue = _stringValue(
      RestrictedJsonPath.readFirst(document, config.roadNamesPath),
    );
    final episodesValue = _stringValue(
      RestrictedJsonPath.readFirst(document, config.roadEpisodesPath),
    );
    if (episodesValue.isEmpty) return <Road>[];
    final roadNames = namesValue.split(config.roadSeparator);
    final roadGroups = episodesValue.split(config.roadSeparator);
    final roads = <Road>[];
    for (var roadIndex = 0; roadIndex < roadGroups.length; roadIndex++) {
      final urls = <String>[];
      final names = <String>[];
      final entries = roadGroups[roadIndex].split(config.episodeSeparator);
      for (var episodeIndex = 0;
          episodeIndex < entries.length;
          episodeIndex++) {
        final entry = entries[episodeIndex].trim();
        if (entry.isEmpty) continue;
        final separatorIndex = entry.indexOf(config.fieldSeparator);
        if (separatorIndex < 0) {
          diagnostics.add(
            '线路 $roadIndex 的剧集条目 $episodeIndex 缺少字段分隔符，已跳过',
          );
          continue;
        }
        final name = entry.substring(0, separatorIndex).trim();
        final rawUrl = entry
            .substring(separatorIndex + config.fieldSeparator.length)
            .trim();
        try {
          final pageUrl = _resolveEpisodeUrl(
            config,
            rootVariables,
            rawUrl: rawUrl,
            roadIndex: roadIndex,
            episodeIndex: episodeIndex,
            baseUrl: baseUrl,
          );
          if (pageUrl.isEmpty) {
            diagnostics.add(
              '线路 $roadIndex 的剧集条目 $episodeIndex 缺少 URL，已跳过',
            );
            continue;
          }
          urls.add(pageUrl);
          names.add(name.isEmpty ? '第${episodeIndex + 1}集' : name);
        } catch (error) {
          diagnostics.add(
            '线路 $roadIndex 的剧集条目 $episodeIndex 解析失败: $error',
          );
        }
      }
      if (urls.isEmpty) {
        diagnostics.add('线路 $roadIndex 没有有效剧集，已跳过');
        continue;
      }
      final configuredName =
          roadIndex < roadNames.length ? roadNames[roadIndex].trim() : '';
      roads.add(
        Road(
          name: configuredName.isEmpty
              ? '${config.defaultRoadName}${roadIndex + 1}'
              : configuredName,
          data: urls,
          identifier: names,
        ),
      );
    }
    return roads;
  }

  String _resolveEpisodeUrl(
    ApiChapterConfig config,
    Map<String, Object?> rootVariables, {
    required String rawUrl,
    required int roadIndex,
    required int episodeIndex,
    required String baseUrl,
  }) {
    final page = config.episodePage;
    if (page == null) return normalizeEpisodeUrl(baseUrl, rawUrl);
    final variables = <String, Object?>{
      ...rootVariables,
      'episodeUrl': rawUrl,
      'roadIndex': roadIndex,
      'roadNumber': roadIndex + 1,
      'episodeIndex': episodeIndex,
      'episodeNumber': episodeIndex + 1,
    };
    final path = _renderTemplate(page.url, variables, encode: true);
    final uri = Uri.tryParse(path);
    if (uri == null) {
      throw ApiRuleFormatException('剧集页面 URL 无效: $path');
    }
    final renderedQuery = _renderMap(page.query, variables).map(
      (key, value) => MapEntry(key, value.toString()),
    );
    final mergedQuery = <String, String>{
      ...uri.queryParameters,
      ...renderedQuery,
    };
    return normalizeEpisodeUrl(
      baseUrl,
      uri.replace(queryParameters: mergedQuery).toString(),
    );
  }

  Map<String, dynamic> _renderMap(
    Map<String, dynamic> input,
    Map<String, Object?> variables,
  ) {
    return input.map(
      (key, value) => MapEntry(
        _renderTemplate(key, variables),
        _renderValue(value, variables),
      ),
    );
  }

  dynamic _renderValue(dynamic value, Map<String, Object?> variables) {
    if (value is String) {
      final exact = RegExp(r'^@([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(value);
      if (exact != null) {
        final name = exact.group(1)!;
        if (!variables.containsKey(name)) {
          throw ApiRuleFormatException('缺少模板变量 @$name');
        }
        return variables[name];
      }
      return _renderTemplate(value, variables);
    }
    if (value is List) {
      return value.map((item) => _renderValue(item, variables)).toList();
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          _renderValue(item, variables),
        ),
      );
    }
    return value;
  }

  String _renderTemplate(
    String template,
    Map<String, Object?> variables, {
    bool encode = false,
  }) {
    return template.replaceAllMapped(
      RegExp(r'(?<![A-Za-z0-9_])@([A-Za-z_][A-Za-z0-9_]*)'),
      (match) {
        final name = match.group(1)!;
        if (!variables.containsKey(name)) {
          throw ApiRuleFormatException('缺少模板变量 @$name');
        }
        final value = variables[name]?.toString() ?? '';
        return encode ? Uri.encodeComponent(value) : value;
      },
    );
  }

  String _stringValue(Object? value) {
    if (value == null) return '';
    return value is String ? value.trim() : value.toString();
  }
}
