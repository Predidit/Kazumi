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
import 'package:kazumi/modules/collect/collect_change_module.dart';
import 'package:kazumi/modules/collect/collect_module_bangumi.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:flutter_modular/flutter_modular.dart';

class BangumiHTTP {
  static final _collectCrudRepository = Modular.get<ICollectCrudRepository>(); // 收藏CRUD数据访问接口
  static final _collectController = Modular.get<CollectController>(); // 收藏控制器

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
      rethrow;
    } catch (e) {
      KazumiLogger().e('Network: get username failed', error: e);
    }
    return null;
  }

  static Future<List<CollectedBangumiAndUpdate>> getBangumiCollectibles() async { 
    final List<CollectedBangumiAndUpdate> bangumiCollection = [];
    final username = await getUsername();
    int failedItemCount = 0;
    if (username is !String) {
      KazumiLogger().w('get username failed');
      return [];
    }

    // 获取所有收藏
    try {
      // 循环获取所有收藏
      int offset=0;
      int? total;
      const int limit = 100;
      const Duration requestInterval = Duration(milliseconds: 250);

      while (true) {
        failedItemCount++;
        dynamic res;
        /// 获取至多100个收藏
        try {
          res = await Request().get(
            Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiGetCollenction, [username, limit, offset]),
          );
        } catch (e) {
          KazumiLogger().w('BangumiHTTP: from Bangumi get collected failed', error: e);
          continue;
        }
        dynamic jsonData = res.data;
        dynamic jsonList = jsonData['data'];
        total ??= jsonData['total'];

        /// 从获取的数据中解析出收藏的番剧
        for (dynamic jsonItem in jsonList) {
          if (jsonItem is Map<String, dynamic>) {
            try {
              final id = jsonItem['subject']['id'];
              await getBangumiInfoByID(id).then((value) {
                if (value != null) {
                  CollectType.fromBangumi(jsonItem['type']);
                  final type = CollectType.fromBangumi(jsonItem['type']).value;
                  final updatedAt = DateTime.parse(jsonItem['updated_at']);
                  bangumiCollection.add(CollectedBangumiAndUpdate(value, type, updatedAt.millisecondsSinceEpoch ~/ 1000));
                }
              });
              await Future.delayed(requestInterval);
            } catch (e) {
              KazumiLogger().e('BangumiHTTP: add collectedBangumi failed', error: e);
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

        offset++;
        await Future.delayed(requestInterval);
      }
    } catch (e) {
      KazumiLogger().e('Network: get bangumi collection failed', error: e);
    }
    KazumiLogger().d('get Bangumi collection count: ${bangumiCollection.length}');
    KazumiLogger().d('get item failed count: $failedItemCount');
    return bangumiCollection;
  }

  static Future<void> updateBangumiById(int id, Map<String, dynamic> params) async {
    const Duration requestInterval = Duration(milliseconds: 250);
    try {
      await Request().post(
        Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiSetCollection, [id]),
        data: params,
        shouldRethrow: true,
      );
      KazumiLogger().d('Update to Bangumi: ${_collectCrudRepository.getCollectible(id).toString()}');
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
          str = 'Unknown Error 未知错误';
      }
      KazumiLogger().e('BangumiApi: $str', error: e);
    } catch (e) {
      KazumiLogger().e('Network: update bangumi collection failed', error: e);
    }
    await Future.delayed(requestInterval);
  }

  /// 更新用户番剧收藏，会将本地收藏type转换成bangumi收藏type
  /// 
  /// [id] 番剧id
  /// [localType] 本地的收藏类型
  static Future<void> updateBangumiByType(int id, int localType) async { 
    final type = CollectType.fromValue(localType).toBangumi();
    return await updateBangumiById(id, {'type': type});
  }

  static Future<void> syncCollectiblesBangumi() async {
    final userToTimeRaw = GStorage.setting.get(SettingBoxKey.bangumiLastSyncTimestamp, defaultValue: <String, int>{});
    final Map<String, int> userToTime = Map<String, int>.from(userToTimeRaw as Map); // 用户最后同步时间
    final remoteCollectibles = await getBangumiCollectibles(); // 远程收藏
    final localCollectibles = _collectCrudRepository.getAllCollectibles(); // 本地收藏
    // final localCollectibles = _collectCrudRepository.getAllCollectibles().where((item) => // TEST
    //   item.type == 1
    // ).toList();
    final localChange = GStorage.collectChangesBgm.values.toList(); // 本地收藏变更
    final localCount = localCollectibles.length;

    final remoteMap = <int, CollectedBangumiAndUpdate>{};
    for (final collectedBangumi in remoteCollectibles) {
      remoteMap[collectedBangumi.bangumiItem.id] = collectedBangumi;
    }

    final localMap = <int, CollectedBangumi>{};
    for (final collectedBangumi in localCollectibles) {
      localMap[collectedBangumi.bangumiItem.id] = collectedBangumi;
    }

    final keys = <int>{...remoteMap.keys, ...localMap.keys};

    final username = await getUsername();
    if (username is !String || username.isEmpty) {
      KazumiLogger().e('sync bangumi failed');
      return;
    }

    final List<CollectedBangumiChange> ignoreChanged = [];
    // WARN 第一次上传失败怎么办 不管了，先让它work先
    if (!userToTime.containsKey(username)) {
      // 第一次同步
      for (final id in keys) {
        if (remoteMap.containsKey(id) && !localMap.containsKey(id)) {
          // 远程有，本地没有 添加
          final item = remoteMap[id];
          await _collectController.addCollectBangumi(item!.bangumiItem, bangumiType: item.type);
        } else if (!remoteMap.containsKey(id) && localMap.containsKey(id)) {
          // 远程没有，本地有 上传
          final item = localMap[id];
          await updateBangumiByType(id, item!.type);
        } else if (remoteMap.containsKey(id) && localMap.containsKey(id)) {
          // 远程有，本地有 更新
          final remote = remoteMap[id];
          final local = localMap[id];
          if (remote?.type != local?.type) {
            final locatUpdate = local!.time.millisecondsSinceEpoch ~/ 1000;
            if (locatUpdate > remote!.updatedAt) {
              // 本地更新时间比远程更新时间晚
              await updateBangumiByType(id, local.type);
            } else {
              // 远程更新时间比本地更新时间晚
              await _collectController.updateLocalCollect(remote.bangumiItem);
            }
          }
        }
        // await GStorage.collectChangesBgm.clear();
      }
    } else {
      final localChangeMap = <int, CollectedBangumiChange>{};
      for (final item in localChange) {
        localChangeMap[item.bangumiID] = item;
      }

      for (final id in keys) {
        if (localMap.containsKey(id) && !remoteMap.containsKey(id)) {
          // 1. 本地有bgm没有 1. 本地新增 2. bgm上删除了
          if (localChangeMap.containsKey(id)) {
            // 本地有修改记录 参照本地更新bgm
            int type = CollectType.fromValue(localMap[id]!.type).toBangumi();
            await updateBangumiByType(id, type);
          } else {
            // 本地没有修改记录 本地删除？
            // await collectController.deleteCollect(localMap[id]!.bangumiItem);
            // TODO: 感觉直接删除不太好
          }
        } else if (remoteMap.containsKey(id) && !localMap.containsKey(id)) {
          // 2. bgm有本地没有 1. 本地上删除了，跳过 2. bgm新增
          if (!localChangeMap.containsKey(id)) {
            // 本地没有修改记录 本地新增
            await _collectController.addCollect(remoteMap[id]!.bangumiItem);
          } else {
            // 本地删除了
            ignoreChanged.add(localChangeMap[id]!);
            // TODO: 没api处理不了
          }
        } else if (remoteMap.containsKey(id) && localMap.containsKey(id)) {
          // 3. 双方都有 1. 都没更新 2. 本地有更新 3. bgm有更新 4. 都更新了
          final remote = remoteMap[id];
          final local = localMap[id];

          if (remote!.type != local!.type) {
            // 有更新 类型不一致
            final change = localChangeMap[id];
            if (change != null) {
              // 本地有更新 对比更新时间再更新
              if (change.timestamp > remote.updatedAt) {
                // 本地更新时间更晚
                await updateBangumiByType(id, change.type);
              } else {
                await _collectController.addCollectBangumi(remote.bangumiItem, bangumiType: remote.type);
              }
            } else {
              // 本地无更新
              await _collectController.addCollectBangumi(remote.bangumiItem, bangumiType: remote.type);
            }
          }
        }
      }
    }
    await GStorage.collectChangesBgm.clear(); // WARN: 有点太简单粗暴了
    await GStorage.collectChangesBgm.addAll(ignoreChanged);
    
    userToTime[username] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await GStorage.setting.put(
      SettingBoxKey.bangumiLastSyncTimestamp, userToTime);
    
    KazumiLogger().i(
      'sync bangumi done. Add count ${_collectCrudRepository.getAllCollectibles().length - localCount}. All count: ${keys.length}, Ignore count: ${ignoreChanged.length}.'
    );
  }
}
