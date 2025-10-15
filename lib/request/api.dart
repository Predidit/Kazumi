class Api {
  /// 当前版本
  static const String version = '1.8.4';
  /// 规则API级别
  static const int apiLevel = 4;
  /// 项目主页
  static const String projectUrl = "https://kazumi.app/";
  /// Github 项目主页
  static const String sourceUrl = "https://github.com/Predidit/Kazumi";
  /// 图标作者
  static const String iconUrl = "https://www.pixiv.net/users/66219277";
  /// 规则仓库
  static const String pluginShop = 'https://raw.githubusercontent.com/Predidit/KazumiRules/main/';
  /// 在线升级
  static const String latestApp =
      'https://api.github.com/repos/Predidit/Kazumi/releases/latest'; 
  /// Github镜像
  static const String gitMirror = 'https://ghfast.top/';
  /// 弹弹官网
  static const String dandanIndex = 'https://www.dandanplay.com/';
  /// Bangumi 官网
  static const String bangumiIndex = 'https://bangumi.tv/';

  /// bangumi API Domain
  static const String bangumiAPIDomain = 'https://api.bgm.tv';
  /// 番剧信息
  static const String bangumiInfoByID = '/v0/subjects/{0}';
  /// 条目搜索
  static const String bangumiRankSearch = '/v0/search/subjects?limit={0}&offset={1}';
  /// 从条目ID获取角色信息
  static const String bangumiCharacterByID = '/v0/subjects/{0}/characters';
  /// 从条目ID获取剧集ID
  static const String bangumiEpisodeByID = '/v0/episodes';

  /// Bangumi Next API Domain
  static const String bangumiAPINextDomain = 'https://next.bgm.tv';
  /// 每日放送
  static const String bangumiCalendar = '/p1/calendar';
  /// 番剧趋势
  static const String bangumiTrendsNext = '/p1/trending/subjects';
  /// 番剧信息
  static const String bangumiInfoByIDNext = '/p1/subjects/{0}';
  /// 番剧评论
  static const String bangumiCommentsByIDNext = '/p1/subjects/{0}/comments?limit={1}&offset={2}';
  /// 番剧剧集评论
  static const String bangumiEpisodeCommentsByIDNext = '/p1/episodes/{0}/comments';
  /// 番剧角色信息
  static const String bangumiCharacterInfoByCharacterIDNext = '/p1/characters/{0}';
  /// 番剧角色评论
  static const String bangumiCharacterCommentsByIDNext = '/p1/characters/{0}/comments';
  /// 番剧工作人员信息
  static const String bangumiStaffByIDNext = '/p1/subjects/{0}/staffs/persons';

  /// DanDanPlay API Domain
  static const String dandanAPIDomain = 'https://api.dandanplay.net';
  /// 获取弹幕
  static const String dandanAPIComment = "/api/v2/comment/";
  /// 检索弹弹番剧元数据
  static const String dandanAPISearch = "/api/v2/search/anime";
  /// 获取弹弹番剧元数据
  static const String dandanAPIInfo = "/api/v2/bangumi/";
  /// 获取弹弹番剧元数据（通过BGM番剧ID）
  static const String dandanAPIInfoByBgmBangumiId = "/api/v2/bangumi/bgmtv/{0}";

  static String formatUrl(String url, List<dynamic> params) {
    for (int i = 0; i < params.length; i++) {
      url = url.replaceAll('{$i}', params[i].toString());
    }
    return url;
  }
}