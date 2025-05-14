import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/request/api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';

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
          KazumiLogger().log(Level.error, '无效的弹幕屏蔽正则表达式: $pattern');
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
      KazumiDialog.showToast(message: '请输入关键词');
      return;
    }
    if (item.length > 64) {
      KazumiDialog.showToast(message: '关键词过长');
      return;
    }
    if (shieldList.contains(item)) {
      KazumiDialog.showToast(message: '已存在该关键词');
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

  Future<bool> checkUpdata({String type = 'manual'}) async {
    Utils.latest().then((value) {
      if (Api.version == value) {
        if (type == 'manual') {
          KazumiDialog.showToast(message: '当前已经是最新版本！');
        }
      } else {
        KazumiDialog.show(
          builder: (context) {
            return AlertDialog(
              title: Text('发现新版本 $value'),
              actions: [
                TextButton(
                  onPressed: () => KazumiDialog.dismiss(),
                  child: Text(
                    '稍后',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      launchUrl(Uri.parse("${Api.sourceUrl}/releases/latest")),
                  child: const Text('Github'),
                ),
              ],
            );
          },
        );
      }
    }).catchError((err) {
      KazumiLogger().log(Level.error, '检查更新失败 ${err.toString()}');
      if (type == 'manual') {
        KazumiDialog.showToast(message: '当前是最新版本！');
      }
    });
    return true;
  }
}
