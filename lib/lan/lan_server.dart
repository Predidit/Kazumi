import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:kazumi/lan/proxy/proxy_session_store.dart';
import 'package:kazumi/lan/proxy/video_proxy_handler.dart';
import 'package:kazumi/lan/source_resolver.dart';
import 'package:kazumi/lan/web_index_html.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/staff/staff_item.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/providers/video/video_source_provider.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';

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
    final box = GStorage.setting;
    final themeMode =
        box.get(SettingBoxKey.themeMode, defaultValue: 'system') as String;
    final rawColor =
        box.get(SettingBoxKey.themeColor, defaultValue: 'default') as String;
    String primaryColor = _defaultPrimaryHex;
    if (rawColor != 'default') {
      try {
        final argb = int.parse(rawColor, radix: 16);
        final rgb = argb & 0xFFFFFF;
        primaryColor = '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
      } catch (_) {
        primaryColor = _defaultPrimaryHex;
      }
    }
    final useDynamicColor =
        box.get(SettingBoxKey.useDynamicColor, defaultValue: false) as bool;
    return _json({
      'themeMode': themeMode,
      'primaryColor': primaryColor,
      'useDynamicColor': useDynamicColor,
    });
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

  static const String _defaultPrimaryHex = '#4CAF50';

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
            ? Utils.getRandomUA()
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
      final item = await BangumiApi.getBangumiInfoByID(bangumiId);
      if (item == null) {
        return _jsonError(404, 'not_found', 'bangumi not found');
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
      KazumiLogger().e('LanServer: bangumi comments failed',
          error: e, stackTrace: st);
      return _jsonError(500, 'comments_failed', e.toString());
    }
  }

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

  static Map<String, dynamic> _danmakuToJson(Danmaku d) {
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
