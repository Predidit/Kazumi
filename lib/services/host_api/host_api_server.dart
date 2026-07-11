import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Router;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:kazumi/bean/settings/effective_color_scheme_notifier.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/services/host_api/source_resolver.dart';
import 'package:kazumi/services/host_api/theme_export.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/video_source/video_source_service.dart';
import 'package:kazumi/utils/http_headers.dart';

/// 用回调形式拿 [PluginsController] 而非构造时持有引用，
/// 避免在 Modular DI 初始化阶段就触发依赖链。
typedef PluginsProvider = PluginsController Function();

/// Host API 协议版本。破坏性变更时递增；外部扩展启动时通过
/// `GET /host/info` 校验自身要求的最低版本。
const int hostApiLevel = 1;

/// 外部扩展 Host API。
///
/// 仅监听 `127.0.0.1`，把宿主独有的能力（规则插件引擎、WebView 视频源解析、
/// 收藏/历史本地数据、弹幕聚合、主题快照）以 JSON API 暴露给本机的外部扩展
/// 进程（sidecar）。不面向局域网，不 serve 任何 UI，不代理视频流量——
/// 那些属于外部扩展自身的职责。
///
/// 所有端点要求 `Authorization: Bearer <token>`；token 由宿主生成并在
/// 设置页展示给用户，缺失或错误一律 401。
class HostApiServer {
  HostApiServer({required PluginsProvider pluginsProvider})
      : _pluginsProvider = pluginsProvider,
        _sourceResolver = HostSourceResolver();

  final PluginsProvider _pluginsProvider;
  final HostSourceResolver _sourceResolver;

  HttpServer? _httpServer;

  bool get isRunning => _httpServer != null;

  int? get port => _httpServer?.port;

  Future<void> start({required int port, required String token}) async {
    if (_httpServer != null) return;
    final handler = const Pipeline()
        .addMiddleware(_authMiddleware(token))
        .addMiddleware(_accessLogMiddleware())
        .addMiddleware(_errorHandlerMiddleware())
        .addHandler(_buildRouter().call);
    // 仅回环地址：Host API 不对局域网暴露任何东西。
    _httpServer =
        await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
    KazumiLogger()
        .i('HostApi: listening on 127.0.0.1:${_httpServer!.port}');
  }

  Future<void> stop() async {
    final server = _httpServer;
    if (server == null) return;
    _httpServer = null;
    try {
      await server.close(force: true);
    } catch (e) {
      KazumiLogger().w('HostApi: stop error: $e');
    }
    await _sourceResolver.dispose();
    KazumiLogger().i('HostApi: stopped');
  }

  Router _buildRouter() {
    final router = Router();

    router.get('/host/info', _handleInfo);
    router.get('/host/plugins', _handlePlugins);
    router.get('/host/search', _handleSearch);
    router.get('/host/episodes', _handleEpisodes);
    router.get('/host/resolve', _handleResolve);
    router.get('/host/danmaku', _handleDanmaku);
    router.get('/host/theme', _handleTheme);

    router.get('/host/history', _handleGetHistory);
    router.get('/host/history/list', _handleListHistory);
    router.post('/host/history/progress', _handleUpdateProgress);
    router.delete('/host/history', _handleDeleteHistory);

    router.get('/host/collect', _handleGetCollect);
    router.get('/host/collect/list', _handleListCollect);
    router.put('/host/collect', _handlePutCollect);
    router.delete('/host/collect', _handleDeleteCollect);

    return router;
  }

  Response _handleInfo(Request request) {
    return _json({
      'name': 'kazumi',
      'version': ApiEndpoints.version,
      'hostApiLevel': hostApiLevel,
    });
  }

  Response _handleTheme(Request request) {
    return _json(_buildThemePayload());
  }

  /// 构造 theme payload。
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
      'themeMode': themeMode,
      'primaryColor': primaryHex,
      'useDynamicColor': useDynamicColor,
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
          .e('HostApi: search unexpected error', error: e, stackTrace: st);
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
      final roads = await plugin.queryChapterRoads(src);
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
          .e('HostApi: episodes unexpected error', error: e, stackTrace: st);
      return _jsonError(500, 'internal_error', e.toString());
    }
  }

  /// WebView 解析视频源，返回裸的真实 URL 与请求头要求。
  ///
  /// 与旧 LAN server 的区别：不再创建代理会话——视频代理是外部扩展的职责，
  /// 扩展拿到 originalUrl + referer/userAgent 后自行建立代理并直连源站拉流。
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
      return _json({
        'originalUrl': source.url,
        'pluginName': plugin.name,
        'referer': plugin.referer,
        'userAgent':
            plugin.userAgent.isEmpty ? getRandomUA() : plugin.userAgent,
        'streamType': _detectStreamType(source.url),
      });
    } on VideoSourceTimeoutException catch (e) {
      return _jsonError(504, 'resolve_timeout', e.toString());
    } on VideoSourceCancelledException catch (e) {
      return _jsonError(499, 'resolve_cancelled', e.toString());
    } on VideoSourceNotFoundException catch (e) {
      return _jsonError(404, 'video_source_not_found', e.toString());
    } catch (e, st) {
      KazumiLogger().e('HostApi: resolve unexpected error',
          error: e, stackTrace: st);
      return _jsonError(500, 'resolve_failed', e.toString());
    }
  }

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
      // 桌面端的弹幕链路：bgm bangumi id -> dandan bangumi id -> 弹幕。
      // dandanplay 凭证编译在宿主二进制内，因此聚合必须由宿主完成。
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
      KazumiLogger().w('HostApi: danmaku fetch failed',
          error: e, stackTrace: st);
      return _jsonError(502, 'danmaku_failed', e.toString());
    }
  }

  // ====== History ======
  IHistoryRepository get _historyRepo => inject<IHistoryRepository>();
  ICollectCrudRepository get _collectRepo =>
      inject<ICollectCrudRepository>();

  /// 按插件名 + bangumiId 查在线观看历史。走仓库遍历而非手拼 box 键，
  /// 与 History 的存储键格式解耦（scoped key 与 legacy key 都能命中）。
  History? _findOnlineHistory(String pluginName, int bangumiId) {
    for (final h in _historyRepo.getAllHistories()) {
      if (h.adapterName == pluginName &&
          h.bangumiItem.id == bangumiId &&
          HistoryEntryKind.normalize(h.entryKind) == HistoryEntryKind.online) {
        return h;
      }
    }
    return null;
  }

  Response _handleGetHistory(Request request) {
    final bangumiId =
        int.tryParse(request.url.queryParameters['bangumiId'] ?? '');
    final pluginName =
        request.url.queryParameters['pluginName']?.trim() ?? '';
    if (bangumiId == null || pluginName.isEmpty) {
      return _jsonError(400, 'invalid_params',
          'bangumiId and pluginName are required');
    }
    final history = _findOnlineHistory(pluginName, bangumiId);
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
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: bangumi,
          pluginName: pluginName,
          episodeNumber: episode,
          episodeTitle: episodeName,
          road: road,
          onlineBangumiSrc: lastSrc,
          // 扩展的进度上报没有单集页面 URL；恢复播放时由扩展自行重新解析。
          episodePageUrl: '',
        ),
        progress: Duration(milliseconds: progressMs),
      );
      return _json({'ok': true});
    } catch (e, st) {
      KazumiLogger().e('HostApi: history update failed',
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
    final history = _findOnlineHistory(pluginName, bangumiId);
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
          .e('HostApi: collect update failed', error: e, stackTrace: st);
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
  /// BangumiApi 仅在此兜底路径使用（写 History/收藏需要完整 BangumiItem），
  /// Host API 不向扩展暴露任何 Bangumi 公开数据端点——那些数据扩展可自行获取。
  Future<BangumiItem?> _resolveBangumiItem(
      int bangumiId, String? pluginName) async {
    if (pluginName != null && pluginName.isNotEmpty) {
      final existing = _findOnlineHistory(pluginName, bangumiId);
      if (existing != null) return existing.bangumiItem;
    }
    final collected = _collectRepo.getCollectible(bangumiId);
    if (collected != null) return collected.bangumiItem;
    return BangumiApi.getBangumiInfoByID(bangumiId);
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
        'info': b.info,
        'tags': b.tags
            .map((t) => {'name': t.name, 'count': t.count})
            .toList(),
        'alias': b.alias,
      };

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

  Plugin? _findPlugin(String name) {
    for (final p in _pluginsProvider().pluginList) {
      if (p.name == name) return p;
    }
    return null;
  }

  static String _detectStreamType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'hls';
    if (lower.contains('.mp4') ||
        lower.contains('.m4v') ||
        lower.contains('.mov')) {
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

  /// Bearer token 认证。所有端点一律要求；缺失/错误返回 401。
  ///
  /// Host API 只绑定回环地址，token 的威胁模型是"本机其他进程"——
  /// 没有 token 的本机程序不能读取收藏/历史或驱动宿主 WebView。
  /// 不下发 CORS 头：浏览器无法跨域携带 Bearer，天然免 CSRF。
  Middleware _authMiddleware(String token) {
    return (Handler inner) {
      return (Request request) async {
        final auth = request.headers['authorization'] ?? '';
        if (token.isEmpty || auth != 'Bearer $token') {
          return _jsonError(401, 'unauthorized', 'invalid or missing token');
        }
        return inner(request);
      };
    };
  }

  /// 把每个进入服务的请求记一行：方法 + 路径 + status + 耗时。
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
              'HostApi: $method $path -> ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
          return response;
        } catch (e) {
          sw.stop();
          KazumiLogger().w(
              'HostApi: $method $path -> THROW after ${sw.elapsedMilliseconds}ms: $e');
          rethrow;
        }
      };
    };
  }

  /// 把 handler 里未捕获的异常兜成 500 JSON，避免连接被无声切断。
  Middleware _errorHandlerMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        try {
          return await inner(request);
        } catch (e, st) {
          KazumiLogger().e(
            'HostApi: unhandled handler error on ${request.method} ${request.requestedUri.path}',
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
}
