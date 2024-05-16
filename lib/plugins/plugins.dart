import 'package:dio/dio.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/request/request.dart';
import 'package:html/parser.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:xpath_selector/xpath_selector.dart';
import 'package:kazumi/utils/parser.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

class Plugin {
  String api;
  String type;
  String name;
  String version;
  bool muliSources;
  bool useWebview;
  bool useNativePlayer;
  String userAgent;
  String baseUrl;
  String searchURL;
  String searchList;
  String searchName;
  String searchResult;
  String chapterRoads;
  String chapterResult;

  Plugin({
    required this.api,
    required this.type,
    required this.name,
    required this.version,
    required this.muliSources,
    required this.useWebview,
    required this.useNativePlayer,
    required this.userAgent,
    required this.baseUrl,
    required this.searchURL,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
  });

  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
        api: json['api'],
        type: json['type'],
        name: json['name'],
        version: json['version'],
        muliSources: json['muliSources'],
        useWebview: json['useWebview'],
        useNativePlayer: json['useNativePlayer'],
        userAgent: json['userAgent'],
        baseUrl: json['baseURL'],
        searchURL: json['searchURL'],
        searchList: json['searchList'],
        searchName: json['searchName'],
        searchResult: json['searchResult'],
        chapterRoads: json['chapterRoads'],
        chapterResult: json['chapterResult']);
  }

  factory Plugin.fromTemplate() {
    return Plugin(
        api: '1',
        type: 'anime',
        name: '',
        version: '',
        muliSources: true,
        useWebview: true,
        useNativePlayer: false,
        userAgent: '',
        baseUrl: '',
        searchURL: '',
        searchList: '',
        searchName: '',
        searchResult: '',
        chapterRoads: '',
        chapterResult: '');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['api'] = this.api;
    data['type'] = this.type;
    data['name'] = this.name;
    data['version'] = this.version;
    data['muliSources'] = this.muliSources;
    data['useWebview'] = this.useWebview;
    data['useNativePlayer'] = this.useNativePlayer;
    data['userAgent'] = this.userAgent;
    data['baseURL'] = this.baseUrl;
    data['searchURL'] = this.searchURL;
    data['searchList'] = this.searchList;
    data['searchName'] = this.searchName;
    data['searchResult'] = this.searchResult;
    data['chapterRoads'] = this.chapterRoads;
    data['chapterResult'] = this.chapterResult;
    return data;
  }

  queryBangumi(String keyword) async {
    String queryURL = searchURL.replaceAll('@keyword', keyword);
    List<SearchItem> searchItems = [];
    var httpHeaders = {
      'referer': baseUrl + '/',
    };
    var resp =
        await Request().get(queryURL, options: Options(headers: httpHeaders));
    var htmlString = resp.data.toString();
    var htmlElement = parse(htmlString).documentElement!;

    htmlElement.queryXPath(searchList).nodes.forEach((element) {
      // debugPrint('调试输出 ${element.queryXPath(searchName).node!.text}');
      SearchItem searchItem = SearchItem(
        name: element.queryXPath(searchName).node!.text ?? '',
        src: element.queryXPath(searchResult).node!.attributes['href'] ?? '',
      );
      searchItems.add(searchItem);
      debugPrint(
          '$name 番剧名称 ${element.queryXPath(searchName).node!.text ?? ''}');
      debugPrint(
          '$name 番剧链接 $baseUrl${element.queryXPath(searchResult).node!.attributes['href'] ?? ''}');
    });
    PluginSearchResponse pluginSearchResponse =
        PluginSearchResponse(pluginName: name, data: searchItems);
    return pluginSearchResponse;
  }

  querychapterRoads(String url) async {
    List<Road> roadList = [];
    String queryURL = baseUrl + url;
    var httpHeaders = {
      'referer': baseUrl + '/',
    };
    try {
      var resp =
          await Request().get(queryURL, options: Options(headers: httpHeaders));
      var htmlString = resp.data.toString();
      var htmlElement = parse(htmlString).documentElement!;
      int count = 1;
      htmlElement.queryXPath(chapterRoads).nodes.forEach((element) {
        try {
          List<String> chapterUrlList = [];
          element.queryXPath(chapterResult).nodes.forEach((item) {
            String itemUrl = item.node.attributes['href'] ?? '';
            chapterUrlList.add(itemUrl);
          });
          if (chapterUrlList.length != 0) {
            Road road = Road(name: '播放列表$count', data: chapterUrlList);
            roadList.add(road);
            count++;
          }
        } catch (_) {}
      });
    } catch (_) {}
    return roadList;
  }

  Future<String> queryVideoUrl(String url) async {
    String queryURL = baseUrl + url;
    String videoUrl = '';
    var httpHeaders = {
      'referer': baseUrl + '/',
    };
    if (useWebview == 'false') {
      videoUrl = await queryVideoUrlWithoutWebview(queryURL, httpHeaders);
    } else {}
    return videoUrl;
  }

  Future<String> queryVideoUrlWithoutWebview(
      String queryURL, Map<String, String> httpHeaders) async {
    String videoUrl = '';
    var resp =
        await Request().get(queryURL, options: Options(headers: httpHeaders));
    try {
      videoUrl = ParserWithoutWebview.extractM3U8Links(resp.data);
    } catch (_) {}
    if (videoUrl == '') {
      try {
        videoUrl = ParserWithoutWebview.extractMP4Links(resp.data);
      } catch (_) {}
    }
    return videoUrl;
  }

  queryVideoUrlWithWebview(String url) {}
}
