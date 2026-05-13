import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:kazumi/lan/proxy/proxy_session_store.dart';
import 'package:kazumi/lan/proxy/video_proxy_handler.dart';
import 'package:kazumi/lan/source_resolver.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/providers/video/video_source_provider.dart';
import 'package:kazumi/utils/logger.dart';
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
        'Kazumi LAN server is running.\n',
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });
    router.get('/healthz', (Request request) {
      return Response.ok('ok');
    });

    router.get('/api/plugins', _handlePlugins);
    router.get('/api/search', _handleSearch);
    router.get('/api/episodes', _handleEpisodes);
    router.get('/api/resolve', _handleResolve);

    router.all('/proxy/<token>', (Request request, String token) {
      return _proxyHandler.handle(request, token);
    });
    router.all('/proxy/<token>/<subPath>',
        (Request request, String token, String subPath) {
      return _proxyHandler.handle(request, token, subPath);
    });

    return router;
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

  Plugin? _findPlugin(String name) {
    for (final p in _pluginsProvider().pluginList) {
      if (p.name == name) return p;
    }
    return null;
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
