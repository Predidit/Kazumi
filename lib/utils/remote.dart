import 'dart:async';
import 'dart:io';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../pages/player/player_controller.dart';

class RemotePlay {
  // 注意：仍需开发 iOS/Linux 设备的远程播放功能。
  // 在 Windows 设备上，对于其他可能的实现，使用 scheme 的方案没有效果。VLC / PotPlayer 等主流播放器更倾向于使用 CLI 命令。
  // 可行的 iOS 处理代码，请参见 ios/Runner/AppDelegate.swift 的注释部分。

  static const platform = MethodChannel('com.predidit.kazumi/intent');

  Future<void> castVideo(BuildContext context, String referer) async {
    final searcher = DLNAManager();
    final dlna = await searcher.start();
    final String video = Modular.get<PlayerController>().videoUrl;
    List<Widget> dlnaDevice = [];
    await KazumiDialog.show(builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('远程播放'),
          content: SingleChildScrollView(
            child: Column(
              children: dlnaDevice,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if ((Platform.isAndroid ||
                    Platform.isWindows) && referer.isEmpty) {
                  if (await _launchURLWithMIME(video, 'video/mp4')) {
                    KazumiDialog.dismiss();
                    KazumiDialog.showToast(
                      message: '尝试唤起外部播放器',
                    );
                  } else {
                    KazumiDialog.showToast(
                      message: '唤起外部播放器失败',
                    );
                  }
                } else if (Platform.isMacOS || Platform.isIOS) {
                  if (await _launchURLWithReferer(video, referer)) {
                    KazumiDialog.dismiss();
                    KazumiDialog.showToast(
                      message: '尝试唤起外部播放器',
                    );
                  } else {
                    KazumiDialog.showToast(
                      message: '唤起外部播放器失败',
                    );
                  }
                } else if (Platform.isLinux && referer.isEmpty) {
                  KazumiDialog.dismiss();
                  if (await canLaunchUrlString(video)) {
                    launchUrlString(video);
                    KazumiDialog.showToast(
                      message: '尝试唤起外部播放器',
                    );
                  } else {
                    KazumiDialog.showToast(
                      message: '无法使用外部播放器',
                    );
                  }
                } else {
                  if (referer.isEmpty) {
                    KazumiDialog.showToast(
                      message: '暂不支持该设备',
                    );
                  } else {
                    KazumiDialog.showToast(
                      message: '暂不支持该规则',
                    );
                  }
                }
              },
              child: const Text('外部播放'),
            ),
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
                      debugPrint('Key: $key');
                      debugPrint(
                          'Value: ${value.info.friendlyName} ${value.info.deviceType} ${value.info.URLBase}');
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
                                    .log(Level.error, 'DLNA Error: $e');
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

  Future<bool> _launchURLWithMIME(String url, String mimeType) async {
    try {
      await platform.invokeMethod(
          'openWithMime', <String, String>{'url': url, 'mimeType': mimeType});
      return true;
    } on PlatformException catch (e) {
      KazumiLogger()
          .log(Level.error, "Failed to open with mime: '${e.message}'.");
      return false;
    }
  }

  Future<bool> _launchURLWithReferer(String url, String referer) async {
    try {
      await platform.invokeMethod(
          'openWithReferer', <String, String>{'url': url, 'referer': referer});
      return true;
    } on PlatformException catch (e) {
      KazumiLogger()
          .log(Level.error, "Failed to open with referer: '${e.message}'.");
      return false;
    }
  }
}
