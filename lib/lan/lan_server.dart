import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:kazumi/utils/logger.dart';

/// 局域网 HTTP 服务。
///
/// 仅封装监听生命周期与本地地址枚举。v0 阶段只暴露一个 `/` 路由用于探活，
/// 后续切片再增加业务 API、视频代理与静态文件。
class LanServer {
  HttpServer? _httpServer;

  bool get isRunning => _httpServer != null;

  int? get port => _httpServer?.port;

  Future<void> start({int port = 0}) async {
    if (_httpServer != null) return;
    final handler = const Pipeline().addHandler(_buildRouter().call);
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
    KazumiLogger().i('LanServer: stopped');
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
    return router;
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
}
