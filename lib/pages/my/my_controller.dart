import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/request/api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';

class MyController {
  Future<bool> checkUpdata({String type = 'manual'}) async {
    Utils.latest().then((value) {
      if (Api.version == value) {
        if (type == 'manual') {
          KazumiDialog.showToast(message:  '当前已经是最新版本！');
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
