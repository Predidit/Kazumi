import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

class BangumiHTTP {
  static Future getBangumiList({int? page}) async {
    List<BangumiItem> bangumiList = [];
    try {
      var res = await Request().get(Api.bangumiCalendar);
      final jsonData = res.data;
      final jsonList = jsonData[0]['items'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          bangumiList.add(BangumiItem.fromJson(jsonItem));
        }
      }
    } catch (e) {
      debugPrint('解析推荐列表错误 ${e.toString()}');
      debugPrint('当前列表长度 ${bangumiList.length}');
    }
    return bangumiList;
  }

  static Future bangumiSearch(String keyword) async {
    List<BangumiItem> bangumiList = [];
    // Bangumi API 文档要求的UA格式
    var httpHeaders = {
      'user-agent':
          'Predidit/Kazumi/0.0.1 (Android) (https://github.com/Predidit/Kazumi)',
      'referer': '',
    };
    Map<String, String> keywordMap = {'type': '2', 'responseGroup': 'small'};

    try {
      final res = await Request().get(
          Api.bangumiSearch + Uri.encodeComponent(keyword),
          data: keywordMap,
          options: Options(headers: httpHeaders));
      final jsonData = res.data;
      final jsonList = jsonData['list'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          debugPrint('尝试添加检索结果');
          bangumiList.add(BangumiItem.fromJson(jsonItem));
        }
      }
    } catch (e) {
      debugPrint('检索错误 ${e.toString()}');
    }
    debugPrint('检索结果长度 ${bangumiList.length}');
    return bangumiList;
  }
}
