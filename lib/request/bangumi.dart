import 'package:dio/dio.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/comments/comment_response.dart';
import 'package:kazumi/modules/characters/characters_response.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/character/character_full_item.dart';
import 'package:kazumi/modules/staff/staff_response.dart';
import 'package:kazumi/modules/collect/collect_module_bangumi.dart';
import 'package:kazumi/modules/collect/collect_type.dart';

class BangumiHTTP {
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

  static Future<String?> getUsername() async {
    try {
      final res = await Request().get(
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiUsernameByToken, []),
        shouldRethrow: true,
      );
      if (res.data['id'] != null) {
        return res.data['username'] ?? '未知用户';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        KazumiLogger().e('unauthorized 未经授权的');
      }
      throw StateError('token未经授权，请更新token');
    } catch (e) {
      KazumiLogger().e('Network: get username failed', error: e);
    }
    return null;
  }

  static Future<List<BangumiRemoteCollection>> getBangumiCollectibles() async { 
    final List<BangumiRemoteCollection> bangumiCollection = [];
    final username = await getUsername();
    int failedItemCount = 0;
    if (username is !String) {
      KazumiLogger().w('get username failed');
      return [];
    }

    // 获取所有收藏
    int? total;
    try {
      // 循环获取所有收藏
      int offset=0;   // 偏移量
      const int limit = 50;   // 最大50
      const Duration requestInterval = Duration(milliseconds: 250);

      while (true) {
        failedItemCount++;
        // dynamic res;
        Response<dynamic> res;
        /// 一次while获取limit个收藏
        try {
          res = await Request().get(
            Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiGetCollenction, [username, limit, offset]),
            shouldRethrow: true,
          );
        } catch (e) {
          KazumiLogger().e('BangumiHTTP: from Bangumi get collected failed', error: e);
          break;
          // continue;
        }
        Map jsonData = res.data;
        List<dynamic> jsonList = jsonData['data'];    // FUTURE: 改进类型注释
        total ??= jsonData['total'];

        // 从获取的数据中解析出收藏的番剧
        for (dynamic jsonItem in jsonList) {
          if (jsonItem is Map<String, dynamic>) {
            try {
              bangumiCollection.add(
                BangumiRemoteCollection.fromJson(jsonItem)
              );
            } catch (e) {
              KazumiLogger().e('BangumiHTTP: analysis collectedBangumi failed: ${e.toString()}', error: e);
              await Future.delayed(requestInterval);
              continue;
            }
          }
        }

        /// 没有出错，最终处理
        failedItemCount--;
        if (total != null && (bangumiCollection.length + failedItemCount >= total || jsonList.isEmpty)) {
          break;
        }
        final t = bangumiCollection.length;
        KazumiLogger().d('$t ; $failedItemCount ; $total');

        offset += limit;
        await Future.delayed(requestInterval);
      }
    } catch (e) {
      KazumiLogger().e('Network: get bangumi collection failed', error: e);
    }
    KazumiLogger().d('get Bangumi collection count: ${bangumiCollection.length}, total: $total');
    KazumiLogger().d('get item failed count: $failedItemCount');
    return bangumiCollection;
  }

  /// 更新bgm番剧收藏，可自定义上传data
  static Future<void> updateBangumiById(int id, Map<String, dynamic> data) async {
    const Duration requestInterval = Duration(milliseconds: 250);
    try {
      await Request().post(
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiSetCollection, [id]),
        data: data,
        shouldRethrow: true,
      );
      KazumiLogger().d('Update to Bangumi: Id: $id');
    } on DioException catch (e) {
      String str;
      switch (e.response?.statusCode) {
        case 400:
          str = 'Validation Error 验证错误';
          break;
        case 401:
          str = 'Unauthorized 未经授权';
          break;
        case 404:
          str = '用户不存在';
          break;
        default:
          str = 'Error $e';
      }
      KazumiLogger().e('BangumiApi: $str', error: e);
    } catch (e) {
      KazumiLogger().e('Network: update bangumi collection failed', error: e);
    }
    await Future.delayed(requestInterval);
  }

  /// 更新bgm番剧收藏，会将本地收藏type转换成bangumi收藏type
  /// 
  /// [id] 番剧id
  /// [localType] 本地的收藏类型
  static Future<void> updateBangumiByType(int id, int localType) async { 
    final type = CollectType.fromValue(localType).toBangumi();
    return await updateBangumiById(id, {'type': type});
  }
}
