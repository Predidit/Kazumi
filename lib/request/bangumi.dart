import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/comments/comment_response.dart';
import 'package:kazumi/modules/characters/character_response.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';

class BangumiHTTP {
  // why the api havn't been replaced by getCalendarBySearch?
  // Because getCalendarBySearch is not stable, it will miss some bangumi items.
  static Future<List<List<BangumiItem>>> getCalendar() async {
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

  // Get clander by search API, we need a list of strings (the start of the season and the end of the season) eg: ["2024-07-01", "2024-10-01"]
  // because the air date is the launch date of the anime, it is usually a few days before the start of the season
  // So we usually use the start of the season month -1 and the end of the season month -1
  static Future<List<List<BangumiItem>>> getCalendarBySearch(List<String> dateRange, int limit, int offset) async {
    List<BangumiItem> bangumiList = [];
    List<List<BangumiItem>> bangumiCalendar = [];
    var params = <String, dynamic>{
      "keyword": "",
      "sort": "rank",
      "filter": {
        "type": [2],
        "tag": ["日本"],
        "air_date": [">=${dateRange[0]}", "<${dateRange[1]}"],
        "rank": [">0", "<=99999"],
        "nsfw": true
      }
    };
    try {
      final url = Api.formatUrl(Api.bangumiRankSearch, [limit, offset]);
      final res = await Request().post(url,
          data: params,
          options: Options(
              headers: bangumiHTTPHeader, contentType: 'application/json'));
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
    try {
      for (int weekday = 1; weekday <= 7; weekday++) {
        List<BangumiItem> bangumiDayList = [];
        for (BangumiItem bangumiItem in bangumiList) {
          if (bangumiItem.airWeekday == weekday) {
            bangumiDayList.add(bangumiItem);
          }
        }
        bangumiCalendar.add(bangumiDayList);
      }
    } catch (e) {
      KazumiLogger().log(
          Level.error, 'Fetch bangumi item to calendar failed ${e.toString()}');
    }
    return bangumiCalendar;
  }

  static Future<List<BangumiItem>> getBangumiList({int rank = 2, String tag = ''}) async {
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
      final res = await Request().post(Api.formatUrl(Api.bangumiRankSearch, [100, 0]),
          data: params,
          options: Options(
              headers: bangumiHTTPHeader, contentType: 'application/json'));
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

  static Future<List<BangumiItem>> bangumiSearch(String keyword) async {
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
      final res = await Request().post(Api.formatUrl(Api.bangumiRankSearch, [100, 0]),
          data: params,
          options: Options(
              headers: bangumiHTTPHeader, contentType: 'application/json'));
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

  static Future<String> getBangumiSummaryByID(int id) async {
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

  static Future<EpisodeInfo> getBangumiEpisodeByID(int id, int episode) async {
    EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();
    try {
      final res = await Request().get('${Api.bangumiEpisodeByID}$id&offset=${episode - 1}&limit=1',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data['data'][0];
      episodeInfo = EpisodeInfo.fromJson(jsonData);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi episode failed ${e.toString()}');
    }
    return episodeInfo;
  }

  static Future<CommentResponse> getBangumiCommentsByID(int id, {int offset = 0}) async {
    CommentResponse commentResponse = CommentResponse.fromTemplate();
    try {
      final res = await Request().get('${Api.bangumiInfoByIDNext}$id/comments?offset=$offset&limit=20',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      commentResponse = CommentResponse.fromJson(jsonData);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi comments failed ${e.toString()}');
    }
    return commentResponse;
  }

  static Future<EpisodeCommentResponse> getBangumiCommentsByEpisodeID(int id) async {
    EpisodeCommentResponse commentResponse = EpisodeCommentResponse.fromTemplate();
    try {
      final res = await Request().get('${Api.bangumiInfoByIDNext}-/episode/$id/comments',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      commentResponse = EpisodeCommentResponse.fromJson(jsonData);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi episode comments failed ${e.toString()}');
    }
    return commentResponse;
  }
  
  static Future<CharacterResponse> getCharatersByID(int id) async {
    CharacterResponse characterResponse = CharacterResponse.fromTemplate();
    try {
      final res = await Request().get(Api.bangumiInfoByID + id.toString() + '/characters',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      characterResponse = CharacterResponse.fromJson(jsonData);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi characters failed ${e.toString()}');
    }
    return characterResponse;
  }
}
