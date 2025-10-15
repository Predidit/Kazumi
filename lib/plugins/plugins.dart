import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/web_yi/web_yi_controller.dart';
import 'package:kazumi/request/request.dart';
import 'package:html/parser.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:xpath_selector/xpath_selector.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'package:kazumi/utils/utils.dart';

WebYiController webYiController = Modular.get<WebYiController>();

class TagParser {
  String url;
  String xpath;
  String value;
  bool show;

  TagParser({
    required this.url,
    required this.xpath,
    this.value = '',
    this.show = false,
  });

  // 添加 fromJson 工厂方法
  factory TagParser.fromJson(Map<String, dynamic>? json) {
    // 如果 json 为 null，返回一个默认的 TagParser
    if (json == null) {
      return TagParser(url: '', xpath: '');
    }

    return TagParser(
      url: json['url'] ?? '',
      xpath: json['xpath'] ?? '',
      value: json['value'] ?? '',
      show: json['show'] ?? false,
    );
  }

  // 添加 toJson 方法
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'xpath': xpath,
      'value': value,
      'show': show,
    };
  }
}

class Plugin {
  String api;
  String type;
  String name;
  String version;
  bool muliSources;
  bool useWebview;
  bool useNativePlayer;
  bool usePost;
  bool useLegacyParser;
  // bool searchWithOthers;
  // bool reloadWithWeb;
  String userAgent;

  // String cookie;
  String baseUrl;
  String searchURL;
  String searchImg;
  String searchList;
  String searchName;
  String searchResult;
  String chapterRoads;
  String chapterItems;
  String chapterResult;
  String chapterResultName;
  String referer;
  Map<String, TagParser> tags;

  // String htmlIdentifier;

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
    // this.reloadWithWeb = false,
    required this.userAgent,
    // this.cookie = '',
    required this.baseUrl,
    required this.searchURL,
    required this.searchList,
    required this.searchName,
    this.searchImg = '',
    required this.searchResult,
    required this.chapterRoads,
    this.chapterItems = '',
    required this.chapterResult,
    this.chapterResultName = '',
    required this.referer,
    required this.tags,
    // this.htmlIdentifier = '',
  });

  factory Plugin.fromJson(Map<String, dynamic> json) {
    // 处理 tags 字段
    Map<String, TagParser> tagsMap = {};
    if (json['tags'] != null && json['tags'] is Map) {
      (json['tags'] as Map).forEach((key, value) {
        if (value is Map<String, dynamic>) {
          tagsMap[key] = TagParser.fromJson(value);
        }
      });
    }

    return Plugin(
      api: json['api'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      version: json['version'] ?? '',
      muliSources: json['muliSources'] ?? true,
      useWebview: json['useWebview'] ?? true,
      useNativePlayer: json['useNativePlayer'] ?? false,
      usePost: json['usePost'] ?? false,
      useLegacyParser: json['useLegacyParser'] ?? false,
      // reloadWithWeb: json['reloadWithWeb'] ?? false,
      userAgent: json['userAgent'] ?? '',
      // cookie: json['cookie'] ?? '',
      baseUrl: json['baseURL'] ?? '',
      searchURL: json['searchURL'] ?? '',
      searchList: json['searchList'] ?? '',
      searchName: json['searchName'] ?? '',
      searchImg: json['searchImg'] ?? '',
      searchResult: json['searchResult'] ?? '',
      chapterRoads: json['chapterRoads'] ?? '',
      chapterItems: json['chapterItems'] ?? '',
      chapterResult: json['chapterResult'] ?? '',
      chapterResultName: json['chapterResultName'] ?? '',
      referer: json['referer'] ?? '',
      tags: tagsMap,
      // 使用处理后的 tagsMap
      // htmlIdentifier: json['htmlIdentifier'] ?? '',
    );
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
      // reloadWithWeb: false,
      userAgent: '',
      // cookie: '',
      baseUrl: '',
      searchURL: '',
      searchList: '',
      searchName: '',
      searchImg: '',
      searchResult: '',
      chapterRoads: '',
      chapterItems: '',
      chapterResult: '',
      chapterResultName: '',
      referer: '',
      tags: {},
      // 初始化为空 Map
      // htmlIdentifier: '',
    );
  }

  Map<String, dynamic> toJson() {
    // 转换 tags 为可序列化的格式
    Map<String, dynamic> serializedTags = {};
    tags.forEach((key, value) {
      serializedTags[key] = value.toJson();
    });

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
    // data['reloadWithWeb'] = reloadWithWeb;
    data['userAgent'] = userAgent;
    // data['cookie'] = cookie;
    data['baseURL'] = baseUrl;
    data['searchURL'] = searchURL;
    data['searchList'] = searchList;
    data['searchName'] = searchName;
    data['searchImg'] = searchImg;
    data['searchResult'] = searchResult;
    data['chapterRoads'] = chapterRoads;
    data['chapterItems'] = chapterItems;
    data['chapterResult'] = chapterResult;
    data['chapterResultName'] = chapterResultName;
    data['referer'] = referer;
    data['tags'] = serializedTags; // 使用序列化后的 tags
    // data['htmlIdentifier'] = htmlIdentifier;
    return data;
  }

  queryTag(String tagName, {XPathNode? element}) async {
    final value = tags[tagName];
    if (value != null) {
      final url = value.url;
      final xpath = value.xpath;

      if (element != null &&
          element.isElement &&
          value.show &&
          value.url == "element") {
        if (getResultType(xpath) == XPathResultType.attribute) {
          value.value = element.queryXPath(xpath).attrs.firstOrNull ?? '';
        } else if (getResultType(xpath) == XPathResultType.text) {
          value.value = element.queryXPath(xpath).node?.text ?? '';
        } else {
          value.value = '';
        }
      } else {
        try {
          if (url.isNotEmpty && xpath.isNotEmpty) {
            final resp = await Request().get(
              url,
              options: Options(headers: {'referer': '$baseUrl/'}),
              shouldRethrow: false,
              extra: {'customError': ''},
            );
            final htmlString = resp.data.toString();
            final htmlElement = parse(htmlString).documentElement!;
            if (getResultType(xpath) == XPathResultType.attribute) {
              value.value =
                  htmlElement.queryXPath(xpath).attrs.firstOrNull ?? '';
            } else if (getResultType(xpath) == XPathResultType.text) {
              value.value = htmlElement.queryXPath(xpath).node?.text ?? '';
            } else {
              value.value = '';
            }
          }
        } catch (e) {
          debugPrint('解析失败 [$tagName]: ${e.toString()}');
          value.value = '';
        }
      }
    }
  }

  String replaceTag(String queryURL) {
    final tagPattern = RegExp(r'@tag\[(.*?)\]', caseSensitive: false);

    // 使用 replaceAllMapped 一次性替换所有匹配项
    queryURL = queryURL.replaceAllMapped(tagPattern, (Match match) {
      final tagName = match.group(1)!.trim(); // 提取标签名并去除两端空格
      queryTag(tagName);
      return Uri.encodeComponent(
          tags[tagName]?.value ?? ''); // 替换为编码后的值，不存在则返回空
    });
    return queryURL;
  }

  Future<PluginSearchResponse> queryBangumi(String keyword, int page,
      {bool shouldRethrow = false}) async {
    String queryURL = searchURL.replaceAll('@keyword', keyword);
    if (queryURL.contains('@pagenum')) {
      queryURL =
          queryURL.replaceAll('@pagenum', page > 0 ? page.toString() : '1');
    }
    queryURL = replaceTag(queryURL);
    print(queryURL);

    List<SearchItem> searchItems = [];

    //todo:根据reloadWithWeb实现web爬取

    var htmlString;

    // if (reload && reloadWithWeb) {
    //   await webYiController.init();
    //   Modular.to.pushNamed('/webYi/');
    //   htmlString = await webYiController.getHtml(queryURL, htmlIdentifier);
    //   cookie = await webYiController.getCookie(baseUrl);
    // } else {
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
          shouldRethrow: shouldRethrow);
    } else {
      var httpHeaders = {
        'referer': '$baseUrl/',
        'Accept-Language': Utils.getRandomAcceptedLanguage(),
        'Connection': 'keep-alive',
      };
      resp = await Request().get(queryURL,
          options: Options(headers: httpHeaders),
          shouldRethrow: shouldRethrow,
          extra: {'customError': ''});
    }

    htmlString = resp.data.toString();
    // }

    var htmlElement = parse(htmlString).documentElement!;

    htmlElement.queryXPath(searchList).nodes.forEach((element) {
      try {
        final pattern = RegExp(
            r'^(.*?)\s*@start-xpath\s+(.*?)\s+@end-xpath\s*(.*)$',
            multiLine: false,
            caseSensitive: false);
        final match = pattern.firstMatch(searchImg);
        var fullImgUrl = '';
        if (match != null) {
          final prefix =
              match.group(1)?.trim() ?? ''; // 第一部分：@start-xpath 之前的内容
          final xpath = match.group(2)?.trim() ?? ''; // 第二部分：中间的 XPath
          final suffix = match.group(3)?.trim() ?? ''; // 第三部分：@end-xpath 之后的内容
          // 构建完整图片 URL
          final relativePath =
              element.queryXPath(xpath).attrs.firstOrNull ?? '';
          fullImgUrl = '$prefix$relativePath$suffix';
        } else {
          fullImgUrl = element.queryXPath(searchImg).attrs.firstOrNull ?? '';
        }

        Map<String, String> processedTags = Map.fromEntries(
            tags.entries.where((entry) => entry.value.show).map((entry) {
          // 对每个键值对执行处理函数
          queryTag(entry.key, element: element);
          return MapEntry(entry.key, entry.value.value);
        }));
        SearchItem searchItem = SearchItem(
          name: (element.queryXPath(searchName).node!.text ?? '')
              .replaceAll(RegExp(r'\s+'), ' ') // 将连续空白替换为单个空格
              .trim(), // 去除首尾空格
          img: fullImgUrl,
          src: element.queryXPath(searchResult).node!.attributes['href'] ?? '',
          tags: processedTags,
        );
        searchItems.add(searchItem);
        KazumiLogger().log(Level.info,
            '$name ${element.queryXPath(searchName).node!.text ?? ''} $baseUrl${element.queryXPath(searchResult).node!.attributes['href'] ?? ''}');
      } catch (_) {}
    });
    PluginSearchResponse pluginSearchResponse =
        PluginSearchResponse(pluginName: name, data: searchItems);
    return pluginSearchResponse;
  }

  Future<List<Road>> querychapterRoads(String url,
      {CancelToken? cancelToken}) async {
    List<Road> roadList = [];
    // 预处理
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
      // 'Cookie': cookie,
    };
    var resp = await Request().get(queryURL,
        options: Options(headers: httpHeaders), cancelToken: cancelToken);
    var htmlString = resp.data.toString();
    // if (!htmlString.contains('<html')) {
    //   await webYiController.init();
    //   htmlString = await webYiController.getHtml(queryURL, htmlIdentifier);
    // }

    try {
      var htmlElement = parse(htmlString).documentElement!;
      int count = 1;
      htmlElement.queryXPath(chapterRoads).nodes.forEach((element) {
        try {
          List<String> chapterUrlList = [];
          List<String> chapterNameList = [];
          element.queryXPath(chapterItems).nodes.forEach((item) {
            String itemUrl =
                item.queryXPath(chapterResult).node!.attributes['href'] ?? '';
            String itemName = '';
            itemName = item.queryXPath(chapterResultName).node?.text ?? '';
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
}

enum XPathResultType { attribute, text }

XPathResultType getResultType(String xpath) {
  // 1. 优先判断属性节点：匹配 @属性名 或 路径中的@属性（如@id、/div/@class）
  // 规则：@后紧跟属性名（字母、数字、下划线、连字符），且不在文本或函数参数中
  if (RegExp(r'^@[\w-]+$').hasMatch(xpath) || // 单独的属性（如@href）
      RegExp(r'/.+?/@[\w-]+').hasMatch(xpath)) {
    // 路径中的属性（如//a/@href）
    return XPathResultType.attribute;
  }

  // 2. 判断文本节点：匹配各种text()表达式（支持索引和last()）
  // 如/text()、//text()[1]、/div/p/text()[last()] 等
  if (RegExp(r'(//|/)text\(\s*(\d+|last\(\))?\s*\)').hasMatch(xpath)) {
    return XPathResultType.text;
  }

  // 3. 对于无法明确归类的情况，可根据业务需求返回默认值
  // （例如视为文本或属性，或抛出异常，这里默认返回文本作为示例）
  return XPathResultType.text;
}
