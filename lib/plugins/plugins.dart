import 'package:dio/dio.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/request/request.dart';
import 'package:html/parser.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';
import 'package:kazumi/plugins/plugin_cookie_manager.dart';

/// Thrown by [Plugin.queryBangumi] when the response contains a CAPTCHA challenge
/// (i.e. the [AntiCrawlerConfig.captchaImage] XPath selector matches something
/// in the returned HTML).
class CaptchaRequiredException implements Exception {
  final String pluginName;
  const CaptchaRequiredException(this.pluginName);
  @override
  String toString() => 'CaptchaRequiredException: $pluginName requires captcha verification';
}

/// Thrown by [Plugin.queryBangumi] when the search request succeeds but the
/// XPath selectors return no results.
class NoResultException implements Exception {
  final String pluginName;
  const NoResultException(this.pluginName);
  @override
  String toString() => 'NoResultException: $pluginName returned no search results';
}

/// Thrown by [Plugin.queryBangumi] when the HTTP request or HTML parsing
/// fails for reasons other than a captcha challenge.
class SearchErrorException implements Exception {
  final String pluginName;
  final Object? cause;
  const SearchErrorException(this.pluginName, {this.cause});
  @override
  String toString() => 'SearchErrorException: $pluginName search failed${cause != null ? ' ($cause)' : ''}';
}

class Plugin {
  String api;
  String type;
  String name;
  String version;
  bool muliSources;
  bool useWebview;
  /// Deprecated (always true)
  bool useNativePlayer;
  bool usePost;
  bool useLegacyParser;
  bool adBlocker;
  String userAgent;
  String baseUrl;
  String searchURL;
  String searchList;
  String searchName;
  String searchResult;
  String chapterRoads;
  String chapterResult;
  String referer;
  AntiCrawlerConfig antiCrawlerConfig;

  Plugin({
    required this.api,
    required this.type,
    required this.name,
    required this.version,
    required this.muliSources,
    required this.useWebview,
    required this.useNativePlayer,
    required this.usePost,
    required this.useLegacyParser,
    required this.adBlocker,
    required this.userAgent,
    required this.baseUrl,
    required this.searchURL,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    required this.referer,
    AntiCrawlerConfig? antiCrawlerConfig,
  }) : antiCrawlerConfig = antiCrawlerConfig ?? AntiCrawlerConfig.empty();

  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
        api: json['api'],
        type: json['type'],
        name: json['name'],
        version: json['version'],
        muliSources: json['muliSources'],
        useWebview: json['useWebview'],
        useNativePlayer: json['useNativePlayer'],
        usePost: json['usePost'] ?? false,
        useLegacyParser: json['useLegacyParser'] ?? false,
        adBlocker: json['adBlocker'] ?? false,
        userAgent: json['userAgent'],
        baseUrl: json['baseURL'],
        searchURL: json['searchURL'],
        searchList: json['searchList'],
        searchName: json['searchName'],
        searchResult: json['searchResult'],
        chapterRoads: json['chapterRoads'],
        chapterResult: json['chapterResult'],
        referer: json['referer'] ?? '',
        antiCrawlerConfig: json['antiCrawlerConfig'] != null
            ? AntiCrawlerConfig.fromJson(
                Map<String, dynamic>.from(json['antiCrawlerConfig']))
            : AntiCrawlerConfig.empty());
  }

  factory Plugin.fromTemplate() {
    return Plugin(
        api: Api.apiLevel.toString(),
        type: 'anime',
        name: '',
        version: '',
        muliSources: true,
        useWebview: true,
        useNativePlayer: true,
        usePost: false,
        useLegacyParser: false,
        adBlocker: false,
        userAgent: '',
        baseUrl: '',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '',
        referer: '',
        antiCrawlerConfig: AntiCrawlerConfig.empty());
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['api'] = api;
    data['type'] = type;
    data['name'] = name;
    data['version'] = version;
    data['muliSources'] = muliSources;
    data['useWebview'] = useWebview;
    data['useNativePlayer'] = useNativePlayer;
    data['usePost'] = usePost;
    data['useLegacyParser'] = useLegacyParser;
    data['adBlocker'] = adBlocker;
    data['userAgent'] = userAgent;
    data['baseURL'] = baseUrl;
    data['searchURL'] = searchURL;
    data['searchList'] = searchList;
    data['searchName'] = searchName;
    data['searchResult'] = searchResult;
    data['chapterRoads'] = chapterRoads;
    data['chapterResult'] = chapterResult;
    data['referer'] = referer;
    data['antiCrawlerConfig'] = antiCrawlerConfig.toJson();
    return data;
  }

  Future<PluginSearchResponse> queryBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    try {
    String queryURL = searchURL.replaceAll('@keyword', keyword);
    dynamic resp;
    List<SearchItem> searchItems = [];
    final String cookieHeader = await _cookieHeaderFor(queryURL);
    if (usePost) {
      Uri uri = Uri.parse(queryURL);
      Map<String, String> queryParams = uri.queryParameters;
      Uri postUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
      );
      var httpHeaders = {
        'referer': '$baseUrl/',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
        if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
      };
      resp = await Request().post(postUri.toString(),
          options: Options(headers: httpHeaders),
          extra: {'customError': ''},
          data: queryParams,
          shouldRethrow: shouldRethrow);
    } else {
      var httpHeaders = {
        'referer': '$baseUrl/',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
        if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
      };
      resp = await Request().get(queryURL,
          options: Options(headers: httpHeaders),
          shouldRethrow: shouldRethrow,
          extra: {'customError': ''});
    }

    var htmlString = resp.data.toString();
    var htmlElement = parse(htmlString).documentElement!;

    // Detect captcha challenge: if antiCrawlerConfig is enabled, check both
    // captchaImage and captchaButton XPaths — if either matches, throw so
    // callers can show the dedicated captcha UI instead of a generic error.
    if (antiCrawlerConfig.enabled) {
      final List<String> detectionXpaths = [
        antiCrawlerConfig.captchaImage,
        antiCrawlerConfig.captchaButton,
      ].where((x) => x.isNotEmpty).toList();
      final bool captchaDetected = detectionXpaths.any(
          (xpath) => htmlElement.queryXPath(xpath).node != null);
      if (captchaDetected) {
        KazumiLogger().w('Plugin: $name detected captcha challenge in search response');
        throw CaptchaRequiredException(name);
      }
    }

    htmlElement.queryXPath(searchList).nodes.forEach((element) {
      try {
        SearchItem searchItem = SearchItem(
          name: element.queryXPath(searchName).node!.text?.trim() ?? '',
          src: element.queryXPath(searchResult).node!.attributes['href'] ?? '',
        );
        searchItems.add(searchItem);
        KazumiLogger().i(
            'Plugin: $name ${element.queryXPath(searchName).node!.text ?? ''} $baseUrl${element.queryXPath(searchResult).node!.attributes['href'] ?? ''}');
      } catch (_) {}
    });
    if (searchItems.isEmpty) throw NoResultException(name);
    return PluginSearchResponse(pluginName: name, data: searchItems);
    } on CaptchaRequiredException {
      rethrow;
    } on NoResultException {
      rethrow;
    } catch (e, st) {
      KazumiLogger().w('Plugin: $name search failed', error: e, stackTrace: st);
      if (shouldRethrow) throw SearchErrorException(name, cause: e);
      return PluginSearchResponse(pluginName: name, data: []);
    }
  }

  Future<List<Road>> querychapterRoads(String url, {CancelToken? cancelToken}) async {
    List<Road> roadList = [];
    if (!url.contains('https')) {
      url = url.replaceAll('http', 'https');
    }
    String queryURL = '';
    if (url.contains(baseUrl)) {
      queryURL = url;
    } else {
      queryURL = baseUrl + url;
    }
    var httpHeaders = {
      'referer': '$baseUrl/',
      'Accept-Language': Utils.getRandomAcceptedLanguage(),
      'Connection': 'keep-alive',
    };
    try {
      var resp =
      await Request().get(queryURL, options: Options(headers: httpHeaders), cancelToken: cancelToken);
      var htmlString = resp.data.toString();
      var htmlElement = parse(htmlString).documentElement!;
      int count = 1;
      htmlElement.queryXPath(chapterRoads).nodes.forEach((element) {
        try {
          List<String> chapterUrlList = [];
          List<String> chapterNameList = [];
          element.queryXPath(chapterResult).nodes.forEach((item) {
            String itemUrl = item.node.attributes['href'] ?? '';
            String itemName = item.node.text ?? '';
            chapterUrlList.add(itemUrl);
            chapterNameList.add(itemName.replaceAll(RegExp(r'\s+'), ''));
          });
          if (chapterUrlList.isNotEmpty && chapterNameList.isNotEmpty) {
            Road road = Road(
                name: '播放列表$count',
                data: chapterUrlList,
                identifier: chapterNameList);
            roadList.add(road);
            count++;
          }
        } catch (_) {}
      });
    } catch (_) {}
    return roadList;
  }

  Future<String> testSearchRequest(String keyword,
      {bool shouldRethrow = false, CancelToken? cancelToken}) async {
    String queryURL = searchURL.replaceAll('@keyword', keyword);
    dynamic resp;
    if (usePost) {
      Uri uri = Uri.parse(queryURL);
      Map<String, String> queryParams = uri.queryParameters;
      Uri postUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
      );
      var httpHeaders = {
        'referer': '$baseUrl/',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
      };
      resp = await Request().post(postUri.toString(),
          options: Options(headers: httpHeaders),
          extra: {'customError': ''},
          data: queryParams,
          shouldRethrow: shouldRethrow,
          cancelToken: cancelToken);
    } else {
      var httpHeaders = {
        'referer': '$baseUrl/',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
      };
      resp = await Request().get(queryURL,
          options: Options(headers: httpHeaders),
          shouldRethrow: shouldRethrow,
          extra: {'customError': ''},
          cancelToken: cancelToken);
    }

    return resp.data.toString();
  }

  Future<String> _cookieHeaderFor(String url) async {
    if (!PluginCookieManager.instance.hasCookies(name)) return '';
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    try {
      final cookies =
          await PluginCookieManager.instance.getJar(name).loadForRequest(uri);
      if (cookies.isEmpty) return '';
      return cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (_) {
      return '';
    }
  }

  String buildFullUrl(String urlItem) {
    if (urlItem.contains(baseUrl) ||
        urlItem.contains(baseUrl.replaceAll('https', 'http'))) {
      return urlItem;
    }
    return baseUrl + urlItem;
  }

  Map<String, String> buildHttpHeaders() {
    return {
      'user-agent': userAgent.isEmpty ? Utils.getRandomUA() : userAgent,
      if (referer.isNotEmpty) 'referer': referer,
    };
  }

  PluginSearchResponse testQueryBangumi(String htmlString) {
    List<SearchItem> searchItems = [];
    var htmlElement = parse(htmlString).documentElement!;
    htmlElement.queryXPath(searchList).nodes.forEach((element) {
      try {
        SearchItem searchItem = SearchItem(
          name: element.queryXPath(searchName).node!.text?.trim() ?? '',
          src: element.queryXPath(searchResult).node!.attributes['href'] ?? '',
        );
        searchItems.add(searchItem);
        KazumiLogger().i(
            'Plugin: $name ${element.queryXPath(searchName).node!.text ?? ''} $baseUrl${element.queryXPath(searchResult).node!.attributes['href'] ?? ''}');
      } catch (_) {}
    });
    PluginSearchResponse pluginSearchResponse =
    PluginSearchResponse(pluginName: name, data: searchItems);
    return pluginSearchResponse;
  }
}
