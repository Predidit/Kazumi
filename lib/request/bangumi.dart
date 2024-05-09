import 'package:flutter/material.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/modules/bangumi/calendar_module.dart';

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
}
