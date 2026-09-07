import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/network_mirror_settings.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/network/proxy_manager.dart';
import 'package:kazumi/services/storage/storage.dart';

class ProxySettingsPage extends StatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  State<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends State<ProxySettingsPage> {
  Future<void> _setProxyEnabled(bool value) async {
    if (value && !GStorage.getSetting(SettingsKeys.proxyConfigured)) {
      KazumiDialog.showToast(message: '请先在代理配置中完成测试');
      return;
    }
    await GStorage.putSetting(SettingsKeys.proxyEnable, value);
    if (value) {
      ProxyManager.applyProxy();
    } else {
      ProxyManager.clearProxy();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final proxyEnabled = GStorage.getSetting(SettingsKeys.proxyEnable);
    return SettingsDetailScaffold(
      title: const Text('网络设置'),
      body: SettingsList(
        sections: [
          NetworkMirrorSettings(
            enableBangumiProxy:
                GStorage.getSetting(SettingsKeys.enableBangumiProxy),
            enableGitProxy: GStorage.getSetting(SettingsKeys.enableGitProxy),
            onBangumiChanged: (value) async {
              await GStorage.putSetting(SettingsKeys.enableBangumiProxy, value);
              if (mounted) setState(() {});
            },
            onGitChanged: (value) async {
              await GStorage.putSetting(SettingsKeys.enableGitProxy, value);
              if (mounted) setState(() {});
            },
          ),
          SettingsSection(
            title: const Text('代理'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.vpn_key_rounded,
                onToggle: (value) => _setProxyEnabled(value ?? !proxyEnabled),
                title: const Text('启用代理'),
                description: const Text('启用后网络请求将通过代理服务器'),
                initialValue: proxyEnabled,
              ),
              SettingsTile(
                leading: Icons.tune_rounded,
                onPressed: (_) async {
                  await context.pushNamed('/settings/proxy/editor');
                  if (mounted) setState(() {});
                },
                title: const Text('代理配置'),
                description: const Text('配置代理服务器地址和认证信息'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
