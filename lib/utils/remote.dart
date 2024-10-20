import 'dart:async';
import 'dart:io';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../pages/player/player_controller.dart';

class RemotePlay {
  // 注意：仍需开发 iOS/macOS/Linux 设备的远程播放功能。
  // 在 Windows 设备上，对于其他可能的实现，使用 scheme 的方案没有效果。VLC / PotPlayer 等主流播放器更倾向于使用 CLI 命令。
  // 而对于 iOS / Mac 设备，由于没有设备，无法进行开发与验证。
  // 可行的 iOS / Mac 处理代码，请参见 ios/Runner/AppDelegate.swift 的注释部分。

  static const platform = MethodChannel('com.predidit.kazumi/intent');

  castVideo(BuildContext context) async {
    final searcher = DLNAManager();
    final dlna = await searcher.start();
    final String video = Modular.get<PlayerController>().videoUrl;
    List<Widget> dlnaDevice = [];
    SmartDialog.show(
        useAnimation: false,
        builder: (context) {
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
                    if (Platform.isAndroid || Platform.isWindows || Platform.isMacOS || Platform.isIOS) {
                      if (await _launchURLWithMIME(video, 'video/mp4')) {
                        SmartDialog.dismiss();
                        SmartDialog.showToast('尝试唤起外部播放器',
                            displayType: SmartToastType.onlyRefresh);
                      } else {
                        SmartDialog.showToast('唤起外部播放器失败',
                            displayType: SmartToastType.onlyRefresh);
                      }
                    } else if (Platform.isLinux) {
                      SmartDialog.dismiss();
                      if (await canLaunchUrlString(video)) {
                        launchUrlString(video);
                        SmartDialog.showToast('尝试唤起外部播放器',
                            displayType: SmartToastType.onlyRefresh);
                      } else {
                        SmartDialog.showToast('无法使用外部播放器',
                            displayType: SmartToastType.onlyRefresh);
                      }
                    } else {
                      SmartDialog.showToast('暂不支持该设备',
                          displayType: SmartToastType.onlyRefresh);
                    }
                  },
                  child: const Text('外部播放'),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () {
                    SmartDialog.dismiss();
                  },
                  child: Text(
                    '退出',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                TextButton(
                    onPressed: () {
                      setState(() {});
                      SmartDialog.showToast('开始搜索',
                          displayType: SmartToastType.onlyRefresh);
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
                                subtitle:
                                    Text(value.info.deviceType.split(':')[3]),
                                onTap: () {
                                  try {
                                    SmartDialog.showToast(
                                        '尝试投屏至 ${value.info.friendlyName}',
                                        displayType:
                                            SmartToastType.onlyRefresh);
                                    DLNADevice(value.info).setUrl(video);
                                    DLNADevice(value.info).play();
                                  } catch (e) {
                                    KazumiLogger()
                                        .log(Level.error, 'DLNA Error: $e');
                                    SmartDialog.showNotify(
                                        msg:
                                            'DLNA 异常: $e \n尝试重新进入 DLNA 投屏或切换设备',
                                        notifyType: NotifyType.alert);
                                  }
                                }));
                          });
                        });
                      });
                      Timer(const Duration(seconds: 30), () {
                        SmartDialog.showToast(
                          '已搜索30s，若未发现设备请尝试重新进入 DLNA 投屏',
                          displayType: SmartToastType.onlyRefresh,
                        );
                      });
                    },
                    child: Text(
                      '搜索',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline),
                    )),
              ],
            );
          });
        }).then((_) {
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
}
