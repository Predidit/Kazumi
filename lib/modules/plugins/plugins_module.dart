import 'package:dio/dio.dart';
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
    var httpHeaders = {
      'referer': baseUrl,
    };
    var resp = await Request().get(queryURL, options: Options(headers: httpHeaders));
    var htmlString = resp.data.toString();
    var htmlElement = parse(htmlString).documentElement!;
    var mid = htmlElement.queryXPath(searchList);
    debugPrint('${mid.nodes.first.text}');
  }
}
