import 'package:dio/dio.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/request/clients/plugin_site_client.dart';
import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';
import 'package:kazumi/services/plugin/plugin_cookie_manager.dart';
import 'package:kazumi/utils/episode_url.dart';
import 'package:kazumi/utils/http_headers.dart';
import 'package:kazumi/utils/media.dart';

/// Thrown by [Plugin.queryBangumi] when the response contains a CAPTCHA challenge
/// (i.e. the [AntiCrawlerConfig.captchaImage] XPath selector matches something
/// in the returned HTML).
class CaptchaRequiredException implements Exception {
  final String pluginName;
  const CaptchaRequiredException(this.pluginName);
  @override
  String toString() =>
      'CaptchaRequiredException: $pluginName requires captcha verification';
}

/// Thrown by [Plugin.queryBangumi] when the search request succeeds but the
/// XPath selectors return no results.
class NoResultException implements Exception {
  final String pluginName;
  const NoResultException(this.pluginName);
  @override
  String toString() =>
      'NoResultException: $pluginName returned no search results';
}

/// Thrown by [Plugin.queryBangumi] when the HTTP request or HTML parsing
/// fails for reasons other than a captcha challenge.
class SearchErrorException implements Exception {
  final String pluginName;
  final Object? cause;
  const SearchErrorException(this.pluginName, {this.cause});
  @override
  String toString() =>
      'SearchErrorException: $pluginName search failed${cause != null ? ' ($cause)' : ''}';
}

class Plugin {
  static final PluginSiteClient _siteClient = PluginSiteClient.instance;

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

  /// 可选：抓取源站“稳定 episode 标识”的 XPath（相对每个 [chapterResult] 节点）。
  /// 命中时作为 [EpisodeIdentity.stableId]；为空则回退用归一化相对 path。
  String episodeId;

  /// 可选：抓取“集序数”的 XPath（相对每个 [chapterResult] 节点）。
  /// 命中并可解析为正整数时作为 [EpisodeIdentity.ordinal]；
  /// 为空则尝试从标题解析；再失败则 ordinal 为 null。
  String episodeOrdinal;
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
    this.episodeId = '',
    this.episodeOrdinal = '',
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
        episodeId: json['episodeId'] ?? '',
        episodeOrdinal: json['episodeOrdinal'] ?? '',
        referer: json['referer'] ?? '',
        antiCrawlerConfig: json['antiCrawlerConfig'] != null
            ? AntiCrawlerConfig.fromJson(
                Map<String, dynamic>.from(json['antiCrawlerConfig']))
            : AntiCrawlerConfig.empty());
  }

  factory Plugin.fromTemplate() {
    return Plugin(
        api: ApiEndpoints.apiLevel.toString(),
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
        episodeId: '',
        episodeOrdinal: '',
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
    data['episodeId'] = episodeId;
    data['episodeOrdinal'] = episodeOrdinal;
    data['referer'] = referer;
    data['antiCrawlerConfig'] = antiCrawlerConfig.toJson();
    return data;
  }

  Future<PluginSearchResponse> queryBangumi(String keyword,
      {bool shouldRethrow = false}) async {
    try {
      String queryURL =
          searchURL.replaceAll('@keyword', Uri.encodeQueryComponent(keyword));
      String htmlString;
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
          'Accept-Language': getRandomAcceptedLanguage(),
          'Connection': 'keep-alive',
          if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
        };
        htmlString = await _siteClient.postFormText(
          postUri.toString(),
          headers: httpHeaders,
          data: queryParams,
        );
      } else {
        var httpHeaders = {
          'referer': '$baseUrl/',
          'Accept-Language': getRandomAcceptedLanguage(),
          'Connection': 'keep-alive',
          if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
        };
        htmlString = await _siteClient.getText(
          queryURL,
          headers: httpHeaders,
        );
      }

      var htmlElement = parse(htmlString).documentElement!;

      if (detectsCaptchaChallenge(htmlString, htmlElement: htmlElement)) {
        KazumiLogger()
            .w('Plugin: $name detected captcha challenge in search response');
        throw CaptchaRequiredException(name);
      }

      htmlElement.queryXPath(searchList).nodes.forEach((element) {
        try {
          SearchItem searchItem = SearchItem(
            name: element.queryXPath(searchName).node!.text?.trim() ?? '',
            src:
                element.queryXPath(searchResult).node!.attributes['href'] ?? '',
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

  Future<List<Road>> querychapterRoads(String url,
      {CancelToken? cancelToken}) async {
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
      'Accept-Language': getRandomAcceptedLanguage(),
      'Connection': 'keep-alive',
    };
    try {
      final htmlString = await _siteClient.getText(
        queryURL,
        headers: httpHeaders,
        cancelToken: cancelToken,
      );
      var htmlElement = parse(htmlString).documentElement!;
      int count = 1;
      htmlElement.queryXPath(chapterRoads).nodes.forEach((element) {
        try {
          final int roadIndex = count - 1;
          final List<EpisodeIdentity> episodes = [];
          element.queryXPath(chapterResult).nodes.forEach((item) {
            final String rawUrl = item.node.attributes['href'] ?? '';
            final String itemName =
                (item.node.text ?? '').replaceAll(RegExp(r'\s+'), '');
            final String normalizedUrl = normalizeEpisodeUrl(baseUrl, rawUrl);
            episodes.add(
              EpisodeIdentity(
                stableId: _resolveEpisodeStableId(item, baseUrl, normalizedUrl),
                pageUrl: normalizedUrl,
                title: itemName,
                ordinal: _resolveEpisodeOrdinal(item, itemName),
                roadIndex: roadIndex,
              ),
            );
          });
          if (episodes.isNotEmpty) {
            roadList.add(Road(name: '播放线路$count', data: episodes));
            count++;
          }
        } catch (_) {}
      });
    } catch (_) {}
    return roadList;
  }

  /// 计算单集的稳定身份 [EpisodeIdentity.stableId]。
  ///
  /// 优先使用规则配置的 [episodeId] XPath 抓取源站显式标识；为空或未命中时，
  /// 回退用 [stableEpisodeIdFromUrl]（域名无关的归一化相对 path），后者保证
  /// 即便源站换域名也能稳定匹配历史进度。
  String _resolveEpisodeStableId(
    dynamic item,
    String baseUrl,
    String normalizedUrl,
  ) {
    if (episodeId.isNotEmpty) {
      final explicit = _extractNodeValue(item, episodeId);
      if (explicit.isNotEmpty) {
        return explicit;
      }
    }
    return stableEpisodeIdFromUrl(baseUrl, normalizedUrl);
  }

  /// 计算单集的序数 [EpisodeIdentity.ordinal]。
  ///
  /// 优先使用规则配置的 [episodeOrdinal] XPath；为空或解析失败时回退从标题解析；
  /// 仍无法判定（如 “OVA”/“特别篇”）时返回 null，由下游决定是否降级为列表位次。
  int? _resolveEpisodeOrdinal(dynamic item, String title) {
    if (episodeOrdinal.isNotEmpty) {
      final raw = _extractNodeValue(item, episodeOrdinal);
      if (raw.isNotEmpty) {
        final parsed = extractEpisodeNumber(raw);
        if (parsed > 0) return parsed;
      }
    }
    final fromTitle = extractEpisodeNumber(title);
    return fromTitle > 0 ? fromTitle : null;
  }

  /// 从相对 [item] 节点的 [xpath] 抽取字符串：优先取文本，否则取首个属性值。
  /// 用于 [episodeId] / [episodeOrdinal] 这类“可能指向文本或属性”的选择器。
  String _extractNodeValue(dynamic item, String xpath) {
    try {
      final node = item.queryXPath(xpath).node;
      if (node == null) return '';
      final text = (node.text ?? '').toString().trim();
      if (text.isNotEmpty) return text;
      final attrs = node.attributes;
      if (attrs is Map && attrs.isNotEmpty) {
        final first = attrs.values.first;
        return first == null ? '' : first.toString().trim();
      }
    } catch (_) {}
    return '';
  }

  Future<String> testSearchRequest(String keyword,
      {bool shouldRethrow = false, CancelToken? cancelToken}) async {
    String queryURL =
        searchURL.replaceAll('@keyword', Uri.encodeQueryComponent(keyword));
    String htmlString;
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
        'Accept-Language': getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
      };
      htmlString = await _siteClient.postFormText(
        postUri.toString(),
        headers: httpHeaders,
        data: queryParams,
        cancelToken: cancelToken,
      );
    } else {
      var httpHeaders = {
        'referer': '$baseUrl/',
        'Accept-Language': getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
      };
      htmlString = await _siteClient.getText(
        queryURL,
        headers: httpHeaders,
        cancelToken: cancelToken,
      );
    }

    return htmlString;
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

  bool detectsCaptchaChallenge(String htmlString, {Element? htmlElement}) {
    if (!antiCrawlerConfig.enabled) return false;

    final detectValue = antiCrawlerConfig.captchaDetectValue.trim();
    if (detectValue.isNotEmpty) {
      switch (antiCrawlerConfig.captchaDetectType) {
        case CaptchaDetectType.text:
          return htmlString.contains(detectValue);
        case CaptchaDetectType.regex:
          try {
            return RegExp(detectValue, caseSensitive: false, dotAll: true)
                .hasMatch(htmlString);
          } catch (e) {
            KazumiLogger()
                .w('Plugin: $name invalid captcha detect regex: $detectValue');
            return false;
          }
        case CaptchaDetectType.xpath:
        default:
          final element = htmlElement ?? parse(htmlString).documentElement!;
          return element.queryXPath(detectValue).node != null;
      }
    }

    final element = htmlElement ?? parse(htmlString).documentElement!;
    final List<String> detectionXpaths = [
      antiCrawlerConfig.captchaImage,
      antiCrawlerConfig.captchaButton,
    ].where((x) => x.isNotEmpty).toList();
    return detectionXpaths
        .any((xpath) => element.queryXPath(xpath).node != null);
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
      'user-agent': userAgent.isEmpty ? getRandomUA() : userAgent,
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
