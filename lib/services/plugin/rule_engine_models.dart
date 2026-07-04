import 'package:dio/dio.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';
import 'package:kazumi/plugins/api_rule_config.dart';

typedef RuleCancelToken = CancelToken;

enum RuleFailureKind {
  request,
  parse,
  noResult,
}

class CaptchaRequiredException implements Exception {
  const CaptchaRequiredException(this.pluginName);

  final String pluginName;

  @override
  String toString() =>
      'CaptchaRequiredException: $pluginName requires captcha verification';
}

class NoResultException implements Exception {
  const NoResultException(this.pluginName);

  final String pluginName;

  @override
  String toString() =>
      'NoResultException: $pluginName returned no search results';
}

class SearchErrorException implements Exception {
  const SearchErrorException(
    this.pluginName, {
    this.cause,
    this.kind = RuleFailureKind.parse,
  });

  final String pluginName;
  final Object? cause;
  final RuleFailureKind kind;

  @override
  String toString() =>
      'SearchErrorException: $pluginName search failed${cause != null ? ' ($cause)' : ''}';
}

class ChapterErrorException implements Exception {
  const ChapterErrorException(
    this.pluginName, {
    this.cause,
    this.kind = RuleFailureKind.parse,
  });

  final String pluginName;
  final Object? cause;
  final RuleFailureKind kind;

  @override
  String toString() => 'ChapterErrorException: $pluginName chapter query failed'
      '${cause != null ? ' ($cause)' : ''}';
}

/// Immutable runtime snapshot built from a plugin rule.
///
/// Playback-only headers such as the rule's User-Agent and Referer are
/// deliberately excluded. API requests can provide their own static headers.
class RuleExecutionConfig {
  const RuleExecutionConfig({
    required this.pluginName,
    required this.baseUrl,
    required this.usePost,
    required this.searchMode,
    required this.chapterMode,
    required this.searchUrl,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    required this.searchApiConfig,
    required this.chapterApiConfig,
    required this.antiCrawlerConfig,
  });

  final String pluginName;
  final String baseUrl;
  final bool usePost;
  final String searchMode;
  final String chapterMode;
  final String searchUrl;
  final String searchList;
  final String searchName;
  final String searchResult;
  final String chapterRoads;
  final String chapterResult;
  final ApiSearchConfig searchApiConfig;
  final ApiChapterConfig chapterApiConfig;
  final AntiCrawlerConfig antiCrawlerConfig;
}

class PreparedRuleRequest {
  const PreparedRuleRequest({
    required this.method,
    required this.url,
    this.headers = const <String, dynamic>{},
    this.query = const <String, dynamic>{},
    this.bodyType = ApiBodyType.none,
    this.body,
    this.includeCookies = false,
  });

  final String method;
  final String url;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> query;
  final String bodyType;
  final Object? body;
  final bool includeCookies;
}

class RuleSearchParseResult {
  const RuleSearchParseResult({
    required this.items,
    this.matchedFragments = const <String>[],
    this.diagnostics = const <String>[],
  });

  final List<SearchItem> items;
  final List<String> matchedFragments;
  final List<String> diagnostics;
}

class RuleChapterParseResult {
  const RuleChapterParseResult({
    required this.roads,
    this.matchedFragments = const <String>[],
    this.diagnostics = const <String>[],
  });

  final List<Road> roads;
  final List<String> matchedFragments;
  final List<String> diagnostics;
}

class RuleSearchTrace {
  const RuleSearchTrace({
    required this.rawResponse,
    required this.response,
    required this.matchedFragments,
    required this.diagnostics,
  });

  final String rawResponse;
  final PluginSearchResponse response;
  final List<String> matchedFragments;
  final List<String> diagnostics;
}

class RuleChapterTrace {
  const RuleChapterTrace({
    required this.rawResponse,
    required this.roads,
    required this.matchedFragments,
    required this.diagnostics,
  });

  final String rawResponse;
  final List<Road> roads;
  final List<String> matchedFragments;
  final List<String> diagnostics;
}
