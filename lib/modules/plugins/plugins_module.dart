import 'package:dio/dio.dart';
import 'package:kazumi/modules/search/search_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/request/request.dart';
import 'package:html/parser.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:xpath_selector/xpath_selector.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

class Plugin {
  String name;
  String version;
  String muliSources;
  String useWebview;
  String userAgent;
  String baseUrl;
  String searchURL;
  String searchList;
  String searchName;
  String searchResult;
  String chapterRoads;
  String chapterResult;

  Plugin({
    required this.name,
    required this.version,
    required this.muliSources,
    required this.useWebview,
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
        name: json['name'],
        version: json['version'],
        muliSources: json['muliSources'],
        useWebview: json['useWebview'],
        userAgent: json['userAgent'],
        baseUrl: json['baseURL'],
        searchURL: json['searchURL'],
        searchList: json['searchList'],
        searchName: json['searchName'],
        searchResult: json['searchResult'],
        chapterRoads: json['chapterRoads'],
        chapterResult: json['chapterResult']);
  }

  queryBangumi(String keyword) async {
    String queryURL = searchURL.replaceAll('@keyword', keyword);
    List<SearchItem> searchItems = [];
    var httpHeaders = {
      'referer': baseUrl + '/',
    };
    try {
      var resp =
          await Request().get(queryURL, options: Options(headers: httpHeaders));
      var htmlString = resp.data.toString();
      var htmlElement = parse(htmlString).documentElement!;

      htmlElement.queryXPath(searchList).nodes.forEach((element) {
        try {
          // debugPrint('调试输出 ${element.queryXPath(searchName).node!.text}');
          SearchItem searchItem = SearchItem(
            name: element.queryXPath(searchName).node!.text ?? '',
            src:
                element.queryXPath(searchResult).node!.attributes['href'] ?? '',
          );
          searchItems.add(searchItem);
          debugPrint(
              '${this.name} 番剧名称 ${element.queryXPath(searchName).node!.text ?? ''}');
          debugPrint(
              '$name 番剧链接 $baseUrl${element.queryXPath(searchResult).node!.attributes['href'] ?? ''}');
        } catch (_) {}
      });
    } catch (_) {}
    SearchResponse searchResponse =
        SearchResponse(pluginName: name, data: searchItems);
    return searchResponse;
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
          Road road = Road(name: '播放列表$count', data: chapterUrlList);
          roadList.add(road);
          count++;
        } catch (_) {}
      });
    } catch (_) {}
    return roadList;
  }
}
