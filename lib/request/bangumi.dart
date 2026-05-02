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
import 'package:kazumi/modules/bangumi/bangumi_collection.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/collect/collect_type_mapper.dart';
import 'package:kazumi/modules/bangumi/bangumi_collection_type.dart';

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
        extra: {'customError': '', 'requiresBangumiAuth': true},
        shouldRethrow: true,
      );
      if (res.data['id'] != null) {
        return res.data['username'] ?? 'Unknown';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        KazumiLogger().e('Bangumi token unauthorized, please check your token');
        throw StateError('Bangumi token 未授权，请检查您的 token');
      }
      rethrow;
    } catch (e) {
      KazumiLogger().e('Network: get username failed', error: e);
    }
    return null;
  }

  /// Get the Bangumi collection of the current user
  static Future<List<BangumiCollection>> getBangumiCollectibles({
    List<BangumiCollectionType> includeBangumiTypes = const [
      BangumiCollectionType.planToWatch,
      BangumiCollectionType.watched,
      BangumiCollectionType.watching,
      BangumiCollectionType.onHold,
      BangumiCollectionType.abandoned,
    ],
    String? username,
    required int limit,
    void Function(String message, int current, int total)? onProgress,
  }) async {
    final List<BangumiCollection> bangumiCollection = [];
    final resolvedUsername =
        username != null && username.isNotEmpty ? username : await getUsername();
    int failedItemCount = 0;
    int progressCurrent = 0;
    int progressTotal = 0;
    if (resolvedUsername == null) {
      KazumiLogger().w('get username failed');
      return [];
    }

    try {
      const Duration requestInterval = Duration(milliseconds: 250);

      for (final collectionType in includeBangumiTypes) {
        if (collectionType == BangumiCollectionType.unknown) {
          continue;
        }
        int offset = 0;
        int? total;
        bool totalInitialized = false;
        while (true) {
          Response<dynamic> res;
          try {
            final url = Api.formatUrl(
                Api.bangumiAPIDomain + Api.bangumiGetCollection,
                [resolvedUsername, limit, offset, collectionType.value]);
            res = await Request().get(
              url,
              extra: {'customError': '', 'requiresBangumiAuth': true},
              shouldRethrow: true,
            );
          } catch (e) {
            KazumiLogger().e(
              'BangumiHTTP: fetch collection failed. type=${collectionType.value}, offset=$offset',
              error: e,
            );
            rethrow;
          }

          final Map jsonData = res.data;
          final List<dynamic> jsonList = jsonData['data'];
          total ??= jsonData['total'];
          if (!totalInitialized && total != null) {
            progressTotal += total;
            totalInitialized = true;
          }

          for (dynamic jsonItem in jsonList) {
            if (jsonItem is Map<String, dynamic>) {
              try {
                bangumiCollection.add(BangumiCollection.fromJson(jsonItem));
                progressCurrent++;
                onProgress?.call(
                  '正在拉取${collectionType.label}收藏',
                  progressCurrent,
                  progressTotal,
                );
              } catch (e) {
                KazumiLogger().e(
                  'BangumiHTTP: parse collection item failed: ${e.toString()}',
                  error: e,
                );
                failedItemCount++;
              }
            }
          }

          if (jsonList.isEmpty || (total != null && offset + limit >= total)) {
            break;
          }

          offset += limit;
          await Future.delayed(requestInterval);
        }
      }
    } catch (e) {
      KazumiLogger().e('Network: get bangumi collection failed', error: e);
      rethrow;
    }
    KazumiLogger()
        .d('get Bangumi collection count: ${bangumiCollection.length}');
    KazumiLogger().d('get item failed count: $failedItemCount');
    return bangumiCollection;
  }

  /// Update the Bangumi collection by ID
  static Future<bool> updateBangumiById(
      int id, Map<String, dynamic> data) async {
    const Duration requestInterval = Duration(milliseconds: 250);
    try {
      await Request().post(
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiSetCollection, [id]),
        data: data,
        extra: {'customError': '', 'requiresBangumiAuth': true},
        shouldRethrow: true,
      );
      KazumiLogger().d('Update to Bangumi: Id: $id');
      return true;
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
          str = 'User not found 用户不存在';
          break;
        default:
          str = 'Error $e';
      }
      KazumiLogger().e('BangumiApi: $str', error: e);
      return false;
    } catch (e) {
      KazumiLogger().e('Network: update bangumi collection failed', error: e);
      rethrow;
    } finally {
      await Future.delayed(requestInterval);
    }
  }

  /// Update the Bangumi collection by Type
  static Future<bool> updateBangumiByType(int id, int localType) async {
    final type = CollectType.fromValue(localType).toBangumiCollectionType();
    if (type == null) {
      return false;
    }
    return await updateBangumiById(id, {'type': type.value});
  }
}
