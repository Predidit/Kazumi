import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/utils/encoding.dart';

void main() {
  test('legacy plugin defaults to XPath modes', () {
    final plugin = Plugin.fromJson(_legacyRule);
    expect(plugin.searchMode, RuleMode.xpath);
    expect(plugin.chapterMode, RuleMode.xpath);
  });

  test('legacy XPath POST setting survives JSON round trip', () {
    final plugin = Plugin.fromJson({..._legacyRule, 'usePost': true});
    final restored = Plugin.fromJson(plugin.toJson());

    expect(plugin.usePost, isTrue);
    expect(restored.usePost, isTrue);
    expect(restored.searchMode, RuleMode.xpath);
  });

  test('detects rules that require a newer client API level', () {
    final compatible = Plugin.fromJson({
      ..._legacyRule,
      'api': ApiEndpoints.apiLevel.toString(),
    });
    final incompatible = Plugin.fromJson({
      ..._legacyRule,
      'api': (ApiEndpoints.apiLevel + 1).toString(),
    });

    expect(compatible.requiresNewerClient, isFalse);
    expect(incompatible.requiresNewerClient, isTrue);
  });

  test('API configuration survives JSON round trip', () {
    final plugin = Plugin.fromJson({
      ..._legacyRule,
      'searchMode': 'api',
      'chapterMode': 'api',
      'searchApiConfig': {
        'request': {
          'method': 'GET',
          'url': 'https://example.com/search',
          'query': {'q': '@keyword'},
        },
        'listPath': r'$.data[*]',
        'namePath': r'$.name',
        'sourcePath': r'$.id',
      },
      'chapterApiConfig': {
        'request': {
          'method': 'GET',
          'url': 'https://example.com/videos/@source',
        },
        'format': 'nested',
        'roadsPath': r'$.data.roads[*]',
        'roadNamePath': r'$.name',
        'episodesPath': r'$.episodes[*]',
        'episodeNamePath': r'$.name',
        'episodeUrlPath': r'$.url',
      },
    });
    final restored = Plugin.fromJson(plugin.toJson());

    expect(restored.searchMode, RuleMode.api);
    expect(restored.chapterMode, RuleMode.api);
    expect(restored.searchApiConfig.request.query['q'], '@keyword');
    expect(
      restored.chapterApiConfig.request.url,
      'https://example.com/videos/@source',
    );
  });

  test('API-only rule may omit legacy XPath fields', () {
    final plugin = Plugin.fromJson({
      'api': '8',
      'name': 'api-only',
      'version': '1',
      'searchMode': RuleMode.api,
      'chapterMode': RuleMode.api,
      'searchApiConfig': {
        'request': {'url': 'https://example.com/search'},
      },
      'chapterApiConfig': {
        'request': {'url': 'https://example.com/detail/@source'},
      },
    });

    expect(plugin.searchURL, isEmpty);
    expect(plugin.chapterRoads, isEmpty);
    expect(plugin.searchMode, RuleMode.api);
  });

  test('configured API rule survives serialization while mode is XPath', () {
    final plugin = Plugin.fromJson({
      ..._legacyRule,
      'searchMode': RuleMode.xpath,
      'chapterMode': RuleMode.xpath,
      'searchApiConfig': {
        'request': {'url': 'https://example.com/search'},
        'listPath': r'$.list[*]',
      },
      'chapterApiConfig': {
        'request': {'url': 'https://example.com/detail/@source'},
        'format': 'delimited',
        'roadNamesPath': r'$.from',
        'roadEpisodesPath': r'$.urls',
      },
    });
    final restored = Plugin.fromJson(plugin.toJson());

    expect(restored.searchApiConfig.request.url, 'https://example.com/search');
    expect(restored.searchApiConfig.listPath, r'$.list[*]');
    expect(restored.chapterApiConfig.roadNamesPath, r'$.from');
    expect(restored.chapterApiConfig.roadEpisodesPath, r'$.urls');
  });

  test('customized inactive chapter format survives serialization', () {
    final config = ApiChapterConfig.fromJson({
      'format': 'delimited',
      'roadNamesPath': r'$.from',
      'roadEpisodesPath': r'$.urls',
      'roadsPath': r'$.custom[*]',
    });
    final restored = ApiChapterConfig.fromJson(config.toJson());

    expect(restored.format, ApiChapterFormat.delimited);
    expect(restored.roadsPath, r'$.custom[*]');
  });

  test('pristine rules omit inactive-mode and inactive-format fields', () {
    final xpathRule = Plugin.fromJson(_legacyRule);
    expect(xpathRule.toJson().containsKey('searchApiConfig'), isFalse);
    expect(xpathRule.toJson().containsKey('chapterApiConfig'), isFalse);

    final nestedChapter = ApiChapterConfig.fromJson({
      'request': {'url': 'https://example.com/detail/@source'},
    }).toJson();
    expect(nestedChapter.containsKey('roadSeparator'), isFalse);
    expect(nestedChapter.containsKey('roadNamesPath'), isFalse);
    expect(nestedChapter['roadsPath'], r'$.data.roads[*]');
  });

  test('kazumi link import and export preserves API rule configuration', () {
    final plugin = Plugin.fromJson({
      ..._legacyRule,
      'api': '8',
      'searchMode': RuleMode.api,
      'chapterMode': RuleMode.api,
      'searchApiConfig': {
        'request': {
          'method': 'GET',
          'url': 'https://example.com/search',
          'query': {'q': '@keyword'},
        },
        'listPath': r'$.data[*]',
        'namePath': r'$.name',
        'sourcePath': r'$.id',
      },
      'chapterApiConfig': {
        'request': {
          'method': 'GET',
          'url': 'https://example.com/detail/@source',
        },
      },
    });

    final link = jsonToKazumiBase64(jsonEncode(plugin.toJson()));
    final restored = Plugin.fromJson(
      jsonDecode(kazumiBase64ToJson(link)) as Map<String, dynamic>,
    );

    expect(restored.toJson(), plugin.toJson());
    expect(restored.chapterApiConfig.request.method, 'GET');
  });

  test('kazumi link decoder accepts wrapped and percent-encoded links', () {
    final link = jsonToKazumiBase64(jsonEncode(_legacyRule));
    final payload = link.substring('kazumi://'.length);
    final wrappedPayload =
        '${payload.substring(0, 16)}\n${payload.substring(16)}';
    final percentEncodedPayload = Uri.encodeComponent(payload);

    expect(
      jsonDecode(kazumiBase64ToJson('  kazumi://$wrappedPayload  ')),
      _legacyRule,
    );
    expect(
      jsonDecode(kazumiBase64ToJson('kazumi:$percentEncodedPayload')),
      _legacyRule,
    );
  });

  test('kazumi link decoder reports malformed links', () {
    expect(
      () => kazumiBase64ToJson('https://example.com/rule'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => kazumiBase64ToJson('kazumi://not-base64!'),
      throwsA(isA<FormatException>()),
    );
  });
}

final Map<String, dynamic> _legacyRule = {
  'api': '7',
  'type': 'anime',
  'name': 'legacy',
  'version': '1.0',
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
};
