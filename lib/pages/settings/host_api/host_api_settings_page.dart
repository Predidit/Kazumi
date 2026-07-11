import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/host_api/host_api_controller.dart';
import 'package:kazumi/services/host_api/host_api_server.dart';

class HostApiSettingsPage extends StatefulWidget {
  const HostApiSettingsPage({super.key});

  @override
  State<HostApiSettingsPage> createState() => _HostApiSettingsPageState();
}

class _HostApiSettingsPageState extends State<HostApiSettingsPage> {
  final HostApiController controller = inject<HostApiController>();
  bool _tokenVisible = false;

  Future<void> _toggle(bool value) async {
    if (value) {
      await controller.start();
      if (mounted && controller.errorMessage != null) {
        KazumiDialog.showToast(message: controller.errorMessage!);
      }
    } else {
      await controller.stop();
    }
    if (mounted) setState(() {});
  }

  Future<void> _copy(String text, {String? hint}) async {
    await Clipboard.setData(ClipboardData(text: text));
    KazumiDialog.showToast(message: hint ?? '已复制');
  }

  String _maskToken(String token) {
    if (token.isEmpty) return '未生成（启用服务时自动生成）';
    if (!_tokenVisible) {
      final head = token.length >= 6 ? token.substring(0, 6) : token;
      return '$head••••••••••••';
    }
    return token;
  }

  Future<void> _regenerateToken() async {
    KazumiDialog.show(builder: (dialogContext) {
      return AlertDialog(
        title: const Text('重置 Token'),
        content: const Text(
            '重置后所有已配置旧 Token 的外部扩展都需要重新填写。'
            '若服务正在运行将自动重启以生效。确认重置吗？'),
        actions: [
          TextButton(
            onPressed: KazumiDialog.dismiss,
            child: Text(
              '取消',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              KazumiDialog.dismiss();
              final wasRunning = controller.isRunning;
              if (wasRunning) {
                await controller.stop(persistPreference: false);
              }
              await controller.regenerateToken();
              if (wasRunning) {
                await controller.start(persistPreference: false);
              }
              if (mounted) setState(() {});
              KazumiDialog.showToast(message: '已重置 Token');
            },
            child: const Text('确认'),
          ),
        ],
      );
    });
  }

  Future<void> _editPort() async {
    final textController =
        TextEditingController(text: controller.configuredPort.toString());
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    KazumiDialog.show(builder: (dialogContext) {
      return AlertDialog(
        title: Text('监听端口', style: TextStyle(fontFamily: fontFamily)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '端口号',
                hintText: '1024–65535',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.isRunning ? '保存后需要重启服务才能生效' : '保存后下次启动服务时生效',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: KazumiDialog.dismiss,
            child: Text('取消',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontFamily: fontFamily)),
          ),
          TextButton(
            onPressed: () async {
              final value = int.tryParse(textController.text.trim());
              if (value == null) {
                KazumiDialog.showToast(message: '请输入数字');
                return;
              }
              final err = await controller.setPort(value);
              if (err != null) {
                KazumiDialog.showToast(message: err);
                return;
              }
              KazumiDialog.dismiss();
              if (mounted) setState(() {});
              KazumiDialog.showToast(
                message: controller.isRunning ? '已保存。重启服务后生效' : '已保存：$value',
              );
            },
            child: Text('保存', style: TextStyle(fontFamily: fontFamily)),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(title: Text('外部扩展 API（实验性）')),
      body: Observer(builder: (context) {
        final running = controller.isRunning;
        final currentPort = controller.port;
        final token = running ? controller.token : controller.peekToken();
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
                  title: Text('启用 Host API',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    running && currentPort != null
                        ? '运行中，监听 127.0.0.1:$currentPort'
                        : '关闭。开启后在本机 127.0.0.1:${controller.configuredPort} '
                            '为外部扩展提供接口，不对局域网开放',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  initialValue: running,
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.numbers_rounded),
                  title: Text('监听端口', style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    running && currentPort != null
                        ? '当前监听 $currentPort'
                        : '配置值 ${controller.configuredPort}',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onPressed: (_) => _editPort(),
                ),
              ],
            ),
            SettingsSection(
              title: Text('访问凭证', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  leading: const Icon(Icons.key_rounded),
                  title: Text('Token', style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    _maskToken(token),
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  trailing: Icon(_tokenVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: (_) {
                    setState(() => _tokenVisible = !_tokenVisible);
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text('复制 Token',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    '外部扩展需要用它连接 Host API',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  onPressed: (_) {
                    if (token.isEmpty) {
                      KazumiDialog.showToast(message: '尚未生成 Token，请先启用服务');
                      return;
                    }
                    _copy(token, hint: '已复制 Token');
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: Text('重置 Token',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    '旧 Token 立即失效，已配置的扩展需重新填写',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                  onPressed: (_) => _regenerateToken(),
                ),
              ],
            ),
            SettingsSection(
              title: Text('说明', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  leading: const Icon(Icons.extension_rounded),
                  title: Text('这是什么？',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    'Host API（协议版本 $hostApiLevel）将 Kazumi 的检索、视频源解析、'
                    '收藏与历史等能力以本机接口的形式提供给外部扩展程序使用，'
                    '例如局域网 Web 服务扩展。它只监听本机回环地址，'
                    '不会对局域网或互联网暴露任何内容',
                    style: TextStyle(fontFamily: fontFamily),
                  ),
                ),
                SettingsTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text('安全提示',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text(
                    '持有 Token 的本机程序可以读取你的收藏与观看历史。'
                    '请只将 Token 提供给你信任的扩展程序',
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
