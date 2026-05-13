import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import 'package:kazumi/utils/logger.dart';

/// 通过 mDNS / DNS-SD 广播 Kazumi 的 HTTP 服务。
///
/// 这一层**不能让** `kazumi.local` 直接被浏览器解析（那是 OS 级 mDNS responder
/// 才能做的，Windows 默认就没有），它做的事是把 `_http._tcp` 服务广播到本地
/// 网络，让支持 DNS-SD 的工具/系统（macOS/iOS 的网络发现、avahi-browse 等）
/// 能看到这台机器在跑 Kazumi。
///
/// 启动失败不致命：调用方应当忽略错误，HTTP 服务本身仍然可用，用户访问 IP 即可。
class LanMdnsBroadcaster {
  BonsoirBroadcast? _broadcast;
  String? _serviceName;

  bool get isBroadcasting => _broadcast != null;

  /// 当前广播的服务名（带 `.local` 后缀风格的提示用，不一定能直接解析）。
  String? get serviceName => _serviceName;

  Future<void> start({required int port}) async {
    if (_broadcast != null) return;
    final service = BonsoirService(
      name: 'Kazumi',
      type: '_http._tcp',
      port: port,
      attributes: const {
        'path': '/',
        'app': 'kazumi',
      },
    );
    final broadcast = BonsoirBroadcast(service: service);
    try {
      await broadcast.ready;
      await broadcast.start();
      _broadcast = broadcast;
      _serviceName = service.name;
      KazumiLogger().i(
          'LanMdnsBroadcaster: started ${service.name} ${service.type}:$port');
    } catch (e, st) {
      KazumiLogger().w('LanMdnsBroadcaster: start failed',
          error: e, stackTrace: st);
      try {
        await broadcast.stop();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> stop() async {
    final broadcast = _broadcast;
    _broadcast = null;
    _serviceName = null;
    if (broadcast == null) return;
    try {
      await broadcast.stop();
    } catch (e) {
      KazumiLogger().w('LanMdnsBroadcaster: stop error: $e');
    }
  }
}
