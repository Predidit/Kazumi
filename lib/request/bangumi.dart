import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/comments/comment_response.dart';
import 'package:kazumi/modules/characters/characters_response.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_auth_models.dart';
import 'package:kazumi/modules/character/character_full_item.dart';
import 'package:kazumi/modules/staff/staff_response.dart';
import 'package:dio/dio.dart';

class BangumiHTTP {
  static Options _authOptions() {
    final token = Request.setting
        .get('bangumiAccessToken', defaultValue: '')
        .toString()
        .trim();
    return Options(headers: {
      'Authorization': 'Bearer $token',
    });
  }

  static int? _mapCollectTypeFromBangumi(int? type) {
    switch (type) {
      case 1:
        return 2;
      case 2:
        return 4;
      case 3:
        return 1;
      case 4:
        return 3;
      case 5:
        return 5;
      default:
        return null;
    }
  }

  static int? _mapCollectTypeToBangumi(int? type) {
    switch (type) {
      case 1:
        return 3;
      case 2:
        return 1;
      case 3:
        return 4;
      case 4:
        return 2;
      case 5:
        return 5;
      default:
        return null;
    }
  }

  static Future<BangumiAuthUser> getCurrentUser() async {
    final res = await Request().get(
      Api.bangumiAPIDomain + Api.bangumiMyself,
      options: _authOptions(),
      extra: {'customError': 'Bangumi 登录校验失败'},
      shouldRethrow: true,
    );
    return BangumiAuthUser.fromJson(Map<String, dynamic>.from(res.data));
  }

  static Future<int?> getCollectionType(int subjectId) async {
    try {
      final username = Request.setting
          .get('bangumiUsername', defaultValue: '')
          .toString()
          .trim();
      if (username.isEmpty) {
        throw Exception('Bangumi 用户名为空，请重新登录');
      }
      final res = await Request().get(
        Api.formatUrl(
            Api.bangumiAPIDomain + '/v0/users/{0}/collections/{1}',
            [username, subjectId]),
        options: _authOptions(),
        extra: {'customError': ''},
        shouldRethrow: true,
      );
      final collection = BangumiSubjectCollection.fromJson(
        Map<String, dynamic>.from(res.data),
      );
      return _mapCollectTypeFromBangumi(collection.type);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return 0;
      }
      rethrow;
    }
  }

  static Future<void> updateCollectionType(int subjectId, int type) async {
    final bangumiType = _mapCollectTypeToBangumi(type);
    if (bangumiType == null) {
      return;
    }
    await Request().post(
      Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiMyCollection, [subjectId]),
      data: {'type': bangumiType},
      options: _authOptions(),
      extra: {'customError': 'Bangumi 收藏同步失败'},
      shouldRethrow: true,
    );
  }

  static Future<List<BangumiSubjectCollection>> getUserCollections({
    int? type,
    int limit = 100,
    int offset = 0,
  }) async {
    final username = Request.setting
        .get('bangumiUsername', defaultValue: '')
        .toString()
        .trim();
    if (username.isEmpty) {
      throw Exception('Bangumi 用户名为空，请重新登录');
    }
    final queryParameters = <String, dynamic>{
      'subject_type': 2,
      'limit': limit,
      'offset': offset,
    };
    if (type != null && type > 0) {
      final bangumiType = _mapCollectTypeToBangumi(type);
      if (bangumiType != null) {
        queryParameters['type'] = bangumiType;
      }
    }
    final res = await Request().get(
      Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiUserCollections, [username]),
      data: queryParameters,
      options: _authOptions(),
      extra: {'customError': 'Bangumi 收藏列表同步失败'},
      shouldRethrow: true,
    );
    final data = (res.data['data'] as List<dynamic>? ?? []);
    return data
        .whereType<Map<String, dynamic>>()
        .map(BangumiSubjectCollection.fromJson)
        .toList();
  }

  static Future<void> markEpisodeWatched({
    required int subjectId,
    required int episodeId,
  }) async {
    await Request().put(
      Api.formatUrl(
          Api.bangumiAPIDomain + Api.bangumiMyEpisodeCollection, [episodeId]),
      data: {'type': 2},
      options: _authOptions(),
      extra: {'customError': 'Bangumi 章节进度同步失败'},
      shouldRethrow: true,
    );
    await Request().patch(
      Api.formatUrl(
          Api.bangumiAPIDomain + Api.bangumiMyCollectionEpisodes, [subjectId]),
      data: {
        'episode_id': [episodeId],
        'type': 2,
      },
      options: _authOptions(),
      extra: {'customError': 'Bangumi 章节进度同步失败'},
      shouldRethrow: true,
    );
  }

  static Future<int?> getEpisodeCollectionType(int episodeId) async {
    try {
      final res = await Request().get(
        Api.formatUrl(
            Api.bangumiAPIDomain + Api.bangumiMyEpisodeCollection, [episodeId]),
        options: _authOptions(),
        extra: {'customError': ''},
        shouldRethrow: true,
      );
      final collection = BangumiEpisodeCollection.fromJson(
        Map<String, dynamic>.from(res.data),
      );
      return collection.type;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return 0;
      }
      rethrow;
    }
  }

  // why the api havn't been replaced by getCalendarBySearch?
  // Because getCalendarBySearch is not stable, it will miss some bangumi items.
  static Future<List<List<BangumiItem>>> getCalendar() async {
    List<List<BangumiItem>> bangumiCalendar = [];
    try {
      var res = await Request().get(
        Api.bangumiAPINextDomain + Api.bangumiCalendar,
      );
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
          .e('Resolve calendar failed', error: e);
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
      final url = Api.formatUrl(
          Api.bangumiAPIDomain + Api.bangumiRankSearch, [limit, offset]);
      final res = await Request().post(
        url,
        data: params,
      );
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          bangumiList.add(BangumiItem.fromJson(jsonItem));
        }
      }
    } catch (e) {
      KazumiLogger()
          .e('Resolve bangumi list failed', error: e);
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
      KazumiLogger().e('Network: fetch bangumi item to calendar failed', error: e);
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
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiRankSearch, [100, 0]),
        data: params,
      );
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          bangumiList.add(BangumiItem.fromJson(jsonItem));
        }
      }
    } catch (e) {
      KazumiLogger()
          .e('Network: resolve bangumi list failed', error: e);
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
      final res = await Request().get(
        Api.bangumiAPINextDomain + Api.bangumiTrendsNext,
        data: params,
      );
      final jsonData = res.data;
      final jsonList = jsonData['data'];
      for (dynamic jsonItem in jsonList) {
        if (jsonItem is Map<String, dynamic>) {
          bangumiList.add(BangumiItem.fromJson(jsonItem['subject']));
        }
      }
    } catch (e) {
      KazumiLogger().e('Network: resolve bangumi trends list failed', error: e);
    }
    return bangumiList;
  }

  static Future<List<BangumiItem>> bangumiSearch(String keyword,
      {List<String> tags = const [],
      int offset = 0,
      String sort = 'heat'}) async {
    List<BangumiItem> bangumiList = [];

    var params = <String, dynamic>{
      'keyword': keyword,
      'sort': sort,
      "filter": {
        "type": [2],
        "tag": tags,
        "rank": (sort == 'rank') ? [">0", "<=99999"] : [">=0", "<=99999"],
        "nsfw": false
      },
    };

    try {
      final res = await Request().post(
        Api.formatUrl(
            Api.bangumiAPIDomain + Api.bangumiRankSearch, [20, offset]),
        data: params,
      );
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
            KazumiLogger().e('Network: resolve search results failed', error: e);
          }
        }
      }
    } catch (e) {
      KazumiLogger().e('Network: unknown search problem', error: e);
    }
    return bangumiList;
  }

  static Future<BangumiItem?> getBangumiInfoByID(int id) async {
    try {
      final res = await Request().get(
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiInfoByID, [id]),
      );
      return BangumiItem.fromJson(res.data);
    } catch (e) {
      KazumiLogger().e('Network: resolve bangumi item failed', error: e);
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
      final res = await Request().get(
        Api.bangumiAPIDomain + Api.bangumiEpisodeByID,
        data: params,
      );
      final jsonData = res.data['data'][0];
      episodeInfo = EpisodeInfo.fromJson(jsonData);
    } catch (e) {
      KazumiLogger().e('Network: resolve bangumi episode failed', error: e);
    }
    return episodeInfo;
  }

  static Future<CommentResponse> getBangumiCommentsByID(int id,
      {int offset = 0}) async {
    final res = await Request().get(
      Api.formatUrl(Api.bangumiAPINextDomain + Api.bangumiCommentsByIDNext,
          [id, 20, offset]),
      extra: {'customError': ''},
      shouldRethrow: true,
    );
    return CommentResponse.fromJson(res.data);
  }

  static Future<EpisodeCommentResponse> getBangumiCommentsByEpisodeID(
      int id) async {
    final res = await Request().get(
      Api.formatUrl(
          Api.bangumiAPINextDomain + Api.bangumiEpisodeCommentsByIDNext,
          [id]),
      extra: {'customError': ''},
      shouldRethrow: true,
    );
    return EpisodeCommentResponse.fromJson(res.data);
  }

  static Future<CharacterCommentResponse> getCharacterCommentsByCharacterID(
      int id) async {
    final res = await Request().get(
      Api.formatUrl(
          Api.bangumiAPINextDomain + Api.bangumiCharacterCommentsByIDNext,
          [id]),
      extra: {'customError': ''},
      shouldRethrow: true,
    );
    return CharacterCommentResponse.fromJson(res.data);
  }

  static Future<StaffResponse> getBangumiStaffByID(int id) async {
    final res = await Request().get(
      Api.formatUrl(
          Api.bangumiAPINextDomain + Api.bangumiStaffByIDNext, [id]),
      extra: {'customError': ''},
      shouldRethrow: true,
    );
    return StaffResponse.fromJson(res.data);
  }

  static Future<CharactersResponse> getCharatersByBangumiID(int id) async {
    final res = await Request().get(
      Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiCharacterByID, [id]),
      extra: {'customError': ''},
      shouldRethrow: true,
    );
    return CharactersResponse.fromJson(res.data);
  }

  static Future<CharacterFullItem> getCharacterByCharacterID(int id) async {
    CharacterFullItem characterFullItem = CharacterFullItem.fromTemplate();
    try {
      final res = await Request().get(
        Api.formatUrl(
            Api.bangumiAPINextDomain +
                Api.bangumiCharacterInfoByCharacterIDNext,
            [id]),
      );
      final jsonData = res.data;
      characterFullItem = CharacterFullItem.fromJson(jsonData);
    } catch (e) {
      KazumiLogger().e('Network: resolve character info failed', error: e);
    }
    return characterFullItem;
  }
}
