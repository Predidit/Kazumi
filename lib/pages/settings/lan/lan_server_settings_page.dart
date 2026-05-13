import 'dart:io';

import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/lan/lan_server_controller.dart';

class LanServerSettingsPage extends StatefulWidget {
  const LanServerSettingsPage({super.key});

  @override
  State<LanServerSettingsPage> createState() => _LanServerSettingsPageState();
}

class _LanServerSettingsPageState extends State<LanServerSettingsPage> {
  final LanServerController controller = Modular.get<LanServerController>();

  Future<void> _toggle(bool value) async {
    if (value) {
      await controller.start();
      if (mounted && controller.errorMessage != null) {
        KazumiDialog.showToast(message: controller.errorMessage!);
      }
    } else {
      await controller.stop();
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    KazumiDialog.showToast(message: '已复制 $text');
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(title: Text('局域网 Web 服务（实验性）')),
      body: Observer(builder: (context) {
        final running = controller.isRunning;
        final currentPort = controller.port;
        final addresses = controller.lanAddresses.toList();
        return SettingsList(
          maxWidth: 800,
          sections: [
            SettingsSection(
              title: Text('服务', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await _toggle(value ?? !running);
                  },
                  title: Text('启用 Web 服务',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    running && currentPort != null
                        ? '服务运行中，端口 $currentPort'
                        : '关闭。开启后将在本机随机可用端口监听 HTTP 请求',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  initialValue: running,
                ),
              ],
            ),
            if (running)
              SettingsSection(
                title: Text('访问地址',
                    style: TextStyle(fontFamily: fontFamily)),
                tiles: [
                  if (addresses.isEmpty)
                    SettingsTile(
                      title: Text('未检测到局域网地址',
                          style: TextStyle(fontFamily: fontFamily)),
                      description: Text(
                        '请检查网络连接，或尝试刷新',
                        style: TextStyle(fontFamily: fontFamily),
                      ),
                    )
                  else
                    for (final addr in addresses)
                      SettingsTile.navigation(
                        onPressed: (_) => _copy('http://$addr:$currentPort'),
                        leading: const Icon(Icons.public_rounded),
                        title: Text(
                          'http://$addr:$currentPort',
                          style: TextStyle(fontFamily: fontFamily),
                        ),
                        description: Text(
                          '点击复制',
                          style: TextStyle(fontFamily: fontFamily),
                        ),
                      ),
                  SettingsTile.navigation(
                    onPressed: (_) => controller.refreshAddresses(),
                    leading: const Icon(Icons.refresh_rounded),
                    title: Text('刷新地址列表',
                        style: TextStyle(fontFamily: fontFamily)),
                  ),
                ],
              ),
            SettingsSection(
              title: Text('说明', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  leading: const Icon(Icons.science_rounded),
                  title: Text('实验性功能',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    '让局域网内其他设备的浏览器访问 Kazumi。功能正在逐步完善，目前仅提供基础探活',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                ),
                if (Platform.isWindows)
                  SettingsTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text('无法访问？检查防火墙',
                        style: TextStyle(fontFamily: fontFamily)),
                    description: Text(
                      'Windows 防火墙可能拦截入站连接。首次启动时请在弹窗中允许 Kazumi 通过专用网络，或在「Windows Defender 防火墙 → 允许应用通过防火墙」中勾选 Kazumi',
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
