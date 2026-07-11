import 'dart:convert';
import 'dart:math';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';

import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/host_api/host_api_server.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

part 'host_api_controller.g.dart';

class HostApiController = _HostApiController with _$HostApiController;

abstract class _HostApiController with Store {
  late final HostApiServer _server = HostApiServer(
    pluginsProvider: () => Modular.get<PluginsController>(),
  );

  @observable
  bool isRunning = false;

  @observable
  int? port;

  @observable
  String? errorMessage;

  @observable
  String token = '';

  Future<void> start({bool persistPreference = true}) async {
    if (isRunning) return;
    errorMessage = null;
    try {
      final t = _ensureToken();
      token = t;
      // Host API 面向本机外部扩展，端口必须稳定可预期——被占用时直接报错
      // 让用户改端口，而不是降级随机（那会让扩展找不到宿主）。
      final p = GStorage.getSetting(SettingsKeys.hostApiPort);
      await _server.start(port: p, token: t);
      port = _server.port;
      isRunning = true;
      if (persistPreference) {
        await GStorage.putSetting(SettingsKeys.hostApiEnable, true);
      }
    } catch (e, st) {
      KazumiLogger()
          .e('HostApiController: start failed', error: e, stackTrace: st);
      errorMessage = '启动失败：$e';
      isRunning = false;
      port = null;
    }
  }

  Future<void> stop({bool persistPreference = true}) async {
    if (!isRunning) return;
    await _server.stop();
    isRunning = false;
    port = null;
    if (persistPreference) {
      await GStorage.putSetting(SettingsKeys.hostApiEnable, false);
    }
  }

  /// 应用退出时调用，停止服务但不修改用户偏好。
  Future<void> shutdown() async {
    if (!isRunning) return;
    await _server.stop();
    isRunning = false;
    port = null;
  }

  /// 用户修改监听端口；运行中改动需重启服务才生效。
  /// 范围 1024-65535（避开系统保留端口）。
  Future<String?> setPort(int newPort) async {
    if (newPort < 1024 || newPort > 65535) {
      return '端口需在 1024–65535 之间';
    }
    await GStorage.putSetting(SettingsKeys.hostApiPort, newPort);
    return null;
  }

  int get configuredPort => GStorage.getSetting(SettingsKeys.hostApiPort);

  /// 读取已持久化的 token；首次启用时生成并落盘。
  String _ensureToken() {
    final existing = GStorage.getSetting(SettingsKeys.hostApiToken);
    if (existing.isNotEmpty) return existing;
    final fresh = _generateToken();
    GStorage.putSetting(SettingsKeys.hostApiToken, fresh);
    return fresh;
  }

  /// 重置 token。运行中的服务会继续使用旧 token 直到重启——调用方应在
  /// 重置后重启服务（设置页负责这个编排）。
  @action
  Future<String> regenerateToken() async {
    final fresh = _generateToken();
    await GStorage.putSetting(SettingsKeys.hostApiToken, fresh);
    token = fresh;
    return fresh;
  }

  /// 读取当前 token（不生成）。设置页展示用。
  String peekToken() {
    return GStorage.getSetting(SettingsKeys.hostApiToken);
  }

  static String _generateToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
