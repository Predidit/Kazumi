import 'dart:io';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';

import 'package:kazumi/lan/lan_mdns_broadcaster.dart';
import 'package:kazumi/lan/lan_server.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

part 'lan_server_controller.g.dart';

class LanServerController = _LanServerController with _$LanServerController;

abstract class _LanServerController with Store {
  late final LanServer _server = LanServer(
    pluginsProvider: () => Modular.get<PluginsController>(),
  );

  final LanMdnsBroadcaster _mdns = LanMdnsBroadcaster();

  @observable
  bool isRunning = false;

  @observable
  int? port;

  @observable
  ObservableList<String> lanAddresses = ObservableList.of([]);

  @observable
  String? errorMessage;

  /// 本机的 OS 主机名。macOS / 多数 Linux 发行版上 `<host>.local` 通常可被
  /// 同网设备解析；Windows 默认不能，但保留下来作为引导文案。
  @observable
  String? hostname;

  @observable
  bool mdnsBroadcasting = false;

  Future<void> start({bool persistPreference = true}) async {
    if (isRunning) return;
    errorMessage = null;
    try {
      // 端口策略：
      //   1. 读取持久化的偏好端口（首次为 0）；
      //   2. 用偏好端口尝试启动；若被占用 (SocketException) 且偏好端口非 0，
      //      降级到 port=0 让 OS 随机；
      //   3. 启动成功后把实际监听端口写回 setting，下次启动直接复用。
      final preferred = _readPreferredPort();
      try {
        await _server.start(port: preferred);
      } on SocketException catch (e) {
        if (preferred == 0) rethrow;
        KazumiLogger().w(
            'LanServerController: preferred port $preferred unavailable ($e), falling back to random');
        await _server.start(port: 0);
        errorMessage = '端口 $preferred 被占用，已临时改用随机端口';
      }
      port = _server.port;
      isRunning = true;
      if (port != null && port! > 0) {
        await GStorage.putSetting(SettingsKeys.lanServerPort, port!);
      }
      hostname = _resolveHostname();
      await refreshAddresses();
      await _tryStartMdns();
      if (persistPreference) {
        await GStorage.putSetting(SettingsKeys.lanServerEnable, true);
      }
    } catch (e, st) {
      KazumiLogger()
          .e('LanServerController: start failed', error: e, stackTrace: st);
      errorMessage = '启动失败：$e';
      isRunning = false;
      port = null;
    }
  }

  int _readPreferredPort() {
    final raw = GStorage.getSetting(SettingsKeys.lanServerPort);
    if (raw >= 1024 && raw <= 65535) return raw;
    return 0;
  }

  /// 用户在设置页给出的"想要的端口"。null 表示从未持久化（首次状态）。
  int? get preferredPort {
    final raw = GStorage.getSetting(SettingsKeys.lanServerPort);
    if (raw >= 1024 && raw <= 65535) return raw;
    return null;
  }

  /// 用户手动修改偏好端口；运行中改动需重启服务才生效。
  /// 范围 1024-65535（避开系统保留端口）。
  Future<String?> setPreferredPort(int newPort) async {
    if (newPort < 1024 || newPort > 65535) {
      return '端口需在 1024–65535 之间';
    }
    await GStorage.putSetting(SettingsKeys.lanServerPort, newPort);
    return null;
  }

  Future<void> stop({bool persistPreference = true}) async {
    if (!isRunning) return;
    await _mdns.stop();
    mdnsBroadcasting = false;
    await _server.stop();
    isRunning = false;
    port = null;
    hostname = null;
    lanAddresses.clear();
    if (persistPreference) {
      await GStorage.putSetting(SettingsKeys.lanServerEnable, false);
    }
  }

  Future<void> _tryStartMdns() async {
    final currentPort = port;
    if (currentPort == null) return;
    try {
      await _mdns.start(port: currentPort);
      mdnsBroadcasting = true;
    } catch (e) {
      // 不致命：Windows 上没装 Bonjour、或网络受限都会导致这里失败。
      // HTTP 服务本身仍可正常工作，用户访问 IP 即可。
      KazumiLogger().w('LanServerController: mDNS broadcast unavailable: $e');
      mdnsBroadcasting = false;
    }
  }

  String? _resolveHostname() {
    try {
      final raw = Platform.localHostname;
      if (raw.isEmpty) return null;
      return raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshAddresses() async {
    final addrs = await LanServer.enumerateLanIPv4();
    lanAddresses
      ..clear()
      ..addAll(addrs);
  }

  /// 应用退出时调用，停止服务但不修改用户偏好。
  Future<void> shutdown() async {
    if (!isRunning) return;
    await _mdns.stop();
    mdnsBroadcasting = false;
    await _server.stop();
    isRunning = false;
    port = null;
    hostname = null;
    lanAddresses.clear();
  }
}
