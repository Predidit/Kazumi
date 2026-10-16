import 'package:kazumi/modules/danmaku/custom_danmaku_client.dart';
import 'package:kazumi/modules/danmaku/custom_danmaku_server_config.dart';
import 'package:kazumi/modules/danmaku/danmaku_ch_convert.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/request/clients/danmaku_client.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

class DanmakuApi {
  static final DanmakuClient _client = DanmakuClient.instance;

  /// 用户配置了可用的自定义弹幕服务器 (danmu_api / LogVar 兼容) 时为 true。
  /// 弹幕请求默认在此分发, 调用方可通过 useCustomServer 参数显式指定服务端
  /// (自定义未命中回退弹弹play、手动选择分集时按结果来源路由)。
  static bool get _useCustomServer => CustomDanmakuServerConfig.isEnabled;

  /// bgmtv ID -> 弹弹play 番剧 ID 映射。
  /// 该映射只涉及弹弹play, 与自定义服务器开关无关, 始终真实请求;
  /// 是否使用由调用方决定 (自定义未命中时的回退路径依赖它)。
  static Future<int> getDanDanBangumiIDByBgmBangumiID(int bgmBangumiID) async {
    final path = ApiEndpoints.formatUrl(
      ApiEndpoints.dandanAPIInfoByBgmBangumiId,
      [bgmBangumiID],
    );
    final endPoint = ApiEndpoints.dandanAPIDomain + path;
    final jsonData = await _client.get(endPoint);
    return DanmakuEpisodeResponse.fromJson(jsonData).bangumiId;
  }

  static Future<DanmakuEpisodeResponse> getDanDanEpisodesByDanDanBangumiID(
    int bangumiID, {
    bool? useCustomServer,
  }) async {
    if (useCustomServer ?? _useCustomServer) {
      return CustomDanmakuClient.instance.getEpisodes(bangumiID);
    }
    final path = ApiEndpoints.dandanAPIInfo + bangumiID.toString();
    final endPoint = ApiEndpoints.dandanAPIDomain + path;
    final jsonData = await _client.get(endPoint);
    return DanmakuEpisodeResponse.fromJson(jsonData);
  }

  // v2 episode search avoids the anime search's 25-result cap.
  // Fetch full episode lists separately; search results can truncate them.
  static Future<DanmakuSearchResponse> searchAnimes(
    String title, {
    bool? useCustomServer,
  }) async {
    if (useCustomServer ?? _useCustomServer) {
      return CustomDanmakuClient.instance.searchAnimes(title);
    }
    final endPoint =
        ApiEndpoints.dandanAPIDomain + ApiEndpoints.dandanAPISearchEpisodes;
    final jsonData = await _client.get(
      endPoint,
      queryParameters: {'anime': title, 'v2': 'true'},
    );
    return DanmakuSearchResponse.fromJson(jsonData);
  }

  static Future<List<DanmakuEntry>> getDanDanmaku(
    int bangumiID,
    int episode,
  ) async {
    if (bangumiID == 0) {
      return [];
    }
    // Automatic matching relies on an undocumented episode ID convention.
    return _getComments('$bangumiID${episode.toString().padLeft(4, '0')}');
  }

  static Future<List<DanmakuEntry>> getDanDanmakuByEpisodeID(
      int episodeID, {bool? useCustomServer}) async {
    // 手动选择分集时 episodeID 来自服务端返回的分集列表, 是真实 ID。
    if (useCustomServer ?? _useCustomServer) {
      return CustomDanmakuClient.instance.getComments(episodeID);
    }
    return _getComments(episodeID.toString());
  }

  static Future<List<DanmakuEntry>> _getComments(String episodeID) async {
    final endPoint =
        '${ApiEndpoints.dandanAPIDomain}${ApiEndpoints.dandanAPIComment}$episodeID';
    final conversion = DanmakuChConvert.fromValue(
      GStorage.getSetting(SettingsKeys.danmakuChConvert),
    );
    KazumiLogger().i('Danmaku: final request URL $endPoint');
    final jsonData = await _client.get(
      endPoint,
      queryParameters: {
        'withRelated': 'true',
        'chConvert': conversion.value.toString(),
      },
    );
    final List<dynamic> comments = jsonData['comments'];
    return [for (final comment in comments) DanmakuEntry.fromJson(comment)];
  }

  // ===================== 自定义弹幕服务器 (danmu_api / LogVar) =====================

  /// 播放时按番剧标题自动匹配并拉取弹幕。
  ///
  /// danmu_api 不兼容弹弹play 的 bgmtv ID 映射与 animeId*10000+集数 的
  /// commentId 约定, 因此先经 match 接口按 "标题 E集数" 解析真实 episodeId,
  /// 失败时退化为 搜索->取首个番剧->按集序取分集。
  ///
  /// 同时带回服务端实际匹配到的番剧/分集标题 (含平台来源标记, 如
  /// "【动漫】 from bahamut"/"【bahamut】第2集"), 供弹幕来源标签完整
  /// 展示; 拿不到时为 null, 由调用方回退到本地番剧标题。
  static Future<
      ({
        List<DanmakuEntry> danmakus,
        String? animeTitle,
        String? episodeTitle
      })> getCustomDanmakuByBangumiName(
    String bangumiName,
    int episode,
  ) async {
    if (!_useCustomServer) {
      return (danmakus: <DanmakuEntry>[], animeTitle: null, episodeTitle: null);
    }
    final title = bangumiName.trim();
    if (title.isEmpty || episode < 1) {
      return (danmakus: <DanmakuEntry>[], animeTitle: null, episodeTitle: null);
    }
    if (CustomDanmakuServerConfig.autoMatch) {
      final match = await CustomDanmakuClient.instance
          .matchEpisodeId(fileName: _buildMatchFileName(title, episode));
      if (match.episodeId != null) {
        final danmakus =
            await CustomDanmakuClient.instance.getComments(match.episodeId!);
        return (
          danmakus: danmakus,
          animeTitle: match.animeTitle,
          episodeTitle: match.episodeTitle,
        );
      }
    }
    return _getCustomDanmakuByEpisodeOrder(title, episode);
  }

  /// 匹配用的文件名。
  ///
  /// danmu_api 的 extractTitleSeasonEpisode 只识别 `SxxExx` 格式
  /// (正则 /^(.+?)[.\s]+S(\d+)E(\d+)/i), 仅传 "标题 E集数" 会解析不出季集
  /// (season/episode 均为 null), 匹配器随即退化为第一集, 造成所有集数
  /// 串到第一集弹幕。这里从标题提取季数并拼成标准的 SxxExx。
  static String _buildMatchFileName(String title, int episode) {
    final cleanTitle = title.trim();
    final season = _extractSeasonFromTitle(cleanTitle) ?? 1;
    final baseTitle = _stripSeasonMarker(cleanTitle);
    final episodePart = episode.toString().padLeft(2, '0');
    final seasonPart = season.toString().padLeft(2, '0');
    final fileName = '$baseTitle S${seasonPart}E$episodePart';
    KazumiLogger().i('Danmaku: custom server match fileName "$fileName"');
    return fileName;
  }

  /// 从番剧标题提取季数 (第X季/期/部, S2, Season 2, Part 2)。
  /// 不识别结尾裸数字 (如 "高达00"), 避免误判。
  static int? _extractSeasonFromTitle(String title) {
    final chineseMatch =
        RegExp(r'第\s*([0-9一二三四五六七八九十]+)\s*[季期部]').firstMatch(title);
    if (chineseMatch != null) {
      return _parseChineseOrArabic(chineseMatch.group(1)!);
    }
    final sMatch =
        RegExp(r'\bS(?:eason)?\s*(\d+)', caseSensitive: false).firstMatch(title);
    if (sMatch != null) {
      return int.tryParse(sMatch.group(1)!);
    }
    final partMatch =
        RegExp(r'\bPart\s*(\d+)', caseSensitive: false).firstMatch(title);
    if (partMatch != null) {
      return int.tryParse(partMatch.group(1)!);
    }
    return null;
  }

  /// 去掉标题中的季数标识, 避免搜索关键词重复携带季信息。
  static String _stripSeasonMarker(String title) {
    var result = title.trim();
    final patterns = <RegExp>[
      RegExp(r'第\s*[0-9一二三四五六七八九十]+\s*[季期部]'),
      RegExp(r'\bS(?:eason)?\s*\d+', caseSensitive: false),
      RegExp(r'\bPart\s*\d+', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(result);
      if (match != null) {
        result = result.replaceFirst(match.group(0)!, ' ');
        break;
      }
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int? _parseChineseOrArabic(String value) {
    final arabic = int.tryParse(value);
    if (arabic != null) {
      return arabic;
    }
    const digits = {
      '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
      '六': 6, '七': 7, '八': 8, '九': 9,
    };
    if (digits.containsKey(value)) {
      return digits[value];
    }
    final tenMatch = RegExp(r'^十([一二三四五六七八九])$').firstMatch(value);
    if (tenMatch != null) {
      return 10 + (digits[tenMatch.group(1)] ?? 0);
    }
    if (value == '十') {
      return 10;
    }
    return null;
  }

  /// 退化路径: 搜索番剧 -> 取首个结果的完整分集列表 -> 按集序取第 episode 集。
  /// 标题同样取服务端返回值 (含平台来源标记) 供来源标签展示。
  static Future<
      ({
        List<DanmakuEntry> danmakus,
        String? animeTitle,
        String? episodeTitle
      })> _getCustomDanmakuByEpisodeOrder(
    String title,
    int episode,
  ) async {
    try {
      final searchResponse =
          await CustomDanmakuClient.instance.searchAnimes(title);
      if (searchResponse.animes.isEmpty) {
        return (danmakus: <DanmakuEntry>[], animeTitle: null, episodeTitle: null);
      }
      final firstAnime = searchResponse.animes.first;
      final bangumiID = firstAnime.animeId;
      final episodes =
          await CustomDanmakuClient.instance.getEpisodes(bangumiID);
      if (episodes.episodes.length < episode) {
        return (danmakus: <DanmakuEntry>[], animeTitle: null, episodeTitle: null);
      }
      final target = episodes.episodes[episode - 1];
      final danmakus =
          await CustomDanmakuClient.instance.getComments(target.episodeId);
      return (
        danmakus: danmakus,
        animeTitle: firstAnime.animeTitle,
        episodeTitle: target.episodeTitle,
      );
    } catch (e) {
      KazumiLogger().w('Danmaku: custom server fallback match failed',
          error: e);
      return (danmakus: <DanmakuEntry>[], animeTitle: null, episodeTitle: null);
    }
  }
}
