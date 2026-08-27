import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/clients/danmaku_client.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';

class DanmakuApi {
  static final DanmakuClient _client = DanmakuClient.instance;

  // 从BgmBangumiID获取DanDanBangumiID
  static Future<int> getDanDanBangumiIDByBgmBangumiID(int bgmBangumiID) async {
    var path = ApiEndpoints.formatUrl(
        ApiEndpoints.dandanAPIInfoByBgmBangumiId, [bgmBangumiID]);
    var endPoint = ApiEndpoints.dandanAPIDomain + path;
    final jsonData = await _client.get(endPoint);
    DanmakuEpisodeResponse danmakuEpisodeResponse =
        DanmakuEpisodeResponse.fromJson(jsonData);
    return danmakuEpisodeResponse.bangumiId;
  }

  // 从DanDanBangumiID获取分集ID
  static Future<DanmakuEpisodeResponse> getDanDanEpisodesByDanDanBangumiID(
      int bangumiID) async {
    var path = ApiEndpoints.dandanAPIInfo + bangumiID.toString();
    var endPoint = ApiEndpoints.dandanAPIDomain + path;
    final jsonData = await _client.get(endPoint);
    DanmakuEpisodeResponse danmakuEpisodeResponse =
        DanmakuEpisodeResponse.fromJson(jsonData);
    return danmakuEpisodeResponse;
  }

  /// Manual search entry point.
  ///
  /// `/api/v2/search/anime` caps results at 25 with no paging parameter, which
  /// drops the main series of large franchises (Detective Conan has 48 entries).
  /// This endpoint is uncapped, but only under `v2`: the legacy engine collapses
  /// a keyword to a single anime. Its inline episode lists are truncated, so
  /// episodes still come from [getDanDanEpisodesByDanDanBangumiID].
  static Future<DanmakuSearchResponse> searchAnimes(String title) async {
    var path = ApiEndpoints.dandanAPISearchEpisodes;
    var endPoint = ApiEndpoints.dandanAPIDomain + path;
    Map<String, String> keywordMap = {
      'anime': title,
      'v2': 'true',
    };

    final jsonData = await _client.get(endPoint, queryParameters: keywordMap);
    return DanmakuSearchResponse.fromJson(jsonData);
  }

  static Future<List<DanmakuEntry>> getDanDanmaku(
      int bangumiID, int episode) async {
    List<DanmakuEntry> danmakus = [];
    if (bangumiID == 0) {
      return danmakus;
    }
    // 这里猜测了弹弹Play的分集命名规则，例如上面的番剧ID为1758，第一集弹幕库ID大概率为17580001，但是此命名规则并没有体现在官方API文档里，保险的做法是请求 ApiEndpoints.dandanInfo
    var path = ApiEndpoints.dandanAPIComment +
        bangumiID.toString() +
        episode.toString().padLeft(4, '0');
    var endPoint = ApiEndpoints.dandanAPIDomain + path;
    Map<String, String> withRelated = {
      'withRelated': 'true',
    };
    KazumiLogger().i("Danmaku: final request URL $endPoint");
    final jsonData = await _client.get(endPoint, queryParameters: withRelated);
    List<dynamic> comments = jsonData['comments'];

    for (var comment in comments) {
      DanmakuEntry danmaku = DanmakuEntry.fromJson(comment);
      danmakus.add(danmaku);
    }
    return danmakus;
  }

  static Future<List<DanmakuEntry>> getDanDanmakuByEpisodeID(
      int episodeID) async {
    var path = ApiEndpoints.dandanAPIComment + episodeID.toString();
    var endPoint = ApiEndpoints.dandanAPIDomain + path;
    List<DanmakuEntry> danmakus = [];
    Map<String, String> withRelated = {
      'withRelated': 'true',
    };
    final jsonData = await _client.get(endPoint, queryParameters: withRelated);
    List<dynamic> comments = jsonData['comments'];

    for (var comment in comments) {
      DanmakuEntry danmaku = DanmakuEntry.fromJson(comment);
      danmakus.add(danmaku);
    }
    return danmakus;
  }
}
