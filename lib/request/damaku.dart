import 'package:dio/dio.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';

class DanmakuRequest {
  //获取弹弹Play集合，需要进一步处理
  static Future<int> getBangumiID(String title) async {
    DanmakuSearchResponse danmakuSearchResponse =
        await getDanmakuSearchResponse(title);

    // 保留此判断以防止错误匹配
    int minAnimeId = 100000;
    for (var anime in danmakuSearchResponse.animes) {
      int animeId = anime.animeId;
      if (animeId < minAnimeId && animeId >= 2) {
        minAnimeId = animeId;
      }
    }
    return minAnimeId;
  }

  //从BangumiID获取分集ID
  static Future<DanmakuEpisodeResponse> getDanDanEpisodesByBangumiID(
      int bangumiID) async {
    var httpHeaders = {
      'user-agent': Utils.getRandomUA(),
      'referer': '',
    };
    final res = await Request().get(Api.dandanInfo + bangumiID.toString(),
        options: Options(headers: httpHeaders),
        extra: {'customError': '弹幕检索错误: 获取弹幕分集ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuEpisodeResponse danmakuEpisodeResponse =
        DanmakuEpisodeResponse.fromJson(jsonData);
    return danmakuEpisodeResponse;
  }

  static Future<DanmakuSearchResponse> getDanmakuSearchResponse(
      String title) async {
    var httpHeaders = {
      'user-agent': Utils.getRandomUA(),
      'referer': '',
    };
    Map<String, String> keywordMap = {
      'keyword': title,
    };

    final res = await Request().get(Api.dandanSearch,
        data: keywordMap,
        options: Options(headers: httpHeaders),
        extra: {'customError': '弹幕检索错误: 获取弹幕番剧ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuSearchResponse danmakuSearchResponse =
        DanmakuSearchResponse.fromJson(jsonData);
    return danmakuSearchResponse;
  }

  static Future<List<Danmaku>> getDanDanmaku(int bangumiID, int episode) async {
    List<Danmaku> danmakus = [];
    if (bangumiID == 100000) {
      return danmakus;
    }
    var httpHeaders = {
      'user-agent': Utils.getRandomUA(),
      'referer': '',
    };
    Map<String, String> withRelated = {
      'withRelated': 'true',
    };
    // 这里猜测了弹弹Play的分集命名规则，例如上面的番剧ID为1758，第一集弹幕库ID大概率为17580001，但是此命名规则并没有体现在官方API文档里，保险的做法是请求 Api.dandanInfo
    KazumiLogger().log(Level.info,
        "弹幕请求最终URL ${"${Api.dandanAPI}$bangumiID${episode.toString().padLeft(4, '0')}"}");
    final res = await Request().get(
        ("${Api.dandanAPI}$bangumiID${episode.toString().padLeft(4, '0')}"),
        data: withRelated,
        options: Options(headers: httpHeaders),
        extra: {'customError': '弹幕检索错误: 获取弹幕失败'});

    Map<String, dynamic> jsonData = res.data;
    List<dynamic> comments = jsonData['comments'];

    for (var comment in comments) {
      Danmaku danmaku = Danmaku.fromJson(comment);
      danmakus.add(danmaku);
    }
    return danmakus;
  }

  static Future<List<Danmaku>> getDanDanmakuByEpisodeID(int episodeID) async {
    List<Danmaku> danmakus = [];
    var httpHeaders = {
      'user-agent': Utils.getRandomUA(),
      'referer': '',
    };
    Map<String, String> withRelated = {
      'withRelated': 'true',
    };
    final res = await Request().get("${Api.dandanAPI}$episodeID",
        data: withRelated,
        options: Options(headers: httpHeaders),
        extra: {'customError': '弹幕检索错误: 获取弹幕失败'});
    Map<String, dynamic> jsonData = res.data;
    List<dynamic> comments = jsonData['comments'];

    for (var comment in comments) {
      Danmaku danmaku = Danmaku.fromJson(comment);
      danmakus.add(danmaku);
    }
    return danmakus;
  }
}
