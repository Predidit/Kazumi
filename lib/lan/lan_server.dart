import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide Router;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:kazumi/bean/settings/effective_color_scheme_notifier.dart';
import 'package:kazumi/lan/proxy/proxy_session_store.dart';
import 'package:kazumi/lan/proxy/video_proxy_handler.dart';
import 'package:kazumi/lan/source_resolver.dart';
import 'package:kazumi/lan/theme_export.dart';
import 'package:kazumi/lan/web_index_html.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/staff/staff_item.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/video_source/video_source_service.dart';
import 'package:kazumi/utils/http_headers.dart';

/// 用回调形式拿 [PluginsController] 而非构造时持有引用，
/// 避免在 Modular DI 初始化阶段就触发依赖链。
typedef PluginsProvider = PluginsController Function();

/// 局域网 HTTP 服务。
///
/// 提供给同一局域网下其他设备（主要是没有 Kazumi 原生客户端的 iOS）通过浏览器访问的入口。
/// v1a 阶段提供搜索/选集 JSON API；视频代理与播放页在后续切片加入。
class LanServer {
  LanServer({required PluginsProvider pluginsProvider})
      : _pluginsProvider = pluginsProvider,
        _sessionStore = ProxySessionStore(),
        _sourceResolver = LanSourceResolver() {
    _proxyHandler = VideoProxyHandler(sessionStore: _sessionStore);
  }

  final PluginsProvider _pluginsProvider;
  final ProxySessionStore _sessionStore;
  final LanSourceResolver _sourceResolver;
  late final VideoProxyHandler _proxyHandler;

  HttpServer? _httpServer;

  bool get isRunning => _httpServer != null;

  int? get port => _httpServer?.port;

  Future<void> start({int port = 0}) async {
    if (_httpServer != null) return;
    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_accessLogMiddleware())
        .addMiddleware(_errorHandlerMiddleware())
        .addHandler(_buildRouter().call);
    _httpServer =
        await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    KazumiLogger().i('LanServer: listening on port ${_httpServer!.port}');
  }

  Future<void> stop() async {
    final server = _httpServer;
    if (server == null) return;
    _httpServer = null;
    try {
      await server.close(force: true);
    } catch (e) {
      KazumiLogger().w('LanServer: stop error: $e');
    }
    _sessionStore.clear();
    await _sourceResolver.dispose();
    _proxyHandler.close();
    KazumiLogger().i('LanServer: stopped');
  }

  /// 枚举本机非回环的 IPv4 地址。供设置页展示给用户。
  static Future<List<String>> enumerateLanIPv4() async {
    final result = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          result.add(addr.address);
        }
      }
    } catch (e) {
      KazumiLogger().w('LanServer: enumerate interfaces failed: $e');
    }
    return result;
  }

  Router _buildRouter() {
    final router = Router();

    router.get('/', (Request request) {
      return Response.ok(
        lanWebIndexHtml,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });
    router.get('/healthz', (Request request) {
      return Response.ok('ok');
    });
    // 浏览器默认会请求 /favicon.ico；不显式处理会被 Router 转成 404，污染日志。
    router.get('/favicon.ico', (Request request) {
      return Response(204);
    });

    router.get('/api/plugins', _handlePlugins);
    router.get('/api/search', _handleSearch);
    router.get('/api/episodes', _handleEpisodes);
    router.get('/api/resolve', _handleResolve);
    router.get('/api/theme', _handleTheme);

    router.get('/api/bangumi/search', _handleBangumiSearch);
    router.get('/api/bangumi/<id|[0-9]+>', _handleBangumiDetail);
    router.get('/api/bangumi/<id|[0-9]+>/characters',
        _handleBangumiCharacters);
    router.get('/api/bangumi/<id|[0-9]+>/comments', _handleBangumiComments);
    router.get('/api/bangumi/<id|[0-9]+>/staff', _handleBangumiStaff);
    router.get('/api/bangumi/<id|[0-9]+>/episodes', _handleBangumiEpisodes);
    router.get('/api/bangumi/<id|[0-9]+>/episode-comments',
        _handleEpisodeComments);
    router.get('/api/popular', _handlePopular);
    router.get('/api/timeline', _handleTimeline);

    router.get('/api/danmaku', _handleDanmaku);

    router.get('/api/history', _handleGetHistory);
    router.get('/api/history/list', _handleListHistory);
    router.post('/api/history/progress', _handleUpdateProgress);
    router.delete('/api/history', _handleDeleteHistory);

    router.get('/api/collect', _handleGetCollect);
    router.get('/api/collect/list', _handleListCollect);
    router.put('/api/collect', _handlePutCollect);
    router.delete('/api/collect', _handleDeleteCollect);

    router.get('/assets/<file>', _handleAsset);

    router.all('/proxy/<token>', (Request request, String token) {
      return _proxyHandler.handle(request, token);
    });
    router.all('/proxy/<token>/<subPath>',
        (Request request, String token, String subPath) {
      return _proxyHandler.handle(request, token, subPath);
    });

    return router;
  }

  Response _handleTheme(Request request) {
    return _json(_buildThemePayload());
  }

  /// 构造 v2 theme payload。
  ///
  /// 颜色优先从 [effectiveColorSchemeNotifier] 拿（桌面端 DynamicColorBuilder
  /// 已经决定的"实际生效"ColorScheme）；若 Notifier 还没就绪（启动早期）
  /// 回退到 `ColorScheme.fromSeed(seed)` 自行生成。
  Map<String, dynamic> _buildThemePayload() {
    final themeMode = GStorage.getSetting(SettingsKeys.themeMode);
    final rawColor = GStorage.getSetting(SettingsKeys.themeColor);
    final oledEnhance = GStorage.getSetting(SettingsKeys.oledEnhance);
    final useDynamicColor = GStorage.getSetting(SettingsKeys.useDynamicColor);

    final seedColor = _parseSeedColor(rawColor);
    final primaryHex = _colorToHex(seedColor);

    final cached = effectiveColorSchemeNotifier.value;
    final lightScheme = cached?.light ??
        buildScheme(
          seed: seedColor,
          brightness: Brightness.light,
          oledEnhance: false,
        );
    final darkScheme = cached?.dark ??
        buildScheme(
          seed: seedColor,
          brightness: Brightness.dark,
          oledEnhance: oledEnhance,
        );

    return {
      'version': 2,
      // v1 兼容字段
      'themeMode': themeMode,
      'primaryColor': primaryHex,
      'useDynamicColor': useDynamicColor,
      // v2 扩展
      'oledEnhance': oledEnhance,
      'schemes': {
        'light': exportColorTokens(lightScheme),
        'dark': exportColorTokens(darkScheme),
      },
      'typography': exportTypographyTokens(),
    };
  }

  Color _parseSeedColor(String raw) {
    if (raw == 'default') return Colors.green;
    try {
      final argb = int.parse(raw, radix: 16);
      // raw 是 ARGB hex；如果是 6 位则补 alpha
      return Color(argb >= 0xFF000000 ? argb : (argb | 0xFF000000));
    } catch (_) {
      return Colors.green;
    }
  }

  String _colorToHex(Color c) {
    final r = (c.r * 255).round() & 0xFF;
    final g = (c.g * 255).round() & 0xFF;
    final b = (c.b * 255).round() & 0xFF;
    return '#'
        '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Future<Response> _handleAsset(Request request, String file) async {
    final entry = _staticAssets[file];
    if (entry == null) {
      return Response.notFound('asset not found');
    }
    try {
      final data = await rootBundle.load(entry.assetPath);
      return Response.ok(
        data.buffer.asUint8List(),
        headers: {
          'content-type': entry.contentType,
          'cache-control': 'public, max-age=604800',
        },
      );
    } catch (e) {
      KazumiLogger().w('LanServer: asset load failed: ${entry.assetPath} ($e)');
      return Response.notFound('asset load error');
    }
  }

  static final Map<String, _StaticAsset> _staticAssets = {
    'MiSans-Regular.ttf': _StaticAsset(
      assetPath: 'assets/fonts/MiSans-Regular.ttf',
      contentType: 'font/ttf',
    ),
    'hls.min.js': _StaticAsset(
      assetPath: 'assets/lan_web/hls.min.js',
      contentType: 'application/javascript; charset=utf-8',
    ),
  };

  Response _handlePlugins(Request request) {
    final plugins = _pluginsProvider().pluginList;
    final list = plugins
        .map((p) => {
              'name': p.name,
              'version': p.version,
              'type': p.type,
              'useNativePlayer': p.useNativePlayer,
              'muliSources': p.muliSources,
            })
        .toList();
    return _json(list);
  }

  Future<Response> _handleSearch(Request request) async {
    final keyword = request.url.queryParameters['keyword']?.trim() ?? '';
    final pluginName = request.url.queryParameters['plugin']?.trim() ?? '';
    if (keyword.isEmpty) {
      return _jsonError(400, 'keyword_required', 'keyword is required');
    }
    if (pluginName.isEmpty) {
      return _jsonError(400, 'plugin_required', 'plugin is required');
    }

    final plugin = _findPlugin(pluginName);
    if (plugin == null) {
      return _jsonError(404, 'plugin_not_found', 'plugin $pluginName not found');
    }

    try {
      final response = await plugin.queryBangumi(keyword, shouldRethrow: true);
      return _json({
        'pluginName': response.pluginName,
        'items': response.data
            .map((item) => {
                  'name': item.name,
                  'src': item.src,
                  'fullUrl': plugin.buildFullUrl(item.src),
                })
            .toList(),
      });
    } on CaptchaRequiredException catch (e) {
      return _jsonError(423, 'captcha_required', e.toString());
    } on NoResultException {
      return _json({'pluginName': plugin.name, 'items': const []});
    } on SearchErrorException catch (e) {
      return _jsonError(502, 'search_failed', e.toString());
    } catch (e, st) {
      KazumiLogger()
          .e('LanServer: search unexpected error', error: e, stackTrace: st);
      return _jsonError(500, 'internal_error', e.toString());
    }
  }

  Future<Response> _handleEpisodes(Request request) async {
    final pluginName = request.url.queryParameters['plugin']?.trim() ?? '';
    final src = request.url.queryParameters['src']?.trim() ?? '';
    if (pluginName.isEmpty) {
      return _jsonError(400, 'plugin_required', 'plugin is required');
    }
    if (src.isEmpty) {
      return _jsonError(400, 'src_required', 'src is required');
    }

    final plugin = _findPlugin(pluginName);
    if (plugin == null) {
      return _jsonError(404, 'plugin_not_found', 'plugin $pluginName not found');
    }

    try {
      final roads = await plugin.querychapterRoads(src);
      return _json({
        'pluginName': plugin.name,
        'roads': roads
            .map((road) => {
                  'name': road.name,
                  'episodes': List<Map<String, String>>.generate(
                    road.data.length,
                    (i) => {
                      'name': i < road.identifier.length
                          ? road.identifier[i]
                          : '第${i + 1}集',
                      'src': road.data[i],
                    },
                  ),
                })
            .toList(),
      });
    } catch (e, st) {
      KazumiLogger()
          .e('LanServer: episodes unexpected error', error: e, stackTrace: st);
      return _jsonError(500, 'internal_error', e.toString());
    }
  }

  Future<Response> _handleResolve(Request request) async {
    final pluginName = request.url.queryParameters['plugin']?.trim() ?? '';
    final episodeUrl =
        request.url.queryParameters['episodeUrl']?.trim() ?? '';
    if (pluginName.isEmpty) {
      return _jsonError(400, 'plugin_required', 'plugin is required');
    }
    if (episodeUrl.isEmpty) {
      return _jsonError(
          400, 'episode_url_required', 'episodeUrl is required');
    }
    final plugin = _findPlugin(pluginName);
    if (plugin == null) {
      return _jsonError(404, 'plugin_not_found', 'plugin $pluginName not found');
    }

    final fullEpisodeUrl = plugin.buildFullUrl(episodeUrl);

    try {
      final source = await _sourceResolver.resolve(
        plugin: plugin,
        episodeUrl: fullEpisodeUrl,
      );
      final session = ProxySession(
        originalUrl: source.url,
        referer: plugin.referer,
        userAgent: plugin.userAgent.isEmpty
            ? getRandomUA()
            : plugin.userAgent,
        pluginName: plugin.name,
        createdAt: DateTime.now(),
      );
      final token = _sessionStore.register(session);
      return _json({
        'token': token,
        'playUrl': VideoProxyHandler.buildRootUrl(token),
        'originalUrl': source.url,
        'pluginName': plugin.name,
        'streamType': _detectStreamType(source.url),
      });
    } on VideoSourceTimeoutException catch (e) {
      return _jsonError(504, 'resolve_timeout', e.toString());
    } on VideoSourceCancelledException catch (e) {
      return _jsonError(499, 'resolve_cancelled', e.toString());
    } on VideoSourceNotFoundException catch (e) {
      return _jsonError(404, 'video_source_not_found', e.toString());
    } catch (e, st) {
      KazumiLogger().e('LanServer: resolve unexpected error',
          error: e, stackTrace: st);
      return _jsonError(500, 'resolve_failed', e.toString());
    }
  }

  Future<Response> _handleBangumiSearch(Request request) async {
    final keyword = request.url.queryParameters['keyword']?.trim() ?? '';
    if (keyword.isEmpty) {
      return _jsonError(400, 'keyword_required', 'keyword is required');
    }
    final offset =
        int.tryParse(request.url.queryParameters['offset'] ?? '0') ?? 0;
    try {
      final list = await BangumiApi.bangumiSearch(keyword, offset: offset);
      return _json({
        'items': list.map(_bangumiItemToJson).toList(),
      });
    } catch (e, st) {
      KazumiLogger().e('LanServer: bangumi search failed',
          error: e, stackTrace: st);
      return _jsonError(500, 'search_failed', e.toString());
    }
  }

  Future<Response> _handleBangumiDetail(Request request, String id) async {
    final bangumiId = int.tryParse(id);
    if (bangumiId == null) {
      return _jsonError(400, 'invalid_id', 'invalid id');
    }
    try {
      final item =
          await _retryNullable(() => BangumiApi.getBangumiInfoByID(bangumiId));
      if (item == null) {
        // 详情页的 id 都来自真实列表，几乎不可能真的不存在；耗尽重试后
        // 仍为 null 基本是上游瞬时不可用，返回可重试语义而非 "not found"。
        return _jsonError(
            502, 'bangumi_unavailable', '上游暂时不可用，请稍后重试');
      }
      return _json(_bangumiItemToJson(item));
    } catch (e, st) {
      KazumiLogger()
          .e('LanServer: bangumi detail failed', error: e, stackTrace: st);
      return _jsonError(500, 'detail_failed', e.toString());
    }
  }

  Future<Response> _handleBangumiCharacters(
      Request request, String id) async {
    final bangumiId = int.tryParse(id);
    if (bangumiId == null) {
      return _jsonError(400, 'invalid_id', 'invalid id');
    }
    try {
      final res = await BangumiApi.getCharatersByBangumiID(bangumiId);
      final ordered = [...res.charactersList];
      const relationOrder = {'主角': 1, '配角': 2, '客串': 3};
      ordered.sort((a, b) =>
          (relationOrder[a.relation] ?? 4)
              .compareTo(relationOrder[b.relation] ?? 4));
      return _json({
        'characters': ordered.map(_characterItemToJson).toList(),
      });
    } catch (e, st) {
      KazumiLogger().e('LanServer: bangumi characters failed',
          error: e, stackTrace: st);
      return _jsonError(500, 'characters_failed', e.toString());
    }
  }

  Future<Response> _handleBangumiComments(
      Request request, String id) async {
    final bangumiId = int.tryParse(id);
    if (bangumiId == null) {
      return _jsonError(400, 'invalid_id', 'invalid id');
    }
    final offset =
        int.tryParse(request.url.queryParameters['offset'] ?? '0') ?? 0;
    try {
      final res = await BangumiApi.getBangumiCommentsByID(bangumiId,
          offset: offset);
      return _json({
        'total': res.total,
        'items': res.commentList.map(_commentItemToJson).toList(),
      });
    } catch (e, st) {
      // 镜像后端不提供吐槽接口时会回 401（其他瞬时故障同理）。应用端把这种
      // 失败收成"吐槽 tab 内的可重试软状态"，不崩页也不泄漏原始异常。
      // web 端对齐：返回干净的可重试语义，原始 NetworkException 只进日志。
      KazumiLogger().e('LanServer: bangumi comments failed',
          error: e, stackTrace: st);
      return _jsonError(502, 'comments_unavailable', '吐槽获取失败，请稍后重试');
    }
  }

  /// 桌面端是否启用了 Bangumi 镜像（api.kazumi.fyi）。
  /// 各内容接口需要据此在"官方 bgm.tv"与"镜像后端"之间切换，
  /// 与应用端 PopularController / TimelineController 的 `_bangumiMirrorEnabled`
  /// 行为完全一致，否则用户开了镜像后 web 端会拉空。
  bool get _bangumiMirrorEnabled =>
      GStorage.getSetting(SettingsKeys.enableBangumiProxy);

  /// 对"硬依赖"的冷拉取做有限重试。
  ///
  /// 上游（尤其镜像后端 api.kazumi.fyi 的 /p1 中继）会间歇性 5s 超时，
  /// 而 [BangumiApi.getBangumiInfoByID] 等方法把任何网络异常都吞成 null。
  /// 应用端进详情页时已有列表传来的 BangumiItem 做兜底，web 端只有 id 必须
  /// 冷拉，单次失败就整页崩。这里对瞬时抖动重试几次（同域 popular 请求
  /// ~600ms 即返回，说明镜像本身可用），把"番剧不存在"和"网络抖动"区分开。
  Future<T?> _retryNullable<T>(
    Future<T?> Function() task, {
    int attempts = 3,
    Duration gap = const Duration(milliseconds: 400),
  }) async {
    for (var i = 0; i < attempts; i++) {
      final result = await task();
      if (result != null) return result;
      if (i < attempts - 1) await Future.delayed(gap);
    }
    return null;
  }

  Future<Response> _handlePopular(Request request) async {
    final tag = request.url.queryParameters['tag']?.trim() ?? '';
    final offset =
        int.tryParse(request.url.queryParameters['offset'] ?? '0') ?? 0;
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '24') ?? 24;
    try {
      // 镜像模式下 trend 与 tag 统一走镜像榜单接口（对齐 PopularController
      // queryBangumiByTrend / queryBangumiByTag 的镜像分支）；
      // 非镜像：无 tag → 趋势接口，有 tag → tag 搜索。
      final List<BangumiItem> list;
      if (_bangumiMirrorEnabled) {
        list = await BangumiApi.getBangumiMirrorPopularSubjects(
          tag: tag,
          limit: limit,
          offset: offset,
        );
      } else {
        list = tag.isEmpty
            ? await BangumiApi.getBangumiTrendsList(offset: offset, limit: limit)
            : await BangumiApi.getBangumiList(
                rank: Random().nextInt(8000) + 1, tag: tag);
      }
      return _json({
        'items': list.map(_bangumiItemToJson).toList(),
      });
    } catch (e, st) {
      KazumiLogger()
          .e('LanServer: popular failed', error: e, stackTrace: st);
      return _jsonError(500, 'popular_failed', e.toString());
    }
  }

  Future<Response> _handleTimeline(Request request) async {
    final season = request.url.queryParameters['season']?.trim() ?? '';
    try {
      if (season.isEmpty) {
        // 默认拉本周日历，与桌面端 timeline_controller.getSchedules 一致
        final calendar = await BangumiApi.getCalendar();
        return _json({
          'days': calendar
              .map((day) => day.map(_bangumiItemToJson).toList())
              .toList(),
        });
      }

      // 桌面端 timeline_controller.getSchedulesBySeason：
      // 4 次 × limit 20 累积拉取，按 air_date 落到对应 weekday。
      final parts = season.split('-');
      if (parts.length != 2) {
        return _jsonError(400, 'invalid_season', 'season must be YYYY-Q');
      }
      final year = int.tryParse(parts[0]);
      final quarter = int.tryParse(parts[1]);
      if (year == null || quarter == null || quarter < 1 || quarter > 4) {
        return _jsonError(400, 'invalid_season', 'season must be YYYY-Q');
      }
      // anime_season.toSeasonStartAndEnd 算法：起始月 = (季-1)*3，
      // 0 月归并到上一年 12 月（"上一个季节的起始月"）。
      final seasonIndex = quarter - 1;
      var startMonth = seasonIndex * 3;
      var startYear = year;
      if (startMonth == 0) {
        startMonth = 12;
        startYear -= 1;
      }
      final start = DateTime(startYear, startMonth, 1);
      final end = DateTime(year, (seasonIndex + 1) * 3, 1);
      final dateRange = [start.toString(), end.toString()];

      // 镜像模式：一次性拉镜像季节时间表（对齐 TimelineController
      // getSchedulesBySeason 的 _bangumiMirrorEnabled 分支）。
      if (_bangumiMirrorEnabled) {
        final calendar =
            await BangumiApi.getBangumiMirrorSeasonCalendar(dateRange);
        return _json({
          'season': season,
          'days': calendar
              .map((day) => day.map(_bangumiItemToJson).toList())
              .toList(),
        });
      }

      const maxRound = 4;
      const limit = 20;
      final calendar = List.generate(7, (_) => <BangumiItem>[]);
      for (var round = 0; round < maxRound; round++) {
        final offset = round * limit;
        final newList =
            await BangumiApi.getCalendarBySearch(dateRange, limit, offset);
        for (var i = 0; i < calendar.length; i++) {
          calendar[i].addAll(newList[i]);
        }
      }
      return _json({
        'season': season,
        'days': calendar
            .map((day) => day.map(_bangumiItemToJson).toList())
            .toList(),
      });
    } catch (e, st) {
      KazumiLogger()
          .e('LanServer: timeline failed', error: e, stackTrace: st);
      return _jsonError(500, 'timeline_failed', e.toString());
    }
  }

  Future<Response> _handleBangumiEpisodes(Request request, String id) async {
    final bangumiId = int.tryParse(id);
    if (bangumiId == null) {
      return _jsonError(400, 'invalid_id', 'invalid id');
    }
    try {
      final list = await BangumiApi.getBangumiEpisodesByID(bangumiId);
      return _json({
        'items': list.map(_episodeInfoToJson).toList(),
      });
    } catch (e, st) {
      KazumiLogger()
          .e('LanServer: episodes failed', error: e, stackTrace: st);
      return _jsonError(500, 'episodes_failed', e.toString());
    }
  }

  Future<Response> _handleEpisodeComments(Request request, String id) async {
    final bangumiId = int.tryParse(id);
    if (bangumiId == null) {
      return _jsonError(400, 'invalid_id', 'invalid id');
    }
    final episode =
        int.tryParse(request.url.queryParameters['episode'] ?? '');
    if (episode == null || episode < 1) {
      return _jsonError(
          400, 'invalid_episode', 'episode query is required (>=1)');
    }
    try {
      // 桌面端链路：先按集数拿 EpisodeInfo，再用 episode.id 拿评论
      final epInfo =
          await BangumiApi.getBangumiEpisodeByID(bangumiId, episode);
      if (epInfo.id == 0) {
        return _json({
          'episode': null,
          'items': const <Map<String, dynamic>>[],
        });
      }
      final res =
          await BangumiApi.getBangumiCommentsByEpisodeID(epInfo.id);
      return _json({
        'episode': _episodeInfoToJson(epInfo),
        'items': res.commentList.map(_episodeCommentItemToJson).toList(),
      });
    } catch (e, st) {
      // 与吐槽同理：镜像后端不提供剧集评论时回 401，收成可重试软状态，
      // 不泄漏原始异常。
      KazumiLogger().e('LanServer: episode comments failed',
          error: e, stackTrace: st);
      return _jsonError(
          502, 'episode_comments_unavailable', '评论获取失败，请稍后重试');
    }
  }

  static Map<String, dynamic> _episodeInfoToJson(EpisodeInfo e) => {
        'id': e.id,
        'episode': e.episode,
        'type': e.type,
        'name': e.name,
        'nameCn': e.nameCn,
        'readType': e.readType(),
      };

  static Map<String, dynamic> _episodeCommentItemToJson(EpisodeCommentItem c) =>
      {
        'user': {
          'username': c.comment.user.username,
          'nickname': c.comment.user.nickname,
          'avatar': c.comment.user.avatar.medium,
        },
        'content': c.comment.comment,
        'createdAt': c.comment.createdAt,
        'replies': c.replies
            .map((r) => {
                  'user': {
                    'username': r.user.username,
                    'nickname': r.user.nickname,
                    'avatar': r.user.avatar.medium,
                  },
                  'content': r.comment,
                  'createdAt': r.createdAt,
                })
            .toList(),
      };

  Future<Response> _handleBangumiStaff(Request request, String id) async {
    final bangumiId = int.tryParse(id);
    if (bangumiId == null) {
      return _jsonError(400, 'invalid_id', 'invalid id');
    }
    try {
      final res = await BangumiApi.getBangumiStaffByID(bangumiId);
      return _json({
        'total': res.total,
        'items': res.data.map(_staffItemToJson).toList(),
      });
    } catch (e, st) {
      KazumiLogger()
          .e('LanServer: bangumi staff failed', error: e, stackTrace: st);
      return _jsonError(500, 'staff_failed', e.toString());
    }
  }

  static Map<String, dynamic> _bangumiItemToJson(BangumiItem b) => {
        'id': b.id,
        'type': b.type,
        'name': b.name,
        'nameCn': b.nameCn,
        'summary': b.summary,
        'airDate': b.airDate,
        'airWeekday': b.airWeekday,
        'rank': b.rank,
        'ratingScore': b.ratingScore,
        'votes': b.votes,
        'votesCount': b.votesCount,
        'images': b.images,
        // info: bangumi 信息行（"导演 / CV / 制作组"），timeline 卡片副文本优先用它
        'info': b.info,
        'tags': b.tags
            .map((t) => {'name': t.name, 'count': t.count})
            .toList(),
        'alias': b.alias,
      };

  static Map<String, dynamic> _characterItemToJson(CharacterItem c) => {
        'id': c.id,
        'name': c.name,
        'relation': c.relation,
        'image': c.avator.large.isNotEmpty
            ? c.avator.large
            : c.avator.medium,
        'actors': c.actorList
            .map((a) => {
                  'id': a.id,
                  'name': a.name,
                  'image': a.avator.medium,
                })
            .toList(),
      };

  static Map<String, dynamic> _commentItemToJson(CommentItem c) => {
        'user': {
          'username': c.user.username,
          'nickname': c.user.nickname,
          'avatar': c.user.avatar.medium,
        },
        'rate': c.comment.rate,
        'comment': c.comment.comment,
        'updatedAt': c.comment.updatedAt,
      };

  Future<Response> _handleDanmaku(Request request) async {
    final bangumiId =
        int.tryParse(request.url.queryParameters['bangumiId'] ?? '');
    final episode =
        int.tryParse(request.url.queryParameters['episode'] ?? '');
    if (bangumiId == null || episode == null) {
      return _jsonError(400, 'invalid_params',
          'bangumiId and episode are required');
    }
    try {
      // 桌面端的弹幕链路：bgm bangumi id -> dandan bangumi id -> 弹幕
      final dandanId =
          await DanmakuApi.getDanDanBangumiIDByBgmBangumiID(bangumiId);
      if (dandanId == 0) {
        return _json({
          'bangumiId': bangumiId,
          'episode': episode,
          'items': const <Map<String, dynamic>>[],
          'reason': 'dandan_bangumi_not_found',
        });
      }
      final list = await DanmakuApi.getDanDanmaku(dandanId, episode);
      return _json({
        'bangumiId': bangumiId,
        'episode': episode,
        'dandanBangumiId': dandanId,
        'items': list.map(_danmakuToJson).toList(),
      });
    } catch (e, st) {
      KazumiLogger().w('LanServer: danmaku fetch failed',
          error: e, stackTrace: st);
      return _jsonError(502, 'danmaku_failed', e.toString());
    }
  }

  // ====== History ======
  IHistoryRepository get _historyRepo => Modular.get<IHistoryRepository>();
  ICollectCrudRepository get _collectRepo =>
      Modular.get<ICollectCrudRepository>();

  Response _handleGetHistory(Request request) {
    final bangumiId =
        int.tryParse(request.url.queryParameters['bangumiId'] ?? '');
    final pluginName =
        request.url.queryParameters['pluginName']?.trim() ?? '';
    if (bangumiId == null || pluginName.isEmpty) {
      return _jsonError(400, 'invalid_params',
          'bangumiId and pluginName are required');
    }
    final history = GStorage.histories.get('$pluginName$bangumiId');
    if (history == null) {
      return _json({'history': null});
    }
    return _json({'history': _historyToJson(history)});
  }

  Response _handleListHistory(Request request) {
    final list = _historyRepo.getAllHistories();
    return _json({
      'items': list.map(_historyToJson).toList(),
    });
  }

  Future<Response> _handleUpdateProgress(Request request) async {
    final body = await request.readAsString();
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return _jsonError(400, 'invalid_body', 'body must be json');
    }
    final bangumiId = (json['bangumiId'] as num?)?.toInt();
    final pluginName = (json['pluginName'] as String?)?.trim();
    final episode = (json['episode'] as num?)?.toInt();
    final road = (json['road'] as num?)?.toInt() ?? 0;
    final progressMs = (json['progressMs'] as num?)?.toInt();
    final lastSrc = (json['lastSrc'] as String?) ?? '';
    final episodeName = (json['episodeName'] as String?) ?? '';
    if (bangumiId == null ||
        pluginName == null ||
        pluginName.isEmpty ||
        episode == null ||
        progressMs == null) {
      return _jsonError(400, 'invalid_params',
          'bangumiId, pluginName, episode, progressMs are required');
    }

    final bangumi = await _resolveBangumiItem(bangumiId, pluginName);
    if (bangumi == null) {
      return _jsonError(404, 'bangumi_not_found', 'bangumi not found');
    }

    try {
      await _historyRepo.updateHistory(
        episode: episode,
        road: road,
        adapterName: pluginName,
        bangumiItem: bangumi,
        progress: Duration(milliseconds: progressMs),
        lastSrc: lastSrc,
        lastWatchEpisodeName: episodeName,
      );
      return _json({'ok': true});
    } catch (e, st) {
      KazumiLogger().e('LanServer: history update failed',
          error: e, stackTrace: st);
      return _jsonError(500, 'history_update_failed', e.toString());
    }
  }

  Future<Response> _handleDeleteHistory(Request request) async {
    final bangumiId =
        int.tryParse(request.url.queryParameters['bangumiId'] ?? '');
    final pluginName =
        request.url.queryParameters['pluginName']?.trim() ?? '';
    if (bangumiId == null || pluginName.isEmpty) {
      return _jsonError(400, 'invalid_params',
          'bangumiId and pluginName are required');
    }
    final history = GStorage.histories.get('$pluginName$bangumiId');
    if (history == null) return _json({'ok': true});
    await _historyRepo.deleteHistory(history);
    return _json({'ok': true});
  }

  Map<String, dynamic> _historyToJson(History h) {
    final progresses = <String, dynamic>{};
    h.progresses.forEach((ep, p) {
      progresses[ep.toString()] = {
        'episode': p.episode,
        'road': p.road,
        'progressMs': p.progress.inMilliseconds,
      };
    });
    return {
      'bangumiId': h.bangumiItem.id,
      'pluginName': h.adapterName,
      'lastWatchEpisode': h.lastWatchEpisode,
      'lastWatchEpisodeName': h.lastWatchEpisodeName,
      'lastWatchTime': h.lastWatchTime.millisecondsSinceEpoch,
      'lastSrc': h.lastSrc,
      'progresses': progresses,
      'bangumi': _bangumiItemToJson(h.bangumiItem),
    };
  }

  // ====== Collect ======
  Response _handleGetCollect(Request request) {
    final bangumiId =
        int.tryParse(request.url.queryParameters['bangumiId'] ?? '');
    if (bangumiId == null) {
      return _jsonError(400, 'invalid_params', 'bangumiId is required');
    }
    final type = _collectRepo.getCollectType(bangumiId);
    final collectible = _collectRepo.getCollectible(bangumiId);
    return _json({
      'bangumiId': bangumiId,
      'type': type,
      'time': collectible?.time.millisecondsSinceEpoch,
    });
  }

  Response _handleListCollect(Request request) {
    final filterType = int.tryParse(request.url.queryParameters['type'] ?? '');
    final all = _collectRepo.getAllCollectibles();
    final list = filterType == null
        ? all
        : all.where((c) => c.type == filterType).toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return _json({
      'items': list.map(_collectibleToJson).toList(),
    });
  }

  Future<Response> _handlePutCollect(Request request) async {
    final body = await request.readAsString();
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return _jsonError(400, 'invalid_body', 'body must be json');
    }
    final bangumiId = (json['bangumiId'] as num?)?.toInt();
    final type = (json['type'] as num?)?.toInt();
    if (bangumiId == null || type == null) {
      return _jsonError(
          400, 'invalid_params', 'bangumiId and type are required');
    }
    if (type == 0) {
      await _collectRepo.deleteCollectible(bangumiId);
      return _json({'ok': true, 'type': 0});
    }
    final bangumi = await _resolveBangumiItem(bangumiId, null);
    if (bangumi == null) {
      return _jsonError(404, 'bangumi_not_found', 'bangumi not found');
    }
    try {
      await _collectRepo.addCollectible(bangumi, type);
      return _json({'ok': true, 'type': type});
    } catch (e, st) {
      KazumiLogger()
          .e('LanServer: collect update failed', error: e, stackTrace: st);
      return _jsonError(500, 'collect_update_failed', e.toString());
    }
  }

  Future<Response> _handleDeleteCollect(Request request) async {
    final bangumiId =
        int.tryParse(request.url.queryParameters['bangumiId'] ?? '');
    if (bangumiId == null) {
      return _jsonError(400, 'invalid_params', 'bangumiId is required');
    }
    await _collectRepo.deleteCollectible(bangumiId);
    return _json({'ok': true});
  }

  Map<String, dynamic> _collectibleToJson(CollectedBangumi c) => {
        'bangumiId': c.bangumiItem.id,
        'type': c.type,
        'time': c.time.millisecondsSinceEpoch,
        'bangumi': _bangumiItemToJson(c.bangumiItem),
      };

  /// 找一个可用的 BangumiItem：本地 history / 收藏里有就直接复用，否则现拉。
  Future<BangumiItem?> _resolveBangumiItem(
      int bangumiId, String? pluginName) async {
    if (pluginName != null && pluginName.isNotEmpty) {
      final existing = GStorage.histories.get('$pluginName$bangumiId');
      if (existing != null) return existing.bangumiItem;
    }
    final collected = _collectRepo.getCollectible(bangumiId);
    if (collected != null) return collected.bangumiItem;
    return BangumiApi.getBangumiInfoByID(bangumiId);
  }

  static Map<String, dynamic> _danmakuToJson(DanmakuEntry d) {
    final colorValue = ((d.color.r * 255).toInt() << 16) |
        ((d.color.g * 255).toInt() << 8) |
        (d.color.b * 255).toInt();
    return {
      'time': d.time,
      'type': d.type,
      'color': colorValue,
      'source': d.source,
      'message': d.message,
    };
  }

  static Map<String, dynamic> _staffItemToJson(StaffFullItem s) => {
        'id': s.staff.id,
        'name': s.staff.name,
        'nameCN': s.staff.nameCN,
        'image': s.staff.images?.medium ?? s.staff.images?.large ?? '',
        'positions': s.positions
            .map((p) => {
                  'type': p.type.cn.isNotEmpty ? p.type.cn : p.type.en,
                  'summary': p.summary,
                })
            .toList(),
      };

  Plugin? _findPlugin(String name) {
    for (final p in _pluginsProvider().pluginList) {
      if (p.name == name) return p;
    }
    return null;
  }

  static String _detectStreamType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'hls';
    if (lower.contains('.mp4') || lower.contains('.m4v') || lower.contains('.mov')) {
      return 'mp4';
    }
    return 'unknown';
  }

  Response _json(Object? body, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Response _jsonError(int status, String code, String message) {
    return _json({'error': code, 'message': message}, status: status);
  }

  /// 把每个进入服务的请求记一行：方法 + 路径 + status + 耗时。
  /// 关键作用：根因排查时能直接从 KazumiLogger 看到请求是否真的到达 handler、
  /// 跑了多久就被切断、返回了什么 status。ERR_EMPTY_RESPONSE 类问题这是
  /// 第一手证据。
  Middleware _accessLogMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        final sw = Stopwatch()..start();
        final method = request.method;
        final path = request.requestedUri.path;
        try {
          final response = await inner(request);
          sw.stop();
          KazumiLogger().i(
              'LanServer: $method $path -> ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
          return response;
        } catch (e) {
          sw.stop();
          KazumiLogger().w(
              'LanServer: $method $path -> THROW after ${sw.elapsedMilliseconds}ms: $e');
          rethrow;
        }
      };
    };
  }

  /// 把 handler 里同步/await 抛出的异常兜成 500 JSON。
  ///
  /// 默认 shelf 在 handler 抛错时会让连接被无声切断，浏览器侧表现为
  /// `ERR_EMPTY_RESPONSE` —— 既看不到 5xx 也拿不到错误信息。这里显式
  /// 包一层，错误打到日志、客户端拿到结构化 JSON。
  Middleware _errorHandlerMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        try {
          return await inner(request);
        } catch (e, st) {
          KazumiLogger().e(
            'LanServer: unhandled handler error on ${request.method} ${request.requestedUri.path}',
            error: e,
            stackTrace: st,
          );
          return Response(
            500,
            body: jsonEncode({
              'error': 'unhandled',
              'message': e.toString(),
              'path': request.requestedUri.path,
            }),
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
      };
    };
  }

  /// 简单的 CORS 中间件。当前服务端通常被同源访问（HTML 客户端来自同一服务），
  /// 但保留宽松 CORS 便于开发期 curl/调试以及未来从 Kazumi 桌面端直接调用。
  Middleware _corsMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: {
          ...response.headersAll,
          ..._corsHeaders,
        });
      };
    };
  }

  static const Map<String, String> _corsHeaders = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type, range',
    'access-control-expose-headers': 'content-length, content-range',
  };
}

class _StaticAsset {
  const _StaticAsset({required this.assetPath, required this.contentType});
  final String assetPath;
  final String contentType;
}
