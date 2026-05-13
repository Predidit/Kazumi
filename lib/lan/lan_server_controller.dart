import 'dart:io';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';

import 'package:kazumi/lan/lan_mdns_broadcaster.dart';
import 'package:kazumi/lan/lan_server.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';

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
      await _server.start();
      port = _server.port;
      isRunning = true;
      hostname = _resolveHostname();
      await refreshAddresses();
      await _tryStartMdns();
      if (persistPreference) {
        await GStorage.setting.put(SettingBoxKey.lanServerEnable, true);
      }
    } catch (e, st) {
      KazumiLogger()
          .e('LanServerController: start failed', error: e, stackTrace: st);
      errorMessage = '启动失败：$e';
      isRunning = false;
      port = null;
    }
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
      await GStorage.setting.put(SettingBoxKey.lanServerEnable, false);
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
