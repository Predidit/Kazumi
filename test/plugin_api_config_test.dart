import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/plugins/plugins.dart';
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
