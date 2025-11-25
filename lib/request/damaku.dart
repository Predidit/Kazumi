import 'package:kazumi/request/request.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/utils/string_match.dart';

class DanmakuRequest {
  // 从BgmBangumiID获取DanDanBangumiID
  static Future<int> getDanDanBangumiIDByBgmBangumiID(int bgmBangumiID) async {
    var path = Api.formatUrl(Api.dandanAPIInfoByBgmBangumiId, [bgmBangumiID]);
    var endPoint = Api.dandanAPIDomain + path;
    final res = await Request().get(endPoint,
        extra: {'customError': '弹幕检索错误: 获取弹幕分集ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuEpisodeResponse danmakuEpisodeResponse =
        DanmakuEpisodeResponse.fromJson(jsonData);
    return danmakuEpisodeResponse.bangumiId;
  }

  // 从标题获取DanDanBangumiID
  static Future<int> getBangumiIDByTitle(String title) async {
    DanmakuSearchResponse danmakuSearchResponse =
        await getDanmakuSearchResponse(title);

    int bestAnimeId = 0;
    double maxSimilarity = 0;

    for (var anime in danmakuSearchResponse.animes) {
      int animeId = anime.animeId;
      if (animeId >= 100000 || animeId < 2) {
        continue;
      }

      String animeTitle = anime.animeTitle;
      double similarity = calculateSimilarity(animeTitle, title);
      if (similarity == 1) {
        KazumiLogger().i('Danmaku: total match $title');
        return animeId;
      }

      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
        bestAnimeId = animeId;
        KazumiLogger().i('Danmaku: match anime danmaku $title --- $animeTitle similarity: $similarity');
      }
    }

    return bestAnimeId;
  }

  // 从BangumiID获取分集ID
  static Future<DanmakuEpisodeResponse> getDanmakuEpisodesByBangumiID(
      int bangumiID) async {
    var path = Api.formatUrl(Api.dandanAPIInfoByBgmBangumiId, [bangumiID]);
    var endPoint = Api.dandanAPIDomain + path;
    final res = await Request().get(endPoint,
        extra: {'customError': '弹幕检索错误: 获取弹幕分集ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuEpisodeResponse danmakuEpisodeResponse =
        DanmakuEpisodeResponse.fromJson(jsonData);
    return danmakuEpisodeResponse;
  }

  // 从DanDanBangumiID获取分集ID
  static Future<DanmakuEpisodeResponse> getDanDanEpisodesByDanDanBangumiID(
      int bangumiID) async {
    var path = Api.dandanAPIInfo + bangumiID.toString();
    var endPoint = Api.dandanAPIDomain + path;
    final res = await Request().get(endPoint,
        extra: {'customError': '弹幕检索错误: 获取弹幕分集ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuEpisodeResponse danmakuEpisodeResponse =
        DanmakuEpisodeResponse.fromJson(jsonData);
    return danmakuEpisodeResponse;
  }

  // 从标题检索DanDan番剧数据库
  static Future<DanmakuSearchResponse> getDanmakuSearchResponse(
      String title) async {
    var path = Api.dandanAPISearch;
    var endPoint = Api.dandanAPIDomain + path;
    Map<String, String> keywordMap = {
      'keyword': title,
    };

    final res = await Request().get(endPoint,
        data: keywordMap,
        extra: {'customError': '弹幕检索错误: 获取弹幕番剧ID失败'});
    Map<String, dynamic> jsonData = res.data;
    DanmakuSearchResponse danmakuSearchResponse =
        DanmakuSearchResponse.fromJson(jsonData);
    return danmakuSearchResponse;
  }

  static Future<List<Danmaku>> getDanDanmaku(int bangumiID, int episode) async {
    List<Danmaku> danmakus = [];
    if (bangumiID == 0) {
      return danmakus;
    }
    // 这里猜测了弹弹Play的分集命名规则，例如上面的番剧ID为1758，第一集弹幕库ID大概率为17580001，但是此命名规则并没有体现在官方API文档里，保险的做法是请求 Api.dandanInfo
    var path = Api.dandanAPIComment +
        bangumiID.toString() +
        episode.toString().padLeft(4, '0');
    var endPoint = Api.dandanAPIDomain + path;
    Map<String, String> withRelated = {
      'withRelated': 'true',
    };
    KazumiLogger().i("Danmaku: final request URL $endPoint");
    final res = await Request().get(endPoint,
        data: withRelated,
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
    var path = Api.dandanAPIComment + episodeID.toString();
    var endPoint = Api.dandanAPIDomain + path;
    List<Danmaku> danmakus = [];
    Map<String, String> withRelated = {
      'withRelated': 'true',
    };
    final res = await Request().get(endPoint,
        data: withRelated,
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
