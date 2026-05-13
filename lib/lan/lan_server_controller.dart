import 'package:mobx/mobx.dart';

import 'package:kazumi/lan/lan_server.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';

part 'lan_server_controller.g.dart';

class LanServerController = _LanServerController with _$LanServerController;

abstract class _LanServerController with Store {
  final LanServer _server = LanServer();

  @observable
  bool isRunning = false;

  @observable
  int? port;

  @observable
  ObservableList<String> lanAddresses = ObservableList.of([]);

  @observable
  String? errorMessage;

  Future<void> start({bool persistPreference = true}) async {
    if (isRunning) return;
    errorMessage = null;
    try {
      await _server.start();
      port = _server.port;
      isRunning = true;
      await refreshAddresses();
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
    await _server.stop();
    isRunning = false;
    port = null;
    lanAddresses.clear();
    if (persistPreference) {
      await GStorage.setting.put(SettingBoxKey.lanServerEnable, false);
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
    await _server.stop();
    isRunning = false;
    port = null;
    lanAddresses.clear();
  }
}
