import 'package:dio/dio.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/request/api.dart';
import 'package:flutter/material.dart' as material;
import 'package:kazumi/modules/danmaku/danmaku_module.dart';

class DanmakuRequest {

  //获取弹弹Play集合，需要进一步处理
  static getBangumiID(String title) async {
    var httpHeaders = {
      'user-agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
      'referer': '',
    };
    Map<String, String> keywordMap = {
      'keyword': title,
    };

    final res = await Request().get(Api.dandanSearch,
        data: keywordMap, options: Options(headers: httpHeaders));
    Map<String, dynamic> jsonData = res.data;
    List<dynamic> animes = jsonData['animes'];

    // 保留此判断以防止错误匹配
    int minAnimeId = 100000;
    for (var anime in animes) {
      int animeId = anime['animeId'];
      if (animeId < minAnimeId && animeId >= 2) {
        minAnimeId = animeId;
      }
    }
    // 这里猜测了弹弹Play的分集命名规则，例如上面的番剧ID为1758，第一集弹幕库ID大概率为17580001，但是此命名规则并没有体现在官方API文档里，保险的做法是请求 Api.dandanInfo
    return minAnimeId;
  }

  static getDanDanmaku(int bangumiID, int episode) async {
    List<Danmaku> danmakus = [];
    if (bangumiID == 100000) {
      return danmakus;
    }
    var httpHeaders = {
      'user-agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
      'referer': '',
    };
    Map<String, String> withRelated = {
      'withRelated': 'true',
    };
    material.debugPrint(
        "弹幕请求最终URL ${Api.dandanAPI + "$bangumiID" + episode.toString().padLeft(4, '0')}");
    final res = await Request().get(
        (Api.dandanAPI + "$bangumiID" + episode.toString().padLeft(4, '0')),
        data: withRelated,
        options: Options(headers: httpHeaders));
    
    Map<String, dynamic> jsonData = res.data;
    List<dynamic> comments = jsonData['comments'];

    for (var comment in comments) {
      Danmaku danmaku = Danmaku.fromJson(comment);
      danmakus.add(danmaku);
    }
    return danmakus;
  }
}
