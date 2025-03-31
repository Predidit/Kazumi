import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/comments/comment_response.dart';
import 'package:kazumi/modules/characters/characters_response.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/character/character_full_item.dart';

class BangumiHTTP {
  // why the api havn't been replaced by getCalendarBySearch?
  // Because getCalendarBySearch is not stable, it will miss some bangumi items.
  static Future<List<List<BangumiItem>>> getCalendar() async {
    List<List<BangumiItem>> bangumiCalendar = [];
    try {
      var res = await Request().get(Api.bangumiCalendar,
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      for (int i = 1; i <= 7; i++) {
        List<BangumiItem> bangumiList = [];
        final jsonList = jsonData['$i'];
        for (dynamic jsonItem in jsonList) {
          try {
            BangumiItem bangumiItem = BangumiItem.fromJson(jsonItem['subject']);
            bangumiList.add(bangumiItem);
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
  static Future<List<List<BangumiItem>>> getCalendarBySearch(
      List<String> dateRange, int limit, int offset) async {
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

  static Future<List<BangumiItem>> getBangumiList(
      {int rank = 2, String tag = ''}) async {
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
          "rank": [">$rank", "<=99999"],
          "nsfw": false
        },
      };
    }
    try {
      final res = await Request().post(
          Api.formatUrl(Api.bangumiRankSearch, [100, 0]),
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

  static Future<List<BangumiItem>> getBangumiTrendsList(
      {int type = 2, int limit = 24, int offset = 0}) async {
    List<BangumiItem> bangumiList = [];
    var params = <String, dynamic>{
      'type': type,
      'limit': limit,
      'offset': offset,
    };
    try {
      final res = await Request().get(Api.bangumiTrendsNext,
          data: params,
          options: Options(
              headers: bangumiHTTPHeader, contentType: 'application/json'));
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          bangumiList.add(BangumiItem.fromJson(jsonItem['subject']));
        }
      }
    } catch (e) {
      KazumiLogger().log(
          Level.error, 'Resolve bangumi trends list failed ${e.toString()}');
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
      final res = await Request().post(
          Api.formatUrl(Api.bangumiRankSearch, [100, 0]),
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

  static Future<BangumiItem?> getBangumiInfoByID(int id) async {
    try {
      final res = await Request().get(Api.bangumiInfoByID + id.toString(),
          options: Options(headers: bangumiHTTPHeader));
      return BangumiItem.fromJson(res.data);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi item failed ${e.toString()}');
      return null;
    }
  }

  static Future<EpisodeInfo> getBangumiEpisodeByID(int id, int episode) async {
    EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();
    var params = <String, dynamic>{
      'subject_id': id,
      'offset': episode - 1,
      'limit': 1
    };
    try {
      final res = await Request().get(Api.bangumiEpisodeByID,
          data: params, options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data['data'][0];
      episodeInfo = EpisodeInfo.fromJson(jsonData);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi episode failed ${e.toString()}');
    }
    return episodeInfo;
  }

  static Future<CommentResponse> getBangumiCommentsByID(int id,
      {int offset = 0}) async {
    CommentResponse commentResponse = CommentResponse.fromTemplate();
    try {
      final res = await Request().get(
          '${Api.bangumiInfoByIDNext}$id/comments?offset=$offset&limit=20',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      commentResponse = CommentResponse.fromJson(jsonData);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve bangumi comments failed ${e.toString()}');
    }
    return commentResponse;
  }

  static Future<EpisodeCommentResponse> getBangumiCommentsByEpisodeID(
      int id) async {
    EpisodeCommentResponse commentResponse =
        EpisodeCommentResponse.fromTemplate();
    try {
      final res = await Request().get(
          '${Api.bangumiEpisodeByIDNext}$id/comments',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      commentResponse = EpisodeCommentResponse.fromJson(jsonData);
    } catch (e) {
      KazumiLogger().log(Level.error,
          'Resolve bangumi episode comments failed ${e.toString()}');
    }
    return commentResponse;
  }

  static Future<CharacterCommentResponse> getCharacterCommentsByCharacterID(
      int id) async {
    CharacterCommentResponse commentResponse =
        CharacterCommentResponse.fromTemplate();
    try {
      final res = await Request().get(
          '${Api.bangumiCharacterByIDNext}$id/comments',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      commentResponse = CharacterCommentResponse.fromJson(jsonData);
    } catch (e) {
      KazumiLogger().log(Level.error,
          'Resolve bangumi character comments failed ${e.toString()}');
    }
    return commentResponse;
  }

  static Future<CharactersResponse> getCharatersByBangumiID(int id) async {
    CharactersResponse charactersResponse = CharactersResponse.fromTemplate();
    try {
      final res = await Request().get('${Api.bangumiInfoByID}$id/characters',
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      charactersResponse = CharactersResponse.fromJson(jsonData);
    } catch (e) {
      KazumiLogger().log(
          Level.error, 'Resolve bangumi characters failed ${e.toString()}');
    }
    return charactersResponse;
  }

  static Future<CharacterFullItem> getCharacterByCharacterID(int id) async {
    CharacterFullItem characterFullItem = CharacterFullItem.fromTemplate();
    try {
      final res = await Request().get(
          Api.formatUrl(Api.characterInfoByCharacterIDNext, [id]),
          options: Options(headers: bangumiHTTPHeader));
      final jsonData = res.data;
      characterFullItem = CharacterFullItem.fromJson(jsonData);
    } catch (e) {
      KazumiLogger()
          .log(Level.error, 'Resolve character info failed ${e.toString()}');
    }
    return characterFullItem;
  }
}
