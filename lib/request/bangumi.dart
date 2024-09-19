import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

class BangumiHTTP {
  static Future getCalendar() async {
    List<List<BangumiItem>> bangumiCalendar = [];
    try {
      var res = await Request().get(Api.bangumiCalendar,
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      KazumiLogger()
          .log(Level.info, 'The length of clendar is ${jsonData.length}');
      for (dynamic jsonDayList in jsonData) {
        List<BangumiItem> bangumiList = [];
        final jsonList = jsonDayList['items'];
        for (dynamic jsonItem in jsonList) {
          try {
            BangumiItem bangumiItem = BangumiItem.fromJson(jsonItem);
            if (bangumiItem.nameCn != '') {
              bangumiList.add(bangumiItem);
            }
          } catch (_) {}
        }
        bangumiCalendar.add(bangumiList);
      }
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve calendar failed ${e.toString()}');
    }
    return bangumiCalendar;
  }

  static Future getBangumiList({int rank = 2, String tag = ''}) async {
    List<BangumiItem> bangumiList = [];
    late Map<String, dynamic> params;
    if (tag == '') {
      params = <String, dynamic>{
        'keyword': '',
        'sort': 'rank',
        "filter": {
          "type": [2],
          "tag": ["日本"],
          "rank": [">$rank", "<=1050"],
          "nsfw": false
        },
      };
    } else {
      params = <String, dynamic>{
        'keyword': '',
        'sort': 'rank',
        "filter": {
          "type": [2],
          "tag": [tag],
          "rank": [">${rank * 2}", "<=99999"],
          "nsfw": false
        },
      };
    }
    try {
      final res = await Request().post(Api.bangumiRankSearch,
          data: params, options: Options(headers: bangumiHTTPHeader, contentType: 'application/json'));
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          bangumiList.add(BangumiItem.fromJson(jsonItem));
        }
      }
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi list failed ${e.toString()}');
    }
    return bangumiList;
  }

  static Future bangumiSearch(String keyword) async {
    List<BangumiItem> bangumiList = [];

    var params = <String, dynamic>{
      'keyword': keyword,
      'sort': 'rank',
      "filter": {
        "type": [2],
        "tag": [],
        "rank": [">0", "<=99999"],
        "nsfw": false
      },
    };

    try {
      final res = await Request().post(Api.bangumiRankSearch,
          data: params, options: Options(headers: bangumiHTTPHeader, contentType: 'application/json'));
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          try {
            BangumiItem bangumiItem = BangumiItem.fromJson(jsonItem);
            if (bangumiItem.nameCn != '') {
              bangumiList.add(bangumiItem);
            }
          } catch (e) {
            KazumiLogger().log(
                Level.error, 'Resolve search results failed ${e.toString()}');
          }
        }
      }
    } catch (e) {
      KazumiLogger().log(Level.error, 'Unknown search problem ${e.toString()}');
    }
    return bangumiList;
  }

  static getBangumiSummaryByID(int id) async {
    try {
      final res = await Request().get(Api.bangumiInfoByID + id.toString(),
          options: Options(headers: bangumiHTTPHeader));
      return res.data['summary'];
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi summary failed ${e.toString()}');
      return '';
    }
  }
}
