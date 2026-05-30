import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/update/auto_updater.dart';

part 'my_controller.g.dart';

class MyController = _MyController with _$MyController;

abstract class _MyController with Store {
  Box setting = GStorage.setting;

  @observable
  ObservableList<String> shieldList = ObservableList.of([]);

  bool isDanmakuBlocked(String? danmaku) {
    if (danmaku == null || danmaku.isEmpty) return false;
    for (String item in shieldList) {
      if (item.isEmpty) continue;
      if (item.startsWith('/') && item.endsWith('/')) {
        if (item.length <= 2) continue;
        String pattern = item.substring(1, item.length - 1);
        try {
          if (RegExp(pattern).hasMatch(danmaku)) return true;
        } catch (_) {
          KazumiLogger()
              .e('Danmaku: invalid danmaku shield regex pattern: $pattern');
          continue;
        }
      } else {
        if (danmaku.contains(item)) return true;
      }
    }
    return false;
  }

  void loadShieldList() {
    shieldList.clear();
    shieldList.addAll(GStorage.shieldList.values.toList());
  }

  void addShieldList(String item) {
    if (item.isEmpty) {
      KazumiDialog.showToast(message: 'Please enter a keyword');
      return;
    }
    if (item.length > 64) {
      KazumiDialog.showToast(message: 'Keyword too long');
      return;
    }
    if (shieldList.contains(item)) {
      KazumiDialog.showToast(message: 'This keyword already exists');
      return;
    }
    shieldList.add(item);
    GStorage.shieldList.put(item, item);
    GStorage.shieldList.flush();
  }

  void removeShieldList(String item) {
    shieldList.remove(item);
    GStorage.shieldList.delete(item);
    GStorage.shieldList.flush();
  }

  Future<bool> checkUpdate({String type = 'manual'}) async {
    try {
      final autoUpdater = AutoUpdater();

      if (type == 'manual') {
        await autoUpdater.manualCheckForUpdates();
      } else {
        await autoUpdater.autoCheckForUpdates();
      }

      return true;
    } catch (err) {
      KazumiLogger().e('Update: check update failed', error: err);
      if (type == 'manual') {
        KazumiDialog.showToast(message: 'Failed to check for updates, please try again later');
      }
      return false;
    }
  }
}
