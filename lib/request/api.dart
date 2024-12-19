class Api {
  // 当前版本
  static const String version = '1.4.7';
  // 规则API级别
  static const int apiLevel = 3;
  // 项目主页
  static const String sourceUrl = "https://github.com/Predidit/Kazumi";
  // 图标作者
  static const String iconUrl = "https://www.pixiv.net/users/66219277";
  // 规则仓库
  static const String pluginShop = 'https://raw.githubusercontent.com/Predidit/KazumiRules/main/';
  // 在线升级
  static const String latestApp =
      'https://api.github.com/repos/Predidit/Kazumi/releases/latest'; 
  // Github镜像
  static const String gitMirror = 'https://mirror.ghproxy.com/';
  // 每日放送
  static const String bangumiCalendar = 'https://api.bgm.tv/calendar';
  // Bangumi 主页
  static const String bangumiIndex = 'https://bangumi.tv/';
  // 番剧检索 (弃用)
  static const String bangumiSearch = 'https://api.bgm.tv/search/subject/';
  // 条目搜索
  static const String bangumiRankSearch = 'https://api.bgm.tv/v0/search/subjects?limit={0}&offset={1}';
  // 从条目ID获取详细信息
  static const String bangumiInfoByID = 'https://api.bgm.tv/v0/subjects/';
  // 从条目ID获取剧集ID
  static const String bangumiEpisodeByID = 'https://api.bgm.tv/v0/episodes?subject_id=';
  // Next条目API
  static const String bangumiInfoByIDNext = 'https://next.bgm.tv/p1/subjects/';
  // 弹弹Play
  static const String dandanIndex = 'https://www.dandanplay.com/';
  static const String dandanAPI = "https://api.dandanplay.net/api/v2/comment/";
  static const String dandanSearch = "https://api.dandanplay.net/api/v2/search/anime";
  static const String dandanInfo = "https://api.dandanplay.net/api/v2/bangumi/";

  static String formatUrl(String url, List<dynamic> params) {
    for (int i = 0; i < params.length; i++) {
      url = url.replaceAll('{$i}', params[i].toString());
    }
    return url;
  }
}