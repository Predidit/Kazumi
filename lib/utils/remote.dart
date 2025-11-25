import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/logger.dart';

class RemotePlay {
  Future<void> castVideo(String video, String referer) async {
    final searcher = DLNAManager();
    final dlna = await searcher.start();
    List<Widget> dlnaDevice = [];
    await KazumiDialog.show(builder: (BuildContext context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('远程投屏'),
          content: SingleChildScrollView(
            child: Column(
              children: dlnaDevice,
            ),
          ),
          actions: [
            const SizedBox(width: 20),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '退出',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
                onPressed: () {
                  setState(() {});
                  KazumiDialog.showToast(
                    message: '开始搜索',
                  );
                  dlna.devices.stream.listen((deviceList) {
                    dlnaDevice = [];
                    deviceList.forEach((key, value) async {
                      KazumiLogger().i('RemotePlay: key: $key');
                      KazumiLogger().i(
                          'RemotePlay: value: ${value.info.friendlyName} ${value.info.deviceType} ${value.info.URLBase}');
                      setState(() {
                        dlnaDevice.add(ListTile(
                            leading: _deviceUPnPIcon(
                                value.info.deviceType.split(':')[3]),
                            title: Text(value.info.friendlyName),
                            subtitle: Text(value.info.deviceType.split(':')[3]),
                            onTap: () {
                              try {
                                KazumiDialog.showToast(
                                  message: '尝试投屏至 ${value.info.friendlyName}',
                                );
                                DLNADevice(value.info).setUrl(video);
                                DLNADevice(value.info).play();
                              } catch (e) {
                                KazumiLogger()
                                    .e('RemotePlay: failed to cast to device', error: e);
                                KazumiDialog.showToast(
                                  message: 'DLNA 异常: $e \n尝试重新进入 DLNA 投屏或切换设备',
                                );
                              }
                            }));
                      });
                    });
                  });
                  // Timer(const Duration(seconds: 30), () {
                  //   KazumiDialog.showToast(
                  //     message: '已搜索30s，若未发现设备请尝试重新进入 DLNA 投屏',
                  //   );
                  // });
                },
                child: Text(
                  '搜索',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                )),
          ],
        );
      });
    }, onDismiss: () {
      searcher.stop();
    });
  }

  Icon _deviceUPnPIcon(String deviceType) {
    switch (deviceType) {
      case 'MediaRenderer':
        return const Icon(Icons.cast_connected);
      case 'MediaServer':
        return const Icon(Icons.cast_connected);
      case 'InternetGatewayDevice':
        return const Icon(Icons.router);
      case 'BasicDevice':
        return const Icon(Icons.device_hub);
      case 'DimmableLight':
        return const Icon(Icons.lightbulb);
      case 'WLANAccessPoint':
        return const Icon(Icons.lan);
      case 'WLANConnectionDevice':
        return const Icon(Icons.wifi_tethering);
      case 'Printer':
        return const Icon(Icons.print);
      case 'Scanner':
        return const Icon(Icons.scanner);
      case 'DigitalSecurityCamera':
        return const Icon(Icons.camera_enhance_outlined);
      default:
        return const Icon(Icons.question_mark);
    }
  }
}
