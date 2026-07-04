import 'package:dio/dio.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/request/clients/plugin_site_client.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/plugin/api_rule_strategy.dart';
import 'package:kazumi/services/plugin/plugin_cookie_manager.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart';
import 'package:kazumi/services/plugin/xpath_rule_strategy.dart';
import 'package:kazumi/utils/http_headers.dart';

abstract interface class RuleRequestExecutor {
  Future<String> execute(
    PreparedRuleRequest request,
    RuleExecutionConfig config, {
    CancelToken? cancelToken,
  });
}

class RuleEngine {
  RuleEngine({
    RuleRequestExecutor? requestExecutor,
    ApiRuleStrategy apiStrategy = const ApiRuleStrategy(),
    XPathRuleStrategy xpathStrategy = const XPathRuleStrategy(),
    bool logFailures = true,
  })  : _requestExecutor = requestExecutor ?? _DefaultRuleRequestExecutor(),
        _apiStrategy = apiStrategy,
        _xpathStrategy = xpathStrategy,
        _logFailures = logFailures;

  final RuleRequestExecutor _requestExecutor;
  final ApiRuleStrategy _apiStrategy;
  final XPathRuleStrategy _xpathStrategy;
  final bool _logFailures;

  Future<RuleSearchTrace> search(
    RuleExecutionConfig config,
    String keyword, {
    CancelToken? cancelToken,
  }) async {
    late final PreparedRuleRequest request;
    try {
      request = config.searchMode == RuleMode.api
          ? _apiStrategy.prepareRequest(
              config.searchApiConfig.request,
              <String, Object?>{'keyword': keyword},
            )
          : _xpathStrategy.prepareSearchRequest(config, keyword);
    } catch (error, stackTrace) {
      _logFailure(config, 'search request preparation', error, stackTrace);
      throw SearchErrorException(
        config.pluginName,
        cause: error,
        kind: RuleFailureKind.parse,
      );
    }

    final raw = await _executeSearchRequest(
      request,
      config,
      cancelToken: cancelToken,
    );
    try {
      final parsed = config.searchMode == RuleMode.api
          ? _apiStrategy.parseSearch(raw, config.searchApiConfig)
          : _xpathStrategy.parseSearch(raw, config);
      if (parsed.items.isEmpty) {
        throw NoResultException(config.pluginName);
      }
      return RuleSearchTrace(
        rawResponse: raw,
        response: PluginSearchResponse(
          pluginName: config.pluginName,
          data: parsed.items,
        ),
        matchedFragments: parsed.matchedFragments,
        diagnostics: parsed.diagnostics,
      );
    } on CaptchaRequiredException {
      rethrow;
    } on NoResultException {
      rethrow;
    } catch (error, stackTrace) {
      if (_isCancellation(error)) rethrow;
      _logFailure(config, 'search response parsing', error, stackTrace);
      throw SearchErrorException(
        config.pluginName,
        cause: error,
        kind: RuleFailureKind.parse,
      );
    }
  }

  Future<RuleChapterTrace> queryChapters(
    RuleExecutionConfig config,
    String source, {
    CancelToken? cancelToken,
  }) async {
    late final PreparedRuleRequest request;
    try {
      request = config.chapterMode == RuleMode.api
          ? _apiStrategy.prepareRequest(
              config.chapterApiConfig.request,
              <String, Object?>{'source': source},
            )
          : _xpathStrategy.prepareChapterRequest(config, source);
    } catch (error, stackTrace) {
      _logFailure(config, 'chapter request preparation', error, stackTrace);
      throw ChapterErrorException(
        config.pluginName,
        cause: error,
        kind: RuleFailureKind.parse,
      );
    }

    final raw = await _executeChapterRequest(
      request,
      config,
      cancelToken: cancelToken,
    );
    try {
      final parsed = config.chapterMode == RuleMode.api
          ? _apiStrategy.parseChapters(
              raw,
              config.chapterApiConfig,
              source: source,
              baseUrl: config.baseUrl,
            )
          : _xpathStrategy.parseChapters(raw, config);
      if (parsed.roads.isEmpty) {
        throw ChapterErrorException(
          config.pluginName,
          kind: RuleFailureKind.noResult,
        );
      }
      return RuleChapterTrace(
        rawResponse: raw,
        roads: parsed.roads,
        matchedFragments: parsed.matchedFragments,
        diagnostics: parsed.diagnostics,
      );
    } on ChapterErrorException {
      rethrow;
    } catch (error, stackTrace) {
      if (_isCancellation(error)) rethrow;
      _logFailure(config, 'chapter response parsing', error, stackTrace);
      throw ChapterErrorException(
        config.pluginName,
        cause: error,
        kind: RuleFailureKind.parse,
      );
    }
  }

  Future<String> _executeSearchRequest(
    PreparedRuleRequest request,
    RuleExecutionConfig config, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _requestExecutor.execute(
        request,
        config,
        cancelToken: cancelToken,
      );
    } catch (error, stackTrace) {
      if (_isCancellation(error)) rethrow;
      _logFailure(config, 'search request', error, stackTrace);
      throw SearchErrorException(
        config.pluginName,
        cause: error,
        kind: RuleFailureKind.request,
      );
    }
  }

  Future<String> _executeChapterRequest(
    PreparedRuleRequest request,
    RuleExecutionConfig config, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _requestExecutor.execute(
        request,
        config,
        cancelToken: cancelToken,
      );
    } catch (error, stackTrace) {
      if (_isCancellation(error)) rethrow;
      _logFailure(config, 'chapter request', error, stackTrace);
      throw ChapterErrorException(
        config.pluginName,
        cause: error,
        kind: RuleFailureKind.request,
      );
    }
  }

  bool _isCancellation(Object error) {
    return error is NetworkException &&
        error.type == NetworkExceptionType.cancel;
  }

  void _logFailure(
    RuleExecutionConfig config,
    String phase,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!_logFailures) return;
    KazumiLogger().w(
      'Plugin: ${config.pluginName} $phase failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class _DefaultRuleRequestExecutor implements RuleRequestExecutor {
  @override
  Future<String> execute(
    PreparedRuleRequest request,
    RuleExecutionConfig config, {
    CancelToken? cancelToken,
  }) async {
    final cookieHeader = request.includeCookies
        ? await _cookieHeaderFor(config.pluginName, request.url)
        : '';
    final headers = <String, dynamic>{
      'referer': '${config.baseUrl}/',
      'Accept-Language': getRandomAcceptedLanguage(),
      'Connection': 'keep-alive',
      if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
      ...request.headers,
    };
    if (request.method == 'POST') {
      switch (request.bodyType) {
        case ApiBodyType.json:
          headers.putIfAbsent('Content-Type', () => 'application/json');
          break;
        case ApiBodyType.form:
          headers.putIfAbsent(
            'Content-Type',
            () => 'application/x-www-form-urlencoded',
          );
          break;
      }
    }
    return PluginSiteClient.instance.requestText(
      request.url,
      method: request.method,
      headers: headers,
      queryParameters: request.query,
      data: request.method == 'POST' ? request.body : null,
      cancelToken: cancelToken,
    );
  }

  Future<String> _cookieHeaderFor(String pluginName, String url) async {
    if (!PluginCookieManager.instance.hasCookies(pluginName)) return '';
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    try {
      final cookies = await PluginCookieManager.instance
          .getJar(pluginName)
          .loadForRequest(uri);
      return cookies
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .join('; ');
    } catch (_) {
      return '';
    }
  }
}
